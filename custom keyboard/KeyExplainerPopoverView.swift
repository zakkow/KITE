import UIKit

/// Small on-keyboard popover explaining a key's current correction state
/// — same underlying data as Heatmap's per-key popover (mechanism,
/// confidence, sample count), reachable without leaving the keyboard.
final class KeyExplainerPopoverView: UIView {
    private let label = UILabel()
    private var dismissTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.systemGray5
        layer.cornerRadius = 10
        isHidden = true
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    func show(key: String, offset: KeyOffset?, near point: CGPoint, in parent: UIView) {
        dismissTimer?.invalidate()
        guard let offset, offset.sampleCount > 0 else {
            label.text = "\(key): not enough data yet"
            presentIfNeeded(near: point, in: parent)
            scheduleDismiss()
            return
        }
        let mechanism = offset.sampleCount < KeyOffset.minSamplesForVarianceTrust
            ? "Learning" : (offset.isDirectionalDrift ? "Directional" : "Widened")
        label.text = "\(key) — \(mechanism)\nConfidence \(Int(offset.confidence * 100))% · \(offset.sampleCount) samples"
        presentIfNeeded(near: point, in: parent)
        scheduleDismiss()
    }

    private func presentIfNeeded(near point: CGPoint, in parent: UIView) {
        if superview == nil {
            parent.addSubview(self)
        }
        translatesAutoresizingMaskIntoConstraints = true
        let width: CGFloat = 160
        let height: CGFloat = 44
        var x = point.x - width / 2
        x = max(4, min(x, parent.bounds.width - width - 4))
        let y = max(4, point.y - height - 8)
        frame = CGRect(x: x, y: y, width: width, height: height)
        isHidden = false
        parent.bringSubviewToFront(self)
    }

    private func scheduleDismiss() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.isHidden = true
        }
    }
}
