import Foundation

/// Demonstrates the CLIENT-SIDE half of a differential-privacy mechanism —
/// calibrated noise added to a real local statistic before it WOULD be
/// shared. There is no server anywhere in this project to receive or
/// aggregate this across users. Real cross-user learning needs backend
/// infrastructure that doesn't exist here — this exists as an honest,
/// demonstrable building block for that future work, not as a working
/// aggregation feature today.
enum DifferentialPrivacyPreview {
    static func addLaplaceNoise(to value: Double, epsilon: Double = 1.0, sensitivity: Double = 0.05) -> Double {
        let scale = sensitivity / epsilon
        let u = Double.random(in: -0.499...0.499)
        let noise = -scale * (u < 0 ? -1.0 : 1.0) * log(1 - 2 * abs(u))
        return max(0, min(1, value + noise))
    }
}
