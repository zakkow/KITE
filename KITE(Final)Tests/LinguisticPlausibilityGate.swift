import UIKit
import Foundation

/// Runs AFTER CorrectionEngine's geometric decision, BEFORE the corrected
/// character is inserted. Pure geometric correction has zero language
/// awareness — it can turn a real word into gibberish (e.g. "name" ->
/// "namr", "my" -> "mt") if a key's learned geometry happens to favor a
/// neighbor.
///
/// Uses THREE independent signals, not one — deliberately redundant, since
/// UITextChecker's completion API alone is known to be sparse/unreliable:
/// 1. Static common-word list (CommonWordList) — fast, no OS dependency,
///    catches the exact everyday-word cases that matter most.
/// 2. UITextChecker.rangeOfMisspelledWord — is this ALREADY a complete
///    real dictionary word right now? Broader than the static list.
/// 3. UITextChecker.completions(forPartialWordRange:) — could this prefix
///    still grow into a word? Weakest signal, never relied on alone.
///
/// This is word-level plausibility, not full sentence grammar — that would
/// need Apple's NaturalLanguage framework and real linguistic tagging, a
/// separate, larger feature. This directly and robustly fixes the
/// "geometric correction produces a non-word" failure mode.
final class LinguisticPlausibilityGate {
    private let textChecker = UITextChecker()

    func shouldAllowCorrection(wordSoFar: String, raw: Character, corrected: Character) -> Bool {
        guard raw != corrected else { return true }
        let withRaw = (wordSoFar + String(raw)).lowercased()
        let withCorrected = (wordSoFar + String(corrected)).lowercased()

        let rawPlausible = isPlausible(withRaw)
        let correctedPlausible = isPlausible(withCorrected)

        // Only veto the unambiguous case: raw is plausible, corrected is
        // not. Everything else defers to the geometric engine.
        if rawPlausible && !correctedPlausible { return false }
        return true
    }

    private func isPlausible(_ candidate: String) -> Bool {
        guard candidate.count >= 2 else { return true }

        if CommonWordList.isCompleteWord(candidate) { return true }
        if CommonWordList.hasWordWithPrefix(candidate) { return true }
        if isCompleteRealWord(candidate) { return true }

        let range = NSRange(location: 0, length: candidate.utf16.count)
        let completions = textChecker.completions(forPartialWordRange: range, in: candidate, language: "en_US")
        return completions?.isEmpty == false
    }

    private func isCompleteRealWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return misspelledRange.location == NSNotFound
    }
}
