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

        let xs = trajectory.map { $0.point.x }
        let ys = trajectory.map { $0.point.y }

        let xCrossings = zeroCrossings(of: xs)
        let yCrossings = zeroCrossings(of: ys)
        let totalCrossings = xCrossings + yCrossings
        guard totalCrossings > 0 else { return nil }

        // How much does each axis actually participate in the motion? Using
        // positional range (max-min) as a simple, sample-count-robust proxy
        // for oscillation amplitude on that axis — avoids relying on variance,
        // which is noisier with only a handful of points per tap.
        let xRange = (xs.max() ?? 0) - (xs.min() ?? 0)
        let yRange = (ys.max() ?? 0) - (ys.min() ?? 0)
        let majorRange = max(xRange, yRange)
        let minorRange = min(xRange, yRange)

        // 0 = motion confined to a single axis (pure linear wobble).
        // 1 = both axes equally involved (circular/elliptical wobble).
        let minorAxisParticipation = majorRange > 0 ? minorRange / majorRange : 0

        // Each full oscillation cycle produces 2 direction-reversal events on
        // an axis that's genuinely participating. A perfectly circular wobble
        // (both axes fully participating) yields 4 total crossings per cycle
        // -> divide by 4. A perfectly linear, single-axis wobble yields only 2
        // crossings per cycle on the one moving axis -> divide by 2. This
        // blends continuously between those two cases based on how much the
        // minor axis actually contributes, instead of assuming one tremor
        // shape fits every user.
        let divisor = 2.0 * (1.0 + minorAxisParticipation)
        let cycles = Double(totalCrossings) / divisor
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
