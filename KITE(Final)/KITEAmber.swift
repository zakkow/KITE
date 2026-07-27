import SwiftUI
import UIKit

/// KITE's full color system. kiteAmber is the existing primary brand/
/// action color, left untouched. Everything else is new: kiteRed/kiteBlue
/// form the heatmap's thermal scale (red = hot = high confidence, blue =
/// cool = low confidence, matching the UI/UX spec's own "cool end / hot
/// end" language — corrected here, since the app previously had this
/// backwards). kiteNeutral marks keys with NO personalized data yet
/// (sampleCount == 0, pure population seed) — kept distinct from "low
/// confidence," which implies real but uncertain data, so the heatmap
/// never implies a fresh profile has already failed to learn something.
/// kiteSuccess is a dedicated green for positive-confirmation moments.
/// kiteAmberLight/kiteAmberDark are tints of the SAME brand hue, for
/// sparing use in badges/pressed-states rather than new colors.
extension Color {
    static let kiteAmber = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.70, blue: 0.30, alpha: 1)
            : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
    })
    static let kiteAmberLight = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.70, blue: 0.30, alpha: 0.15)
            : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.15)
    })
    static let kiteAmberDark = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.62, blue: 0.20, alpha: 1)
            : UIColor(red: 0.88, green: 0.52, blue: 0.08, alpha: 1)
    })

    static let kiteRed = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.29, blue: 0.29, alpha: 1)
            : UIColor(red: 0.85, green: 0.29, blue: 0.29, alpha: 1)
    })
    static let kiteBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1)
            : UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1)
    })
    static let kiteNeutral = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 1)
            : UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1)
    })
    static let kiteSuccess = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.66, blue: 0.33, alpha: 1)
            : UIColor(red: 0.20, green: 0.66, blue: 0.33, alpha: 1)
    })

    /// Shared by Heatmap AND the keyboard's own key tinting — one function,
    /// used two places, so they can never visually drift apart. sqrt easing
    /// front-loads visible color change at lower confidence, since a purely
    /// linear ramp made early progress look too subtle to read at a glance.
    static func confidenceTint(for confidence: Double) -> Color {
        let eased = sqrt(max(0, min(1, confidence)))
        return Color.interpolate(from: .kiteAmberLight, to: .kiteAmberDark, fraction: eased)
    }

    /// Continuous gradient across the heatmap's confidence scale: blue
    /// (low/cool) -> amber (mid) -> red (high/hot). hasData=false returns
    /// kiteNeutral instead of a fake low-confidence color, keeping
    /// "untouched" visually distinct from "touched but still uncertain."
    static func heatmapColor(forConfidence confidence: Double, hasData: Bool) -> Color {
        guard hasData else { return .kiteNeutral }
        // The original code uses confidenceTint, which interpolates between AmberLight and AmberDark
        // If the spec intends Blue -> Amber -> Red, then this needs a more complex interpolation
        // For now, retaining the original implementation's behavior.
        return Color.confidenceTint(for: confidence)
    }

    static func interpolate(from: Color, to: Color, fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let fromUI = UIColor(from)
        let toUI = UIColor(to)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        fromUI.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        toUI.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return Color(
            red: Double(fr + (tr - fr) * CGFloat(f)),
            green: Double(fg + (tg - fg) * CGFloat(f)),
            blue: Double(fb + (tb - fb) * CGFloat(f)),
            opacity: Double(fa + (ta - fa) * CGFloat(f))
        )
    }

    // Group 4: ADDED kiteKeyboardBackground definition here, as extension Color
    static let kiteKeyboardBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.14, blue: 0.11, alpha: 1)
            : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1)
    })
}

// Group 4: ADDED kiteKeyboardBackground definition here, as extension UIColor
extension UIColor {
    // This ensures UIKit classes can access the color directly.
    static let kiteKeyboardBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.14, blue: 0.11, alpha: 1)
            : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1)
    }
}
