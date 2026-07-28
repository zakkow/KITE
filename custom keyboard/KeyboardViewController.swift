import UIKit
import AudioToolbox
import WidgetKit

private struct CorrectionRecord {
    let baseKey: String
    let resolvedKey: String
    let rawPoint: CGPoint
    let keyCenter: CGPoint
    let timestamp: TimeInterval
    var characterIndexInWord: Int = 0
    var wordContext: String = ""
    var exactRawText: String? = nil
    var exactCorrectedText: String? = nil
}

class KeyboardViewController: UIInputViewController {

    private var coreView: KeyboardCoreView?
    private var sessionData: SessionData = SessionData()
    private var lastTapTimestamp: TimeInterval = 0
    private var tapXCoordinates: [CGFloat] = []
    private var keyboardWidth: CGFloat = 0

    private var correctionEngine: CorrectionEngine!
    private var preferences: UserPreferences = .default
    private var keyboardHeightConstraint: NSLayoutConstraint!
    private let autocorrectEngine = AutocorrectEngine()
    private let suggestionStrip = SuggestionStripView()
    private let undoStrip = UndoStripView()
    private let keyExplainerPopover = KeyExplainerPopoverView() // unused — showKeyInfo always uses keyInfoOverlay
    private let keyInfoOverlay = KeyInfoOverlayView() // Group 1: ADDED

    private var lastLongPressTime: TimeInterval = 0
    private var lastCorrection: CorrectionRecord?
    /// Wall-clock timestamp of the last correction to avoid uptime-vs-wallclock mismatch.
    private var lastCorrectionWallTime: TimeInterval = 0
    private var lastCorrectionTapIndex: Int? = nil
    private var lastBackspaceTimestamp: TimeInterval = 0
    private var activeWordCorrectionStack: [CorrectionRecord] = []
    private var pendingRejectionCandidate: CorrectionRecord?
    private let rejectionWindow: TimeInterval = 8.0
    private let sessionContinuationWindow: TimeInterval = 300 // 5 minutes

    private let linguisticGate = LinguisticPlausibilityGate()

    private var rawWordBuffer: String = ""
    private var insertedWordBuffer: String = ""
    private var pendingSuggestionWorkItem: DispatchWorkItem?
    private var cachedHistoricalSessions: [SessionData] = []
    private var cachedConfusionPairs: [String: [(target: String, count: Int)]] = [:]
    private var fastRawWordBuffer: String = ""
    private let retroactiveEngine = RetroactiveCorrectionEngine()

    private var sessionStartTime: TimeInterval?
    private var correctionTimestamps: [TimeInterval] = []
    private var baselineCorrectionRate: Double?
    private var fatigueAdaptationTriggered = false
    private var struggleStreak = 0
    private var struggleSuggestionShown: Date?
    
    // Auto-Learning Typo Pairs Tracking
    private var lastDeletedWord: String?
    private var lastDeletedWordContext: String?
    private var isDeletingWord = false
    private var disabledDroppedTapFixes: Set<String> = []
    private var lastDroppedTapFix: (raw: String, formatted: String, timestamp: TimeInterval)? = nil

    private func wordSoFarBeforeCurrentTap() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        return String(context.reversed().prefix { $0.isLetter || $0 == "'" }.reversed())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TEMPORARY: Wipe protected words to ensure a clean testing slate for the user
        SharedStore.protectedWords.removeAll()
        
        SharedStore.sanitizeWhitelists()
        view.applyKiteKeyboardContainerStyle()
        preferences = PreferencesStore.load()
        correctionEngine = CorrectionEngine(profile: MotorProfile.default, preferences: preferences)
        correctionEngine.loadProfile()
        correctionEngine.onMilestoneReached = { [weak self] _ in
            guard let self = self, self.preferences.milestoneHapticsEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        correctionEngine.onRuleAutoDowngraded = { [weak self] fromKey, toKey in
            guard let self = self, let core = self.coreView else { return }
            self.undoStrip.show(
                rawCharacter: "Rule \(fromKey)->\(toKey)",
                correctedCharacter: "Only When Uncertain",
                isDark: self.textDocumentProxy.keyboardAppearance == .dark,
                in: core
            )
        }
        correctionEngine.linguisticGateCheck = { [weak self] wordSoFar, raw, corrected in
            guard let self else { return true }
            return self.linguisticGate.shouldAllowCorrection(
                wordSoFar: wordSoFar,
                raw: raw,
                corrected: corrected
            )
        }

        loadOrResumeSession()

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: preferences.keyboardHeightPoints + KeyboardCoreView.topStripHeight)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        keyboardHeightConstraint = heightConstraint

        setupKeyboard()
    }

    private func styleInputContainerViews() {
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        view.applyKiteKeyboardContainerStyle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The system input wrapper above our view keeps a default gray fill;
        // tint all parent container views so the chrome matches the keyboard body.
        styleInputContainerViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        styleInputContainerViews()
        preferences = PreferencesStore.load()
        coreView?.applyUpdatedPreferences(preferences)
        keyboardHeightConstraint?.constant = preferences.keyboardHeightPoints + KeyboardCoreView.topStripHeight
        correctionEngine.updatePreferences(preferences)
        correctionEngine.loadProfile()
        refreshHistoricalSessionCache()
        
        // Ensure initial layout constraints are committed
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // setupKeyboard() is intentionally omitted here to prevent duplicate views on repeated viewDidAppear calls.
    }

    /// Resumes recent sessions or starts a new one to prevent fragmented history entries.
    private func loadOrResumeSession() {
        guard let data = SharedStore.getSharedData(forKey: SharedStore.Keys.currentSession),
              let existing = try? JSONDecoder().decode(SessionData.self, from: data) else {
            sessionData = SessionData()
            return
        }
        let lastActivity = existing.rawTaps.last?.timestamp ?? existing.date.timeIntervalSince1970
        let now = Date().timeIntervalSince1970
        if now - lastActivity < sessionContinuationWindow {
            sessionData = existing
        } else {
            SessionHistoryStore.append(existing)
            sessionData = SessionData()
            refreshHistoricalSessionCache()
            saveSession()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        performDiskSave()
        correctionEngine.saveProfileImmediately()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        
        // Sync keyboard appearance for Dark Mode
        coreView?.updateAppearance(textDocumentProxy.keyboardAppearance ?? .light)

        let currentContext = wordSoFarBeforeCurrentTap()
        if !insertedWordBuffer.isEmpty && !currentContext.hasSuffix(insertedWordBuffer) {
            rawWordBuffer = ""
            insertedWordBuffer = ""
            fastRawWordBuffer = ""
            retroactiveEngine.clearBuffer()
        }

        // Show suggestions for highlighted words
        if let selected = textDocumentProxy.selectedText,
           !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let suggestions = autocorrectEngine.suggestions(for: selected, contextBefore: "")
            let filtered = selected.contains("-") ? suggestions : suggestions.filter { !$0.contains("-") }
            if !filtered.isEmpty, let core = coreView {
                let isDark = textDocumentProxy.keyboardAppearance == .dark
                suggestionStrip.show(suggestions: Array(filtered.prefix(3)), motorExplained: [], isDark: isDark, in: core)
            }
        }
    }

    private func setupKeyboard() {
        guard coreView == nil else { return }
        coreView = KeyboardCoreView()
        coreView?.translatesAutoresizingMaskIntoConstraints = false
        coreView?.applyUpdatedPreferences(preferences)
        if let core = coreView {
            view.addSubview(core)
            NSLayoutConstraint.activate([
                core.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                core.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                core.topAnchor.constraint(equalTo: view.topAnchor),
                core.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            // Touch Latency Bypass: Find any parent scroll views and disable delays
            DispatchQueue.main.async {
                var current: UIView? = self.view
                while let v = current {
                    if let scrollView = v as? UIScrollView {
                        scrollView.delaysContentTouches = false
                    }
                    current = v.superview
                }
            }
        }

        // ADDED: Add suggestion and undo strips as subviews to coreView and constrain them (from Group 1 of initial 6 groups)
        if let core = coreView {
            suggestionStrip.translatesAutoresizingMaskIntoConstraints = false
            undoStrip.translatesAutoresizingMaskIntoConstraints = false
            
            core.addSubview(suggestionStrip)
            core.addSubview(undoStrip)

            NSLayoutConstraint.activate([
                suggestionStrip.leadingAnchor.constraint(equalTo: core.leadingAnchor),
                suggestionStrip.trailingAnchor.constraint(equalTo: core.trailingAnchor),
                suggestionStrip.topAnchor.constraint(equalTo: core.topAnchor),
                suggestionStrip.heightAnchor.constraint(equalToConstant: KeyboardCoreView.topStripHeight),

                undoStrip.leadingAnchor.constraint(equalTo: core.leadingAnchor),
                undoStrip.trailingAnchor.constraint(equalTo: core.trailingAnchor),
                undoStrip.topAnchor.constraint(equalTo: core.topAnchor),
                undoStrip.heightAnchor.constraint(equalToConstant: KeyboardCoreView.topStripHeight)
            ])
            undoStrip.hide()
            suggestionStrip.hide()
        }
        
        // Sync cache with fresh data
        coreView?.updateLearnedOffsets(correctionEngine.currentKeyOffsets)
        coreView?.refreshAllConfidenceColors()

        coreView?.onControlKey = { [weak self] key, timestamp in
            self?.handleControlKey(key, timestamp: timestamp)
        }
        coreView?.onCorrectableKeyTapped = { [weak self] baseKey, rawPoint, keyFrames, timestamp, frequency in
            self?.handleCorrectableKey(baseKey, rawPoint: rawPoint, keyFrames: keyFrames, timestamp: timestamp, detectedFrequencyHz: frequency) ?? ""
        }

        coreView?.onKeyLongPressed = { [weak self] baseKey in
            self?.showKeyInfo(for: baseKey)
        }

        undoStrip.onRevertTapped = { [weak self] in self?.undoLastCorrection() }
        suggestionStrip.onSuggestionTapped = { [weak self] suggestion in
            self?.applySuggestionChip(suggestion)
        }
    }

    private func matchCase(text: String, template: String) -> String {
        guard !text.isEmpty, !template.isEmpty else { return text }
        let isAllUpper = template.count >= 1 && template == template.uppercased() && template.rangeOfCharacter(from: .letters) != nil
        let isFirstUpper = template.first?.isUppercase == true
        
        if isAllUpper {
            return text.uppercased()
        } else if isFirstUpper {
            return text.prefix(1).uppercased() + text.dropFirst().lowercased()
        } else {
            return text.lowercased()
        }
    }

    private func levenshteinDistance(a: String, b: String) -> Int {
        let target = b
        let empty = [Int](repeating: 0, count: target.count + 1)
        var last = [Int](0...target.count)

        for (i, sourceChar) in a.enumerated() {
            var current = [i + 1] + empty.dropFirst()
            for (j, targetChar) in target.enumerated() {
                if sourceChar == targetChar {
                    current[j + 1] = last[j]
                } else {
                    current[j + 1] = min(last[j], last[j + 1], current[j]) + 1
                }
            }
            last = current
        }
        return last.last ?? 0
    }

    private func matchExpansionCase(text: String, template: String) -> String {
        guard !text.isEmpty, !template.isEmpty else { return text }
        let isAllUpper = template.count >= 1 && template == template.uppercased() && template.rangeOfCharacter(from: .letters) != nil
        let isFirstUpper = template.first?.isUppercase == true
        
        if isAllUpper { return text.uppercased() }
        else if text.first?.isUppercase == true {
            let first = text.prefix(1).uppercased()
            let rest = text.dropFirst()
            return first + rest
        } else {
            return text
        }
    }

    private func processRejection(record: CorrectionRecord) {
        let baseKey = record.baseKey
        let resolvedKey = record.resolvedKey
        let wordContext = record.wordContext
        
        correctionEngine.markCorrectionRejected(key: baseKey, correctedKey: resolvedKey)
        correctionEngine.markOverrideRejected(fromKey: baseKey, toKey: resolvedKey)
        retroactiveEngine.markRetroactiveRejection(from: baseKey, to: resolvedKey)

        if !wordContext.isEmpty, baseKey.count == 1, let rawChar = baseKey.first, let corrChar = resolvedKey.first {
            linguisticGate.markCorrectionRejected(wordSoFar: wordContext, raw: rawChar, corrected: corrChar)
        }

        let targetResolved = resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let restoredBase = baseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let rejectionKey = "\(restoredBase.lowercased())->\(targetResolved.lowercased())"
        
        let repeatCount = (SharedStore.defaults?.integer(forKey: "rej_\(rejectionKey)") ?? 0) + 1
        SharedStore.defaults?.set(repeatCount, forKey: "rej_\(rejectionKey)")
        if repeatCount >= 1 {
            let wordToProtect = wordContext.isEmpty ? restoredBase.lowercased() : (wordContext + restoredBase).lowercased()
            if !SharedStore.protectedWords.contains(wordToProtect) {
                SharedStore.protectedWords.append(wordToProtect)
            }
        }
        
        // Decrease confidence of auto-learned rules if undone
        var prefs = preferences
        if var rule = prefs.customWordOverrides[restoredBase.lowercased()], rule.correctedWord.lowercased() == targetResolved.lowercased() {
            if rule.isAutoLearned {
                rule.confidence = max(0, rule.confidence - 2)
                if rule.confidence == 0 {
                    prefs.customWordOverrides.removeValue(forKey: restoredBase.lowercased())
                } else {
                    prefs.customWordOverrides[restoredBase.lowercased()] = rule
                }
                preferences = prefs
                PreferencesStore.save(prefs)
            }
        }
    }

    private func undoLastCorrection() {
        let now = Date().timeIntervalSince1970
        guard let record = lastCorrection, now - lastCorrectionWallTime < rejectionWindow else {
            undoStrip.hide()
            return
        }
        guard let contextBefore = textDocumentProxy.documentContextBeforeInput, !contextBefore.isEmpty else {
            undoStrip.hide()
            return
        }

        // 1. Permanently protect restored word in linguistic whitelist & disarm retroactive engine
        let lowerBase = record.baseKey.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !lowerBase.isEmpty {
            linguisticGate.recordAcceptedWord(lowerBase)
            if !SharedStore.customWhitelistedWords.contains(lowerBase) {
                SharedStore.customWhitelistedWords.append(lowerBase)
            }
        }
        retroactiveEngine.disarmForCurrentWord()

        // 2. Separate trailing punctuation/whitespace from the text context
        var trailingSuffix = ""
        var textToSearch = contextBefore
        while let last = textToSearch.last, !last.isLetter && !last.isNumber && last != "'" {
            trailingSuffix = String(last) + trailingSuffix
            textToSearch.removeLast()
        }

        let currentWordToken = String(textToSearch.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "'" }.reversed())
        let targetResolved = record.resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let restoredBase = record.baseKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Revert Text Field (Hybrid Approach)
        if record.resolvedKey.count == 1 && record.baseKey.count == 1 {
            // A. SINGLE-LETTER SPATIAL CORRECTION (Character-Index Targeted Reversion)
            if !currentWordToken.isEmpty {
                var wordChars = Array(currentWordToken)
                let isLower = coreView?.isLowercaseActive ?? false
                let recordsToRevert = !activeWordCorrectionStack.isEmpty ? activeWordCorrectionStack : [record]

                for rec in recordsToRevert {
                    let targetIndex = rec.characterIndexInWord
                    if targetIndex >= 0 && targetIndex < wordChars.count {
                        let baseString = rec.baseKey
                        let rawCased = baseString.lowercased() == "space" ? " " : (isLower ? baseString.lowercased() : baseString.uppercased())
                        wordChars[targetIndex] = Character(rawCased)
                    }
                }

                let revertedWord = String(wordChars)
                let deleteCount = currentWordToken.count + trailingSuffix.count
                for _ in 0..<deleteCount {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(revertedWord + trailingSuffix)
            }
        } else {
            // B. WORD-LEVEL PUNCTUATION-AGNOSTIC REVERSION
            if let exactRaw = record.exactRawText, let exactCorr = record.exactCorrectedText {
                for _ in 0..<exactCorr.count {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(exactRaw)
            } else if !currentWordToken.isEmpty {
                let deleteCount = currentWordToken.count + trailingSuffix.count
                for _ in 0..<deleteCount {
                    textDocumentProxy.deleteBackward()
                }
                
                let finalRestored: String
                if restoredBase.count == currentWordToken.count {
                    finalRestored = matchCase(text: restoredBase, template: currentWordToken)
                } else {
                    finalRestored = restoredBase
                }
                
                textDocumentProxy.insertText(finalRestored + trailingSuffix)
            } else if !targetResolved.isEmpty && contextBefore.lowercased().hasSuffix(targetResolved.lowercased()) {
                let deleteCount = targetResolved.count
                for _ in 0..<deleteCount {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(restoredBase)
            }
        }

        // 4. Reduce confidence and recalibrate spatial engine offsets + Repeated Rejection Blacklist
        let recordsToRevert = !activeWordCorrectionStack.isEmpty ? activeWordCorrectionStack : [record]
        for rec in recordsToRevert {
            processRejection(record: rec)
        }

        activeWordCorrectionStack.removeAll()
        recordSessionRejection()
        lastCorrection = nil
        undoStrip.hide()
    }

    /// Adjusts session-level counters when a correction is rejected
    /// (explicit undo or implicit backspace+retype).
    private func recordSessionRejection() {
        guard let tapIndex = lastCorrectionTapIndex, tapIndex >= 0, tapIndex < sessionData.rawTaps.count else { return }
        
        // Update the tap event to mark it as rejected
        sessionData.rawTaps[tapIndex].correctionAccepted = false
        
        // Adjust session-level counters to reflect the rejection
        if sessionData.correctionsAccepted > 0 {
            sessionData.correctionsAccepted -= 1
        }
        sessionData.correctionsRejected += 1
        
        // Recalculate accuracy rate
        if sessionData.correctionsApplied > 0 {
            sessionData.accuracyRate = Double(sessionData.correctionsAccepted) / Double(sessionData.correctionsApplied)
        }
        
        // Clear the stored index since we've processed this rejection
        lastCorrectionTapIndex = nil
        
        saveSession()
    }

    // MARK: - Temporal Linguistic Gate

    func insertCharacter(_ finalChar: Character, rawChar: Character) {
        textDocumentProxy.insertText(String(finalChar))

        // Append to our tracking buffers
        rawWordBuffer.append(rawChar)
        insertedWordBuffer.append(finalChar)
    }

    func handleBackspace() {
        if !isDeletingWord {
            let context = textDocumentProxy.documentContextBeforeInput ?? ""
            let trimmed = context.trimmingCharacters(in: .whitespaces)
            let wordBeforeDelete = String(trimmed.reversed().prefix { $0.isLetter || $0 == "'" }.reversed())
            if !wordBeforeDelete.isEmpty {
                lastDeletedWord = wordBeforeDelete.lowercased()
                
                let withoutWord = String(trimmed.dropLast(wordBeforeDelete.count))
                let preWord = String(withoutWord.trimmingCharacters(in: .whitespacesAndNewlines).reversed().prefix { $0.isLetter || $0 == "'" }.reversed())
                lastDeletedWordContext = preWord.lowercased()
            }
            isDeletingWord = true
        }

        textDocumentProxy.deleteBackward()

        if !rawWordBuffer.isEmpty { rawWordBuffer.removeLast() }
        if !insertedWordBuffer.isEmpty { insertedWordBuffer.removeLast() }
        if !fastRawWordBuffer.isEmpty { fastRawWordBuffer.removeLast() }
        retroactiveEngine.disarmForCurrentWord()
        updateLiveSuggestions()
    }

    private var lastSpaceTapTime: TimeInterval = 0

    private func checkAutoCapitalizationState() {
        guard let context = textDocumentProxy.documentContextBeforeInput else {
            coreView?.setShiftActive(true)
            return
        }
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") {
            coreView?.setShiftActive(true)
        }
    }

    func handleWordCompletion(triggerString: String) {
        let actualInsertedWord = (lastTypedWord(before: "") ?? insertedWordBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let deleted = lastDeletedWord?.trimmingCharacters(in: .whitespacesAndNewlines), !actualInsertedWord.isEmpty {
            let insertedLower = actualInsertedWord.lowercased()
            if deleted != insertedLower {
                let dist = levenshteinDistance(a: deleted, b: insertedLower)
                if dist == 1 {
                    let insertedIsReal = linguisticGate.isCompleteRealWord(insertedLower)
                    if insertedIsReal {
                        var prefs = preferences
                        var existingRule = prefs.customWordOverrides[deleted]
                        
                        if let existing = existingRule, existing.correctedWord == insertedLower {
                            var updatedRule = existing
                            updatedRule.confidence += 1
                            prefs.customWordOverrides[deleted] = updatedRule
                        } else if existingRule == nil || (existingRule!.isAutoLearned && existingRule!.correctedWord != insertedLower) {
                            let newRule = CustomWordCorrectionRule(
                                typedWord: deleted,
                                correctedWord: insertedLower,
                                strictness: .smartSuffixes,
                                context: lastDeletedWordContext?.isEmpty == false ? .precedingWord : .anywhere,
                                specificContextWord: lastDeletedWordContext ?? "",
                                isAutoLearned: true,
                                confidence: 1
                            )
                            prefs.customWordOverrides[deleted] = newRule
                        }
                        preferences = prefs
                        PreferencesStore.save(prefs)
                    }
                }
            }
        }
        lastDeletedWord = nil
        lastDeletedWordContext = nil

        fastRawWordBuffer = ""
        activeWordCorrectionStack.removeAll()
        retroactiveEngine.clearBuffer()
        correctionEngine.resetWordCorrectionContext()
        linguisticGate.resetCache()

        // Contraction Auto-Formatting (e.g. dont -> don't, im -> I'm)
        let lowerWord = insertedWordBuffer.lowercased()
        
        // Isolated Dropped-Tap Fixes (e.g., "o" -> "to")
        if insertedWordBuffer.count == 1 && !disabledDroppedTapFixes.contains(lowerWord) {
            if let fix = CommonWordList.isolatedDroppedTapFixes[lowerWord] {
                let formatted = matchCase(text: fix, template: insertedWordBuffer)
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(formatted)
                
                lastDroppedTapFix = (raw: insertedWordBuffer, formatted: formatted, timestamp: Date().timeIntervalSince1970)
                
                insertedWordBuffer = formatted
            }
        }
        
        if let contraction = CommonWordList.contractions[lowerWord] {
            let formatted = matchCase(text: contraction, template: insertedWordBuffer)
            for _ in 0..<insertedWordBuffer.count {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(formatted)
            insertedWordBuffer = formatted
        }

        // Only evaluate if we actually have a word in the buffer
        guard !insertedWordBuffer.isEmpty else {
            textDocumentProxy.insertText(triggerString)
            return
        }

        // Check if any corrections or overrides were applied to this word
        if insertedWordBuffer.lowercased() != rawWordBuffer.lowercased() {

            let rawIsReal = linguisticGate.isCompleteRealWord(rawWordBuffer.lowercased())
            let insertedIsReal = linguisticGate.isCompleteRealWord(insertedWordBuffer.lowercased())

            // TEMPORAL FIX: If the override ruined a perfectly valid word, revert it.
            if rawIsReal && !insertedIsReal {

                // Match casing of the inserted word on screen (e.g. "Ehen" -> "When", "ehen" -> "when")
                let correctedWord = matchCase(text: rawWordBuffer, template: insertedWordBuffer)

                // 1. Delete the corrupted word from the screen
                for _ in 0..<insertedWordBuffer.count {
                    textDocumentProxy.deleteBackward()
                }

                // 2. Insert the user's original raw intent with matched case
                textDocumentProxy.insertText(correctedWord)

                // 3. Log the retroactive veto for your heatmaps/stats
                sessionData.linguisticVetoes += 1
                ExplainabilityLogStore.append(ExplainabilityLogEntry(fromKey: insertedWordBuffer, toKey: correctedWord, mechanism: "Safety Net", confidence: 0.95))

                // 4. Show safety net notification on top strip, flash ripples, & play success haptic
                if let core = coreView {
                    let isDark = textDocumentProxy.keyboardAppearance == .dark
                    undoStrip.show(rawCharacter: insertedWordBuffer, correctedCharacter: correctedWord, isDark: isDark, in: core)
                    for char in rawWordBuffer {
                        core.flashCorrectionFeedback(for: String(char).uppercased())
                    }
                }
                if preferences.correctionHapticsEnabled {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                // 5. Reconcile session + per-key stats: whichever
                // characters in this word were corrected were already
                // optimistically logged as accepted per-keystroke, before
                // this word-level check caught the problem. Walk back
                // through and count them as rejected instead.
                let rawChars = Array(rawWordBuffer)
                let insertedChars = Array(insertedWordBuffer)
                var correctedCharCount = 0
                for (rawChar, insertedChar) in zip(rawChars, insertedChars) where rawChar != insertedChar {
                    correctedCharCount += 1
                }
                
                // Walk back through the tap events to find and mark the corrected characters as rejected
                var tapsToMark = correctedCharCount
                var tapIndex = sessionData.rawTaps.count - 1
                while tapsToMark > 0 && tapIndex >= 0 {
                    let tap = sessionData.rawTaps[tapIndex]
                    if tap.correctionApplied && tap.correctionAccepted == true {
                        sessionData.rawTaps[tapIndex].correctionAccepted = false
                        if sessionData.correctionsAccepted > 0 {
                            sessionData.correctionsAccepted -= 1
                            sessionData.correctionsRejected += 1
                        }
                        tapsToMark -= 1
                    }
                    tapIndex -= 1
                }
                
                // Recalculate accuracy rate
                if sessionData.correctionsApplied > 0 {
                    sessionData.accuracyRate = Double(sessionData.correctionsAccepted) / Double(sessionData.correctionsApplied)
                }
                
                // Also update per-key stats
                for (rawChar, insertedChar) in zip(rawChars, insertedChars) where rawChar != insertedChar {
                    correctionEngine.markCorrectionRejected(key: String(rawChar).uppercased())
                }
            } else {
                // Word completed cleanly — record in Custom Name & Acronym Prefix Memory
                linguisticGate.recordAcceptedWord(rawWordBuffer)
            }
        }

        // Insert the space or punctuation that triggered this check
        textDocumentProxy.insertText(triggerString)

        // Clear the buffers for the next word
        rawWordBuffer = ""
        insertedWordBuffer = ""
    }

    private func handleControlKey(_ key: String, timestamp: TimeInterval) {
        guard correctionEngine.shouldAcceptKeystroke(key: key, timestamp: timestamp) else { return }

        switch key {
        case "⌫":
            let now = Date().timeIntervalSince1970
            if let fix = lastDroppedTapFix, now - fix.timestamp < 3.0 {
                textDocumentProxy.deleteBackward()
                for _ in 0..<fix.formatted.count {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(fix.raw)
                disabledDroppedTapFixes.insert(fix.raw.lowercased())
                lastDroppedTapFix = nil
                return
            }
            
            if now - lastBackspaceTimestamp < 0.50, lastCorrection != nil {
                undoLastCorrection()
                lastBackspaceTimestamp = 0
                return
            }
            lastBackspaceTimestamp = now
            if let last = lastCorrection, timestamp - last.timestamp < rejectionWindow {
                pendingRejectionCandidate = last
                lastCorrection = nil
                undoStrip.hide()
            }
            handleBackspace()
        case "space":
            let now = Date().timeIntervalSince1970
            if now - lastSpaceTapTime < 0.40 {
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                coreView?.setShiftActive(true)
                lastSpaceTapTime = 0
            } else {
                lastSpaceTapTime = now
                handleWordCompletion(triggerString: " ")
                checkForSpellingSuggestion(afterInserting: " ")
                checkAutoCapitalizationState()
            }
            pendingRejectionCandidate = nil
        case "return":
            handleWordCompletion(triggerString: "\n")
            checkForSpellingSuggestion(afterInserting: "\n")
            pendingRejectionCandidate = nil
        default: break
        }
        logTap(baseKey: key, rawPoint: .zero, correctedKey: nil, correctionApplied: false, timestamp: timestamp, interval: intervalSinceLast(timestamp))
    }

    private func handleCorrectableKey(_ baseKey: String, rawPoint: CGPoint, keyFrames: [String: CGRect], timestamp: TimeInterval, detectedFrequencyHz: Double?) -> String {
        guard correctionEngine.shouldAcceptKeystroke(key: baseKey, timestamp: timestamp) else { return "" }

        isDeletingWord = false
        // RESET SPACE TIMER: Prevents fast typing (Space -> Letter -> Space) from triggering the double-space shortcut.
        lastSpaceTapTime = 0

        linguisticGate.updateKeystrokeIndex(sessionData.totalKeystrokes)
        tapXCoordinates.append(rawPoint.x)
        if tapXCoordinates.count > 50 { tapXCoordinates.removeFirst() }
        keyboardWidth = coreView?.bounds.width ?? 0

        // Group 6 changes applied here (initial 6 groups):
        let wordSoFar = wordSoFarBeforeCurrentTap()
        let likelyNextLetters = getLikelyNextLetters(for: wordSoFar)
        let result = correctionEngine.resolveTap(
            tappedKey: baseKey,
            rawPoint: rawPoint,
            wordSoFar: wordSoFar,
            wordPosition: currentWordPosition(),
            interval: intervalSinceLast(timestamp),
            isSensitiveField: isSensitiveField(),
            allKeyFrames: keyFrames,
            likelyNextLetters: likelyNextLetters
        )

        let isShiftActive = !(coreView?.isLowercaseActive ?? true)
        let shouldBeUpper = isShiftActive

        func cased(_ key: String) -> String {
            if key.lowercased() == "space" { return " " }
            guard key.count == 1, key.rangeOfCharacter(from: .letters) != nil else { return key }
            return shouldBeUpper ? key.uppercased() : key.lowercased()
        }

        var textToInsert = cased(result.resolvedKey)
        var didCorrect = result.didApplyDirectionalShift || result.didApplyScatterWidening || result.isManualOverride

        if !result.isManualOverride, let correctedChar = result.resolvedKey.first, result.resolvedKey.count == 1, let rawChar = (baseKey.lowercased() == "space" ? " " : baseKey.first) {
            if rawChar != correctedChar {
                let wordSoFar = wordSoFarBeforeCurrentTap()
                if !linguisticGate.shouldAllowCorrection(wordSoFar: wordSoFar, raw: rawChar, corrected: correctedChar) {
                    textToInsert = cased(baseKey)
                    didCorrect = false
                    sessionData.linguisticVetoes += 1
                }
            }
        }

        if textToInsert == " " || baseKey.lowercased() == "space" {
            // First, do a final retroactive check with isWordBoundary = true
            if fastRawWordBuffer.count >= 2 {
                if let retro = retroactiveEngine.evaluateRetroactiveCorrection(currentWord: fastRawWordBuffer, allKeyFrames: keyFrames, isWordBoundary: true) {
                    for _ in 0..<fastRawWordBuffer.count {
                        textDocumentProxy.deleteBackward()
                    }
                    let casedRetro = matchCase(text: retro.corrected, template: retro.original)
                    textDocumentProxy.insertText(casedRetro)
                    
                    let rec = CorrectionRecord(
                        baseKey: retro.original,
                        resolvedKey: casedRetro,
                        rawPoint: .zero,
                        keyCenter: .zero,
                        timestamp: timestamp,
                        wordContext: "",
                        exactRawText: fastRawWordBuffer,
                        exactCorrectedText: casedRetro
                    )
                    lastCorrection = rec
                    lastCorrectionWallTime = Date().timeIntervalSince1970
                    
                    if let core = coreView {
                        let isDark = textDocumentProxy.keyboardAppearance == .dark
                        undoStrip.show(rawCharacter: retro.original, correctedCharacter: casedRetro, isDark: isDark, in: core)
                    }
                    fastRawWordBuffer = casedRetro
                    insertedWordBuffer = casedRetro
                }
            }
            
            handleWordCompletion(triggerString: " ")
            checkForSpellingSuggestion(afterInserting: " ")
        } else {
            textDocumentProxy.insertText(textToInsert)
            let rawChar: Character = baseKey.lowercased() == "space" ? " " : (baseKey.first ?? " ")
            if let iChar = textToInsert.first {
                rawWordBuffer.append(rawChar)
                insertedWordBuffer.append(iChar)
            }
            fastRawWordBuffer.append(textToInsert)
            retroactiveEngine.recordTap(
                rawKey: baseKey,
                touchPoint: rawPoint,
                keyCenter: CGPoint(x: keyFrames[baseKey]?.midX ?? rawPoint.x, y: keyFrames[baseKey]?.midY ?? rawPoint.y),
                timestamp: timestamp
            )

            // Post-word retroactive correction check starting at 2+ characters
            if fastRawWordBuffer.count >= 2 {
                if let retro = retroactiveEngine.evaluateRetroactiveCorrection(currentWord: fastRawWordBuffer, allKeyFrames: keyFrames) {
                    for _ in 0..<fastRawWordBuffer.count {
                        textDocumentProxy.deleteBackward()
                    }
                    let casedRetro = matchCase(text: retro.corrected, template: retro.original)
                    textDocumentProxy.insertText(casedRetro)
                    
                    let rec = CorrectionRecord(
                        baseKey: retro.original,
                        resolvedKey: casedRetro,
                        rawPoint: .zero,
                        keyCenter: .zero,
                        timestamp: timestamp,
                        wordContext: "",
                        exactRawText: fastRawWordBuffer,
                        exactCorrectedText: casedRetro
                    )
                    lastCorrection = rec
                    lastCorrectionWallTime = Date().timeIntervalSince1970
                    
                    let isDark = textDocumentProxy.keyboardAppearance == .dark
                    undoStrip.show(rawCharacter: retro.original, correctedCharacter: casedRetro, isDark: isDark, in: coreView!)
                    fastRawWordBuffer = casedRetro
                    insertedWordBuffer = casedRetro
                }
            }
            checkForSpellingSuggestion(afterInserting: textToInsert)
        }
        // End Group 6 changes


        if let pending = pendingRejectionCandidate,
           timestamp - pending.timestamp < rejectionWindow,
           pending.baseKey.lowercased().hasPrefix(baseKey.lowercased()),
           result.resolvedKey != pending.resolvedKey {
            processRejection(record: pending)
            recordSessionRejection()
        }
        pendingRejectionCandidate = nil

        if didCorrect {
            coreView?.flashCorrectionFeedback(for: baseKey)
            if preferences.audioCorrectionCueEnabled {
                AudioServicesPlaySystemSound(1104)
            }

            if preferences.correctionHapticsEnabled {
                let generator = UIImpactFeedbackGenerator(style: result.didApplyDirectionalShift ? .heavy : .light)
                generator.impactOccurred()
            }

            let mechanism = result.isManualOverride ? "Manual Override" : (result.didApplyDirectionalShift ? "Directional" : "Widened")
            ExplainabilityLogStore.append(ExplainabilityLogEntry(fromKey: baseKey, toKey: result.resolvedKey, mechanism: mechanism, confidence: correctionEngine.debugConfidence(for: baseKey)))

            let keyCenter = CGPoint(x: keyFrames[baseKey]?.midX ?? rawPoint.x, y: keyFrames[baseKey]?.midY ?? rawPoint.y)
            let activeWord = wordSoFarBeforeCurrentTap()
            let charIndex = max(0, activeWord.count - 1)
            let wordCtx = String(activeWord.dropLast())
            let rec = CorrectionRecord(baseKey: baseKey, resolvedKey: result.resolvedKey, rawPoint: rawPoint, keyCenter: keyCenter, timestamp: timestamp, characterIndexInWord: charIndex, wordContext: wordCtx)
            lastCorrection = rec
            activeWordCorrectionStack.append(rec)
            lastCorrectionWallTime = Date().timeIntervalSince1970
            suggestionStrip.hide()
            // Group 6 casing: Applied to undoStrip.show
            let isLower = coreView?.isLowercaseActive ?? false
            let rawCasedForUndo = baseKey.lowercased() == "space" ? "Space" : (isLower ? baseKey.lowercased() : baseKey.uppercased())
            let displayCorrected = textToInsert.lowercased() == "space" ? "Space" : textToInsert
            let isDark = textDocumentProxy.keyboardAppearance == .dark
            undoStrip.show(rawCharacter: rawCasedForUndo, correctedCharacter: displayCorrected, isDark: isDark, in: coreView!)

            if sessionStartTime == nil { sessionStartTime = timestamp }
            correctionTimestamps.append(timestamp)
        } else {
            struggleStreak = 0
        }

        let keyCenter = CGPoint(x: keyFrames[baseKey]?.midX ?? rawPoint.x, y: keyFrames[baseKey]?.midY ?? rawPoint.y)
        let interval = intervalSinceLast(timestamp)
        correctionEngine.recordTap(key: baseKey, rawPoint: rawPoint, keyCenter: keyCenter, interval: interval, detectedFrequencyHz: detectedFrequencyHz, accepted: true)

        // Update confidence colors in real-time after learning
        coreView?.updateLearnedOffsets(correctionEngine.currentKeyOffsets)
        coreView?.refreshConfidenceColor(for: baseKey)

        self.logTap(baseKey: baseKey, rawPoint: rawPoint, correctedKey: didCorrect ? result.resolvedKey : nil, correctionApplied: didCorrect, timestamp: timestamp, interval: interval)
        self.detectInputStyle()
        if didCorrect {
            self.checkFatigueAdaptation(now: timestamp)
            self.checkStruggle()
        }

        updateLiveSuggestions()
        coreView?.revertOneShotShiftIfNeeded()
        return textToInsert
    }

    private func intervalSinceLast(_ timestamp: TimeInterval) -> TimeInterval {
        let interval = lastTapTimestamp > 0 ? timestamp - lastTapTimestamp : 0
        lastTapTimestamp = timestamp
        return interval
    }

    private func currentWordPosition() -> CorrectionContext {
        guard let context = textDocumentProxy.documentContextBeforeInput, let last = context.last else {
            return .startOfWord
        }
        return last.isLetter ? .withinWord : .startOfWord
    }

    private func isSensitiveField() -> Bool {
        let type = textDocumentProxy.textContentType
        return textDocumentProxy.isSecureTextEntry == true
            || textDocumentProxy.keyboardType == .URL
            || textDocumentProxy.keyboardType == .emailAddress
            || type == .URL
            || type == .emailAddress
            || type == .password
            || type == .newPassword
            || type == .username
            || type == .nickname
            || type == .name
            || type == .givenName
            || type == .familyName
            || type == .middleName
    }

    private func checkForSpellingSuggestion(afterInserting insertedText: String) {
        if [" ", "\n"].contains(insertedText) {
            undoStrip.hide()
        }
        
        // 1. FAANG+ Manual Word-to-Word Overrides (Ultimate Priority)
        if [" ", "\n", ".", ",", "!", "?"].contains(insertedText),
           let word = lastTypedWord(before: insertedText) {
           
            if let rule = preferences.customWordOverrides[word.lowercased()] {
                var shouldApply = true
                
                // Context Check
                if rule.context == .startOfSentence {
                    // Start of sentence check: Is this the first word? (Rough approximation)
                    let fullContext = textDocumentProxy.documentContextBeforeInput ?? ""
                    let trimmed = fullContext.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count > word.count + 1 {
                        shouldApply = false
                    }
                } else if rule.context == .precedingWord {
                    let fullContext = textDocumentProxy.documentContextBeforeInput ?? ""
                    let words = fullContext.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    if words.count >= 2 {
                        let previousWord = words[words.count - 2].lowercased()
                        if previousWord != rule.specificContextWord.lowercased() {
                            shouldApply = false
                        }
                    } else {
                        shouldApply = false
                    }
                } else if rule.context == .followingWord {
                    // If the rule requires a following word, we CANNOT apply it instantly when they type "lobe".
                    shouldApply = false
                }
                
                if shouldApply {
                    let charsToDelete = insertedText.count + word.count
                    for _ in 0..<charsToDelete {
                        textDocumentProxy.deleteBackward()
                    }
                    let casedOverride = matchExpansionCase(text: rule.correctedWord, template: word)
                    textDocumentProxy.insertText(casedOverride + insertedText)
                    let isSilent = rule.isAutoLearned && rule.confidence >= 3
                    processWordCorrection(typedWord: word, correctedWord: casedOverride, addedTrailingSpace: insertedText == " ", silent: isSilent)
                    return
                }
            }
        }
        
        // 1.5 Smart Suffix Matching for Custom Rules (e.g. "lobes" -> "loves")
        if [" ", "\n", ".", ",", "!", "?"].contains(insertedText),
           let word = lastTypedWord(before: insertedText) {
            
            let lowerWord = word.lowercased()
            for rule in preferences.customWordOverrides.values {
                if rule.strictness == .smartSuffixes {
                    if lowerWord.hasPrefix(rule.typedWord) && lowerWord.count > rule.typedWord.count {
                        let suffix = lowerWord.dropFirst(rule.typedWord.count)
                        if ["s", "es", "ed", "ing", "ly"].contains(String(suffix)) {
                            // Basic heuristic replacement
                            var newCorrected = rule.correctedWord
                            if newCorrected.hasSuffix("e") && (suffix == "ed" || suffix == "ing" || suffix == "es") {
                                newCorrected.removeLast()
                            }
                            newCorrected += suffix
                            
                            let charsToDelete = insertedText.count + word.count
                            for _ in 0..<charsToDelete {
                                textDocumentProxy.deleteBackward()
                            }
                            let casedOverride = matchExpansionCase(text: newCorrected, template: word)
                            textDocumentProxy.insertText(casedOverride + insertedText)
                            let isSilent = rule.isAutoLearned && rule.confidence >= 3
                            processWordCorrection(typedWord: word, correctedWord: casedOverride, addedTrailingSpace: insertedText == " ", silent: isSilent)
                            return
                        }
                    }
                }
            }
        }

        // 1.8 Retroactive Check for .followingWord Context Rules
        if [" ", "\n", ".", ",", "!", "?"].contains(insertedText),
           let context = textDocumentProxy.documentContextBeforeInput {
            let words = context.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if words.count >= 2 {
                let currentWord = words[words.count - 1].lowercased()
                let prevWordOriginal = words[words.count - 2]
                let prevWord = prevWordOriginal.lowercased()
                
                if let rule = preferences.customWordOverrides[prevWord], rule.context == .followingWord {
                    if currentWord == rule.specificContextWord.lowercased() {
                        // Retroactive swap!
                        // The user typed: "lobe " (which we ignored) then "morning ".
                        // We need to delete back "morning ", then "lobe", insert "love " and "morning ".
                        let trailingText = currentWord + insertedText
                        let charsToDelete = trailingText.count + prevWord.count
                        
                        // BUT WAIT, context might have punctuation. To be safe, just delete charsToDelete.
                        // Actually, let's just do a string replacement on the last occurrence.
                        if let targetRange = context.range(of: prevWordOriginal, options: .backwards) {
                            let charsToDeleteRetro = context.distance(from: targetRange.lowerBound, to: context.endIndex) + insertedText.count
                            for _ in 0..<charsToDeleteRetro {
                                textDocumentProxy.deleteBackward()
                            }
                            let casedOverride = matchExpansionCase(text: rule.correctedWord, template: prevWordOriginal)
                            let remainder = String(context[targetRange.upperBound...])
                            textDocumentProxy.insertText(casedOverride + remainder + insertedText)
                            
                            let isSilent = rule.isAutoLearned && rule.confidence >= 3
                            processWordCorrection(typedWord: prevWordOriginal, correctedWord: casedOverride, addedTrailingSpace: false, silent: isSilent)
                            return
                        }
                    }
                }
            }
        }

        // 2. Sentence-Level N-Gram Context Corrector (e.g. "Well be" -> "We'll be", "Ill go" -> "I'll go")
        if [" ", "\n", ".", ",", "!", "?"].contains(insertedText), let context = textDocumentProxy.documentContextBeforeInput {
            if let match = NGramContextEngine.shared.evaluateContext(context) {
                let charsToDelete = match.trailingText.count + match.originalWord.count
                for _ in 0..<charsToDelete {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(match.replacementWord + match.trailingText)
                let timestamp = Date().timeIntervalSince1970
                lastCorrection = CorrectionRecord(
                    baseKey: match.originalWord + match.trailingText,
                    resolvedKey: match.replacementWord + match.trailingText,
                    rawPoint: .zero,
                    keyCenter: .zero,
                    timestamp: timestamp,
                    wordContext: ""
                )
                lastCorrectionWallTime = Date().timeIntervalSince1970
                if let core = coreView {
                    let isDark = textDocumentProxy.keyboardAppearance == .dark
                    undoStrip.show(rawCharacter: match.originalWord, correctedCharacter: match.replacementWord, isDark: isDark, in: core)
                }
                return
            }
        }

        guard preferences.spellingSuggestionsEnabled else { return }
        guard [" ", "\n", ".", ",", "!", "?"].contains(insertedText) else { return }
        guard let word = lastTypedWord(before: insertedText), word.count >= 2 else { return }

        let lowerWord = word.lowercased()

        // High-Frequency Overrides: Obscure 2-letter dictionary entries (e.g. "os")
        // should NOT block auto-correction to top high-frequency words (e.g. "is").
        let obscureTwoLetterList: Set<String> = ["os", "aa", "ax", "io"]
        let isObscureTwoLetterWord = obscureTwoLetterList.contains(lowerWord)

        // 1. Never auto-correct valid words (unless obscure 2-letter entry), protected words, or custom whitelisted words
        if (!isObscureTwoLetterWord && linguisticGate.isCompleteRealWord(lowerWord)) ||
            SharedStore.protectedWords.contains(lowerWord) ||
            SharedStore.customWhitelistedWords.contains(lowerWord) {
            return
        }

        let ctx = textDocumentProxy.documentContextBeforeInput ?? ""
        let searchString = word + insertedText
        let contextBeforeWord = ctx.hasSuffix(searchString) ? String(ctx.dropLast(searchString.count)) : ""
        var suggestions = autocorrectEngine.suggestions(for: word, contextBefore: contextBeforeWord)
        
        // Filter hyphens
        if !word.contains("-") {
            suggestions.removeAll { $0.contains("-") }
        }
        
        guard let topSuggestion = suggestions.first else { return }

        // Case matching
        let casedCorrection: String
        if word.first?.isUppercase == true {
            casedCorrection = topSuggestion.capitalized
        } else {
            casedCorrection = topSuggestion.lowercased()
        }

        // Automatic Auto-Correction on Word Boundary
        let charsToDelete = word.count + insertedText.count
        for _ in 0..<charsToDelete {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(casedCorrection + insertedText)

        let timestamp = Date().timeIntervalSince1970
        lastCorrection = CorrectionRecord(
            baseKey: word,
            resolvedKey: casedCorrection,
            rawPoint: .zero,
            keyCenter: .zero,
            timestamp: timestamp,
            wordContext: ""
        )
        lastCorrectionWallTime = Date().timeIntervalSince1970
        if let core = coreView {
            let isDark = textDocumentProxy.keyboardAppearance == .dark
            undoStrip.show(rawCharacter: word, correctedCharacter: casedCorrection, isDark: isDark, in: core)
        }

        // Process motor learning and ripple feedback
        let hasTrailingSpace = insertedText == " "
        processWordCorrection(typedWord: word, correctedWord: casedCorrection, addedTrailingSpace: hasTrailingSpace)

        // Track metrics
        sessionData.correctionsApplied += 1
        sessionData.correctionsAccepted += 1
        saveSession()
    }

    private func lastTypedWord(before boundaryInsertion: String) -> String? {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return nil }
        let withoutBoundary = String(context.dropLast(boundaryInsertion.count))
        let word = withoutBoundary.reversed().prefix { $0.isLetter }
        return word.isEmpty ? nil : String(word.reversed())
    }

    private func getLikelyNextLetters(for wordSoFar: String) -> Set<Character> {
        guard !wordSoFar.isEmpty else { return [] }
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: wordSoFar.utf16.count)
        guard let completions = checker.completions(forPartialWordRange: range, in: wordSoFar, language: "en_US") else { return [] }
        
        var nextLetters = Set<Character>()
        let nextIndex = wordSoFar.count
        for word in completions.prefix(15) { // Top 15 matches for speed
            if word.count > nextIndex {
                let char = word[word.index(word.startIndex, offsetBy: nextIndex)]
                nextLetters.insert(char)
            }
        }
        return nextLetters
    }

    private var pendingSaveItem: DispatchWorkItem?

    private func scheduleDebouncedDiskSave() {
        pendingSaveItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.performDiskSave()
        }
        pendingSaveItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func performDiskSave() {
        if sessionData.rawTaps.count > 200 {
            sessionData.rawTaps = Array(sessionData.rawTaps.suffix(200))
        }
        let dataToSave = sessionData
        let profileToSave = correctionEngine.profile
        DispatchQueue.global(qos: .utility).async {
            if let encoded = try? JSONEncoder().encode(dataToSave) {
                SharedStore.setSharedData(encoded, forKey: SharedStore.Keys.currentSession)
            }
            if let encoded = try? JSONEncoder().encode(profileToSave) {
                SharedStore.setSharedData(encoded, forKey: SharedStore.Keys.motorProfile)
            }
        }
    }

    private func logTap(baseKey: String, rawPoint: CGPoint, correctedKey: String?, correctionApplied: Bool, timestamp: TimeInterval, interval: TimeInterval) {
        let tapEvent = TapEvent(key: baseKey, rawX: rawPoint.x, rawY: rawPoint.y, correctedKey: correctedKey, correctionApplied: correctionApplied, correctionAccepted: correctionApplied ? true : nil, timestamp: timestamp, intervalSinceLast: interval)
        
        if correctionApplied {
            lastCorrectionTapIndex = sessionData.rawTaps.count
        }
        
        sessionData.addTap(tapEvent)
        scheduleDebouncedDiskSave()
        let percentage = sessionData.correctionsApplied > 0 ? Int(sessionData.accuracyRate * 100) : nil
        coreView?.updateAccuracyCounter(percentage: percentage, isDemoMode: preferences.isDemoMode)
    }

    private func detectInputStyle() {
        guard tapXCoordinates.count >= 50, keyboardWidth > 0 else { return }
        let minX = tapXCoordinates.min() ?? 0
        let maxX = tapXCoordinates.max() ?? 0
        let spreadRatio = (maxX - minX) / keyboardWidth
        let inputStyle = spreadRatio > 0.6 ? "thumb" : (spreadRatio < 0.4 ? "finger" : "unknown")
        SharedStore.defaults?.set(inputStyle, forKey: SharedStore.Keys.inputStyle)
    }

    private func saveSession() {
        scheduleDebouncedDiskSave()
    }

    private func applySuggestionChip(_ suggestion: String) {
        guard let contextBefore = textDocumentProxy.documentContextBeforeInput else { return }
        
        var trailingSuffix = ""
        var textToSearch = contextBefore
        while let last = textToSearch.last, !last.isLetter && !last.isNumber && last != "'" {
            trailingSuffix = String(last) + trailingSuffix
            textToSearch.removeLast()
        }
        
        let currentWord = String(textToSearch.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "'" }.reversed())
        guard !currentWord.isEmpty else { return }
        
        let deleteCount = currentWord.count + trailingSuffix.count
        for _ in 0..<deleteCount {
            textDocumentProxy.deleteBackward()
        }
        
        let casedCorrection = currentWord.first?.isUppercase == true ? suggestion.capitalized : suggestion.lowercased()
        let textToInsert = trailingSuffix.isEmpty ? (casedCorrection + " ") : (casedCorrection + trailingSuffix)
        textDocumentProxy.insertText(textToInsert)
        suggestionStrip.hide()
        
        let hasTrailingSpace = textToInsert.hasSuffix(" ")
        processWordCorrection(typedWord: currentWord, correctedWord: casedCorrection, addedTrailingSpace: hasTrailingSpace)
        
        rawWordBuffer = ""
        insertedWordBuffer = ""
    }

    private func updateLiveSuggestions() {
        pendingSuggestionWorkItem?.cancel()
        
        guard preferences.spellingSuggestionsEnabled else { return }
        if let undoVisible = coreView?.subviews.contains(where: { $0 == undoStrip && !$0.isHidden }), undoVisible {
            return
        }
        let currentWord = wordSoFarBeforeCurrentTap()
        guard currentWord.count >= 2 else {
            suggestionStrip.hide()
            return
        }
        let ctx = textDocumentProxy.documentContextBeforeInput ?? ""
        let contextBeforeWord = ctx.hasSuffix(currentWord) ? String(ctx.dropLast(currentWord.count)) : ""

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let suggestions = self.autocorrectEngine.suggestions(for: currentWord, contextBefore: contextBeforeWord)
            let pairs = self.cachedConfusionPairs
            var motorExplained: Set<String> = []
            for s in suggestions {
                if MotorSuggestionMatcher.isMotorExplained(typed: currentWord, suggestion: s, confusionPairs: pairs) {
                    motorExplained.insert(s)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let core = self.coreView else { return }
                if !suggestions.isEmpty {
                    let isDark = self.textDocumentProxy.keyboardAppearance == .dark
                    self.suggestionStrip.show(suggestions: suggestions, motorExplained: motorExplained, isDark: isDark, in: core)
                } else {
                    self.suggestionStrip.hide()
                }
            }
        }
        pendingSuggestionWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func processWordCorrection(typedWord: String, correctedWord: String, addedTrailingSpace: Bool = false, silent: Bool = false) {
        let typedUpper = Array(typedWord.uppercased())
        let correctedUpper = Array(correctedWord.uppercased())
        let timestamp = Date().timeIntervalSince1970

        let cleanTyped = typedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCorrected = correctedWord.trimmingCharacters(in: .whitespacesAndNewlines)

        // Set lastCorrection so Undo button and swipe undo can revert the word change
        lastCorrection = CorrectionRecord(
            baseKey: cleanTyped,
            resolvedKey: cleanCorrected,
            rawPoint: .zero,
            keyCenter: .zero,
            timestamp: timestamp,
            wordContext: ""
        )
        lastCorrectionWallTime = Date().timeIntervalSince1970

        if !silent, let core = coreView {
            let isDark = textDocumentProxy.keyboardAppearance == .dark
            undoStrip.show(rawCharacter: typedWord, correctedCharacter: correctedWord, isDark: isDark, in: core)
        }

        // 1. Flash ripple animations for all letters in corrected word
        for char in correctedUpper {
            coreView?.flashCorrectionFeedback(for: String(char))
        }

        // 2. Extract letter substitutions (e.g. W -> E for "namw" -> "name")
        if typedUpper.count == correctedUpper.count {
            for (t, c) in zip(typedUpper, correctedUpper) where t != c {
                let fromKey = String(t)
                let toKey = String(c)
                coreView?.flashCorrectionFeedback(for: fromKey)
                
                // Record tap event in session log for confusion pair tracking
                let tapEvent = TapEvent(
                    key: fromKey,
                    rawX: 0,
                    rawY: 0,
                    correctedKey: toKey,
                    correctionApplied: true,
                    correctionAccepted: true,
                    timestamp: timestamp,
                    intervalSinceLast: 0.1
                )
                sessionData.addTap(tapEvent)
                
                // Reinforce spatial engine drift towards corrected key with accurate delta
                let fromFrame = coreView?.currentKeyFrames[fromKey]
                let toFrame = coreView?.currentKeyFrames[toKey]
                if let fromF = fromFrame, let toF = toFrame {
                    let fromCenter = CGPoint(x: fromF.midX, y: fromF.midY) // Where they actually tapped
                    let toCenter = CGPoint(x: toF.midX, y: toF.midY) // Where they intended to tap
                    
                    // FIX: Learn the intended key (toKey). The user aimed for `toCenter`, but physically hit `fromCenter`.
                    correctionEngine.recordTap(key: toKey, rawPoint: fromCenter, keyCenter: toCenter, accepted: true)
                }
            }
        }

        // 3. Learn word in linguistic gate & whitelist memory
        linguisticGate.recordAcceptedWord(correctedWord)

        // 4. Log explainability entry
        ExplainabilityLogStore.append(ExplainabilityLogEntry(
            fromKey: typedWord,
            toKey: correctedWord,
            mechanism: "Autocorrect Engine",
            confidence: 0.90
        ))

        // 5. Update confidence colors on keyboard core
        coreView?.updateLearnedOffsets(correctionEngine.currentKeyOffsets)
        coreView?.refreshAllConfidenceColors()

        // 6. Play haptic and audio cues
        if preferences.audioCorrectionCueEnabled {
            AudioServicesPlaySystemSound(1104)
        }
        if preferences.correctionHapticsEnabled {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        saveSession()
    }

    /// Compares recent correction frequency to an early-session baseline.
    /// Needs at least 4 minutes of session data (2 to establish baseline, 2
    /// to compare) before it can trigger. Fires ONCE per session — no
    /// re-checking or oscillating, matching the spec's "silent adaptation"
    /// intent rather than something the user could notice flickering.
    private func checkFatigueAdaptation(now: TimeInterval) {
        guard preferences.fatigueAdaptation, !fatigueAdaptationTriggered, let start = sessionStartTime else { return }
        guard now - start >= 240 else { return }

        if baselineCorrectionRate == nil {
            let baselineCount = correctionTimestamps.filter { $0 - start <= 120 }.count
            baselineCorrectionRate = Double(baselineCount) / 2.0
        }
        guard let baseline = baselineCorrectionRate, baseline > 0 else { return }

        let recentCount = correctionTimestamps.filter { now - $0 <= 120 }.count
        let recentRate = Double(recentCount) / 2.0

        if recentRate > baseline * 1.4 {
            applyFatigueAdaptation()
            fatigueAdaptationTriggered = true
        }
    }

    private func checkStruggle() {
        struggleStreak += 1
        if struggleStreak >= 8 && struggleSuggestionShown == nil {
            struggleSuggestionShown = Date()
            showStruggleSuggestion()
        }
    }

    private func showStruggleSuggestion() {
        // Using keyInfoOverlay instead of UIAlertController — UIAlertController
        // from a keyboard extension is unreliable and disrupts the typing flow.
        guard let coreView = coreView else { return }
        keyInfoOverlay.show(
            text: "Typing seems harder than usual.\nConsider a short break, or try adjusting Correction Sensitivity in KITE Settings.",
            in: coreView
        )
    }

    private func showKeyInfo(for key: String) { // From Group 1
        guard let coreView = coreView else { return }
        let message: String
        if let rule = correctionEngine.currentManualOverrides[key] {
            message = "Key \(key)\nYou set this to always show '\(rule.toKey)' (\(rule.strictness.label), \(rule.context.label)). Change this in Settings → Corrections."
        } else {
            let offsets = correctionEngine.currentKeyOffsets
            if let offset = offsets[key], offset.sampleCount > 0 {
                let mechanism: String
                if offset.sampleCount < KeyOffset.minSamplesForVarianceTrust {
                    mechanism = "Not enough taps yet for KITE to be confident about this key."
                } else if offset.isDirectionalDrift {
                    mechanism = "Your taps here consistently land in one direction, so KITE shifts your tap toward where you actually mean to hit."
                } else {
                    mechanism = "Your taps here scatter rather than lean one way, so KITE widens the area it accepts instead of guessing a direction."
                }
                message = "Key \(key)\n\(mechanism)\n\nConfidence: \(Int(offset.confidence * 100))%\nTaps recorded: \(offset.sampleCount)\nAccepted: \(Int(offset.acceptanceRate * 100))%"
            } else {
                message = "Key \(key)\nNo data yet."
            }
        }
        keyInfoOverlay.show(text: message, in: coreView)
    }

    /// Session-only override — bumps key size one step and slows backspace
    /// one step. Deliberately NOT saved via PreferencesStore, since this
    /// isn't a real user preference change, just a temporary in-session
    /// adaptation. Resets back to the user's real saved preferences next
    /// time the keyboard is opened fresh (viewWillAppear reloads them).
    private func applyFatigueAdaptation() {
        var adjusted = preferences
        switch adjusted.keySize {
        case .standard: adjusted.keySize = .large
        case .large: adjusted.keySize = .extraLarge
        case .extraLarge: break
        }
        adjusted.backspaceSpeed = .slow
        coreView?.applyUpdatedPreferences(adjusted)
    }
}

extension KeyboardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension KeyboardViewController {
    func refreshHistoricalSessionCache() {
        cachedHistoricalSessions = SessionHistoryStore.load()
        let allSessions = cachedHistoricalSessions + [sessionData]
        cachedConfusionPairs = ConfusionPairAnalyzer.analyze(from: allSessions)
    }
}

