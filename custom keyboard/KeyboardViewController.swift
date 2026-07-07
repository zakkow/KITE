import UIKit

class KeyboardViewController: UIInputViewController {

    private var keyboardView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
    }

    private func setupKeyboard() {
        keyboardView = UIView()
        keyboardView.backgroundColor = UIColor.systemGray5
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Explicit height required — without this the keyboard collapses to zero.
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 216)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
    }
}
