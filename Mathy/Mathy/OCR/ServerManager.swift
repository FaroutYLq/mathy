import Foundation
import Combine

@MainActor
final class ServerManager: ObservableObject {
    enum Status {
        case stopped, starting, running, error
    }

    @Published var status: Status = .stopped

    private var process: Process?
    private var healthCheckTimer: Timer?
    private var restartCount = 0
    private let maxRestarts = 3

    func start() {
        guard status != .running, status != .starting else { return }
        status = .starting
        restartCount = 0

        // Check if server is already running (e.g. started manually)
        Task {
            if await isServerAlreadyRunning() {
                print("[ServerManager] Server already running on port \(Constants.serverPort)")
                status = .running
                return
            }
            launchServer()
        }
    }

    private func isServerAlreadyRunning() async -> Bool {
        guard let url = URL(string: "\(Constants.serverBaseURL)/health") else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return false
            }
            struct HealthResponse: Decodable {
                let status: String
                let model_loaded: Bool
            }
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.model_loaded
        } catch {
            return false
        }
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil
        status = .stopped
    }

    private func launchServer() {
        let pythonPath = findPython()
        guard let pythonPath else {
            print("Python not found")
            status = .error
            return
        }

        let serverScript = findServerScript()
        guard let serverScript else {
            print("Server script not found")
            status = .error
            return
        }

        print("[ServerManager] Launching: \(pythonPath) \(serverScript)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [serverScript, String(Constants.serverPort)]

        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                print("[mathy-server] \(str)", terminator: "")
            }
        }

        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self, self.status != .stopped else { return }
                self.process = nil

                if self.restartCount < self.maxRestarts {
                    self.restartCount += 1
                    let delay = Double(self.restartCount) * 2.0
                    print("Server crashed. Restarting in \(delay)s (attempt \(self.restartCount)/\(self.maxRestarts))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self.launchServer()
                } else {
                    self.status = .error
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            startHealthPolling()
        } catch {
            print("Failed to launch server: \(error)")
            status = .error
        }
    }

    private func startHealthPolling() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkHealth()
            }
        }
    }

    private func checkHealth() async {
        guard let url = URL(string: "\(Constants.serverBaseURL)/health") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return
            }

            struct HealthResponse: Decodable {
                let status: String
                let model_loaded: Bool
            }

            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            if health.model_loaded {
                status = .running
                healthCheckTimer?.invalidate()
                healthCheckTimer = nil
            }
        } catch {
            // Server not ready yet, keep polling
        }
    }

    /// Resolves the project root by walking up from known paths.
    private static func findProjectRoot() -> URL? {
        // Try SOURCE_ROOT env (set by Xcode builds)
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            // SOURCE_ROOT points to Mathy/, go up one level
            let candidate = URL(fileURLWithPath: sourceRoot).deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("server/mathy_server.py").path) {
                return candidate
            }
            // Or SOURCE_ROOT is already the project root
            if FileManager.default.fileExists(atPath: URL(fileURLWithPath: sourceRoot).appendingPathComponent("server/mathy_server.py").path) {
                return URL(fileURLWithPath: sourceRoot)
            }
        }

        // Walk up from the executable/bundle location
        var dir = Bundle.main.bundleURL
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("server/mathy_server.py").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }

        return nil
    }

    private func findPython() -> String? {
        // 1. Managed venv (auto-installed by onboarding)
        let managedPython = PythonEnvironmentManager.venvPython
        if FileManager.default.isExecutableFile(atPath: managedPython) {
            print("[ServerManager] Using managed Python: \(managedPython)")
            return managedPython
        }

        // 2. User-specified path
        let userDefault = UserDefaults.standard.string(forKey: "pythonPath")
        if let userDefault, !userDefault.isEmpty, FileManager.default.isExecutableFile(atPath: userDefault) {
            return userDefault
        }

        // 3. Project venv (developer workflow)
        var candidates = [String]()
        if let root = Self.findProjectRoot() {
            candidates.append(root.appendingPathComponent(".venv/bin/python3").path)
        }

        candidates += [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                print("[ServerManager] Found Python at: \(path)")
                return path
            }
        }

        // 4. Fallback: `which python3`
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["python3"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let output, !output.isEmpty {
            print("[ServerManager] Found Python via which: \(output)")
            return output
        }

        return nil
    }

    private func findServerScript() -> String? {
        // Check bundled copy first
        if let bundled = Bundle.main.path(forResource: "mathy_server", ofType: "py") {
            return bundled
        }

        // Check project root
        if let root = Self.findProjectRoot() {
            let path = root.appendingPathComponent("server/mathy_server.py").path
            if FileManager.default.fileExists(atPath: path) {
                print("[ServerManager] Found server script at: \(path)")
                return path
            }
        }

        return nil
    }
}
