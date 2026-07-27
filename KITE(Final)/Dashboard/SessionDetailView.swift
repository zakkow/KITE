import SwiftUI

struct SessionDetailView: View {
    let session: SessionData

    private var keyBreakdown: [(key: String, count: Int)] {
        var counts: [String: Int] = [:]
        for tap in session.rawTaps where tap.correctionApplied {
            counts[tap.key, default: 0] += 1
        }
        return counts.map { (key: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Time", value: session.date.formatted(date: .omitted, time: .shortened))
                LabeledContent("Total Taps", value: "\(session.totalKeystrokes)")
            }
            Section("Corrections") {
                LabeledContent("Applied", value: "\(session.correctionsApplied)")
                LabeledContent("Accepted", value: "\(session.correctionsAccepted)")
                LabeledContent("Rejected", value: "\(session.correctionsRejected)")
                if session.correctionsApplied > 0 {
                    LabeledContent("Acceptance Rate", value: "\(Int(session.accuracyRate * 100))%")
                }
            }
            if !keyBreakdown.isEmpty {
                Section("Most Corrected Keys") {
                    ForEach(keyBreakdown.prefix(6), id: \.key) { item in
                        LabeledContent(item.key, value: "\(item.count)×")
                    }
                }
            }
        }
        .navigationTitle("Session Detail")
    }
}
