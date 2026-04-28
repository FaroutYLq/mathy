import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [ConversionRecord] = []

    private let maxRecords = 100
    private let fileManager = FileManager.default
    private var historyFileURL: URL {
        Constants.appSupportDirectory.appendingPathComponent("history.json")
    }

    init() {
        load()
    }

    func add(_ record: ConversionRecord) {
        records.insert(record, at: 0)
        pruneIfNeeded()
        save()
    }

    func remove(at offsets: IndexSet) {
        let toRemove = offsets.map { records[$0] }
        for record in toRemove {
            try? fileManager.removeItem(atPath: record.imagePath)
        }
        records.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        for record in records {
            try? fileManager.removeItem(atPath: record.imagePath)
        }
        records.removeAll()
        save()
    }

    private func pruneIfNeeded() {
        while records.count > maxRecords {
            let removed = records.removeLast()
            try? fileManager.removeItem(atPath: removed.imagePath)
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            records = try JSONDecoder().decode([ConversionRecord].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    private func save() {
        try? fileManager.createDirectory(
            at: Constants.appSupportDirectory,
            withIntermediateDirectories: true
        )
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
}
