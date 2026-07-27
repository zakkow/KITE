import UIKit

/// Shared color utilities for the keyboard extension.
/// The keyboard extension cannot use SwiftUI Color, so these UIColor-based
/// functions provide the same visual consistency.
enum SharedColorUtils {
    /// Returns a UIColor interpolated between two colors based on fraction.
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

    /// Shared confidence tinting with sqrt easing for better visual feedback.
    static func confidenceTint(for confidence: Double) -> UIColor {
        let eased = sqrt(max(0, min(1, confidence)))
        let lightColor = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.15)
        let darkColor = UIColor(red: 0.75, green: 0.56, blue: 0.24, alpha: 1)
        return interpolate(from: lightColor, to: darkColor, fraction: eased)
    }
}

extension UIView {
    /// Matches the system input container to KITE's warm keyboard chrome.
    func applyKiteKeyboardContainerStyle(cornerRadius: CGFloat = 12) {
        backgroundColor = .kiteKeyboardBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true
    }
}
