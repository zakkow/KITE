import UIKit

/// Non-modal overlay for key info — deliberately NOT a UIAlertController.
/// Presenting UIAlertController from inside a keyboard extension is known
/// to be unreliable (extensions run in a constrained window/view hierarchy
/// context) and is the most likely cause of the extension appearing to
/// reset back to the default keyboard after a long-press. This stays
/// entirely within the extension's own view, same pattern as the existing
/// Undo/Suggestion strips.
final class KeyInfoOverlayView: UIView {
    private let textLabel = UILabel()
    private var dismissTimer: Timer?

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = UIColor.systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        isHidden = true

        textLabel.numberOfLines = 0
        textLabel.font = .systemFont(ofSize: 13)
        textLabel.textColor = .label
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        dismissButton.addTarget(self, action: #selector(hide), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dismissButton.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 8),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    func show(text: String, in parent: UIView) {
        dismissTimer?.invalidate()
        textLabel.text = text
        translatesAutoresizingMaskIntoConstraints = false
        if superview == nil {
            parent.addSubview(self)
            NSLayoutConstraint.activate([
                leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
                trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
                centerYAnchor.constraint(equalTo: parent.centerYAnchor)
            ])
        }
        isHidden = false
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in self?.hide() }
    }

    @objc func hide() {
        dismissTimer?.invalidate()
        isHidden = true
    }
}
