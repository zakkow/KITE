import Foundation

struct SessionData: Codable {
    /// iOS kills keyboard extensions near ~120MB. This cap keeps raw tap history bounded.
    static let maxRawTapsRetained = 300

    var id: UUID = UUID()
    var date: Date = Date()
    var totalKeystrokes: Int = 0
    var correctionsApplied: Int = 0
    var correctionsAccepted: Int = 0
    var correctionsRejected: Int = 0
    var linguisticVetoes: Int = 0
    var accuracyRate: Double = 0
    var rawTaps: [TapEvent] = []

    /// Appends a tap, updates aggregate stats, and trims raw history to the cap.
    mutating func addTap(_ tap: TapEvent) {
        rawTaps.append(tap)
        if rawTaps.count > SessionData.maxRawTapsRetained {
            rawTaps.removeFirst(rawTaps.count - SessionData.maxRawTapsRetained)
        }

        totalKeystrokes += 1
        if tap.correctionApplied {
            correctionsApplied += 1
            if tap.correctionAccepted == true {
                correctionsAccepted += 1
            } else if tap.correctionAccepted == false {
                correctionsRejected += 1
            }
        }
        if correctionsApplied > 0 {
            accuracyRate = Double(correctionsAccepted) / Double(correctionsApplied)
        }
    }
}
