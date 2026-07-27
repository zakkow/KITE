import Foundation

enum HandSide { case left, right, center }

/// Standard touch-typing QWERTY hand assignment — a heuristic convention,
/// not a literal biomechanical model of any individual's actual hand usage.
enum HandSideMapping {
    private static let leftKeys: Set<String> = ["Q","W","E","R","T","A","S","D","F","G","Z","X","C","V","B"]
    private static let rightKeys: Set<String> = ["Y","U","I","O","P","H","J","K","L","N","M"]

    static func side(for key: String) -> HandSide {
        if leftKeys.contains(key) { return .left }
        if rightKeys.contains(key) { return .right }
        return .center
    }
}
