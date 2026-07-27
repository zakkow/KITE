import SwiftUI

struct ProfileSummaryView: View {
    @State private var profile: MotorProfile?
    @State private var baseline: ProfileSnapshot?
    @State private var sessions: [SessionData] = []

    private var summary: (learned: Int, learning: Int, avgConfidence: Int)? {
        guard let offsets = profile?.keyOffsets, !offsets.isEmpty else { return nil }
        let learned = offsets.values.filter { $0.confidence >= 0.7 }.count
        let learning = offsets.values.filter { $0.confidence < 0.33 }.count
        let avg = offsets.values.map { $0.confidence }.reduce(0, +) / Double(offsets.count)
        return (learned, learning, Int(avg * 100))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KiteSpacing.l) {
                if let profile {
                    VStack(alignment: .leading, spacing: 4) {
                        ScaledText(profileLabel(profile.profileType), size: 24, weight: .bold, relativeTo: .title)
                        ScaledText("Calibrated \(baseline?.date.formatted(date: .abbreviated, time: .omitted) ?? "recently") · \(sessions.count) session\(sessions.count == 1 ? "" : "s") recorded", size: 13, relativeTo: .footnote, color: .secondary)
                    }
                }

                if let summary {
                    HStack(spacing: KiteSpacing.s) {
                        statCard(value: "\(summary.avgConfidence)%", label: "Avg. Confidence")
                        statCard(value: "\(summary.learned)", label: "Well-Learned")
                        statCard(value: "\(summary.learning)", label: "Still Learning")
                    }
                }

                VStack(alignment: .leading, spacing: KiteSpacing.s) {
                    Label {
                        ScaledText("Your Pattern", size: 15, weight: .semibold, relativeTo: .subheadline, color: .kiteAmber)
                    } icon: {
                        Image(systemName: "text.bubble").foregroundColor(.kiteAmber)
                    }
                    ScaledText(profile.map { PlainEnglishSummaryGenerator.generateSummary(for: $0) } ?? "Not enough data yet.", size: 15, relativeTo: .subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding().background(Color(.systemGray6)).cornerRadius(KiteRadius.large)

                let pairs = ConfusionPairAnalyzer.topConfusionPairs(limit: 5)
                if !pairs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ScaledText("Most Common Corrections", size: 15, weight: .semibold, relativeTo: .subheadline)
                        ForEach(pairs, id: \.pair) { item in
                            HStack {
                                ScaledText(item.pair, size: 14, relativeTo: .subheadline)
                                Spacer()
                                ScaledText("\(item.count)×", size: 14, relativeTo: .subheadline, color: .secondary)
                            }
                        }
                    }
                }

                if let profile, !profile.manualOverrides.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ScaledText("Your Manual Corrections", size: 15, weight: .semibold, relativeTo: .subheadline)
                        ForEach(profile.manualOverrides.values.sorted(by: { $0.fromKey < $1.fromKey })) { rule in
                            ScaledText("\(rule.fromKey) → \(rule.toKey) (\(rule.strictness.label), \(rule.context.label))", size: 13, relativeTo: .footnote, color: .secondary)
                        }
                    }
                }

                ShareLink(item: reportText) {
                    Label("Export This Summary", systemImage: "square.and.arrow.up")
                }
                .padding(.top, KiteSpacing.s)
            }
            .padding()
        }
        .navigationTitle("Profile Summary")
        .onAppear { load() }
    }

    private var reportText: String {
        guard let profile else { return "No profile data yet." }
        return ProfileReportGenerator.generateReport(profile: profile, sessions: sessions)
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            ScaledText(value, size: 20, weight: .bold, relativeTo: .title3, color: .kiteAmber)
            ScaledText(label, size: 11, relativeTo: .caption2, color: .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, KiteSpacing.s)
        .background(Color(.systemGray6)).cornerRadius(KiteRadius.medium)
    }

    private func profileLabel(_ type: ProfileType) -> String {
        switch type {
        case .tremor: return "Tremor Profile"
        case .spasticity: return "Spasticity / CP Profile"
        case .general: return "General Profile"
        case .notSure: return "Adaptive Profile"
        }
    }

    private func load() {
        sessions = SessionHistoryStore.load()
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.baselineProfileSnapshot),
           let decoded = try? JSONDecoder().decode(ProfileSnapshot.self, from: data) { baseline = decoded }
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
           let decoded = try? JSONDecoder().decode(MotorProfile.self, from: data) { profile = decoded }
    }
}

#Preview { NavigationStack { ProfileSummaryView() } }
