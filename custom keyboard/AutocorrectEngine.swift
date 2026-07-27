import UIKit

/// Suggests spelling corrections for a just-completed word using
/// UITextChecker — Apple's own on-device spell-check engine, the same
/// dictionary/lookup system the built-in keyboard uses. No network call;
/// this stays consistent with the "no data leaves the device" privacy story.
/// Suggest-only by design — KITE never silently auto-replaces a word, since
/// a forced, only-undoable-after-the-fact replacement adds exactly the kind
/// of friction this app exists to remove.
final class AutocorrectEngine {

    private var textChecker: UITextChecker { SharedStore.sharedTextChecker }

    /// Returns up to maxSuggestions spelling suggestions for `word`, or an
    /// empty array if it's already correctly spelled — or if UITextChecker
    /// simply doesn't recognize it (proper nouns, slang, technical terms
    /// aren't in its dictionary; this is a known limitation of using a
    /// general-purpose system dictionary, not a bug).
    func suggestions(for word: String, contextBefore: String = "", maxSuggestions: Int = 3) -> [String] {
        guard !word.isEmpty else { return [] }
        
        let recentContext = String(contextBefore.suffix(50))
        let fullText = recentContext + word
        let wordRange = NSRange(location: recentContext.utf16.count, length: word.utf16.count)

        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: fullText, range: wordRange, startingAt: wordRange.location, wrap: false, language: "en_US"
        )
        guard misspelledRange.location != NSNotFound else {
            return [] // correctly spelled, or unrecognized-but-not-flagged
        }

        let guesses = textChecker.guesses(forWordRange: misspelledRange, in: fullText, language: "en_US") ?? []
        return Array(guesses.prefix(maxSuggestions))
    }
}
