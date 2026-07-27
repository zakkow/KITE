import SwiftUI
import Charts

struct DashboardView: View {
    @State private var sessionHistory: [SessionData] = []
    @State private var correctionsThisWeek: Int = 0
    @State private var acceptanceRate: Double = 0.0
    @State private var weekOverWeekChange: Double = 0.0
    @State private var chartVisible = false

    private var liveSession: SessionData? {
        guard let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.currentSession),
              let session = try? JSONDecoder().decode(SessionData.self, from: data),
              session.totalKeystrokes > 0 else { return nil }
        return session
    }

    private var thisWeekSessions: [SessionData] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionHistory.filter { $0.date >= weekAgo }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: KiteSpacing.l) {
                ScreenTitleHeader(title: "Dashboard")

                HStack(spacing: KiteSpacing.s) {
                    MetricChip(value: "\(correctionsThisWeek)", label: "Corrections",
                        accessibilityText: "\(correctionsThisWeek) corrections this week")
                        .accessibilityIdentifier("correctionsThisWeekValue")

                    MetricChip(value: "\(Int(acceptanceRate * 100))%", label: "Acceptance",
                        accessibilityText: "\(Int(acceptanceRate * 100)) percent acceptance rate")
                        .accessibilityIdentifier("acceptanceRateValue")

                    MetricChip(
                        value: "\(weekOverWeekChange >= 0 ? "+" : "")\(Int(weekOverWeekChange * 100))%",
                        label: "vs last week",
                        valueColor: weekOverWeekChange >= 0 ? .kiteAmber : .red,
                        accessibilityText: "\(Int(weekOverWeekChange * 100)) percent change from last week"
                    )
                }
                .padding(.horizontal)

                HStack(spacing: KiteSpacing.s) {
                    MetricChip(value: "\(thisWeekSessions.reduce(0) { $0 + $1.linguisticVetoes })", label: "Safety Net Catches",
                        accessibilityText: "\(thisWeekSessions.reduce(0) { $0 + $1.linguisticVetoes }) corrections blocked by the linguistic safety net this week")
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: KiteSpacing.s) {
                    ScaledText("Accuracy Trend (14 Days)", size: 18, weight: .semibold, relativeTo: .title3)
                        .padding(.horizontal)

                    AccuracyChart(dailyAcceptanceRates: calculateDailyAcceptanceRates())
                        .frame(height: 200)
                        .padding(.horizontal)
                        .opacity(chartVisible ? 1 : 0)
                        .scaleEffect(y: chartVisible ? 1 : 0.3, anchor: .bottom)
                        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.15), value: chartVisible)
                }

                VStack(alignment: .leading, spacing: KiteSpacing.s) {
                    ScaledText("Recent Sessions", size: 18, weight: .semibold, relativeTo: .title3)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(sessionHistory.suffix(10).reversed(), id: \.id) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                HStack {
                                    Text("\(session.date.formatted(date: .omitted, time: .shortened)) · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 14))
                                    Spacer()
                                    Text(session.correctionsApplied > 0
                                        ? "\(session.correctionsApplied) corrections · \(Int(session.accuracyRate * 100))% accepted"
                                        : "\(session.totalKeystrokes) taps · no corrections needed")
                                        .font(.system(size: 14)).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, KiteSpacing.s)
                            Divider()
                        }
                        if sessionHistory.count > 10 {
                            NavigationLink(destination: SessionHistoryDetailView(sessions: sessionHistory)) {
                                ScaledText("See Full History (\(sessionHistory.count) sessions)", size: 14, relativeTo: .subheadline, color: .kiteAmber)
                            }
                            .padding(.top, KiteSpacing.s)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            loadSessionData()
            withAnimation { chartVisible = true }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                loadSessionData()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
    }

    private func loadSessionData() {
        if let historyData = SharedStore.getSharedData(forKey: SharedStore.Keys.sessionHistory),
           let history = try? JSONDecoder().decode([SessionData].self, from: historyData) {
            sessionHistory = history
        }

        if let currentData = SharedStore.getSharedData(forKey: SharedStore.Keys.currentSession),
           let current = try? JSONDecoder().decode(SessionData.self, from: currentData) {
            // Remove any existing session with the same ID to prevent duplicates
            sessionHistory.removeAll { $0.id == current.id }
            sessionHistory.insert(current, at: 0)
        }

        calculateMetrics()
    }

    private func calculateMetrics() {
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        var thisWeekCorrections = 0
        var thisWeekTotal = 0
        var thisWeekAccepted = 0

        var lastWeekCorrections = 0
        var lastWeekTotal = 0
        var lastWeekAccepted = 0

        for session in thisWeekSessions {
            let sessionDate = session.date

            if sessionDate >= oneWeekAgo {
                thisWeekCorrections += session.correctionsApplied
                thisWeekTotal += session.totalKeystrokes
                thisWeekAccepted += session.correctionsAccepted
            } else if sessionDate >= twoWeeksAgo && sessionDate < oneWeekAgo {
                lastWeekCorrections += session.correctionsApplied
                lastWeekTotal += session.totalKeystrokes
                lastWeekAccepted += session.correctionsAccepted
            }
        }

        correctionsThisWeek = thisWeekCorrections
        acceptanceRate = thisWeekCorrections > 0 ? Double(thisWeekAccepted) / Double(thisWeekCorrections) : 0.0

        let lastWeekRate = lastWeekCorrections > 0 ? Double(lastWeekAccepted) / Double(lastWeekCorrections) : 0.0
        weekOverWeekChange = acceptanceRate - lastWeekRate
    }

    private func calculateDailyAcceptanceRates() -> [Double] {
        var dailyRates: [Double] = Array(repeating: 0.0, count: 14)
        var dailyCorrections: [Int] = Array(repeating: 0, count: 14)
        var dailyAccepted: [Int] = Array(repeating: 0, count: 14)

        let now = Date()
        let calendar = Calendar.current

        for session in sessionHistory {
            let sessionDate = session.date
            let daysSince = calendar.dateComponents([.day], from: sessionDate, to: now).day ?? 0

            if daysSince < 14 {
                dailyCorrections[daysSince] += session.correctionsApplied
                dailyAccepted[daysSince] += session.correctionsAccepted
            }
        }

        for i in 0..<14 {
            dailyRates[i] = dailyCorrections[i] > 0 ? Double(dailyAccepted[i]) / Double(dailyCorrections[i]) : 0.0
        }

        return dailyRates.reversed()
    }
}

struct MetricChip: View {
    let value: String
    let label: String
    var valueColor: Color = .primary
    var accessibilityText: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            // Reduced the font size from 32 to 28 to prevent wrapping for "100%"
            ScaledText(value, size: 28, weight: .bold, relativeTo: .title, color: valueColor)
            ScaledText(label, size: 12, relativeTo: .caption, color: .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.kiteAmber.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? "\(value) \(label)")
    }
}

struct AccuracyChart: View {
    let dailyAcceptanceRates: [Double]

    var body: some View {
        Chart {
            ForEach(Array(dailyAcceptanceRates.enumerated()), id: \.offset) { index, rate in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Rate", rate * 100)
                )
                .foregroundStyle(Color.kiteAmber)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Day", index),
                    y: .value("Rate", rate * 100)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.kiteAmber.opacity(0.25), Color.kiteAmber.opacity(0.03)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Reference line at 50% acceptance so users can read their trend
            RuleMark(y: .value("50%", 50))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.secondary.opacity(0.35))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("50%").font(.system(size: 9)).foregroundColor(.secondary)
                }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.border(Color.clear)
        }
    }
}


struct SessionRow: View {
    let session: SessionData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                ScaledText(formatDate(session.date), size: 14, weight: .medium, relativeTo: .subheadline)
                    .foregroundColor(.primary)

                ScaledText("\(session.totalKeystrokes) taps • \(session.correctionsApplied) corrections", size: 12, relativeTo: .caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                let rate = session.correctionsApplied > 0 ? Double(session.correctionsAccepted) / Double(session.correctionsApplied) : 0.0
                ScaledText(String(format: "%.1f%%", rate * 100), size: 16, weight: .semibold, relativeTo: .body)
                    .foregroundColor(.kiteAmber)

                ScaledText("acceptance", size: 12, relativeTo: .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(KiteSpacing.m)
        .background(Color(.systemGray6))
        .cornerRadius(KiteRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: KiteRadius.large)
                .stroke(Color.kiteAmber.opacity(0.20), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    DashboardView()
}
