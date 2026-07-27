import Foundation
import UIKit

/// Central place for the shared App Group container and its keys.
/// Both targets read/write through this — never construct
/// UserDefaults(suiteName:) anywhere else in the codebase.
struct SharedStore {
    static let sharedTextChecker = UITextChecker()
    static let groupID = "group.com.kite.shared"

    static var sharedFolderURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID) ?? UserDefaults.standard
    }

    static func setSharedData(_ data: Data, forKey key: String) {
        defaults?.set(data, forKey: key)
        DispatchQueue.global(qos: .utility).async {
            if let folder = sharedFolderURL {
                let fileURL = folder.appendingPathComponent("\(key).json")
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    static func getSharedData(forKey key: String) -> Data? {
        if let folder = sharedFolderURL {
            let fileURL = folder.appendingPathComponent("\(key).json")
            if let fileData = try? Data(contentsOf: fileURL), !fileData.isEmpty {
                return fileData
            }
        }
        return defaults?.data(forKey: key)
    }

    static func removeSharedData(forKey key: String) {
        defaults?.removeObject(forKey: key)
        DispatchQueue.global(qos: .utility).async {
            if let folder = sharedFolderURL {
                let fileURL = folder.appendingPathComponent("\(key).json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    enum Keys {
        static let motorProfile = "motorProfile"
        static let userPreferences = "userPreferences"
        static let sessionHistory = "sessionHistory"
        static let currentSession = "currentSession"
        static let isDemoMode = "isDemoMode"
        static let onboardingComplete = "onboardingComplete" // standard UserDefaults, not shared
        static let inputStyle = "inputStyle"
        static let baselineProfileSnapshot = "baselineProfileSnapshot"
        static let explainabilityLog = "explainabilityLog"
        static let protectedWords = "protectedWords"
        static let customWhitelistedWords = "customWhitelistedWords"
    }

    static var protectedWords: [String] {
        get { defaults?.stringArray(forKey: Keys.protectedWords) ?? [] }
        set { defaults?.set(newValue, forKey: Keys.protectedWords) }
    }

    static var customWhitelistedWords: [String] {
        get { defaults?.stringArray(forKey: Keys.customWhitelistedWords) ?? [] }
        set { defaults?.set(newValue, forKey: Keys.customWhitelistedWords) }
    }

    static var blacklistedWords: [String] {
        get { protectedWords }
        set { protectedWords = newValue }
    }

    static var whitelistedWords: [String] {
        get { customWhitelistedWords }
        set { customWhitelistedWords = newValue }
    }

    static func sanitizeWhitelists() {
        let textChecker = sharedTextChecker
        func isRealWordOrPrefix(_ word: String) -> Bool {
            let lower = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lower.isEmpty else { return false }
            let range = NSRange(location: 0, length: lower.utf16.count)
            let misspelled = textChecker.rangeOfMisspelledWord(in: lower, range: range, startingAt: 0, wrap: false, language: "en_US")
            if misspelled.location == NSNotFound { return true }
            let completions = textChecker.completions(forPartialWordRange: range, in: lower, language: "en_US")
            return completions?.isEmpty == false
        }
        
        let cleanedWhitelist = customWhitelistedWords.filter { isRealWordOrPrefix($0) }
        if cleanedWhitelist != customWhitelistedWords {
            customWhitelistedWords = cleanedWhitelist
        }
        
        let cleanedProtected = protectedWords.filter { isRealWordOrPrefix($0) }
        if cleanedProtected != protectedWords {
            protectedWords = cleanedProtected
        }
    }
}
