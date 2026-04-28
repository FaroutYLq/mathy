import Foundation

struct ConversionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let latex: String
    let timestamp: Date
    let imagePath: String

    init(id: UUID = UUID(), latex: String, timestamp: Date = Date(), imagePath: String) {
        self.id = id
        self.latex = latex
        self.timestamp = timestamp
        self.imagePath = imagePath
    }
}
