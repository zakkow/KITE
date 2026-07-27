import Foundation

/// Reads historical correction data for confusion-pair analysis.
enum ConfusionPairAnalyzer {
    static func mostConfusedTarget(forKey key: String, from sessions: [SessionData]? = nil) -> String? {
        let sessionList = sessions ?? SessionHistoryStore.load()
        var counts: [String: Int] = [:]
        for session in sessionList {
            for tap in session.rawTaps where tap.key == key && tap.correctionApplied {
                if let corrected = tap.correctedKey, corrected != key {
                    counts[corrected, default: 0] += 1
                }
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    static func analyze(from sessions: [SessionData]) -> [String: [(target: String, count: Int)]] {
        var pairs: [String: [(target: String, count: Int)]] = [:]
        for session in sessions {
            for tap in session.rawTaps where tap.correctionApplied {
                if let corrected = tap.correctedKey, corrected != tap.key {
                    pairs[tap.key, default: []].append((target: corrected, count: 1))
                }
            }
        }
        return pairs
    }

    static func topConfusionPairs(limit: Int = 8) -> [(pair: String, count: Int)] {
        var counts: [String: Int] = [:]
        for session in SessionHistoryStore.load() {
            for tap in session.rawTaps where tap.correctionApplied {
                if let corrected = tap.correctedKey, corrected != tap.key {
                    counts["\(tap.key) → \(corrected)", default: 0] += 1
                }
            }
        }
        let sorted = counts.map { (pair: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
        return Array(sorted.prefix(limit))
    }
}
