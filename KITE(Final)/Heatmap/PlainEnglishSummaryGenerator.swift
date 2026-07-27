import Foundation
import CoreGraphics

/// Deterministic, rule-based, entirely on-device — reads only from the
/// already-tested KeyOffset math (isDirectionalDrift, scatterRadius), not a
/// separate model or network call. "Drift %" is an approximate scaling
/// against a 20pt reference (roughly the magnitude used in Demo Mode's
/// exaggerated profile), not a clinical measurement — stated honestly as
/// an approximation, not false precision.
enum PlainEnglishSummaryGenerator {

    static func generateSummary(for profile: MotorProfile) -> String {
        let controlKeys: Set<String> = ["space", "return", "⌫", "123", "ABC", "🌐"]
        let offsets = profile.keyOffsets.filter { $0.value.sampleCount > 0 && !controlKeys.contains($0.key.lowercased()) }
        guard !offsets.isEmpty else {
            return "Not enough typing data yet to summarize your pattern. Type a few sentences using the KITE keyboard, then check back here."
        }

        let directionalKeys = offsets.filter { $0.value.isDirectionalDrift }
            .sorted { magnitude(of: $0.value) > magnitude(of: $1.value) }
            .prefix(3)

        let scatterKeys = offsets.filter {
            !$0.value.isDirectionalDrift && $0.value.sampleCount >= KeyOffset.minSamplesForVarianceTrust && $0.value.scatterRadius > 4
        }.sorted { $0.value.scatterRadius > $1.value.scatterRadius }.prefix(3)

        var sentences: [String] = []

        if let strongest = directionalKeys.first {
            let percentage = driftPercentage(offset: strongest.value)
            let direction = compassDirection(dx: strongest.value.averageDeltaX, dy: strongest.value.averageDeltaY)
            let profileNote = profile.profileType == .spasticity ? " — consistent with your Spasticity profile" : ""
            let additionalCount = directionalKeys.count - 1
            let additionalNote = additionalCount > 0 ? " \(additionalCount) other key\(additionalCount > 1 ? "s show" : " shows") a similar consistent pattern." : ""
            sentences.append("Your \(strongest.key) key consistently drifts about \(percentage)% toward the \(direction)\(profileNote).\(additionalNote)")
        }

        if !scatterKeys.isEmpty {
            let keyNames = scatterKeys.map { $0.key }.joined(separator: ", ")
            let plural = scatterKeys.count > 1
            sentences.append("Your \(keyNames) key\(plural ? "s show" : " shows") more scattered variation than a consistent direction, so KITE widens \(plural ? "their" : "its") hit area instead of shifting \(plural ? "them" : "it").")
        }

        return sentences.isEmpty
            ? "Your typing pattern looks fairly consistent so far — no single key stands out yet."
            : sentences.joined(separator: " ")
    }

    private static func magnitude(of offset: KeyOffset) -> CGFloat {
        sqrt(offset.averageDeltaX * offset.averageDeltaX + offset.averageDeltaY * offset.averageDeltaY)
    }

    private static func driftPercentage(offset: KeyOffset) -> Int {
        let referenceMagnitude: CGFloat = 20
        return min(100, Int((magnitude(of: offset) / referenceMagnitude) * 100))
    }

    private static func compassDirection(dx: CGFloat, dy: CGFloat) -> String {
        let threshold: CGFloat = 2
        let horizontal = dx > threshold ? "right" : (dx < -threshold ? "left" : "")
        let vertical = dy > threshold ? "lower" : (dy < -threshold ? "upper" : "")
        if !horizontal.isEmpty && !vertical.isEmpty { return "\(vertical)-\(horizontal)" }
        if !horizontal.isEmpty { return horizontal }
        if !vertical.isEmpty { return vertical == "upper" ? "top" : "bottom" }
        return "center"
    }
}
