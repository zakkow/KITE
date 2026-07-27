import Foundation
import CoreGraphics
import UIKit

struct BufferedTap {
    let rawKey: String
    let touchPoint: CGPoint
    let keyCenter: CGPoint
    let timestamp: TimeInterval
}

final class RetroactiveCorrectionEngine {
    private(set) var tapBuffer: [BufferedTap] = []
    private var dampenedPairs: [String: Int] = [:]
    private(set) var isDisarmed: Bool = false

    func recordTap(rawKey: String, touchPoint: CGPoint, keyCenter: CGPoint, timestamp: TimeInterval) {
        tapBuffer.append(BufferedTap(rawKey: rawKey, touchPoint: touchPoint, keyCenter: keyCenter, timestamp: timestamp))
    }

    func clearBuffer() {
        tapBuffer.removeAll()
        isDisarmed = false
    }

    func disarmForCurrentWord() {
        isDisarmed = true
    }

    func markRetroactiveRejection(from: String, to: String) {
        let key = "\(from.lowercased())->\(to.lowercased())"
        dampenedPairs[key, default: 0] += 1
    }

    /// Evaluates if buffered taps (2+ characters) form a word that can be retroactively improved.
    /// Returns (originalTypedWord, correctedWord) if a high-confidence retroactive correction is found.
    func evaluateRetroactiveCorrection(
        currentWord: String,
        allKeyFrames: [String: CGRect],
        isWordBoundary: Bool = false,
        lastTapInterval: TimeInterval = 0
    ) -> (original: String, corrected: String)? {

        // GUARD C: Backspace immunity disarms retroactive engine for active word
        guard !isDisarmed else { return nil }

        // GUARD A: Mid-stream typing speed gating
        // Only evaluate if a word boundary was reached, OR if a micro-pause occurs (> 0.35s since last tap)
        if !isWordBoundary && lastTapInterval < 0.35 {
            return nil
        }

        guard tapBuffer.count >= 2, currentWord.count == tapBuffer.count else { return nil }

        // GUARD B: Proper Noun, Acronym, and Whitelist Immunity
        let isAllCaps = currentWord.count > 1 && currentWord == currentWord.uppercased()
        let isFirstUpper = currentWord.first?.isUppercase == true
        let lowerWord = currentWord.lowercased()

        if isAllCaps || isFirstUpper || SharedStore.customWhitelistedWords.contains(lowerWord) || SharedStore.protectedWords.contains(lowerWord) {
            return nil
        }

        // If currentWord is already a valid common English word (like "he", "to", "yo"), don't retroactively break it
        if CommonWordList.isCompleteWord(lowerWord) && lowerWord.count <= 2 {
            return nil
        }

        // New Multi-Letter Spatial Check using UITextChecker guesses + CommonWordList
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: currentWord.utf16.count)
        var guesses = checker.guesses(forWordRange: range, in: currentWord, language: "en_US") ?? []
        
        let commonWords = CommonWordList.words.filter { $0.count == currentWord.count }
        for word in commonWords {
            if !guesses.contains(word) {
                guesses.append(word)
            }
        }
        
        // Add protected/common words to guesses so they can defend themselves geometrically.
        // Obscure words (e.g. "lobe") are excluded to allow common word override (e.g. "love").
        let isProtected = SharedStore.protectedWords.contains(lowerWord) || SharedStore.customWhitelistedWords.contains(lowerWord)
        let isCommon = CommonWordList.isCompleteWord(lowerWord)
        
        if isProtected || isCommon {
            if !guesses.contains(lowerWord) {
                guesses.append(lowerWord)
            }
        }
        
        var bestGuess: String? = nil
        var lowestTotalDistance: CGFloat = .greatestFiniteMagnitude
        
        for guess in guesses {
            // Filter hyphens unless explicitly typed
            if guess.contains("-") && !currentWord.contains("-") { continue }
            
            // Only evaluate guesses of the same exact length for geometric mapping
            guard guess.count == currentWord.count else { continue }
            let guessLower = guess.lowercased()
            
            let pairKey = "\(lowerWord)->\(guessLower)"
            if (dampenedPairs[pairKey] ?? 0) >= 2 { continue }
            
            // Calculate total geometric distance for this word guess
            var totalDistance: CGFloat = 0
            var isValidGeometry = true
            
            for (index, tap) in tapBuffer.enumerated() {
                let guessCharIndex = guessLower.index(guessLower.startIndex, offsetBy: index)
                let guessChar = String(guessLower[guessCharIndex]).uppercased()
                let baseKey = tap.rawKey.uppercased()
                
                // Distance is 0 for exact match
                if guessChar == baseKey { continue }
                
                guard let guessFrame = allKeyFrames[guessChar], let baseFrame = allKeyFrames[baseKey] else {
                    isValidGeometry = false
                    break
                }
                
                let baseWidth = max(baseFrame.width, 30.0)
                let baseHeight = max(baseFrame.height, 40.0)
                let gCenter = CGPoint(x: guessFrame.midX, y: guessFrame.midY)
                let dist = hypot(
                    (tap.touchPoint.x - gCenter.x) / (baseWidth / 2.0),
                    (tap.touchPoint.y - gCenter.y) / (baseHeight / 2.0)
                )
                
                // Relaxed to 4.5 to allow up to a 2-key miss
                if dist > 4.5 {
                    isValidGeometry = false
                    break
                }
                totalDistance += dist
            }
            
            if isValidGeometry && totalDistance < lowestTotalDistance {
                lowestTotalDistance = totalDistance
                bestGuess = guessLower
            }
        }
        
        if let best = bestGuess, best != lowerWord {
            // Ensure average distance per letter is mathematically sound (<= 2.5)
            if lowestTotalDistance / CGFloat(currentWord.count) <= 2.5 {
                return (currentWord, best)
            }
        }

        return nil
    }
}
