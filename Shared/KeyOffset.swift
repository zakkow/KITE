import CoreGraphics
import Foundation

/// Per-key motor drift model. Tracks average offset (bias) and variance (scatter) to distinguish consistent drift from oscillation.
struct KeyOffset: Codable {
    var key: String
    var averageDeltaX: CGFloat = 0
    var averageDeltaY: CGFloat = 0
    var varianceX: CGFloat = 0
    var varianceY: CGFloat = 0
    var confidence: Double = 0
    var acceptanceRate: Double = 1.0
    var sampleCount: Int = 0
    var averageInterval: TimeInterval = 0
    var detectedFrequencyHz: Double = 0
    var frequencySampleCount: Int = 0
    var lastUpdated: Date? = nil

    /// Computes confidence applying a 14-day exponential half-life decay
    /// for stale motor offset statistics.
    var effectiveDecayedConfidence: Double {
        guard let last = lastUpdated else { return confidence }
        let elapsedDays = Date().timeIntervalSince(last) / (24.0 * 3600.0)
        guard elapsedDays > 1.0 else { return confidence }
        let decayFactor = exp(-0.693147 * (elapsedDays / 14.0))
        return confidence * decayFactor
    }

    static let minSamplesForVarianceTrust = 3
    static let highConsistencyThreshold = 0.6 // mean magnitude / stdDev

    /// Ratio of mean magnitude to standard deviation. High ratio = consistent drift.
    var consistencyRatio: Double {
        let stdDev = sqrt(Double(varianceX + varianceY))
        guard stdDev > 0.01 else {
            return sampleCount >= KeyOffset.minSamplesForVarianceTrust ? 10.0 : 0.0
        }
        let meanMagnitude = sqrt(Double(averageDeltaX * averageDeltaX + averageDeltaY * averageDeltaY))
        return meanMagnitude / stdDev
    }

    /// True if bias is proven consistent across enough samples.
    var isDirectionalDrift: Bool {
        sampleCount >= KeyOffset.minSamplesForVarianceTrust &&
        consistencyRatio >= KeyOffset.highConsistencyThreshold
    }

    /// Scatter radius derived from variance components.
    var scatterRadius: CGFloat {
        (sqrt(varianceX) + sqrt(varianceY)) / 2.0
    }

    /// True when frequency estimates fall within essential-tremor range (4-12 Hz).
    var isConsistentWithTremorFrequency: Bool {
        frequencySampleCount >= 5 && detectedFrequencyHz >= 4.0 && detectedFrequencyHz <= 12.0
    }

    static func empty(for key: String) -> KeyOffset {
        KeyOffset(key: key)
    }

    /// Cold-start defaults for scatter-widening informed by motor-impairment research.
    static func seeded(for key: String, profileType: ProfileType) -> KeyOffset {
        switch profileType {
        case .tremor:
            return KeyOffset(key: key, varianceX: 6.5, varianceY: 6.5, confidence: 0.3)
        case .spasticity:
            return KeyOffset(key: key, varianceX: 3.0, varianceY: 3.0, confidence: 0.3)
        case .general:
            return KeyOffset(key: key, varianceX: 5.0, varianceY: 5.0, confidence: 0.3)
        case .notSure:
            return KeyOffset(key: key, varianceX: 4.0, varianceY: 4.0, confidence: 0.2)
        }
    }
}
