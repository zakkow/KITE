import UIKit

/// Shared color utilities for both main app and keyboard extension.
/// The keyboard extension cannot use SwiftUI Color, so these UIColor-based
/// functions provide the same visual consistency across targets.
enum SharedColorUtils {
    /// Returns a UIColor interpolated between two colors based on fraction.
    /// Used by both the keyboard extension and main app for confidence tinting.
    static func interpolate(from: UIColor, to: UIColor, fraction: Double) -> UIColor {
        let f = max(0, min(1, fraction))
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return UIColor(
            red: fr + (tr - fr) * CGFloat(f),
            green: fg + (tg - fg) * CGFloat(f),
            blue: fb + (tb - fb) * CGFloat(f),
            alpha: fa + (ta - fa) * CGFloat(f)
        )
    }

    /// Shared by Heatmap AND the keyboard's own key tinting — one function,
    /// used two places, so they can never visually drift apart. sqrt easing
    /// front-loads visible color change at lower confidence, since a purely
    /// linear ramp made early progress look too subtle to read at a glance.
    static func confidenceTint(for confidence: Double) -> UIColor {
        let eased = sqrt(max(0, min(1, confidence)))
        let lightColor = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.15)
        let darkColor = UIColor(red: 0.75, green: 0.56, blue: 0.24, alpha: 1)
        return interpolate(from: lightColor, to: darkColor, fraction: eased)
    }
}

extension UIColor {
    /// Warm keyboard background color, adaptive to light/dark mode.
    /// Light: warm cream. Dark: warm very-dark brown.
    static let kiteKeyboardBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.14, blue: 0.11, alpha: 1)
            : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1)
    }
}
