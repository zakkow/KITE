import UIKit

final class LinguisticPlausibilityGate {
    private var textChecker: UITextChecker { SharedStore.sharedTextChecker }

    /// Cache for evaluatePlausibility / shouldAllowCorrection to prevent redundant dictionary lookups
    private var validityCache: [String: Bool] = [:]

    func resetCache() {
        validityCache.removeAll()
    }

    /// Valid single-letter English words. Other single letters are evaluated strictly as prefixes.
    private let validStandaloneLetters: Set<String> = ["a", "i", "o"]
    
    /// Adaptive Rejection Decay: Tracks rejection count and last keystroke index for word context vetoes.
    /// 1 Undo = 50-stroke temporary cooldown; 2 Undos = 500-stroke cooldown; 3+ Undos = Permanent blacklist.
    private var rejectedWordContextScores: [String: Int] = [:]
    private var rejectedWordContextLastTap: [String: Int] = [:]
    private var currentKeystrokeIndex: Int = 0

    /// Custom Name & Acronym Prefix Memory: Remembers words typed by the user 3+ times without undo.
    private var learnedCustomPrefixes: Set<String> = []
    private var prefixTapCounts: [String: Int] = [:]

    func updateKeystrokeIndex(_ index: Int) {
        currentKeystrokeIndex = index
    }

    func recordAcceptedWord(_ word: String) {
        let lower = word.lowercased()
        guard lower.count >= 2 else { return }
        // Guardrail: Only auto-learn words if they are valid dictionary words or prefixes.
        // Never auto-whitelist uncorrected gibberish (e.g. "namw").
        guard isCompleteRealWord(lower) || hasValidCompletions(lower) else { return }
        prefixTapCounts[lower, default: 0] += 1
        if prefixTapCounts[lower]! >= 3 {
            learnedCustomPrefixes.insert(lower)
            var current = SharedStore.customWhitelistedWords
            if !current.contains(lower) {
                current.append(lower)
                SharedStore.customWhitelistedWords = current
            }
        }
    }

    private var rejectionCountsForBlacklist: [String: Int] = [:]

    func markCorrectionRejected(wordSoFar: String, raw: Character, corrected: Character) {
        let key = (wordSoFar + "::" + String(raw) + "->" + String(corrected)).lowercased()
        rejectedWordContextScores[key, default: 0] += 1
        rejectedWordContextLastTap[key] = currentKeystrokeIndex

        // Matches recordAcceptedWord's 3-occurrence threshold.
        let wordEntry = (wordSoFar + String(raw)).lowercased()
        rejectionCountsForBlacklist[wordEntry, default: 0] += 1
        if rejectionCountsForBlacklist[wordEntry]! >= 3 {
            var currentProtected = SharedStore.protectedWords
            if !currentProtected.contains(wordEntry) {
                currentProtected.append(wordEntry)
                SharedStore.protectedWords = currentProtected
            }
        }
    }

    func shouldAllowCorrection(wordSoFar: String, raw: Character, corrected: Character) -> Bool {
        guard raw != corrected else { return true }
        let key = (wordSoFar + "::" + String(raw) + "->" + String(corrected)).lowercased()

        if let cached = validityCache[key] {
            return cached
        }

        let withRaw = (wordSoFar + String(raw)).lowercased()
        let withCorrected = (wordSoFar + String(corrected)).lowercased()

        // 1. User-Managed Protected Words Check (from Settings / Undos)
        if SharedStore.protectedWords.contains(withRaw) {
            validityCache[key] = false
            return false
        }
        
        // 2. Adaptive Rejection Decay Check
        if let score = rejectedWordContextScores[key], let lastTap = rejectedWordContextLastTap[key] {
            let cooldown = score == 1 ? 50 : 500
            if currentKeystrokeIndex - lastTap < cooldown {
                validityCache[key] = false
                return false
            }
        }
        
        

        let result = evaluatePlausibility(original: withRaw, candidate: withCorrected)
        validityCache[key] = result
        return result
    }

    func shouldAllowOverride(wordSoFar: String, from: Character, to: Character) -> Bool {
        guard from != to else { return true }
        let withOriginal = (wordSoFar + String(from)).lowercased()
        let withOverride = (wordSoFar + String(to)).lowercased()
        
        // Protect top common English words (like "how", "who", "two", "we", "was", "when", "what") from manual override corruptions (e.g. "hoe")
        if CommonWordList.isCompleteWord(withOriginal) {
            let obscureSecondaryWords: Set<String> = ["hoe", "eho", "toe", "ehat", "ehen"]
            if obscureSecondaryWords.contains(withOverride) {
                return false
            }
        }
        
        return evaluatePlausibility(original: withOriginal, candidate: withOverride)
    }
    
    private func evaluatePlausibility(original: String, candidate: String) -> Bool {
        let origLower = original.lowercased()
        let candLower = candidate.lowercased()
        
        let originalIsComplete = CommonWordList.isCompleteWord(origLower) || isCompleteRealWord(origLower)
        let candidateIsComplete = CommonWordList.isCompleteWord(candLower) || isCompleteRealWord(candLower)
        
        // PILLAR 1: Plural & Suffix Complete Real Word Dominance
        if originalIsComplete && !candidateIsComplete {
            return false
        }
        
        // PILLAR 2: Long Word Length Lock (4+ Letters)
        if original.count >= 4 {
            if originalIsComplete && !candidateIsComplete {
                return false
            }
            if !candidateIsComplete && !hasHighFrequencyCompletions(candLower) {
                return false
            }
        }
        
        // PILLAR 3: Top English Question/Common Word Protection
        let topQuestionWords: Set<String> = ["how", "who", "when", "what", "where", "why", "we", "was", "two", "you", "they", "them"]
        if topQuestionWords.contains(origLower) {
            if candLower == "hoe" || !CommonWordList.isCompleteWord(candLower) {
                return false
            }
        }
        
        let originalPlausible = isPlausible(original)
        let candidatePlausible = isPlausible(candidate)
        
        if originalPlausible && !candidatePlausible { 
            return false 
        }
        return true
    }

    private func isPlausible(_ candidate: String) -> Bool {
        guard !candidate.isEmpty else { return false }
        
        // 0. Learned Custom Prefix & User Whitelist
        let lowerCandidate = candidate.lowercased()
        if learnedCustomPrefixes.contains(lowerCandidate) || SharedStore.customWhitelistedWords.contains(lowerCandidate) {
            return true
        }

        // 1. Single-Letter Guard
        if candidate.count == 1 {
            if validStandaloneLetters.contains(candidate) { return true }
            return hasValidCompletions(candidate)
        }

        // 2. Exact Dictionary Word Match
        if isCompleteRealWord(candidate) { return true }

        // 3. Prefix Plausibility
        if hasValidCompletions(candidate) { return true }

        return false
    }

    // MARK: - Linguistic Helpers

    func isCompleteRealWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return misspelledRange.location == NSNotFound
    }
    
    private func hasValidCompletions(_ prefix: String) -> Bool {
        let range = NSRange(location: 0, length: prefix.utf16.count)
        let completions = textChecker.completions(forPartialWordRange: range, in: prefix, language: "en_US")
        return completions?.isEmpty == false
    }

    private func hasHighFrequencyCompletions(_ prefix: String) -> Bool {
        let range = NSRange(location: 0, length: prefix.utf16.count)
        guard let completions = textChecker.completions(forPartialWordRange: range, in: prefix, language: "en_US") else {
            return false
        }
        return completions.contains { CommonWordList.isCompleteWord($0.lowercased()) }
    }
}
