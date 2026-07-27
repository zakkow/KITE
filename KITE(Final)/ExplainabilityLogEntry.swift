import Foundation

struct ExplainabilityLogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var fromKey: String
    var toKey: String
    var mechanism: String
    var confidence: Double
}

enum ExplainabilityLogStore {
    static let maxEntriesRetained = 50
    private static var inMemoryCache: [ExplainabilityLogEntry]? = nil

    static func load() -> [ExplainabilityLogEntry] {
        if let cached = inMemoryCache { return cached }
        guard let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.explainabilityLog),
              let entries = try? JSONDecoder().decode([ExplainabilityLogEntry].self, from: data) else { return [] }
        inMemoryCache = entries
        return entries
    }

    static func append(_ entry: ExplainabilityLogEntry) {
        var entries = load()
        entries.append(entry)
        if entries.count > maxEntriesRetained {
            entries.removeFirst(entries.count - maxEntriesRetained)
        }
        inMemoryCache = entries

        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(entries) else { return }
            SharedStore.defaults?.set(data, forKey: SharedStore.Keys.explainabilityLog)
        }
    }
}
