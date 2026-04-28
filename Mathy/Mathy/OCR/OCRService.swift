import Foundation

final class OCRService {
    private let session = URLSession.shared

    struct PredictResponse: Decodable {
        let latex: String
    }

    struct ErrorResponse: Decodable {
        let detail: String
    }

    func predict(imageURL: URL) async throws -> String {
        let url = URL(string: "\(Constants.serverBaseURL)/predict")!
        let imageData = try Data(contentsOf: imageURL)

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"capture.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw OCRError.serverError(errorResp.detail)
            }
            throw OCRError.httpError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(PredictResponse.self, from: data)
        return result.latex
    }

    enum OCRError: LocalizedError {
        case invalidResponse
        case httpError(Int)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from server"
            case .httpError(let code): return "HTTP error \(code)"
            case .serverError(let msg): return "Server error: \(msg)"
            }
        }
    }
}
