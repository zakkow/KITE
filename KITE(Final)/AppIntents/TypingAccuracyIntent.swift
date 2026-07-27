import AppIntents
import UIKit

struct TypingAccuracyIntent: AppIntent {
    static var title: LocalizedStringResource = "Typing Accuracy This Week"
    static var description = IntentDescription("Reports your KITE keyboard correction and acceptance stats for this week.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sessions = SessionHistoryStore.loadIncludingCurrent()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = sessions.filter { $0.date >= weekAgo }
        let applied = thisWeek.reduce(0) { $0 + $1.correctionsApplied }
        let accepted = thisWeek.reduce(0) { $0 + $1.correctionsAccepted }
        let rate = applied > 0 ? Int((Double(accepted) / Double(applied)) * 100) : 0
        let dialog = applied > 0
            ? "This week, KITE made \(applied) corrections with a \(rate) percent acceptance rate."
            : "No typing data recorded yet this week."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// Siri shortcut: "Open KITE settings" — navigates to the Settings tab.
struct OpenKITESettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open KITE Settings"
    static var description = IntentDescription("Opens KITE's Settings screen.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Siri shortcut: "Open my KITE vocabulary" — navigates to Learned Vocabulary.
struct OpenLearnedVocabularyIntent: AppIntent {
    static var title: LocalizedStringResource = "Open My KITE Vocabulary"
    static var description = IntentDescription("Opens KITE's Learned Vocabulary manager to view and edit whitelisted and blacklisted words.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct KITEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TypingAccuracyIntent(),
            phrases: ["How's my typing been on \(.applicationName)", "Check my \(.applicationName) accuracy"],
            shortTitle: "Typing Accuracy",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: OpenKITESettingsIntent(),
            phrases: ["Open \(.applicationName) settings", "Show \(.applicationName) settings"],
            shortTitle: "Open Settings",
            systemImageName: "slider.horizontal.3"
        )
        AppShortcut(
            intent: OpenLearnedVocabularyIntent(),
            phrases: ["Open my \(.applicationName) vocabulary", "Show my \(.applicationName) words"],
            shortTitle: "My Vocabulary",
            systemImageName: "text.book.closed.fill"
        )
    }
}
