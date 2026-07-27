//
//  KITEWidget.swift
//  KITEWidget
//
//  Created by Apple on 7/16/26.
//

import WidgetKit
import SwiftUI

struct AccuracyEntry: TimelineEntry {
    let date: Date
    let accuracyPercent: Int
    let correctionsCount: Int
}

struct AccuracyProvider: TimelineProvider {
    func placeholder(in context: Context) -> AccuracyEntry {
        AccuracyEntry(date: Date(), accuracyPercent: 0, correctionsCount: 0)
    }
    func getSnapshot(in context: Context, completion: @escaping (AccuracyEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AccuracyEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    private func currentEntry() -> AccuracyEntry {
        let sessions = SessionHistoryStore.loadIncludingCurrent()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = sessions.filter { $0.date >= weekAgo }
        let applied = thisWeek.reduce(0) { $0 + $1.correctionsApplied }
        let accepted = thisWeek.reduce(0) { $0 + $1.correctionsAccepted }
        let rate = applied > 0 ? Int((Double(accepted) / Double(applied)) * 100) : 0
        return AccuracyEntry(date: Date(), accuracyPercent: rate, correctionsCount: applied)
    }
}

struct KITEWidgetView: View {
    let entry: AccuracyEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("KITE").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            Text("\(entry.accuracyPercent)%").font(.system(size: 28, weight: .bold)).foregroundColor(.orange)
            Text("acceptance this week").font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding()
    }
}

struct KITEWidget: Widget {
    let kind: String = "KITEWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AccuracyProvider()) { entry in
            KITEWidgetView(entry: entry)
        }
        .configurationDisplayName("Typing Accuracy")
        .description("See your weekly KITE correction acceptance rate.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    KITEWidget()
} timeline: {
    AccuracyEntry(date: .now, accuracyPercent: 85, correctionsCount: 42)
}
