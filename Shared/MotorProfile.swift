import Foundation

struct MotorProfile: Codable {
    var profileType: ProfileType = .general
    var inputStyle: InputStyle = .unknown
    var keyOffsets: [String: KeyOffset] = [:]
    var manualOverrides: [String: ManualCorrectionRule] = [:] // e.g. "T": ManualCorrectionRule(fromKey: "T", toKey: "E", ...) — forces T taps to always produce E
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()
    var totalSessions: Int = 0
    var isDemoMode: Bool = false

    static var `default`: MotorProfile { MotorProfile() }

    /// Fresh profile for a newly selected type. keyOffsets stays empty —
    /// CorrectionEngine seeds individual keys lazily via
    /// KeyOffset.seeded(for:profileType:) the first time each key is touched.
    static func fresh(profileType: ProfileType) -> MotorProfile {
        var profile = MotorProfile()
        profile.profileType = profileType
        return profile
    }

    /// Pre-seeded profile for live demos. Uses CONSISTENT DIRECTIONAL drift
    /// (low variance relative to a large mean offset) so the directional-shift
    /// mechanism fires reliably — it's the more visually dramatic correction
    /// for a live audience. Scatter-widening is real but subtler to show.
    static var demo: MotorProfile {
        var profile = MotorProfile()
        profile.profileType = .spasticity
        profile.isDemoMode = true
        let demoKeys = ["Q","W","E","R","T","Y","U","I","O","P",
                        "A","S","D","F","G","H","J","K","L",
                        "Z","X","C","V","B","N","M"]
        for key in demoKeys {
            profile.keyOffsets[key] = KeyOffset(
                key: key,
                averageDeltaX: 15,
                averageDeltaY: -14,
                varianceX: 1.5,  // low relative to mean -> high consistency ratio -> directional shift fires
                varianceY: 1.5,
                confidence: 0.95,
                acceptanceRate: 0.94,
                sampleCount: 200,
                averageInterval: 0.18
            )
        }
        return profile
    }
}

enum ProfileType: String, Codable, CaseIterable {
    case tremor, spasticity, general, notSure
}

enum InputStyle: String, Codable {
    case finger, thumb, unknown
}
