import Foundation

enum CorrectionStrictness: String, Codable, CaseIterable {
    case always
    case whenUncertain
    var label: String { self == .always ? "Always" : "Only When Uncertain" }
}

enum CorrectionContext: String, Codable, CaseIterable {
    case anywhere
    case startOfWord
    case withinWord
    var label: String {
        switch self {
        case .anywhere: return "Anywhere"
        case .startOfWord: return "Start of a Word"
        case .withinWord: return "Within a Word"
        }
    }
}

struct ManualCorrectionRule: Codable, Identifiable {
    var id: String { fromKey }
    var fromKey: String
    var toKey: String
    var strictness: CorrectionStrictness = .always
    var context: CorrectionContext = .anywhere
}
