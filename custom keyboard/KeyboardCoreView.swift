//
//  KeyboardCoreView.swift
//  KITE(Final)
//
//  Created by Apple on 7/12/26.
//

import UIKit
import SwiftUI // Still needed for Color enum definition (not extension)

// DELETED: The entire `extension UIColor` block for `kiteKeyboardBackground` has been removed from here.

enum KeyboardLayer {
    case letters
    case numbersAndSymbols
}

enum ShiftState {
    case lowercase
    case shiftedOnce
    case capsLocked
}

class KeyButton: UIButton {
    private(set) var lastTouchPoint: CGPoint = .zero
    private(set) var detectedFrequencyHz: Double?
    var onTouchDownAction: ((KeyButton) -> Void)?

    // touch.timestamp uses monotonic system-uptime clock, not Date().timeIntervalSince1970.
    // Never mix these two clocks; trajectory timestamps are only used internally relative to each other.
    private var trajectory: [(point: CGPoint, timestamp: TimeInterval)] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            lastTouchPoint = touch.location(in: self)
            trajectory = [(lastTouchPoint, touch.timestamp)]
        }
        super.touchesBegan(touches, with: event)
        isHighlighted = false
        onTouchDownAction?(self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            trajectory.append((touch.location(in: self), touch.timestamp))
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if trajectory.count >= 4 {
            detectedFrequencyHz = TremorFrequencyEstimator.estimateFrequencyHz(from: trajectory)
        } else {
            detectedFrequencyHz = nil
        }
        super.touchesEnded(touches, with: event)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Expand lateral hit target for edge-of-key slop, but constrain vertical
        // expansion heavily to prevent bottom row (Spacebar) from stealing
        // bottom-edge taps intended for the V/B/N row above it.
        let hitBounds = CGRect(x: bounds.minX - 6, y: bounds.minY - 2, width: bounds.width + 12, height: bounds.height + 4)
        return hitBounds.contains(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
}

/// The real keyboard's layout, rendering, and real-touch-capture logic,
/// extracted so BOTH the keyboard extension AND the in-app calibration
/// screen use the EXACT same rendering and tap-coordinate capture. This
/// view knows nothing about text insertion or correction — only layout and
/// shift/caps/layer state. Each host wires taps differently via closures.
final class KeyboardCoreView: UIView {

    /// Reduced from 44 to 36 to lessen top empty space
    static let topStripHeight: CGFloat = 44

    /// Fired for "⌫", "space", "return". (Shift/layer-toggle handled internally.)
    var onControlKey: ((_ key: String, _ timestamp: TimeInterval) -> Void)?

    /// Fired for every correctable key tap. Host resolves correction and
    /// returns the exact text that was typed (already case-adjusted), or ""
    /// if nothing should be inserted (e.g. debounce rejected it).
    var onCorrectableKeyTapped: ((_ baseKey: String, _ rawPoint: CGPoint, _ keyFrames: [String: CGRect], _ timestamp: TimeInterval, _ detectedFrequencyHz: Double?) -> String)?

    var onKeyLongPressed: ((String) -> Void)?

    var currentKeyFrames: [String: CGRect] { keyFrames }

    private var hasValidWidth = false
    private var currentLayer: KeyboardLayer = .letters
    private var shiftState: ShiftState = .shiftedOnce
    private var correctableButtons: [String: KeyButton] = [:]
    private var shiftButton: KeyButton?
    private var keyFrames: [String: CGRect] = [:]
    private var backspaceRepeatTimer: Timer?
    private var lastLongPressTime: TimeInterval = 0
    private var suppressNextTapForKey: Set<String> = []

    private let accuracyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor.systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    var preferences: UserPreferences = .default

    /// Explicit, deliberate rebuild trigger — replaces the old didSet
    /// approach. That implicit trigger caused unwanted extra rebuilds
    /// (contributing to the earlier flicker issue), but removing it with
    /// nothing in its place silently broke every Settings change that
    /// depends on a rebuild (key size, keyboard height). This gives full
    /// control back: only rebuilds when the view controller explicitly
    /// calls this after loading fresh preferences.
    func applyUpdatedPreferences(_ newPrefs: UserPreferences) {
        preferences = newPrefs
        guard hasValidWidth else { return }
        rebuildKeys()
    }

    var learnedKeyOffsets: [String: KeyOffset] = [:]
    private var keyHeight: CGFloat { preferences.keyHeightPoints }

    private func rebuildKeysIfNeeded() {
        guard hasValidWidth else { return }
        rebuildKeys()
    }

    private func confidence(for key: String) -> Double {
        guard let learned = learnedKeyOffsets[key.count == 1 ? key.uppercased() : key] else {
            return 0
        }
        return learned.confidence
    }

    private var currentAppearance: UIKeyboardAppearance = .light

    func updateAppearance(_ appearance: UIKeyboardAppearance) {
        if currentAppearance != appearance {
            currentAppearance = appearance
            backgroundColor = appearance == .dark ? UIColor(red: 0.1, green: 0.11, blue: 0.12, alpha: 1.0) : .kiteKeyboardBackground
            rebuildKeysIfNeeded()
        }
    }

    /// Calculates the confidence color for a given key based on learned offsets.
    /// - Parameter key: The key to calculate color for
    /// - Returns: The appropriate background color for the key's confidence level
    private func confidenceColor(for key: String) -> UIColor {
        let isDark = currentAppearance == .dark
        let defaultBase = isDark ? UIColor(white: 0.2, alpha: 1.0) : UIColor.systemBackground

        guard preferences.keyConfidenceTintEnabled,
              let learned = learnedKeyOffsets[key.count == 1 ? key.uppercased() : key] else {
            return defaultBase
        }
        
        let eased = sqrt(max(0, min(1, learned.confidence)))
        let lightColor = isDark ? UIColor(red: 0.75, green: 0.5, blue: 0.1, alpha: 0.3) : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.15)
        let darkColor = isDark ? UIColor(red: 0.85, green: 0.6, blue: 0.15, alpha: 0.8) : UIColor(red: 0.75, green: 0.56, blue: 0.24, alpha: 1)
        let f = eased
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        lightColor.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        darkColor.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return UIColor(
            red: fr + (tr - fr) * CGFloat(f),
            green: fg + (tg - fg) * CGFloat(f),
            blue: fb + (tb - fb) * CGFloat(f),
            alpha: fa + (ta - fa) * CGFloat(f)
        )
    }

    let letterRows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⌫"],
        ["123", "space", "return"]
    ]

    let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'", "⌫"],
        ["ABC", "space", "return"]
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Group 4 change: Now correctly uses the UIColor extension from KITEAmber.swift
        backgroundColor = .kiteKeyboardBackground
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        setupAccuracyLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Group 4 change: Now correctly uses the UIColor extension from KITEAmber.swift
        backgroundColor = .kiteKeyboardBackground
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        setupAccuracyLabel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasValidWidth, bounds.width > 0 else { return }
        hasValidWidth = true
        rebuildKeys()
    }

    private func rebuildKeys() {
        subviews.forEach { view in
            if let button = view as? KeyButton {
                button.removeTarget(nil, action: nil, for: .allEvents)
                button.onTouchDownAction = nil
                button.gestureRecognizers?.forEach { button.removeGestureRecognizer($0) }
                button.removeFromSuperview()
            }
        }
        correctableButtons.removeAll()
        keyFrames.removeAll()
        shiftButton = nil

        let rows = currentLayer == .letters ? letterRows : numberRows
        layoutKeys(rows: rows)

        if currentLayer == .letters {
            applyShiftStateToButtonTitles()
        }
        bringSubviewToFront(accuracyLabel)
    }

    private func switchLayer(to layer: KeyboardLayer) {
        currentLayer = layer
        rebuildKeys()
    }

    private func layoutKeys(rows: [[String]]) {
        // Adaptive Layout can nudge a key up to ±6pt. Two adjacent keys with
        // opposite-signed drift could otherwise overlap by up to 2 * maxNudge
        // minus the normal gap. Widening the gap only while the feature is on
        // keeps the worst case non-overlapping without shrinking the nudge
        // itself down to something imperceptible.
        let keyGap: CGFloat = preferences.adaptiveLayoutEnabled ? 14 : 4
        var yOffset: CGFloat = KeyboardCoreView.topStripHeight + 12.0 // 12pt gap separating top strip from row 1 keys

        for row in rows {
            let rowWidth = bounds.width
            let isControlRow = row.contains("space")
            var widths: [CGFloat] = []

            if isControlRow {
                let totalGaps = CGFloat(row.count + 1) * keyGap
                let available = rowWidth - totalGaps
                let spaceWidth = available * 0.55
                let otherCount = row.count - 1
                let otherWidth = otherCount > 0 ? (available - spaceWidth) / CGFloat(otherCount) : 0
                widths = row.map { $0 == "space" ? spaceWidth : otherWidth }
            } else {
                let keyWidth = (rowWidth - CGFloat(row.count + 1) * keyGap) / CGFloat(row.count)
                widths = Array(repeating: keyWidth, count: row.count)
            }

            var xOffset: CGFloat = keyGap
            for (i, key) in row.enumerated() {
                let keyWidth = widths[i]
                let button = KeyButton(type: .system)
                button.setTitle(displayTitle(for: key), for: .normal)
                let isControlKey = ["⇧", "⌫", "return", "123", "ABC", "🌐"].contains(key)
                let isDark = currentAppearance == .dark
                if isControlKey {
                    button.backgroundColor = isDark ? UIColor(white: 0.15, alpha: 1.0) : UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1.0)
                    button.layer.borderWidth = 1.5
                    button.layer.borderColor = isDark ? UIColor(white: 0.25, alpha: 1.0).cgColor : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.45).cgColor
                } else {
                    let conf = confidence(for: key)
                    button.backgroundColor = confidenceColor(for: key)
                    button.layer.borderWidth = 1.5
                    let amberAlpha = 0.50 + (CGFloat(conf) * 0.40)
                    button.layer.borderColor = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: amberAlpha).cgColor
                }
                button.setTitleColor(isDark ? .white : UIColor.label, for: .normal)
                button.layer.cornerRadius = 8
                button.layer.cornerCurve = .continuous
                button.layer.shadowColor = UIColor.black.cgColor
                button.layer.shadowOpacity = 0.08
                button.layer.shadowRadius = 1
                button.layer.shadowOffset = CGSize(width: 0, height: 1)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.clipsToBounds = false
                button.layer.masksToBounds = false
                button.accessibilityLabel = accessibilityLabel(for: key)
                button.isMultipleTouchEnabled = true
                button.isExclusiveTouch = false

                var nudgeX: CGFloat = 0
                var nudgeY: CGFloat = 0

                if key == "⇧" {
                    shiftButton = button
                    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(shiftLongPressed(_:)))
                    longPress.minimumPressDuration = preferences.longPressThreshold
                    button.addGestureRecognizer(longPress)
                } else if isCorrectableKey(key) {
                    let baseKey = key.count == 1 ? key.uppercased() : key
                    correctableButtons[baseKey] = button

                    if preferences.adaptiveLayoutEnabled {
                        let lookupKey = key.count == 1 ? key.uppercased() : key
                        if let learned = learnedKeyOffsets[lookupKey], learned.isDirectionalDrift {
                            let maxNudge: CGFloat = 6
                            nudgeX = max(-maxNudge, min(maxNudge, learned.averageDeltaX * 0.5))
                            nudgeY = max(-maxNudge, min(maxNudge, learned.averageDeltaY * 0.5))
                        }
                    }

                    keyFrames[baseKey] = CGRect(x: xOffset + nudgeX, y: yOffset + nudgeY, width: keyWidth, height: keyHeight)
                    button.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: keyWidth, height: keyHeight), cornerRadius: 8).cgPath
                }

                if key == "⌫" {
                    let holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
                    holdGesture.minimumPressDuration = 0.4
                    button.addGestureRecognizer(holdGesture)
                }

                button.onTouchDownAction = { [weak self] btn in
                    self?.keyTapped(btn)
                }
                addSubview(button)

                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset + nudgeX),
                    button.topAnchor.constraint(equalTo: topAnchor, constant: yOffset + nudgeY),
                    button.widthAnchor.constraint(equalToConstant: keyWidth),
                    button.heightAnchor.constraint(equalToConstant: keyHeight)
                ])

                xOffset += keyWidth + keyGap
            }
            yOffset += keyHeight + keyGap
        }
    }

    private func isCorrectableKey(_ key: String) -> Bool {
        !["⇧", "⌫", "return", "123", "ABC", "🌐", "space"].contains(key)
    }

    private func displayTitle(for key: String) -> String {
        guard currentLayer == .letters, key.count == 1, key.rangeOfCharacter(from: .letters) != nil else {
            return key
        }
        return shiftState == .lowercase ? key.lowercased() : key
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "🌐": return "Switch Keyboard"
        case "⇧": return "shift"
        case "⌫": return "delete"
        case "space": return "space"
        case "return": return "return"
        case "123": return "numbers"
        case "ABC": return "letters"
        default: return key
        }
    }

    private func toggleShiftSingleTap() {
        switch shiftState {
        case .lowercase: shiftState = .shiftedOnce
        case .shiftedOnce, .capsLocked: shiftState = .lowercase
        }
        applyShiftStateToButtonTitles()
    }

    @objc private func shiftLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        shiftState = shiftState == .capsLocked ? .lowercase : .capsLocked
        applyShiftStateToButtonTitles()
    }

    private func applyShiftStateToButtonTitles() {
        for (letter, button) in correctableButtons where letter.count == 1 && letter.rangeOfCharacter(from: .letters) != nil {
            button.setTitle(shiftState == .lowercase ? letter.lowercased() : letter, for: .normal)
        }
        let isDark = currentAppearance == .dark
        shiftButton?.backgroundColor = shiftState == .lowercase
            ? (isDark ? UIColor(white: 0.15, alpha: 1.0) : UIColor.systemGray4)
            : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.30)
    }

    func revertOneShotShiftIfNeeded() {
        if shiftState == .shiftedOnce {
            shiftState = .lowercase
            applyShiftStateToButtonTitles()
        }
    }

    var isLowercaseActive: Bool { shiftState == .lowercase }

    func setShiftActive(_ active: Bool) {
        shiftState = active ? .shiftedOnce : .lowercase
        applyShiftStateToButtonTitles()
    }

    private func setupAccuracyLabel() {
        addSubview(accuracyLabel)
        NSLayoutConstraint.activate([
            accuracyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            accuracyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    /// Updates the small in-corner accuracy readout. Pass nil to hide it —
    /// e.g. before any taps have occurred yet this session.
    func updateAccuracyCounter(percentage: Int?, isDemoMode: Bool) {
        guard let percentage else {
            accuracyLabel.isHidden = true
            return
        }
        accuracyLabel.isHidden = false
        accuracyLabel.text = isDemoMode ? "Demo \(percentage)%" : "\(percentage)%"
    }

    func flashCorrectionFeedback(for baseKey: String) {
        guard let button = correctableButtons[baseKey] else { return }
        let originalColor = button.backgroundColor
        let amberGold = UIColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 0.75)

        if UIAccessibility.isReduceMotionEnabled {
            button.backgroundColor = amberGold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak button] in button?.backgroundColor = originalColor }
            return
        }

        // True liquid radial wave ripple layer expanding outwards from key center
        let diameter = max(button.bounds.width, button.bounds.height) * 1.5
        let rippleLayer = CAShapeLayer()
        let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        
        rippleLayer.path = circlePath.cgPath
        rippleLayer.fillColor = UIColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.50).cgColor
        rippleLayer.strokeColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.95).cgColor
        rippleLayer.lineWidth = 2.0
        rippleLayer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        rippleLayer.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        rippleLayer.opacity = 0.0

        button.layer.addSublayer(rippleLayer)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            rippleLayer.removeFromSuperlayer()
        }

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.15
        scaleAnimation.toValue = 1.35
        scaleAnimation.duration = 0.45
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.95
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = 0.45
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        rippleLayer.add(scaleAnimation, forKey: "rippleScale")
        rippleLayer.add(opacityAnimation, forKey: "rippleOpacity")

        CATransaction.commit()

        UIView.animate(withDuration: 0.15, animations: {
            button.backgroundColor = amberGold
        }) { _ in
            UIView.animate(withDuration: 0.45) { [weak button] in
                button?.backgroundColor = originalColor
            }
        }
    }

    /// Updates the learned offsets cache without triggering a keyboard rebuild.
    /// This allows real-time confidence color updates during typing.
    /// - Parameter offsets: The new learned offsets to apply
    func updateLearnedOffsets(_ offsets: [String: KeyOffset]) {
        learnedKeyOffsets = offsets
    }

    /// Refreshes confidence color for a single key without rebuilding the keyboard.
    /// This is called after recordTap to show real-time learning updates.
    /// - Parameter key: The key to update
    func refreshConfidenceColor(for key: String) {
        let normalizedKey = key.count == 1 ? key.uppercased() : key
        guard let button = correctableButtons[normalizedKey] else { return }
        button.backgroundColor = confidenceColor(for: key)
    }

    /// Refreshes confidence colors for all keys without rebuilding the keyboard.
    /// This is called when the keyboard reappears to ensure UI matches the cache.
    func refreshAllConfidenceColors() {
        for (key, button) in correctableButtons {
            button.backgroundColor = confidenceColor(for: key)
        }
    }

    @objc private func backspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            backspaceRepeatTimer?.invalidate()
            backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: preferences.backspaceInterval, repeats: true) { [weak self] _ in
                self?.onControlKey?("⌫", Date().timeIntervalSince1970)
            }
        case .ended, .cancelled, .failed:
            backspaceRepeatTimer?.invalidate()
            backspaceRepeatTimer = nil
        default:
            break
        }
    }

    var isSwipeActive: Bool = false

    private func processTap(displayedTitle: String, rawPoint: CGPoint, detectedFrequencyHz: Double?) {
        guard !isSwipeActive else { return }
        if isCorrectableKey(displayedTitle) {
            let checkKey = displayedTitle.count == 1 ? displayedTitle.uppercased() : displayedTitle
            if suppressNextTapForKey.remove(checkKey) != nil { return }
        }

        let timestamp = Date().timeIntervalSince1970
        if !isCorrectableKey(displayedTitle) {
            switch displayedTitle {
            case "123": switchLayer(to: .numbersAndSymbols)
            case "ABC": switchLayer(to: .letters)
            case "⇧": toggleShiftSingleTap()
            default: onControlKey?(displayedTitle, timestamp)
            }
            return
        }
        let baseKey = displayedTitle.count == 1 ? displayedTitle.uppercased() : displayedTitle
        _ = onCorrectableKeyTapped?(baseKey, rawPoint, keyFrames, timestamp, detectedFrequencyHz)
        revertOneShotShiftIfNeeded()
    }

    @objc private func keyTapped(_ sender: KeyButton) {
        guard Date().timeIntervalSince1970 - lastLongPressTime > 0.5 else { return }
        guard let displayedTitle = sender.title(for: .normal) else { return }
        
        // Micro-spring scale pop for silky tactile smoothness
        UIView.animate(withDuration: 0.04, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }) { _ in
            UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseOut], animations: {
                sender.transform = .identity
            }, completion: nil)
        }

        let rawPoint = sender.convert(sender.lastTouchPoint, to: self)
        processTap(displayedTitle: displayedTitle, rawPoint: rawPoint, detectedFrequencyHz: sender.detectedFrequencyHz)
    }

    @objc private func correctableKeyLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? KeyButton, let title = button.title(for: .normal) else { return }
        let baseKey = title.count == 1 ? title.uppercased() : title
        suppressNextTapForKey.insert(baseKey)
        onKeyLongPressed?(baseKey)
    }

    #if DEBUG
    func syntheticTap(forDisplayedCharacter character: String) {
        let baseKey = character.count == 1 ? character.uppercased() : character
        guard let frame = keyFrames[baseKey] else { return }
        // DEBUG-only tool — widened from the original ±2pt, which was too
        // small to ever cross into a neighboring key given 3-6.5pt seeded
        // variance. This tool exists purely for fast developer data
        // generation, so exaggerating jitter here carries no real-world risk.
        let point = CGPoint(x: frame.midX + CGFloat.random(in: -12...12), y: frame.midY + CGFloat.random(in: -12...12))
        let displayTitle = (currentLayer == .letters && character.rangeOfCharacter(from: .letters) != nil)
            ? (shiftState == .lowercase ? character.lowercased() : character.uppercased())
            : character
        processTap(displayedTitle: displayTitle, rawPoint: point, detectedFrequencyHz: nil)
    }

    func syntheticControlTap(key: String) {
        processTap(displayedTitle: key, rawPoint: .zero, detectedFrequencyHz: nil)
    }
    #endif
}
