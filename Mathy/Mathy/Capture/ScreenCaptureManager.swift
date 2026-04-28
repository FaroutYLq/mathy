import AppKit

final class ScreenCaptureManager: @unchecked Sendable {
    private let fileManager = FileManager.default

    /// Uses AppleScript to invoke the system screenshot UI (same as Cmd+Shift+4).
    /// This avoids TCC permission issues since the screenshot is handled by the
    /// system's screencapture process, not our app.
    func captureRegion() async -> URL? {
        let tempDir = fileManager.temporaryDirectory
        let filename = "mathy_capture_\(UUID().uuidString).png"
        let outputURL = tempDir.appendingPathComponent(filename)
        let path = outputURL.path

        // Use `do shell script` so screencapture runs as an independent process,
        // not as a child of our app — avoids inheriting our TCC context.
        let script = """
        do shell script "/usr/sbin/screencapture -i -s " & quoted form of "\(path)"
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let fm = FileManager.default
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                appleScript?.executeAndReturnError(&error)

                if let error {
                    print("screencapture failed: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard fm.fileExists(atPath: path) else {
                    continuation.resume(returning: nil)
                    return
                }

                let persistentURL = self.saveToPersistentStorage(tempURL: outputURL)
                continuation.resume(returning: persistentURL ?? outputURL)
            }
        }
    }

    private func saveToPersistentStorage(tempURL: URL) -> URL? {
        let imagesDir = Constants.appSupportDirectory.appendingPathComponent("images")
        try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let filename = "capture_\(Date().timeIntervalSince1970).png"
        let destURL = imagesDir.appendingPathComponent(filename)

        do {
            try fileManager.copyItem(at: tempURL, to: destURL)
            try? fileManager.removeItem(at: tempURL)
            return destURL
        } catch {
            print("Failed to save capture: \(error)")
            return nil
        }
    }
}
