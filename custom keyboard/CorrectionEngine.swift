import UIKit

final class CorrectionEngine {

    var profile: MotorProfile
    private var preferences: UserPreferences
    private var consecutiveRejections: [String: Int] = [:]
    private var lastKeyTime: [String: TimeInterval] = [:]
    private var keysWithAnnouncedMilestone: Set<String> = []

    private let microPauseThreshold: TimeInterval = 1.5
    private let microPauseForgiveness: Double = 0.15
    private let fastTypingThreshold: TimeInterval = 0.12
    private let fastTypingConfidenceBoost: Double = 0.15

    /// Tracks explicit rejections of a specific fromKey->toKey MANUAL OVERRIDE mapping.
    /// Timed against real keystrokes, independent of geometric tap confidence.
    private var overrideRejectionExpiry: [String: Int] = [:]
    private var globalKeystrokeCount: Int = 0
    private let overrideRejectionCooldownKeystrokes = 5

    var onMilestoneReached: ((String) -> Void)?
    
    /// Closure to check if a manual override makes linguistic sense.
    /// Set by KeyboardViewController to provide word context validation.
    var linguisticGateCheck: ((String, Character, Character) -> Bool)?

    var isDemoMode: Bool { profile.isDemoMode }
    var profileType: ProfileType { profile.profileType }
    var currentKeyOffsets: [String: KeyOffset] { profile.keyOffsets }
    var currentManualOverrides: [String: ManualCorrectionRule] { profile.manualOverrides }

    init(profile: MotorProfile, preferences: UserPreferences) {
        self.profile = profile
        self.preferences = preferences
    }

    func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
    }

    func updateProfile(_ newProfile: MotorProfile) {
        profile = newProfile
    }

    func shouldAcceptKeystroke(key: String, timestamp: TimeInterval) -> Bool {
        let threshold = preferences.debounceThreshold
        guard threshold > 0 else { return true }
        if let last = lastKeyTime[key], timestamp - last < threshold {
            return false
        }
        lastKeyTime[key] = timestamp
        return true
    }

    struct CorrectionResult {
        let resolvedKey: String
        let didApplyDirectionalShift: Bool
        let didApplyScatterWidening: Bool
        let isManualOverride: Bool
    }

    private func effectiveConfidenceThreshold(sinceLastTap interval: TimeInterval, forKey key: String = "") -> Double {
        var threshold = preferences.confidenceThreshold
        if interval > 0 {
            if interval < fastTypingThreshold {
                threshold = max(preferences.confidenceThreshold - fastTypingConfidenceBoost, 0.15)
            } else if interval > microPauseThreshold {
                threshold = max(preferences.confidenceThreshold - microPauseForgiveness, 0.15)
            }
        }
        threshold += handSplitAdjustment(for: key)
        return max(0.1, min(0.95, threshold))
    }

    private func handSplitAdjustment(for key: String) -> Double {
        guard preferences.handSplitModelingEnabled else { return 0 }
        let side = HandSideMapping.side(for: key)
        guard side != .center else { return 0 }
        let isNonDominant = (preferences.dominantHand == .left && side == .right) || (preferences.dominantHand == .right && side == .left)
        return isNonDominant ? -0.1 : 0.05
    }

    private var overrideRejectionCounts: [String: Int] = [:]

    var onRuleAutoDowngraded: ((_ fromKey: String, _ toKey: String) -> Void)?

    /// Called when the user explicitly rejects a result from a manual override rule.
    /// Temporarily suppresses that mapping for a keystroke cooldown window, allowing the
    /// linguistic gate's word-context memory to permanently protect that specific word.
    func markOverrideRejected(fromKey: String, toKey: String) {
        let lookupKey = fromKey.uppercased()
        let ruleKey = "\(lookupKey)->\(toKey.uppercased())"
        overrideRejectionCounts[ruleKey, default: 0] += 1
        let count = overrideRejectionCounts[ruleKey]!
        // Cooldown scales with rejection count so persistent rejections give typing room
        let cooldown = min(15 * count, 60)
        overrideRejectionExpiry[ruleKey] = globalKeystrokeCount + cooldown
        
        // Self-Healing Safeguard: Auto-downgrade or delete rejected rules
        if let rule = profile.manualOverrides[lookupKey] ?? profile.manualOverrides[fromKey] {
            if count >= 5 {
                var updatedProfile = profile
                updatedProfile.manualOverrides.removeValue(forKey: lookupKey)
                updatedProfile.manualOverrides.removeValue(forKey: fromKey)
                updateProfile(updatedProfile)
                saveProfile()
                
                ExplainabilityLogStore.append(ExplainabilityLogEntry(
                    fromKey: fromKey,
                    toKey: toKey,
                    mechanism: "Auto-Deleted Bad Rule",
                    confidence: 0.90
                ))
            } else if rule.strictness == .always && count >= 3 {
                var updatedProfile = profile
                var updatedRule = rule
                updatedRule.strictness = .whenUncertain
                updatedProfile.manualOverrides[lookupKey] = updatedRule
                updateProfile(updatedProfile)
                saveProfile()
                
                ExplainabilityLogStore.append(ExplainabilityLogEntry(
                    fromKey: fromKey,
                    toKey: toKey,
                    mechanism: "Auto-Downgraded Rule",
                    confidence: 0.90
                ))
                
                onRuleAutoDowngraded?(fromKey, toKey)
            }
        }
    }

    private func isOverrideSuppressed(fromKey: String, toKey: String) -> Bool {
        guard let expiry = overrideRejectionExpiry["\(fromKey)->\(toKey)"] else { return false }
        return globalKeystrokeCount < expiry
    }

    private var lastAppliedCorrectionInCurrentWord: (from: String, to: String)?

    func resetWordCorrectionContext() {
        lastAppliedCorrectionInCurrentWord = nil
    }

    private var lastTapInfo: (key: String, point: CGPoint, timestamp: TimeInterval)?

    func resolveTap(
        tappedKey: String,
        rawPoint: CGPoint,
        wordSoFar: String,
        wordPosition: CorrectionContext,
        interval: TimeInterval,
        isSensitiveField: Bool = false,
        allKeyFrames: [String: CGRect],
        likelyNextLetters: Set<Character> = []
    ) -> CorrectionResult {

        // MARK: - Rapid Double-Letter Lock
        // If the same key is tapped in rapid succession (<140ms), lock to tappedKey to protect double-letter words ("uddin", "good", "book")
        let now = Date().timeIntervalSince1970
        if let last = lastTapInfo, last.key.lowercased() == tappedKey.lowercased(), (now - last.timestamp) < 0.14 {
            let dist = hypot(rawPoint.x - last.point.x, rawPoint.y - last.point.y)
            if dist < 35.0 {
                lastTapInfo = (tappedKey, rawPoint, now)
                return CorrectionResult(resolvedKey: tappedKey, didApplyDirectionalShift: false, didApplyScatterWidening: false, isManualOverride: false)
            }
        }
        lastTapInfo = (tappedKey, rawPoint, now)

        // MARK: - Manual Override Path
        let lookupKey = tappedKey.uppercased()
        if !isSensitiveField,
           let rule = profile.manualOverrides[lookupKey] ?? profile.manualOverrides[tappedKey],
           !isOverrideSuppressed(fromKey: lookupKey, toKey: rule.toKey) {

            let contextMatches = rule.context == .anywhere || rule.context == wordPosition

            if contextMatches {
                let linguisticVeto: Bool
                if let gate = linguisticGateCheck {
                    linguisticVeto = !gate(wordSoFar, Character(tappedKey), Character(rule.toKey))
                } else {
                    linguisticVeto = false
                }

                if !linguisticVeto {
                    return CorrectionResult(
                        resolvedKey: rule.toKey,
                        didApplyDirectionalShift: false,
                        didApplyScatterWidening: false,
                        isManualOverride: true
                    )
                } else {
                    // Vetoed linguistically, return raw tap.
                    return CorrectionResult(
                        resolvedKey: tappedKey,
                        didApplyDirectionalShift: false,
                        didApplyScatterWidening: false,
                        isManualOverride: false
                    )
                }
            }
        }

        // Suppress immediate single-letter candidate replacements on isolated first taps without preceding context
        if wordSoFar.isEmpty && wordPosition == .startOfWord {
            let tappedFrame = allKeyFrames[tappedKey]
            let tappedCenter = tappedFrame != nil ? CGPoint(x: tappedFrame!.midX, y: tappedFrame!.midY) : rawPoint
            let tappedWidth = tappedFrame?.width ?? 36.0
            let tappedHeight = tappedFrame?.height ?? 44.0
            let normDist = hypot(
                (rawPoint.x - tappedCenter.x) / max(tappedWidth / 2.0, 1.0),
                (rawPoint.y - tappedCenter.y) / max(tappedHeight / 2.0, 1.0)
            )
            if normDist < 0.45 {
                return CorrectionResult(resolvedKey: tappedKey, didApplyDirectionalShift: false, didApplyScatterWidening: false, isManualOverride: false)
            }
        }

        // MARK: - Geometric Correction Path & Spatial-Linguistic Cost Coupling
        let tappedFrame = allKeyFrames[tappedKey]
        let tappedCenter = tappedFrame != nil ? CGPoint(x: tappedFrame!.midX, y: tappedFrame!.midY) : rawPoint
        let tappedWidth = tappedFrame?.width ?? 36.0
        let tappedHeight = tappedFrame?.height ?? 44.0
        let tappedNormalizedDist = hypot(
            (rawPoint.x - tappedCenter.x) / max(tappedWidth / 2.0, 1.0),
            (rawPoint.y - tappedCenter.y) / max(tappedHeight / 2.0, 1.0)
        )
        let isDeadCenterTap = tappedNormalizedDist < 0.25
        let isFastTypingBurst = interval > 0 && interval < 0.10
        let baseThreshold: CGFloat = isDeadCenterTap
            ? (profile.profileType == .tremor ? 1.55 : 1.40)
            : (profile.profileType == .tremor ? 1.85 : 1.70)
        let costThreshold: CGFloat = isFastTypingBurst ? (baseThreshold * 0.65) : baseThreshold

        var bestKey: String = tappedKey
        var lowestCost: CGFloat = .greatestFiniteMagnitude
        var winningShiftApplied = false
        var winningScatterApplied = false

        for (key, frame) in allKeyFrames {
            let offset = offsetForKey(key)

            var shiftedPoint = rawPoint
            var appliedShift = false

            if !isSensitiveField,
               offset.isDirectionalDrift,
               offset.confidence >= effectiveConfidenceThreshold(
                sinceLastTap: interval,
                forKey: key
               ) {
                shiftedPoint = CGPoint(
                    x: rawPoint.x - offset.averageDeltaX,
                    y: rawPoint.y - offset.averageDeltaY
                )
                appliedShift = true
            }

            let keyCenter = CGPoint(x: frame.midX, y: frame.midY)
            let widthRadius = max(frame.width / 2.0, 1.0)
            let heightRadius = max(frame.height / 2.0, 1.0)
            let normX = (shiftedPoint.x - keyCenter.x) / widthRadius
            let normY = (shiftedPoint.y - keyCenter.y) / heightRadius
            let normalizedDistance = hypot(normX, normY)

            let avgKeyRadius = (widthRadius + heightRadius) / 2.0
            let effectiveRadius = max(CGFloat(offset.scatterRadius) / avgKeyRadius, 0.4)
            let baseCost = normalizedDistance / effectiveRadius
            
            var cost = baseCost
            if let firstChar = key.lowercased().first, likelyNextLetters.contains(firstChar) {
                cost *= 0.65 // 35% discount if contextually probable (allows adjacent keys under the 1.40 threshold)
            }

            if cost < lowestCost {
                lowestCost = cost
                bestKey = key
                winningShiftApplied = appliedShift
                winningScatterApplied = (normalizedDistance > 1.0 && cost <= 1.0)
            }
        }

        if lowestCost > costThreshold {
            return CorrectionResult(
                resolvedKey: tappedKey,
                didApplyDirectionalShift: false,
                didApplyScatterWidening: false,
                isManualOverride: false
            )
        }

        if bestKey != tappedKey {
            // SEPARATE STAGE 2 SPACE-VS-LETTER VETO CHECK
            if (tappedKey == "space" && bestKey.count == 1 && !wordSoFar.isEmpty)
                || (bestKey == "space" && tappedKey.count == 1 && !wordSoFar.isEmpty) {
                let wordAlreadyComplete = CommonWordList.isCompleteWord(wordSoFar.lowercased())
                let convertingToLetter = bestKey.count == 1
                // Don't extend a word that's already finished; don't cut off a word that isn't.
                let allowed = convertingToLetter ? !wordAlreadyComplete : wordAlreadyComplete
                if !allowed {
                    return CorrectionResult(resolvedKey: tappedKey, didApplyDirectionalShift: false, didApplyScatterWidening: false, isManualOverride: false)
                }
            }

            let linguisticVeto: Bool
            if let gate = linguisticGateCheck, tappedKey.count == 1, bestKey.count == 1 {
                linguisticVeto = !gate(wordSoFar, Character(tappedKey), Character(bestKey))
            } else {
                linguisticVeto = false
            }

            if linguisticVeto {
                return CorrectionResult(
                    resolvedKey: tappedKey,
                    didApplyDirectionalShift: false,
                    didApplyScatterWidening: false,
                    isManualOverride: false
                )
            }
        }

        return CorrectionResult(
            resolvedKey: bestKey,
            didApplyDirectionalShift: winningShiftApplied && bestKey != tappedKey,
            didApplyScatterWidening: winningScatterApplied && bestKey != tappedKey && !winningShiftApplied,
            isManualOverride: false
        )
    }

    func debugConfidence(for key: String) -> Double {
        offsetForKey(key).confidence
    }

    func recordTap(key: String, rawPoint: CGPoint, keyCenter: CGPoint, interval: TimeInterval = 0, detectedFrequencyHz: Double? = nil, accepted: Bool) {
        globalKeystrokeCount += 1

        let deltaX = rawPoint.x - keyCenter.x
        let deltaY = rawPoint.y - keyCenter.y

        var offset = profile.keyOffsets[key] ?? KeyOffset.seeded(for: key, profileType: profile.profileType)

        offset.averageDeltaX = (offset.averageDeltaX * 0.7) + (deltaX * 0.3)
        offset.averageDeltaY = (offset.averageDeltaY * 0.7) + (deltaY * 0.3)

        let devX = deltaX - offset.averageDeltaX
        let devY = deltaY - offset.averageDeltaY
        offset.varianceX = (offset.varianceX * 0.7) + ((devX * devX) * 0.3)
        offset.varianceY = (offset.varianceY * 0.7) + ((devY * devY) * 0.3)

        offset.sampleCount += 1

        let magnitude = hypot(offset.averageDeltaX, offset.averageDeltaY)
        let scatter = sqrt(offset.varianceX + offset.varianceY)
        let consistencyRatio = magnitude / (scatter + 0.1)

        // Faster confidence ramp: reaches full confidence in 10 taps.
        let timeConfidence = min(Double(offset.sampleCount) / 10.0, 1.0)

        let snrThreshold: Double = 0.8
        let dynamicMultiplier = min(max(consistencyRatio / snrThreshold, 0.2), 1.0)

        offset.confidence = timeConfidence * dynamicMultiplier

        let n = Double(offset.sampleCount)
        offset.acceptanceRate = accepted
            ? (offset.acceptanceRate * (n - 1) + 1.0) / n
            : (offset.acceptanceRate * (n - 1)) / n

        if interval > 0 {
            offset.averageInterval = (offset.averageInterval * 0.7) + (interval * 0.3)
        }

        if let freq = detectedFrequencyHz {
            offset.detectedFrequencyHz = (offset.detectedFrequencyHz * 0.7) + (freq * 0.3)
            offset.frequencySampleCount += 1
        }

        offset.lastUpdated = Date()
        profile.keyOffsets[key] = offset

        if offset.isDirectionalDrift, !keysWithAnnouncedMilestone.contains(key) {
            keysWithAnnouncedMilestone.insert(key)
            onMilestoneReached?(key)
        }

        if accepted {
            consecutiveRejections[key] = 0
        } else {
            consecutiveRejections[key, default: 0] += 1
            if consecutiveRejections[key]! >= 3 {
                profile.keyOffsets[key] = KeyOffset.seeded(for: key, profileType: profile.profileType)
                consecutiveRejections[key] = 0
            }
        }
    }

    private var pendingSaveItem: DispatchWorkItem?

    func saveProfile() {
        pendingSaveItem?.cancel()
        let profileToSave = profile
        let item = DispatchWorkItem { [weak self] in
            guard let data = try? JSONEncoder().encode(profileToSave) else { return }
            SharedStore.setSharedData(data, forKey: SharedStore.Keys.motorProfile)
            self?.captureBaselineSnapshotIfNeeded()
        }
        pendingSaveItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    /// Synchronous, immediate save — bypasses the 2-second debounce. Use
    /// ONLY when the extension might be about to be suspended/killed
    /// (e.g. viewWillDisappear), where the debounce window risks losing
    /// the last few minutes of learned data.
    func saveProfileImmediately() {
        pendingSaveItem?.cancel()
        guard let data = try? JSONEncoder().encode(profile) else { return }
        SharedStore.setSharedData(data, forKey: SharedStore.Keys.motorProfile)
        captureBaselineSnapshotIfNeeded()
    }

    private func captureBaselineSnapshotIfNeeded() {
        guard SharedStore.getSharedData(forKey: SharedStore.Keys.baselineProfileSnapshot) == nil,
              !profile.keyOffsets.isEmpty else { return }
        let snapshot = ProfileSnapshot(date: Date(), keyOffsets: profile.keyOffsets)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        SharedStore.setSharedData(data, forKey: SharedStore.Keys.baselineProfileSnapshot)
    }

    func loadProfile() {
        if preferences.isDemoMode {
            profile = MotorProfile.demo
            return
        }
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
           let decoded = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            profile = decoded
        } else {
            profile = MotorProfile.default
        }
    }

    /// Reverted: no longer bumps sampleCount on rejection — see
    /// markOverrideRejected above for why that conflation was wrong.
    func markCorrectionRejected(key: String, correctedKey: String? = nil) {
        var offset = profile.keyOffsets[key] ?? KeyOffset.seeded(for: key, profileType: profile.profileType)
        let n = Double(offset.sampleCount)
        if n > 0 {
            offset.acceptanceRate = max(0, offset.acceptanceRate - 1.0 / n)
            // Recalibrate confidence & shift deltas when undone so key regains stability
            offset.confidence = max(0.0, offset.confidence * 0.60)
            offset.averageDeltaX *= 0.6
            offset.averageDeltaY *= 0.6
            profile.keyOffsets[key] = offset
        }

        // Penalize the capturing key that stole the tap so it stops pulling neighboring keys
        if let corrected = correctedKey, corrected != key {
            var correctedOffset = profile.keyOffsets[corrected] ?? KeyOffset.seeded(for: corrected, profileType: profile.profileType)
            correctedOffset.averageDeltaX *= 0.5
            correctedOffset.averageDeltaY *= 0.5
            correctedOffset.confidence = max(0.0, correctedOffset.confidence * 0.50)
            correctedOffset.varianceX *= 0.7
            correctedOffset.varianceY *= 0.7
            profile.keyOffsets[corrected] = correctedOffset
        }

        consecutiveRejections[key, default: 0] += 1
        if consecutiveRejections[key]! >= 3 {
            profile.keyOffsets[key] = KeyOffset.seeded(for: key, profileType: profile.profileType)
            consecutiveRejections[key] = 0
        }
    }

    #if DEBUG
    var debugProfile: MotorProfile { profile }
    #endif

    private func offsetForKey(_ key: String) -> KeyOffset {
        profile.keyOffsets[key] ?? KeyOffset.seeded(for: key, profileType: profile.profileType)
    }
}

private extension CGRect {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = max(self.minX - point.x, 0, point.x - self.maxX)
        let dy = max(self.minY - point.y, 0, point.y - self.maxY)
        return hypot(dx, dy)
    }
}
