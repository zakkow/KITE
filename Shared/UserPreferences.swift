import Foundation

struct UserPreferences: Codable, Equatable {
    var keySize: KeySize = .standard
    var keyboardHeight: KeyboardHeight = .standard
    var longPressThreshold: TimeInterval = 0.5
    var backspaceSpeed: BackspaceSpeed = .standard
    var debounceThreshold: TimeInterval = 0.02
    var correctionSensitivity: Sensitivity = .balanced
    var undoButtonSize: UndoSize = .standard
    var fatigueAdaptation: Bool = true
    var isDemoMode: Bool = false
    /// Off by default — fires a single, rare haptic the first time a key
    /// crosses into proven directional-drift correction. Not per-correction,
    /// so it stays a progress signal rather than a buzz on every keystroke.
    var milestoneHapticsEnabled: Bool = false
    /// Off by default — plays a subtle system sound on the same trigger as
    /// the visual ripple. Exists because many motor-impaired typists watch
    /// the text field, not the keyboard, and would otherwise never know a
    /// correction fired (and so could never use undo to reject a bad one).
    var audioCorrectionCueEnabled: Bool = false
    /// On by default — unlike the two sensory-feedback toggles, spelling
    /// suggestions are a widely-expected, low-risk keyboard feature. Still
    /// user-adjustable, matching "every default can be changed."
    var spellingSuggestionsEnabled: Bool = true
    /// Off by default — a distinct vibration per correction type (firmer for
    /// directional, lighter for widened). Complements the visual ripple and
    /// audio cue for users who benefit from tactile confirmation.
    var correctionHapticsEnabled: Bool = false
    var adaptiveLayoutEnabled: Bool = false
    var handSplitModelingEnabled: Bool = false
    var dominantHand: DominantHand = .right
    var differentialPrivacyPreviewEnabled: Bool = false
    var keyConfidenceTintEnabled: Bool = true
    /// When enabled, the Settings screen transforms from a dense Form into
    /// a large-card macro-board layout with oversized tap targets. Designed
    /// for users with motor disabilities who find standard list rows too small.
    var comfortModeEnabled: Bool = false
    var customWordOverrides: [String: CustomWordCorrectionRule] = [:]

    static var `default`: UserPreferences { UserPreferences() }

    /// Confidence threshold gates the DIRECTIONAL SHIFT mechanism only.
    /// Scatter widening is not gated by this — it uses seeded/learned
    /// variance immediately, since it's the safer, always-on correction.
    var confidenceThreshold: Double {
        switch correctionSensitivity {
        case .light:    return 0.75
        case .balanced: return 0.60
        case .firm:     return 0.45
        }
    }

    /// Standard is 44pt — matches Apple's documented minimum accessible
    /// touch target (see 06_KITE_ClinicalGrounding.md, Source 2). Large and
    /// Extra Large were already comfortably above this minimum.
    var keyHeightPoints: CGFloat {
        switch keySize {
        case .standard:   return 44
        case .large:      return 52
        case .extraLarge: return 64
        }
    }

    var keyboardHeightPoints: CGFloat {
        switch keyboardHeight {
        case .standard: return 216
        case .tall:     return 260
        case .full:     return 300
        }
    }

    var backspaceInterval: TimeInterval {
        switch backspaceSpeed {
        case .slow:     return 0.2
        case .standard: return 0.1
        }
    }
}

enum KeySize: String, Codable, CaseIterable, Equatable {
    case standard, large, extraLarge
    var label: String {
        switch self {
        case .standard:   return "Standard"
        case .large:      return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

enum KeyboardHeight: String, Codable, CaseIterable, Equatable {
    case standard, tall, full
    var label: String {
        switch self {
        case .standard: return "Standard"
        case .tall:     return "Tall"
        case .full:     return "Full"
        }
    }
}

enum BackspaceSpeed: String, Codable, CaseIterable, Equatable {
    case slow, standard
    var label: String { self == .slow ? "Slow" : "Standard" }
}

enum Sensitivity: String, Codable, CaseIterable, Equatable {
    case light, balanced, firm
    var label: String {
        switch self {
        case .light:    return "Light"
        case .balanced: return "Balanced"
        case .firm:     return "Firm"
        }
    }
}

enum UndoSize: String, Codable, CaseIterable, Equatable {
    case standard, large, alwaysVisible
    var label: String {
        switch self {
        case .standard:      return "Standard"
        case .large:         return "Large"
        case .alwaysVisible: return "Always Visible"
        }
    }
}

enum DominantHand: String, Codable, CaseIterable, Equatable {
    case left, right
    var label: String { self == .left ? "Left" : "Right" }
}
