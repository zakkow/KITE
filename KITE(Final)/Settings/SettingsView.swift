import SwiftUI
import UIKit // Added for UIApplication.openSettingsURLString
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @State private var preferences = PreferencesStore.load()
    @State private var currentProfileType: ProfileType = .general
    @State private var manualOverrides: [String: ManualCorrectionRule] = [:]
    @State private var editingRule: ManualCorrectionRule? = nil
    @State private var showProfileSheet = false
    @State private var showResetConfirmation = false
    @State private var showRetrainConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var showClearedAlert = false
    @State private var showAddCorrectionSheet = false
    @State private var showAddWordCorrectionSheet = false
    @State private var editingWordShortcut: StringWrapper? = nil
    
    struct StringWrapper: Identifiable {
        let id: String
        var value: String { id }
    }
    
    @State private var showExportSheet = false
    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var exportDocument: KiteProfileDocument?
    @State private var importResultMessage: String?
    @State private var showImportResultAlert = false
    @State private var protectedWords: [String] = SharedStore.protectedWords
    @State private var customWords: [String] = SharedStore.customWhitelistedWords
    @State private var showAddCustomWordAlert = false
    @State private var newCustomWord = ""
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile").foregroundColor(.kiteAmberDark)) {
                    Button {
                        showProfileSheet = true
                    } label: {
                        HStack {
                            Text("Profile Type")
                            Spacer()
                            Text(profileLabel(currentProfileType)).foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    NavigationLink("View Profile Summary") { ProfileSummaryView() }
                    NavigationLink("View Motor Profile (Silent Corrections)") { MotorProfileView() }

                    Button("Retrain Motor Profile") { showRetrainConfirmation = true }
                        .foregroundColor(.kiteAmber)
                    Button("Reset to Defaults") { showResetConfirmation = true }
                        .foregroundColor(.red)
                }

                Section(header: Text("Corrections").foregroundColor(.kiteAmberDark)) {
                    if manualOverrides.isEmpty {
                        ScaledText("No corrections yet.", size: 14, relativeTo: .subheadline, color: .secondary)
                    } else {
                        ForEach(manualOverrides.values.sorted(by: { $0.fromKey < $1.fromKey })) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(rule.fromKey) → \(rule.toKey)").foregroundColor(.primary)
                                        Text("\(rule.strictness.label) · \(rule.context.label)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { removeOverride(rule.fromKey) } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete correction rule \(rule.fromKey) to \(rule.toKey)")
                                }
                            }
                            .accessibilityLabel("Edit correction: \(rule.fromKey) maps to \(rule.toKey), \(rule.strictness.label), \(rule.context.label)")
                        }
                    }
                    Button("Add Correction") { showAddCorrectionSheet = true }
                        .foregroundColor(.kiteAmber)
                }

                Section(header: Text("Custom Word Typo Corrections").foregroundColor(.kiteAmberDark)) {
                    if preferences.customWordOverrides.isEmpty {
                        ScaledText("No custom word corrections yet.", size: 14, relativeTo: .subheadline, color: .secondary)
                    } else {
                        ForEach(preferences.customWordOverrides.values.sorted(by: { $0.typedWord < $1.typedWord })) { rule in
                            Button {
                                editingWordShortcut = StringWrapper(id: rule.typedWord)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("\(rule.typedWord) → \(rule.correctedWord)").foregroundColor(.primary)
                                            if rule.isAutoLearned {
                                                Text("Auto-Learned")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.2))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("\(rule.strictness.label) · \(rule.context.label)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        preferences.customWordOverrides.removeValue(forKey: rule.typedWord)
                                        PreferencesStore.save(preferences)
                                    } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Button("Add Word Correction") { showAddWordCorrectionSheet = true }
                        .foregroundColor(.kiteAmber)
                }

                Section(header: Text("Learned Words & Vocabulary").foregroundColor(.kiteAmberDark)) {
                    if protectedWords.isEmpty && customWords.isEmpty {
                        ScaledText("No blacklisted or whitelisted words yet.", size: 14, relativeTo: .subheadline, color: .secondary)
                    } else {
                        if !protectedWords.isEmpty {
                            Text("Blacklisted Words (Top 3 Recent)")
                                .font(.caption).foregroundColor(.red)
                            ForEach(Array(protectedWords.suffix(3).reversed()), id: \.self) { word in
                                HStack {
                                    Text("\"\(word)\"").foregroundColor(.primary)
                                    Spacer()
                                    Button(role: .destructive) { removeProtectedWord(word) } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if !customWords.isEmpty {
                            Text("Whitelisted Words (Top 3 Recent)")
                                .font(.caption).foregroundColor(.kiteAmber)
                            ForEach(Array(customWords.suffix(3).reversed()), id: \.self) { word in
                                HStack {
                                    Text("\"\(word)\"").foregroundColor(.primary)
                                    Spacer()
                                    Button(role: .destructive) { removeCustomWord(word) } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    NavigationLink {
                        LearnedVocabularyManagerView()
                    } label: {
                        HStack {
                            Text("View & Manage Full Vocabulary")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(protectedWords.count + customWords.count) items")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    Button("Add Custom Word") { showAddCustomWordAlert = true }
                        .foregroundColor(.kiteAmber)
                }

                Section(header: Text("Keyboard Feel").foregroundColor(.kiteAmberDark)) {
                    Picker("Key Size", selection: $preferences.keySize) {
                        ForEach(KeySize.allCases, id: \.self) { size in
                            Text(size.label).tag(size)
                        }
                    }.pickerStyle(.segmented)
                    Picker("Keyboard Height", selection: $preferences.keyboardHeight) {
                        ForEach(KeyboardHeight.allCases, id: \.self) { height in
                            Text(height.label).tag(height)
                        }
                    }.pickerStyle(.segmented)
                    Picker("Backspace Speed", selection: $preferences.backspaceSpeed) {
                        ForEach(BackspaceSpeed.allCases, id: \.self) { speed in
                            Text(speed.label).tag(speed)
                        }
                    }.pickerStyle(.segmented)
                    HStack {
                        Toggle("Show Learning Progress on Keys", isOn: $preferences.keyConfidenceTintEnabled)
                        InfoButton(text: "Keys slowly turn amber as KITE learns your pattern for them.")
                    }
                }

                Section(header: Text("Corrections & Feedback").foregroundColor(.kiteAmberDark)) {
                    Picker("Correction Sensitivity", selection: $preferences.correctionSensitivity) {
                        ForEach(Sensitivity.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack {
                        Toggle("Fatigue Adaptation", isOn: $preferences.fatigueAdaptation)
                        InfoButton(text: "Adjusts the keyboard if typing accuracy drops over time.")
                    }
                    HStack {
                        Toggle("Spelling Suggestions", isOn: $preferences.spellingSuggestionsEnabled)
                        InfoButton(text: "Suggests fixes for misspelled words.")
                    }
                    HStack {
                        Toggle("Milestone Haptics", isOn: $preferences.milestoneHapticsEnabled)
                        InfoButton(text: "A quick vibration when KITE learns a new pattern.")
                    }
                    HStack {
                        Toggle("Audio Correction Cue", isOn: $preferences.audioCorrectionCueEnabled)
                        InfoButton(text: "A soft sound when a correction happens.")
                    }
                    HStack {
                        Toggle("Correction Haptics", isOn: $preferences.correctionHapticsEnabled)
                        InfoButton(text: "A different vibration for each correction type.")
                    }
                }

                Section(header: Text("Experimental Features").foregroundColor(.kiteAmberDark)) {
                    HStack {
                        Toggle("Adaptive Key Layout", isOn: $preferences.adaptiveLayoutEnabled)
                        InfoButton(text: "Slightly moves keys toward where you actually tap.")
                    }
                    Toggle("Hand-Split Modeling", isOn: $preferences.handSplitModelingEnabled)
                    if preferences.handSplitModelingEnabled {
                        Picker("Dominant Hand", selection: $preferences.dominantHand) {
                            ForEach(DominantHand.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                }

                Section(header: Text("Accessibility").foregroundColor(.kiteAmberDark)) {
                    HStack {
                        Toggle("Comfort Mode", isOn: $preferences.comfortModeEnabled)
                        InfoButton(text: "Replaces the settings list with large, easy-to-tap cards. Designed for users with motor disabilities.")
                    }
                }

                Section(header: Text("Appearance").foregroundColor(.kiteAmberDark)) {
                    Picker("Appearance", selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
                    }.pickerStyle(.segmented)
                }

                Section(header: Text("Keyboard Setup").foregroundColor(.kiteAmberDark)) {
                    HStack {
                        Button("Enable KITE Keyboard") {
                            openKeyboardSettings()
                        }
                        .foregroundColor(.kiteAmber)
                        InfoButton(text: "Opens Keyboard Settings so you can turn on KITE as a keyboard.")
                    }
                    HStack {
                        Button("Try KITE!") {
                            if let url = URL(string: "https://www.google.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.kiteAmber)
                        InfoButton(text: "Opens Safari so you can test the KITE keyboard.")
                    }
                }

                Section(header: Text("Demo Mode").foregroundColor(.kiteAmberDark)) {
                    HStack {
                        Toggle("Demo Mode", isOn: $preferences.isDemoMode)
                        InfoButton(text: "Shows exaggerated corrections for demos.")
                    }
                }

                Section {
                    NavigationLink("Help") { HelpView() }
                }

                Section(header: Text("Privacy").foregroundColor(.kiteAmberDark)) {
                    NavigationLink("Privacy Details") { AccessibilityNutritionLabelView() }
                    Button("Export Report") { showExportSheet = true }
                    HStack {
                        Toggle("Help Improve KITE (Preview)", isOn: $preferences.differentialPrivacyPreviewEnabled)
                        InfoButton(text: "Shows what anonymized data could look like — nothing is sent yet.")
                    }
                    if preferences.differentialPrivacyPreviewEnabled, let profile = currentMotorProfile(), !profile.keyOffsets.isEmpty {
                        let realAvg = profile.keyOffsets.values.map { $0.confidence }.reduce(0, +) / Double(profile.keyOffsets.count)
                        let noised = DifferentialPrivacyPreview.addLaplaceNoise(to: realAvg)
                        Text("Example: \(Int(noised * 100))% (real: \(Int(realAvg * 100))%, noise added for privacy)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Data").foregroundColor(.kiteAmberDark)) {
                    Button("Export Profile to Files") {
                        guard let profile = currentMotorProfile() else { return }
                        var bundle = KiteExportBundle(profile: profile, preferences: preferences)
                        bundle.sessionHistory = SessionHistoryStore.load()
                        if let baselineData = SharedStore.defaults?.data(forKey: SharedStore.Keys.baselineProfileSnapshot),
                           let snapshot = try? JSONDecoder().decode(ProfileSnapshot.self, from: baselineData) {
                            bundle.baselineSnapshot = snapshot
                        }
                        bundle.explainabilityLog = ExplainabilityLogStore.load()
                        bundle.inputStyle = SharedStore.defaults?.string(forKey: SharedStore.Keys.inputStyle)
                        if let data = try? JSONEncoder().encode(bundle) {
                            exportDocument = KiteProfileDocument(data: data)
                            showExportPicker = true
                        }
                    }
                    Button("Import Profile from Files") { showImportPicker = true }
                    HStack {
                        Button("Clear All Data") { showClearAllConfirmation = true }
                            .foregroundColor(.red)
                        InfoButton(text: "Deletes everything KITE has learned. Can't be undone.")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { refreshFromStorage() }
            .onChange(of: preferences) { _, newValue in PreferencesStore.save(newValue) }
            .sheet(isPresented: $showProfileSheet) {
                ProfilePickerSheet { chosen in
                    changeProfileType(chosen)
                    currentProfileType = chosen
                    showProfileSheet = false
                }
            }
            .sheet(isPresented: $showAddCorrectionSheet) {
                ManualCorrectionSheet { rule in saveOverride(rule) }
            }
            .sheet(item: $editingRule) { rule in
                ManualCorrectionSheet(existingRule: rule, onSave: saveOverride)
            }
            .sheet(isPresented: $showAddWordCorrectionSheet) {
                WordCorrectionSheet { rule in
                    preferences.customWordOverrides[rule.typedWord] = rule
                    PreferencesStore.save(preferences)
                }
            }
            .sheet(item: $editingWordShortcut) { wrapper in
                WordCorrectionSheet(existingRule: preferences.customWordOverrides[wrapper.id]) { rule in
                    if rule.typedWord != wrapper.id {
                        preferences.customWordOverrides.removeValue(forKey: wrapper.id)
                    }
                    preferences.customWordOverrides[rule.typedWord] = rule
                    PreferencesStore.save(preferences)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                let sessions = SessionHistoryStore.load()
                if let profile = currentMotorProfile() {
                    ShareSheetWrapper(text: ProfileReportGenerator.generateReport(profile: profile, sessions: sessions))
                }
            }
            .fileExporter(isPresented: $showExportPicker, document: exportDocument, contentType: .json, defaultFilename: "KITE-Profile") { _ in }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url),
                       let bundle = try? JSONDecoder().decode(KiteExportBundle.self, from: data) {
                        writeProfile(bundle.profile)
                        preferences = bundle.preferences
                        PreferencesStore.save(bundle.preferences)

                        if let history = bundle.sessionHistory,
                           let historyData = try? JSONEncoder().encode(history) {
                            SharedStore.defaults?.set(historyData, forKey: SharedStore.Keys.sessionHistory)
                        }
                        if let snapshot = bundle.baselineSnapshot,
                           let snapshotData = try? JSONEncoder().encode(snapshot) {
                            SharedStore.defaults?.set(snapshotData, forKey: SharedStore.Keys.baselineProfileSnapshot)
                        }
                        if let log = bundle.explainabilityLog,
                           let logData = try? JSONEncoder().encode(log) {
                            SharedStore.defaults?.set(logData, forKey: SharedStore.Keys.explainabilityLog)
                        }
                        if let inputStyle = bundle.inputStyle {
                            SharedStore.defaults?.set(inputStyle, forKey: SharedStore.Keys.inputStyle)
                        }
                        importResultMessage = "Profile imported successfully."
                        WidgetCenter.shared.reloadTimelines(ofKind: "KITEWidget")
                    } else {
                        importResultMessage = "Could not read that file — make sure it's a KITE profile export."
                    }
                case .failure:
                    importResultMessage = "Import cancelled or failed."
                }
                showImportResultAlert = true
            }
            .alert("Import Profile", isPresented: $showImportResultAlert) {
                Button("OK") {}
            } message: { Text(importResultMessage ?? "") }
            .alert("Add Custom Word", isPresented: $showAddCustomWordAlert) {
                TextField("Word, name, or acronym", text: $newCustomWord)
                Button("Add") { addCustomWord() }
                Button("Cancel", role: .cancel) { newCustomWord = "" }
            } message: {
                Text("Enter a word, custom name, or acronym you want KITE to always recognize.")
            }
            .confirmationDialog(
                "Retrain motor profile? This clears everything KITE has learned and starts fresh with your current profile type.",
                isPresented: $showRetrainConfirmation, titleVisibility: .visible
            ) {
                Button("Retrain", role: .destructive) { saveNewProfile(currentProfileType) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Reset all settings to defaults?",
                isPresented: $showResetConfirmation, titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { preferences = .default; PreferencesStore.save(preferences) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Clear all KITE data? This deletes everything KITE has learned and all your settings. This cannot be undone.",
                isPresented: $showClearAllConfirmation, titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Data Cleared", isPresented: $showClearedAlert) {
                Button("OK") {}
            } message: {
                Text("Please close and reopen KITE to start fresh.")
            }
            .onAppear {
                refreshFromStorage()
            }
        }
    }

    private func profileLabel(_ type: ProfileType) -> String {
        switch type {
        case .tremor: return "Tremor"
        case .spasticity: return "Spasticity / CP"
        case .general: return "General"
        case .notSure: return "Not Sure Yet"
        }
    }

    /// Explicit @State refresh — fixes a real bug where the profile label
    /// previously read UserDefaults directly inside a computed property,
    /// which SwiftUI has no way of observing. It WAS saving instantly; only
    /// the displayed label was stale until something unrelated forced a
    /// re-render.
    private func refreshFromStorage() {
        if let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.motorProfile),
           let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            currentProfileType = profile.profileType
            manualOverrides = profile.manualOverrides
        }
        protectedWords = SharedStore.protectedWords
        customWords = SharedStore.customWhitelistedWords
    }

    private func saveNewProfile(_ type: ProfileType) {
        let fresh = MotorProfile.fresh(profileType: type)
        guard let data = try? JSONEncoder().encode(fresh),
              (try? JSONDecoder().decode(MotorProfile.self, from: data)) != nil else { return }
        SharedStore.defaults?.set(data, forKey: SharedStore.Keys.motorProfile)
        manualOverrides = [:] // fresh profile has none yet
    }

    private func changeProfileType(_ type: ProfileType) {
        guard var profile = currentMotorProfile() else {
            saveNewProfile(type)
            return
        }
        profile.profileType = type
        writeProfile(profile)
        manualOverrides = profile.manualOverrides
    }

    private func saveOverride(_ rule: ManualCorrectionRule) {
        var profile = currentMotorProfile() ?? MotorProfile.fresh(profileType: .general)
        let key = rule.fromKey.uppercased()
        profile.manualOverrides[key] = ManualCorrectionRule(fromKey: key, toKey: rule.toKey.uppercased(), strictness: rule.strictness, context: rule.context)
        writeProfile(profile)
        manualOverrides = profile.manualOverrides
    }

    private func removeOverride(_ key: String) {
        guard var profile = currentMotorProfile() else { return }
        profile.manualOverrides.removeValue(forKey: key.uppercased())
        profile.manualOverrides.removeValue(forKey: key)
        writeProfile(profile)
        manualOverrides = profile.manualOverrides
    }

    private func currentMotorProfile() -> MotorProfile? {
        guard let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
              let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) else { return nil }
        return profile
    }

    private func writeProfile(_ profile: MotorProfile) {
        guard let data = try? JSONEncoder().encode(profile),
              (try? JSONDecoder().decode(MotorProfile.self, from: data)) != nil else { return }
        SharedStore.setSharedData(data, forKey: SharedStore.Keys.motorProfile)
    }

    private func clearAllData() {
        let keys = [
            SharedStore.Keys.motorProfile, SharedStore.Keys.sessionHistory,
            SharedStore.Keys.currentSession, SharedStore.Keys.baselineProfileSnapshot,
            SharedStore.Keys.userPreferences, SharedStore.Keys.inputStyle,
            SharedStore.Keys.explainabilityLog, SharedStore.Keys.isDemoMode
        ]
        for key in keys { SharedStore.defaults?.removeObject(forKey: key) }
        UserDefaults.standard.set(false, forKey: "onboardingComplete")
        showClearedAlert = true
    }

    private func removeProtectedWord(_ word: String) {
        var current = SharedStore.protectedWords
        current.removeAll { $0 == word }
        SharedStore.protectedWords = current
        protectedWords = current
    }

    private func removeCustomWord(_ word: String) {
        var current = SharedStore.customWhitelistedWords
        current.removeAll { $0 == word }
        SharedStore.customWhitelistedWords = current
        customWords = current
    }

    private func addCustomWord() {
        let trimmed = newCustomWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        var current = SharedStore.customWhitelistedWords
        if !current.contains(trimmed) {
            current.append(trimmed)
            SharedStore.customWhitelistedWords = current
            customWords = current
        }
        newCustomWord = ""
    }

    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct ProfilePickerSheet: View {
    var onSelect: (ProfileType) -> Void
    @State private var selected: ProfileType = .general

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProfileCard(profile: .general, title: "General", description: "For most users with typical motor patterns", isSelected: selected == .general) { selected = .general }
                ProfileCard(profile: .tremor, title: "Tremor", description: "For users with hand tremor or oscillation", isSelected: selected == .tremor) { selected = .tremor }
                ProfileCard(profile: .spasticity, title: "Spasticity / CP", description: "My hand pulls in one direction", isSelected: selected == .spasticity) { selected = .spasticity }
                ProfileCard(profile: .notSure, title: "Not Sure Yet", description: "Start with defaults and adapt", isSelected: selected == .notSure) { selected = .notSure }
                Spacer()
                Button("Save") { onSelect(selected) }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.kiteAmber)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
            }
            .padding()
            .navigationTitle("Change Profile")
        }
    }
}

#Preview { SettingsView() }
