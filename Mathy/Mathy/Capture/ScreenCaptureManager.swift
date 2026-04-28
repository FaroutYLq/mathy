import Foundation

final class ScreenCaptureManager {
    private let fileManager = FileManager.default

    /// Invokes the native macOS screencapture tool for interactive region selection.
    /// Returns the URL of the captured PNG, or nil if the user cancelled.
    func captureRegion() async -> URL? {
        let tempDir = fileManager.temporaryDirectory
        let filename = "mathy_capture_\(UUID().uuidString).png"
        let outputURL = tempDir.appendingPathComponent(filename)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", outputURL.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("screencapture failed: \(error)")
            return nil
        }

        guard process.terminationStatus == 0,
              fileManager.fileExists(atPath: outputURL.path) else {
            return nil
        }

        // Copy to persistent storage
        let persistentURL = saveToPersistentStorage(tempURL: outputURL)
        return persistentURL ?? outputURL
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
