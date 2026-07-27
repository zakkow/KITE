import UIKit

/// Overlay strip across the top of the keyboard showing spelling
/// suggestions — same visual convention as the undo strip. Auto-dismisses
/// after 8 seconds if untouched; nothing is ever forced on the user.
final class SuggestionStripView: UIView {
    var onSuggestionTapped: ((String) -> Void)?
    private var dismissTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isHidden = true
    }

    func show(suggestions: [String], motorExplained: Set<String> = [], isDark: Bool = false, in parent: UIView) {
        dismissTimer?.invalidate()
        subviews.forEach { $0.removeFromSuperview() }

        StripChipStyle.applyContainerStyle(to: self, isDark: isDark)
        translatesAutoresizingMaskIntoConstraints = false
        if superview == nil {
            parent.addSubview(self)
            NSLayoutConstraint.activate([
                leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 6),
                trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -6),
                topAnchor.constraint(equalTo: parent.topAnchor, constant: 4),
                heightAnchor.constraint(equalToConstant: KeyboardCoreView.topStripHeight)
            ])
        }
        isHidden = false

        let stack = UIStackView(arrangedSubviews: suggestions.map { suggestion in
            let button = StripChipStyle.makeChipButton(title: suggestion, isDark: isDark)
            let isMotorMatch = motorExplained.contains(suggestion)
            button.accessibilityLabel = isMotorMatch ? "\(suggestion), matches your typing pattern" : suggestion
            if isMotorMatch {
                button.layer.borderWidth = 2
                button.layer.borderColor = UIColor.systemOrange.cgColor
            }
            button.addAction(UIAction { [weak self] _ in
                self?.onSuggestionTapped?(suggestion)
                self?.hide()
            }, for: .touchUpInside)
            return button
        })
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        dismissTimer?.invalidate()
        isHidden = true
    }
}
