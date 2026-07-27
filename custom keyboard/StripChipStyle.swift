import UIKit

/// One shared visual style for every top-strip button (Undo, Spelling
/// Suggestion, Word Prediction) — so they read as one consistent design
/// language instead of three separately-styled bars.
enum StripChipStyle {
    static func makeChipButton(title: String, isDark: Bool = false) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = isDark ? UIColor(red: 0.85, green: 0.6, blue: 0.15, alpha: 1) : UIColor(red: 0.75, green: 0.56, blue: 0.24, alpha: 1)
        config.baseBackgroundColor = isDark ? UIColor(white: 0.15, alpha: 1.0) : UIColor.systemBackground
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        button.configuration = config
        button.layer.cornerRadius = 10
        return button
    }

    static func applyContainerStyle(to view: UIView, isDark: Bool = false) {
        view.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1.0) : UIColor.systemGray6
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1.0
        view.layer.borderColor = isDark ? UIColor(red: 0.85, green: 0.6, blue: 0.15, alpha: 0.5).cgColor : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.30).cgColor
    }
}
