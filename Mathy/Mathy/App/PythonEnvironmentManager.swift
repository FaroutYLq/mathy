import Foundation

@MainActor
final class PythonEnvironmentManager: ObservableObject {
    enum SetupStage: Equatable {
        case idle
        case checkingPython
        case creatingVenv
        case installingDeps
        case verifying
        case ready
        case failed(String)
    }

    @Published var stage: SetupStage = .idle
    @Published var installLog: String = ""

    static var venvDirectory: URL {
        Constants.appSupportDirectory.appendingPathComponent("venv")
    }

    static var venvPython: String {
        venvDirectory.appendingPathComponent("bin/python3").path
    }

    private static var venvPip: String {
        venvDirectory.appendingPathComponent("bin/pip3").path
    }

    /// Quick check: is a working venv with pix2tex already set up?
    func checkExistingSetup() async -> Bool {
        guard FileManager.default.isExecutableFile(atPath: Self.venvPython) else { return false }
        let (status, _) = await runProcess(Self.venvPython, arguments: ["-c", "import pix2tex"])
        return status == 0
    }

    func findSystemPython() async -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let (status, output) = await runProcess("/usr/bin/which", arguments: ["python3"])
        if status == 0 {
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    func runSetup() async {
        stage = .checkingPython
        installLog = ""

        // Step 1: Find system Python
        appendLog("Looking for Python 3...")
        guard let systemPython = await findSystemPython() else {
            stage = .failed(
                "Python 3 not found on your system.\n\n"
                + "Install via Homebrew:\n"
                + "  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
                + "  brew install python3\n\n"
                + "Or download from https://www.python.org/downloads/"
            )
            return
        }
        appendLog("Found Python at: \(systemPython)")

        // Step 2: Create venv
        stage = .creatingVenv
        appendLog("Creating Python environment...")
        let venvPath = Self.venvDirectory.path

        // Remove broken venv if exists
        if FileManager.default.fileExists(atPath: venvPath) {
            try? FileManager.default.removeItem(atPath: venvPath)
        }

        let (venvStatus, venvOutput) = await runProcess(systemPython, arguments: ["-m", "venv", venvPath])
        if venvStatus != 0 {
            stage = .failed("Failed to create Python environment:\n\(venvOutput)")
            return
        }
        appendLog("Environment created.")

        // Step 3: Install dependencies
        stage = .installingDeps
        appendLog("Installing pix2tex and dependencies...")
        appendLog("This may take a few minutes on first run.\n")

        // Upgrade pip quietly
        let _ = await runProcessStreaming(Self.venvPip, arguments: ["install", "--upgrade", "pip"])

        // Install from bundled requirements.txt or inline list
        var installArgs = ["install"]
        if let reqPath = Bundle.main.path(forResource: "requirements", ofType: "txt") {
            installArgs += ["-r", reqPath]
        } else {
            installArgs += ["pix2tex", "fastapi", "uvicorn[standard]", "python-multipart", "Pillow"]
        }

        let (installStatus, _) = await runProcessStreaming(Self.venvPip, arguments: installArgs)
        if installStatus != 0 {
            stage = .failed("Installation failed. Check the log for details.")
            return
        }

        // Step 4: Verify
        stage = .verifying
        appendLog("\nVerifying installation...")
        let (verifyStatus, _) = await runProcess(Self.venvPython, arguments: ["-c", "import pix2tex; print('OK')"])
        if verifyStatus != 0 {
            stage = .failed("Verification failed — pix2tex could not be imported.")
            return
        }
        appendLog("Setup complete!")
        stage = .ready
    }

    /// Delete the managed venv so setup can run fresh.
    func resetEnvironment() {
        let venvPath = Self.venvDirectory.path
        try? FileManager.default.removeItem(atPath: venvPath)
        stage = .idle
        installLog = ""
    }

    // MARK: - Process Helpers

    private func runProcess(_ executable: String, arguments: [String]) async -> (Int32, String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (proc.terminationStatus, output))
                } catch {
                    continuation.resume(returning: (-1, error.localizedDescription))
                }
            }
        }
    }

    private func runProcessStreaming(_ executable: String, arguments: [String]) async -> (Int32, String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                var fullOutput = ""
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        fullOutput += str
                        Task { @MainActor in
                            self?.installLog += str
                        }
                    }
                }

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: (proc.terminationStatus, fullOutput))
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: (-1, error.localizedDescription))
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        installLog += text + (text.hasSuffix("\n") ? "" : "\n")
    }
}
