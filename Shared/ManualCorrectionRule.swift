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

enum WordCorrectionStrictness: String, Codable, CaseIterable {
    case exact
    case smartSuffixes
    
    var label: String {
        switch self {
        case .exact: return "Exact Match Only"
        case .smartSuffixes: return "Include Plurals & Suffixes"
        }
    }
}

enum WordCorrectionContext: String, Codable, CaseIterable {
    case anywhere
    case startOfSentence
    case precedingWord
    case followingWord
    
    var label: String {
        switch self {
        case .anywhere: return "Anywhere"
        case .startOfSentence: return "Start of Sentence Only"
        case .precedingWord: return "Must follow specific word..."
        case .followingWord: return "Must precede specific word..."
        }
    }
}

struct CustomWordCorrectionRule: Codable, Identifiable, Equatable {
    var id: String { typedWord }
    var typedWord: String
    var correctedWord: String
    var strictness: WordCorrectionStrictness = .exact
    var context: WordCorrectionContext = .anywhere
    var specificContextWord: String = "" // Used if context is .precedingWord or .followingWord
    var isAutoLearned: Bool = false
    var confidence: Int = 1
}
