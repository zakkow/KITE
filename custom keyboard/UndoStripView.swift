import UIKit

/// Shows the raw (pre-correction) character after a correction fires.
/// Tapping "Undo" reverts it. Auto-dismisses after 8s if untouched —
/// long enough for a motor-impaired user to read and react.
final class UndoStripView: UIView {
    var onRevertTapped: (() -> Void)?
    private var dismissTimer: Timer?
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        StripChipStyle.applyContainerStyle(to: self)
        isHidden = true
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(revertTapped))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }

    @objc private func revertTapped() { onRevertTapped?() }

    func show(rawCharacter: String, correctedCharacter: String, isDark: Bool = false, in parent: UIView) {
        dismissTimer?.invalidate()
        StripChipStyle.applyContainerStyle(to: self, isDark: isDark)
        label.textColor = isDark ? .white : .label
        label.text = "⌫ Reverted \(rawCharacter) → \(correctedCharacter)  ·  Tap to Undo"
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
        parent.bringSubviewToFront(self)
        isHidden = false
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        dismissTimer?.invalidate()
        isHidden = true
    }
}
