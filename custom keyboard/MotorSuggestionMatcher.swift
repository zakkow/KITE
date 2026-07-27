import Foundation

/// Determines whether a spelling suggestion is explained by this user's
/// own real confusion-pair history — i.e. some letter in the typed word
/// has historically resolved, for this user, to the corresponding letter
/// in the suggestion — not just generic dictionary distance. Only
/// handles same-length, single-letter substitution (matches how the
/// correction model itself works: one mis-tapped key, not insertions or
/// deletions), a known, honest scope limit.
enum MotorSuggestionMatcher {
    static func isMotorExplained(typed: String, suggestion: String, confusionPairs: [String: [(target: String, count: Int)]]) -> Bool {
        let typedChars = Array(typed.uppercased())
        let suggestionChars = Array(suggestion.uppercased())
        guard typedChars.count == suggestionChars.count else { return false }
        for (t, s) in zip(typedChars, suggestionChars) where t != s {
            let pairs = confusionPairs[String(t)] ?? []
            if pairs.contains(where: { $0.target == String(s) }) {
                return true
            }
        }
        return false
    }
}
