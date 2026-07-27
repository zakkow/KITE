import UIKit

extension UIView {
    func applyKiteKeyboardContainerStyle() {
        // Apply corner radius to the view that holds the entire keyboard.
        // The system's UIInputViewController.view can have arbitrary superviews
        // (UIVisualEffectViews, _UIInputViewControllerOutputView, etc.)
        // We want to apply rounding and background to all of them.
        
        var current: UIView? = self
        while let viewToStyle = current {
            viewToStyle.layer.cornerRadius = 12 // Using a fixed value or KiteRadius.large
            viewToStyle.layer.masksToBounds = true // Crucial for cornerRadius to work
            viewToStyle.layer.cornerCurve = .continuous // Modern Apple-style rounding

            // Also set background to match.
            // UIInputViewController.view is often transparent or has a blur effect.
            // We want to ensure it has our desired background color.
            viewToStyle.backgroundColor = .kiteKeyboardBackground
            
            // If it's a UIVisualEffectView, remove its effect for a solid background.
            if let effectView = viewToStyle as? UIVisualEffectView {
                effectView.effect = nil
            }
            
            // Stop at the UIInputViewController's view.
            // This ensures we style the container views, but don't try to style
            // views outside the keyboard's own hierarchy.
            if viewToStyle == self { break }
            current = viewToStyle.superview
        }
    }
}
