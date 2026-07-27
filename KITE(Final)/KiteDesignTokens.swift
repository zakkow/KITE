import SwiftUI
import UIKit // This import can remain, it does no harm.

/// Central 8pt spacing + corner radius scale.
enum KiteSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum KiteRadius {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 12
    static let pill: CGFloat = 20
}

// The 'extension Color' block for kiteKeyboardBackground and
// 'extension UIColor' for kiteKeyboardBackground have been REMOVED
// from this file to resolve the redeclaration error and revert this change.
