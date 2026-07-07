import Foundation

/// Central place for the shared App Group container and its keys.
/// Both targets read/write through this — never construct
/// UserDefaults(suiteName:) anywhere else in the codebase.
struct SharedStore {
    static let groupID = "group.com.kite.shared"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    enum Keys {
        static let motorProfile = "motorProfile"
        static let userPreferences = "userPreferences"
        static let sessionHistory = "sessionHistory"
        static let currentSession = "currentSession"
        static let isDemoMode = "isDemoMode"
        static let onboardingComplete = "onboardingComplete" // standard UserDefaults, not shared
    }
}
