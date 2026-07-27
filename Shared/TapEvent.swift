import CoreGraphics
import Foundation

struct TapEvent: Codable {
    var key: String
    var rawX: CGFloat
    var rawY: CGFloat
    var correctedKey: String?
    var correctionApplied: Bool
    var correctionAccepted: Bool?
    var timestamp: TimeInterval
    var intervalSinceLast: TimeInterval
}
