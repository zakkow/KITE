import CoreGraphics
import Foundation

/// Estimates the dominant oscillation frequency of a single key press's
/// real touch trajectory (finger-down to finger-up) — NOT the timing
/// between separate keystrokes. Inter-keystroke timing is dominated by
/// voluntary typing rhythm and language planning, not physical tremor;
/// analyzing it for oscillation frequency would conflate cognition with
/// motor signal. This instead samples the actual physical wobble while a
/// finger is in contact with the screen, which is where genuine tremor
/// signal actually lives.
///
/// Implementation is a simple, explainable zero-crossing rate estimate —
/// counting direction reversals in the trajectory and converting cycle
/// count to Hz using real elapsed duration. Deliberately not a full FFT:
/// a single tap typically provides only a handful of samples over ~50-
/// 150ms, too little for a real spectral analysis to be more than
/// misleadingly precise. This trades some precision for a result that's
/// simple to verify and explain, which matters as much as raw accuracy
/// for a feature whose main value is honest corroboration, not a hidden
/// black-box number.
enum TremorFrequencyEstimator {

    private static let minimumSamplesRequired = 5
    private static let minimumDurationSeconds: TimeInterval = 0.03

    /// Returns nil if the trajectory is too short/sparse to say anything
    /// meaningful. Most ordinary quick taps will correctly return nil —
    /// that's the honest answer, not a forced guess.
    static func estimateFrequencyHz(from trajectory: [(point: CGPoint, timestamp: TimeInterval)]) -> Double? {
        guard trajectory.count >= minimumSamplesRequired else { return nil }
        guard let first = trajectory.first, let last = trajectory.last else { return nil }
        let duration = last.timestamp - first.timestamp
        guard duration >= minimumDurationSeconds else { return nil }

        let xCrossings = zeroCrossings(of: trajectory.map { $0.point.x })
        let yCrossings = zeroCrossings(of: trajectory.map { $0.point.y })
        let totalCrossings = xCrossings + yCrossings
        guard totalCrossings > 0 else { return nil }

        // Each full oscillation cycle produces 2 direction-reversal events
        // per axis; averaging both axes since real tremor wobble is
        // typically 2D, not confined to one clean axis.
        let cycles = Double(totalCrossings) / 2.0 / 2.0
        return cycles / duration
    }

    /// Counts sign changes in the first difference (velocity) of a value
    /// series — each sign change is one direction reversal.
    private static func zeroCrossings(of values: [CGFloat]) -> Int {
        guard values.count >= 3 else { return 0 }
        let deltas = zip(values, values.dropFirst()).map { $1 - $0 }
        var crossings = 0
        for i in 1..<deltas.count where deltas[i] != 0 && deltas[i - 1] != 0 && (deltas[i] > 0) != (deltas[i - 1] > 0) {
            crossings += 1
        }
        return crossings
    }
}
