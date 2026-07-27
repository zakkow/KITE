import SwiftUI

struct HeatmapView: View {
    @State private var baseline: ProfileSnapshot?
    @State private var currentProfile: MotorProfile?
    @State private var selectedKey: String?       // single-tap: shows strict stat data
    @State private var longPressKey: String?      // long-press: shows plain-English quirk overlay
    @State private var showResetKeyConfirmation = false
    @State private var confusionPairs: [(pair: String, count: Int)] = []
    @State private var recentLog: [ExplainabilityLogEntry] = []

    let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"],
        ["space"]
    ]

    private var summary: (learned: Int, improving: Int, learning: Int, touched: Int, avgConfidence: Int)? {
        let letterKeys = rows.flatMap { $0 }
        guard let allOffsets = currentProfile?.keyOffsets else { return nil }
        let touchedOffsets = letterKeys.compactMap { allOffsets[$0] }.filter { $0.sampleCount > 0 }
        guard !touchedOffsets.isEmpty else { return nil }
        let learned = touchedOffsets.filter { $0.confidence >= 0.7 }.count
        let improving = touchedOffsets.filter { $0.confidence >= 0.33 && $0.confidence < 0.7 }.count
        let learning = touchedOffsets.filter { $0.confidence < 0.33 }.count
        let avg = touchedOffsets.map { $0.confidence }.reduce(0, +) / Double(touchedOffsets.count)
        return (learned, improving, learning, touchedOffsets.count, Int(avg * 100))
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ScreenTitleHeader(title: "Heatmap")

                    if let summary {
                        HStack(spacing: 12) {
                            statCard(value: "\(summary.avgConfidence)%", label: "Avg. Confidence")
                            statCard(value: "\(summary.learned)", label: "Well-Learned")
                            statCard(value: "\(summary.improving)", label: "Improving")
                        }
                        .padding(.horizontal)
                        Text("\(summary.touched) of \(rows.flatMap { $0 }.count) keys touched so far · \(summary.learning) still learning")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    legend

                    // Heatmaps stacked vertically; baseline on top, Today on bottom.
                    VStack(spacing: 12) {
                        panel(title: baselineDateLabel, offsets: baseline?.keyOffsets, isInteractive: false)
                        // Today panel: ZStack so the long-press quirk overlay floats ON TOP of the keys
                        ZStack(alignment: .top) {
                            panel(title: "Today", offsets: currentProfile?.keyOffsets, isInteractive: true)
                            if let lpKey = longPressKey {
                                FloatingQuirkOverlay(
                                    key: lpKey,
                                    offset: currentProfile?.keyOffsets[lpKey]
                                ) { longPressKey = nil }
                                .padding(8)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .zIndex(1)
                            }
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: longPressKey)
                    }
                    .padding(.horizontal)

                    if let currentProfile {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                ScaledText("Your Pattern", size: 14, weight: .semibold, relativeTo: .subheadline, color: .kiteAmber)
                            } icon: {
                                Image(systemName: "text.bubble").foregroundColor(.kiteAmber)
                            }
                            ScaledText(PlainEnglishSummaryGenerator.generateSummary(for: currentProfile), size: 14, relativeTo: .subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .kiteCard(.primary)
                        .padding(.horizontal)
                        .accessibilityElement(children: .combine)

                        NavigationLink(destination: ProfileSummaryView()) {
                            ScaledText("View Full Profile Summary", size: 14, relativeTo: .subheadline, color: .kiteAmber)
                        }
                        .padding(.horizontal)
                    }

                    if let selectedKey {
                        VStack(spacing: 8) {
                            if let offset = currentProfile?.keyOffsets[selectedKey] {
                                KeyStatsPopover(key: selectedKey, offset: offset)
                                Button(action: { showResetKeyConfirmation = true }) {
                                    ScaledText("Reset this key", size: 13, relativeTo: .footnote, color: .red)
                                }
                            } else {
                                KeyNoDataPopover(key: selectedKey)
                            }
                        }
                        .padding(.horizontal)
                        .confirmationDialog(
                            "Reset \(selectedKey) back to its starting default? This clears everything KITE has learned about this specific key.",
                            isPresented: $showResetKeyConfirmation, titleVisibility: .visible
                        ) {
                            Button("Reset", role: .destructive) { resetKey(selectedKey) }
                            Button("Cancel", role: .cancel) {}
                        }
                    } else if currentProfile?.keyOffsets.isEmpty != false {
                        ScaledText("Type a few sentences using the KITE keyboard, then come back here to see what it\'s learned about your typing pattern.", size: 14, relativeTo: .subheadline, color: .secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, KiteSpacing.xl)
                    }


                    if !confusionPairs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ScaledText("Confusion Pairs", size: 15, weight: .semibold, relativeTo: .subheadline)
                            ForEach(confusionPairs.prefix(8), id: \.pair) { item in
                                HStack {
                                    ScaledText(item.pair, size: 13, relativeTo: .footnote)
                                    Spacer()
                                    ScaledText("\(item.count)×", size: 13, relativeTo: .footnote, color: .secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if !recentLog.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ScaledText("Recent Corrections", size: 15, weight: .semibold, relativeTo: .subheadline)
                            ForEach(recentLog.reversed().prefix(10)) { entry in
                                HStack {
                                    ScaledText("\(entry.fromKey)→\(entry.toKey)", size: 13, relativeTo: .footnote)
                                    ScaledText(entry.mechanism, size: 11, relativeTo: .caption2, color: .secondary)
                                    Spacer()
                                    ScaledText("\(Int(entry.confidence * 100))%", size: 12, relativeTo: .caption, color: .secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { load() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    load()
                }
            }
        }
    }

    private func load() {
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.baselineProfileSnapshot),
           let snapshot = try? JSONDecoder().decode(ProfileSnapshot.self, from: data) {
            baseline = snapshot
        }

        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
           let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            currentProfile = profile
        }

        recentLog = ExplainabilityLogStore.load()
        confusionPairs = computeConfusionPairs()
    }

    private func computeConfusionPairs() -> [(pair: String, count: Int)] {
        ConfusionPairAnalyzer.topConfusionPairs()
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Circle().fill(Color.kiteNeutral).frame(width: 10, height: 10)
                Text("No data yet").font(.system(size: 12)).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                Text("Less confident").font(.system(size: 11)).foregroundColor(.secondary)
                LinearGradient(colors: [.kiteAmberLight, .kiteAmberDark], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 60, height: 8)
                    .clipShape(Capsule())
                Text("Well-learned").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            ScaledText(label, size: 12, relativeTo: .caption, color: .secondary)
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            ScaledText(value, size: 22, weight: .bold, relativeTo: .title2, color: .kiteAmber)
            ScaledText(label, size: 11, relativeTo: .caption2, color: .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color(.systemGray6)).cornerRadius(KiteRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: KiteRadius.medium)
                .stroke(Color.kiteAmber.opacity(0.20), lineWidth: 1)
        )
    }

    private var baselineDateLabel: String {
        guard let date = baseline?.date else { return "No data yet" }
        return "Day 1 · \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    @ViewBuilder
    private func panel(title: String, offsets: [String: KeyOffset]?, isInteractive: Bool) -> some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                if let offsets, !offsets.isEmpty {
                    let cellWidth = max((geo.size.width - 11 * 3) / 10, 14)
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(row, id: \.self) { key in
                                keyCell(for: key, offsets: offsets, width: key == "space" ? cellWidth * 5 : cellWidth, isInteractive: isInteractive)
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Not enough\ndata yet").font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
                Text(title).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .frame(height: 170)
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isInteractive ? Color.kiteAmber.opacity(0.22) : Color(.systemGray3).opacity(0.40),
                    lineWidth: 1
                )
        )
    }

    private func keyCell(for key: String, offsets: [String: KeyOffset], width: CGFloat, isInteractive: Bool) -> some View {
        let offset = offsets[key]
        let confidence = offset?.confidence ?? 0
        let hasData = (offset?.sampleCount ?? 0) > 0
        let deltaX = CGFloat(offset?.averageDeltaX ?? 0)
        let deltaY = CGFloat(offset?.averageDeltaY ?? 0)
        
        return ZStack {
            Text(key)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)

            if hasData && (abs(deltaX) > 0.5 || abs(deltaY) > 0.5) {
                let normDx = max(-8.0, min(8.0, deltaX * 0.4))
                let normDy = max(-6.0, min(6.0, deltaY * 0.4))
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .offset(x: normDx, y: normDy)
            }
        }
        .frame(width: width, height: 24)
        .background(Color.heatmapColor(forConfidence: confidence, hasData: hasData))
        .cornerRadius(KiteRadius.tiny)
        .onTapGesture {
            if isInteractive {
                longPressKey = nil  // dismiss quirk overlay when selecting a new key
                selectedKey = key
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            if isInteractive {
                selectedKey = nil   // dismiss stat panel when showing quirk overlay
                longPressKey = key
            }
        }
    }

    private func resetKey(_ key: String) {
        guard var profile = currentProfile else { return }
        profile.keyOffsets[key] = KeyOffset.seeded(for: key, profileType: profile.profileType)
        guard let data = try? JSONEncoder().encode(profile),
              (try? JSONDecoder().decode(MotorProfile.self, from: data)) != nil else { return()
        }
        SharedStore.defaults?.set(data, forKey: SharedStore.Keys.motorProfile)
        currentProfile = profile
    }
}

struct KeyStatsPopover: View {
    let key: String
    let offset: KeyOffset

    private var mechanismLabel: String {
        if offset.sampleCount < KeyOffset.minSamplesForVarianceTrust { return "Learning" }
        return offset.isDirectionalDrift ? "Directional" : "Widened"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScaledText(key, size: 20, weight: .bold, relativeTo: .largeTitle)
            ScaledText("Samples: \(offset.sampleCount)", size: 14, relativeTo: .subheadline)
            ScaledText("Acceptance: \(Int(offset.acceptanceRate * 100))%", size: 14, relativeTo: .subheadline)
            ScaledText("Confidence: \(Int(offset.confidence * 100))%", size: 14, relativeTo: .subheadline)
            ScaledText("Mechanism: \(mechanismLabel)", size: 14, relativeTo: .subheadline).foregroundColor(.secondary)
            if offset.frequencySampleCount >= 5 {
                ScaledText("Detected rhythm: \(String(format: "%.1f", offset.detectedFrequencyHz)) Hz\(offset.isConsistentWithTremorFrequency ? " (consistent with tremor)" : "")", size: 13, relativeTo: .footnote, color: .secondary)
            } else {
                ScaledText("Detected rhythm: not enough data yet", size: 13, relativeTo: .footnote, color: .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(KiteRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: KiteRadius.large)
                .stroke(Color(red: 0.2, green: 0.55, blue: 0.75).opacity(0.28), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KeyNoDataPopover: View {
    let key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScaledText(key, size: 20, weight: .bold, relativeTo: .largeTitle)
            ScaledText("No data yet for this key.", size: 14, relativeTo: .subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(KiteRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: KiteRadius.large)
                .stroke(Color(.systemGray3).opacity(0.45), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { HeatmapView() }

/// Plain-English quirk overlay — floats OVER the Today heatmap panel
/// when the user long-presses a key. Mirrors the logic in
/// KeyExplainerPopoverView (in the live keyboard) so the two never drift.
struct FloatingQuirkOverlay: View {
    let key: String
    let offset: KeyOffset?
    let onDismiss: () -> Void

    private var quirkText: String {
        guard let offset, offset.sampleCount > 0 else {
            return "No data yet for \(key). Type more with KITE to see what it learns here."
        }
        if offset.sampleCount < KeyOffset.minSamplesForVarianceTrust {
            return "Still learning \(key) — not enough taps yet for KITE to be confident here."
        } else if offset.isDirectionalDrift {
            let dx = offset.averageDeltaX, dy = offset.averageDeltaY
            let h = dx > 2 ? "right" : (dx < -2 ? "left" : "")
            let v = dy > 2 ? "lower" : (dy < -2 ? "upper" : "")
            let dir: String
            if !h.isEmpty && !v.isEmpty { dir = "\(v)-\(h)" }
            else if !h.isEmpty { dir = h }
            else if !v.isEmpty { dir = v == "upper" ? "top" : "bottom" }
            else { dir = "center" }
            return "Your \(key) taps drift \(dir) — KITE shifts its target zone to catch where you actually mean to hit."
        } else {
            return "Your \(key) taps scatter in multiple directions — KITE widens the acceptance area instead of guessing a direction."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(key)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.kiteAmber)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray3))
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Dismiss quirk info for \(key)")
            }
            Text(quirkText)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: KiteRadius.large)
                .fill(Color(.systemBackground).opacity(0.96))
                .shadow(color: Color.kiteAmber.opacity(0.25), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KiteRadius.large)
                .stroke(Color.kiteAmber.opacity(0.55), lineWidth: 1.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
