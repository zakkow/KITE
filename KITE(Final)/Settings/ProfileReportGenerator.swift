import Foundation

enum ProfileReportGenerator {
    static func generateReport(profile: MotorProfile, sessions: [SessionData]) -> String {
        var lines: [String] = []
        lines.append("KITE Typing Profile Report")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("")
        lines.append("Profile Type: \(profileLabel(profile.profileType))")
        lines.append("Sessions Recorded: \(sessions.count)")
        lines.append("")
        lines.append("Summary:")
        lines.append(PlainEnglishSummaryGenerator.generateSummary(for: profile))
        lines.append("")
        lines.append("Per-Key Summary:")
        for (key, offset) in profile.keyOffsets.sorted(by: { $0.key < $1.key }) {
            let mechanism = offset.sampleCount < KeyOffset.minSamplesForVarianceTrust ? "Still learning" : (offset.isDirectionalDrift ? "Directional drift" : "Scatter / widened")
            lines.append("- \(key): confidence \(Int(offset.confidence * 100))%, acceptance \(Int(offset.acceptanceRate * 100))%, samples \(offset.sampleCount) — \(mechanism)")
        }
        lines.append("")
        lines.append("This report reflects on-device typing pattern data only. No data has ever left this device.")
        return lines.joined(separator: "\n")
    }

    private static func profileLabel(_ type: ProfileType) -> String {
        switch type {
        case .tremor: return "Tremor"
        case .spasticity: return "Spasticity / CP"
        case .general: return "General"
        case .notSure: return "Not Sure Yet"
        }
    }
}
