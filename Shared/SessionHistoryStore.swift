import Foundation

enum SessionHistoryStore {
    static func load() -> [SessionData] {
        guard let data = SharedStore.getSharedData(forKey: SharedStore.Keys.sessionHistory),
              let sessions = try? JSONDecoder().decode([SessionData].self, from: data) else {
            return []
        }
        return sessions
    }

    /// Committed history plus a live read of the in-progress session (if
    /// any), without writing it into permanent history. Use this for
    /// anything the user might check shortly after typing (Dashboard,
    /// Widget, Siri) so recent activity isn't invisible just because the
    /// current session hasn't gone stale yet.
    static func loadIncludingCurrent() -> [SessionData] {
        var sessions = load()
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.currentSession),
           let current = try? JSONDecoder().decode(SessionData.self, from: data) {
            sessions.append(current)
        }
        return sessions
    }

    static func append(_ session: SessionData) {
        var sessions = load()
        // Deduplicate: don't append if a session with this ID already exists
        if sessions.contains(where: { $0.id == session.id }) {
            return
        }
        sessions.append(session)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        sessions = sessions.filter { $0.date > thirtyDaysAgo }
        if let data = try? JSONEncoder().encode(sessions) {
            SharedStore.setSharedData(data, forKey: SharedStore.Keys.sessionHistory)
        }
    }

    static func clear() {
        SharedStore.removeSharedData(forKey: SharedStore.Keys.sessionHistory)
    }
}
