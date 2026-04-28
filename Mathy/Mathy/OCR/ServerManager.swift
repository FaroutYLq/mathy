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
        launchServer()
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

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [serverScript, String(Constants.serverPort)]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

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

    private func findPython() -> String? {
        let userDefault = UserDefaults.standard.string(forKey: "pythonPath")
        if let userDefault, FileManager.default.isExecutableFile(atPath: userDefault) {
            return userDefault
        }

        // Check common paths
        let candidates = [
            // Project venv
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".venv/bin/python3").path,
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try `which python3`
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
            return output
        }

        return nil
    }

    private func findServerScript() -> String? {
        // Check bundled copy first
        if let bundled = Bundle.main.path(forResource: "mathy_server", ofType: "py") {
            return bundled
        }

        // Check project directory (development)
        let devPath = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("server/mathy_server.py").path

        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return nil
    }
}
