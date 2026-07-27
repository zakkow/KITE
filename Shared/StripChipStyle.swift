import UIKit
import SwiftUI

/// One shared visual style for every top-strip button (Undo, Spelling
/// Suggestion, Word Prediction) — so they read as one consistent design
/// language instead of three separately-styled bars.
enum StripChipStyle {
    static func makeChipButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(Color.kiteAmberDark), for: .normal)
        button.backgroundColor = UIColor.systemBackground
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        return button
    }

    static func applyContainerStyle(to view: UIView) {
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 14
    }
}
