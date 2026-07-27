import Foundation

/// Dynamic POS & N-Gram Sentence Context Engine
/// Combines dynamic Parts-of-Speech (POS) syntactic tagging (NSLinguisticTagger)
/// with multi-word N-Gram sentence context to retroactively resolve ambiguous
/// homophones and contractions ("Hell be" -> "He'll be", "Well be" -> "We'll be", "Ill go" -> "I'll go").
class NGramContextEngine {
    static let shared = NGramContextEngine()

    struct RetroactiveNGramMatch {
        let originalWord: String
        let replacementWord: String
        let trailingText: String
    }

    /// Dynamic contraction mappings for homophone pairs
    private let homophoneContractionMap: [String: String] = [
        "well": "we'll",
        "hell": "he'll",
        "shell": "she'll",
        "ill": "i'll",
        "were": "we're",
        "its": "it's",
        "theyre": "they're",
        "youre": "you're",
        "whats": "what's",
        "hows": "how's",
        "wheres": "where's",
        "theres": "there's",
        "lets": "let's",
        "dont": "don't",
        "cant": "can't",
        "wont": "won't"
    ]

    /// Common verb triggers that indicate a preceding contraction is grammatically required
    private let verbTriggers: Set<String> = [
        "be", "go", "see", "get", "have", "take", "arrive", "do", "call", "come", "find", "make",
        "going", "coming", "here", "there", "ready", "so", "glad", "excited", "happy", "a", "great", "good"
    ]

    /// Evaluates multi-word sentence context (up to 4 words back) using POS tagging and syntactic rules.
    func evaluateContext(_ contextBefore: String) -> RetroactiveNGramMatch? {
        guard !contextBefore.isEmpty else { return nil }

        let components = contextBefore.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let nonKeys = components.filter { !$0.isEmpty }

        guard nonKeys.count >= 2 else { return nil }

        let maxLookback = min(4, nonKeys.count - 1)
        
        for offset in 1...maxLookback {
            let targetIndex = nonKeys.count - 1 - offset
            guard targetIndex >= 0 else { continue }
            
            let targetWordRaw = nonKeys[targetIndex]
            let targetWordClean = targetWordRaw.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let followingWords = nonKeys[(targetIndex + 1)...].map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            guard let nextWord = followingWords.first else { continue }
            
            var replacement: String? = nil
            
            // 1. Homophone Contractions (e.g. "hell" -> "he'll", "dont" -> "don't")
            if let contractionReplacement = homophoneContractionMap[targetWordClean] {
                // If it's a guaranteed contraction (like "dont"), apply unconditionally
                let guaranteed: Set<String> = ["dont", "cant", "wont", "lets", "its", "whats", "wheres", "hows", "theres"]
                if guaranteed.contains(targetWordClean) {
                    replacement = contractionReplacement
                } else {
                    let hasVerbMatch = followingWords.contains { verbTriggers.contains($0) || isVerbTag($0) }
                    if hasVerbMatch {
                        replacement = contractionReplacement
                    }
                }
            }
            
            // 2. A vs An
            if targetWordClean == "a", startsWithVowelSound(nextWord) {
                replacement = "an"
            } else if targetWordClean == "an", !startsWithVowelSound(nextWord) {
                replacement = "a"
            }
            
            // 3. Their vs They're
            if targetWordClean == "their", isVerbTag(nextWord) {
                replacement = "they're"
            } else if targetWordClean == "theyre" || targetWordClean == "they're" {
                if isNounTag(nextWord) {
                    replacement = "their"
                }
            }
            
            // 4. To vs Too
            if targetWordClean == "to", isAdjectiveTag(nextWord) {
                replacement = "too"
            }
            
            // 5. Its vs It's
            if targetWordClean == "its" {
                if isAdjectiveTag(nextWord) || isVerbTag(nextWord) {
                    replacement = "it's"
                }
            }
            
            // 6. God vs Good (since length mismatch prevents geometric retroactive fix)
            if targetWordClean == "god" {
                let goodTriggers: Set<String> = ["morning", "afternoon", "evening", "night", "luck", "job", "work", "time", "boy", "girl", "dog", "news"]
                if goodTriggers.contains(nextWord) {
                    replacement = "good"
                }
            }

            if let repl = replacement {
                let isCapitalized = targetWordRaw.first?.isUppercase == true
                let formattedReplacement: String
                if isCapitalized {
                    formattedReplacement = repl.prefix(1).uppercased() + repl.dropFirst()
                } else {
                    formattedReplacement = repl.lowercased()
                }
                
                if let targetRange = contextBefore.range(of: targetWordRaw, options: .backwards) {
                    let trailing = String(contextBefore[targetRange.upperBound...])
                    return RetroactiveNGramMatch(
                        originalWord: targetWordRaw,
                        replacementWord: formattedReplacement,
                        trailingText: trailing
                    )
                }
            }
        }

        return nil
    }

    private lazy var tagger: NSLinguisticTagger = {
        return NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
    }()

    private func isVerbTag(_ word: String) -> Bool {
        tagger.string = word
        let tag = tagger.tag(at: 0, scheme: .lexicalClass, tokenRange: nil, sentenceRange: nil)
        return tag == .verb
    }
    
    private func isNounTag(_ word: String) -> Bool {
        tagger.string = word
        let tag = tagger.tag(at: 0, scheme: .lexicalClass, tokenRange: nil, sentenceRange: nil)
        return tag == .noun
    }
    
    private func isAdjectiveTag(_ word: String) -> Bool {
        tagger.string = word
        let tag = tagger.tag(at: 0, scheme: .lexicalClass, tokenRange: nil, sentenceRange: nil)
        return tag == .adjective
    }
    
    private func startsWithVowelSound(_ word: String) -> Bool {
        guard let first = word.first else { return false }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        // Exception handling for words like "hour", "honor"
        if word.hasPrefix("ho") && (word == "hour" || word == "honor" || word == "honest") {
            return true
        }
        // Exception handling for "universe", "user", "unicorn", "ukulele"
        if word.hasPrefix("uni") || word.hasPrefix("use") || word.hasPrefix("uku") {
            return false
        }
        return vowels.contains(first)
    }
}
