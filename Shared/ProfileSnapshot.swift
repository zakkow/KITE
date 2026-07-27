import Foundation

/// Lightweight, immutable snapshot of per-key confidence taken once, the
/// first time real (non-empty) tap data exists. This is the "before" panel
/// in Heatmap's comparison — never overwritten afterward, so it stays a
/// genuine baseline instead of drifting alongside "now."
struct ProfileSnapshot: Codable {
    var date: Date
    var keyOffsets: [String: KeyOffset]
}
