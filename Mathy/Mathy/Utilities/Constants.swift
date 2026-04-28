import Foundation

enum Constants {
    static let serverPort = 8765
    static let serverBaseURL = "http://127.0.0.1:\(serverPort)"

    static var appSupportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mathy")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
