import SwiftUI

// MARK: - ComfortCardView (pure layout — no button, no gesture)

/// The visual body of a Comfort Mode card. Intentionally NOT a Button so it
/// can be placed safely inside a NavigationLink label without the nested-
/// button tap-conflict that caused the original navigation cards to silently
/// swallow taps and do nothing.
struct ComfortCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.20), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - ComfortActionCard (action-only cards — wraps ComfortCardView in a Button)

/// For cards whose tap fires a direct action (not a navigation push).
/// Uses ComfortCardView for the visual, wraps it in Button for the gesture.
struct ComfortActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ComfortCardView(icon: icon, title: title, subtitle: subtitle, color: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

// MARK: - ComfortModeSettingsView

/// Large-card "macro-board" settings layout designed for motor-impaired users.
/// Every interactive element is ≥72pt tall — well above Apple's 44pt minimum.
struct ComfortModeSettingsView: View {
    @State private var preferences = PreferencesStore.load()
    @State private var manualOverrides: [String: ManualCorrectionRule] = [:]
    @State private var editingRule: ManualCorrectionRule? = nil
    @State private var showAddCustomWordAlert = false
    @State private var newCustomWord = ""
    @State private var showRetrainConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var showClearedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerBanner
                    cardGrid
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .onAppear { loadOverrides() }
            .onChange(of: preferences) { _, newValue in PreferencesStore.save(newValue) }
            .sheet(item: $editingRule) { rule in
                ManualCorrectionSheet(existingRule: rule) { updated in saveOverride(updated) }
            }
            .alert("Add Custom Word", isPresented: $showAddCustomWordAlert) {
                TextField("Word, name, or acronym", text: $newCustomWord)
                Button("Add") { addCustomWord() }
                Button("Cancel", role: .cancel) { newCustomWord = "" }
            } message: {
                Text("Enter a word, name, or acronym you want KITE to always recognise.")
            }
            .confirmationDialog(
                "Retrain motor profile? This clears everything KITE has learned.",
                isPresented: $showRetrainConfirmation, titleVisibility: .visible
            ) {
                Button("Retrain", role: .destructive) { retrainProfile() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Clear all KITE data? This cannot be undone.",
                isPresented: $showClearAllConfirmation, titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Data Cleared", isPresented: $showClearedAlert) {
                Button("OK") {}
            } message: { Text("Please close and reopen KITE to start fresh.") }
        }
    }

    // MARK: Header

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 28))
                .foregroundColor(.kiteAmber)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Comfort Mode")
                    .font(.system(size: 20, weight: .bold))
                Text("Large tap targets for easier navigation")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.kiteAmber.opacity(0.10))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kiteAmber.opacity(0.25), lineWidth: 1))
        .padding(.top, 12)
    }

    // MARK: Card Grid

    @ViewBuilder
    private var cardGrid: some View {

        // ── Enable Keyboard (action) ──────────────────────────────────────
        ComfortActionCard(
            icon: "keyboard.fill",
            title: "Enable KITE Keyboard",
            subtitle: "Go to iOS Settings to turn KITE on",
            color: .kiteAmber
        ) {
            openKeyboardSettings()
        }
        .accessibilityIdentifier("comfortCard_enableKeyboard")

        // ── Profile (navigation) ──────────────────────────────────────────
        NavigationLink(destination: SettingsView()) {
            ComfortCardView(
                icon: "person.fill",
                title: "Profile & Motor Settings",
                subtitle: "Change your motor profile, retrain, or reset",
                color: .kiteAmber,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile and Motor Settings")
        .accessibilityHint("Change your motor profile, retrain, or reset")
        .accessibilityIdentifier("comfortCard_profile")

        // ── Keyboard Feel (navigation) ────────────────────────────────────
        NavigationLink(destination: ComfortKeyboardFeelView(preferences: $preferences)) {
            ComfortCardView(
                icon: "slider.horizontal.3",
                title: "Keyboard Feel",
                subtitle: "Key size, height, backspace speed",
                color: .blue,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keyboard Feel")
        .accessibilityHint("Key size, height, backspace speed")
        .accessibilityIdentifier("comfortCard_keyboardFeel")

        // ── Corrections (navigation) ──────────────────────────────────────
        NavigationLink(destination: SettingsView()) {
            ComfortCardView(
                icon: "wand.and.stars",
                title: "Corrections",
                subtitle: "\(manualOverrides.count) manual rule\(manualOverrides.count == 1 ? "" : "s") — tap to manage",
                color: .kiteAmber,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Corrections, \(manualOverrides.count) rules")
        .accessibilityHint("Tap to manage manual correction rules")
        .accessibilityIdentifier("comfortCard_corrections")

        // ── Vocabulary (navigation) ───────────────────────────────────────
        NavigationLink(destination: LearnedVocabularyManagerView()) {
            ComfortCardView(
                icon: "text.book.closed.fill",
                title: "Learned Vocabulary",
                subtitle: "Blacklisted and whitelisted words",
                color: .green,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learned Vocabulary")
        .accessibilityHint("Blacklisted and whitelisted words")
        .accessibilityIdentifier("comfortCard_vocabulary")

        // ── Add Custom Word (action) ──────────────────────────────────────
        ComfortActionCard(
            icon: "plus.circle.fill",
            title: "Add Custom Word",
            subtitle: "Teach KITE a word it should always recognise",
            color: .green
        ) {
            showAddCustomWordAlert = true
        }
        .accessibilityIdentifier("comfortCard_addWord")

        // ── Help (navigation) ─────────────────────────────────────────────
        NavigationLink(destination: HelpView()) {
            ComfortCardView(
                icon: "questionmark.circle.fill",
                title: "Help",
                subtitle: "How KITE works and what to expect",
                color: .purple,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Help")
        .accessibilityHint("How KITE works and what to expect")
        .accessibilityIdentifier("comfortCard_help")

        // ── Divider ───────────────────────────────────────────────────────
        Divider().padding(.vertical, 4)

        // ── Switch to Standard Mode (action) ─────────────────────────────
        ComfortActionCard(
            icon: "list.bullet.rectangle",
            title: "Switch to Standard Mode",
            subtitle: "Show the full Settings list",
            color: .gray
        ) {
            preferences.comfortModeEnabled = false
            PreferencesStore.save(preferences)
        }
        .accessibilityIdentifier("comfortCard_standardMode")
    }

    // MARK: Helpers

    private func loadOverrides() {
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
           let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            manualOverrides = profile.manualOverrides
        }
    }

    private func saveOverride(_ rule: ManualCorrectionRule) {
        var profile = currentMotorProfile() ?? MotorProfile.fresh(profileType: .general)
        let key = rule.fromKey.uppercased()
        profile.manualOverrides[key] = ManualCorrectionRule(fromKey: key, toKey: rule.toKey.uppercased(), strictness: rule.strictness, context: rule.context)
        writeProfile(profile)
        manualOverrides = profile.manualOverrides
    }

    private func retrainProfile() {
        guard let profile = currentMotorProfile() else { return }
        let fresh = MotorProfile.fresh(profileType: profile.profileType)
        writeProfile(fresh)
        manualOverrides = [:]
    }

    private func clearAll() {
        let keys = [
            SharedStore.Keys.motorProfile, SharedStore.Keys.sessionHistory,
            SharedStore.Keys.currentSession, SharedStore.Keys.baselineProfileSnapshot,
            SharedStore.Keys.userPreferences, SharedStore.Keys.inputStyle,
            SharedStore.Keys.explainabilityLog, SharedStore.Keys.isDemoMode
        ]
        for key in keys { SharedStore.removeSharedData(forKey: key) }
        UserDefaults.standard.set(false, forKey: "onboardingComplete")
        showClearedAlert = true
    }

    private func addCustomWord() {
        let trimmed = newCustomWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        var current = SharedStore.customWhitelistedWords
        if !current.contains(trimmed) { current.append(trimmed); SharedStore.customWhitelistedWords = current }
        newCustomWord = ""
    }

    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
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
}

// MARK: - ComfortKeyboardFeelView

/// Keyboard-feel sub-settings with large segmented controls.
struct ComfortKeyboardFeelView: View {
    @Binding var preferences: UserPreferences

    var body: some View {
        Form {
            Section(header: Text("Key Size").foregroundColor(.kiteAmberDark)) {
                Picker("Key Size", selection: $preferences.keySize) {
                    ForEach(KeySize.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Keyboard Height").foregroundColor(.kiteAmberDark)) {
                Picker("Keyboard Height", selection: $preferences.keyboardHeight) {
                    ForEach(KeyboardHeight.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Backspace Speed").foregroundColor(.kiteAmberDark)) {
                Picker("Backspace Speed", selection: $preferences.backspaceSpeed) {
                    ForEach(BackspaceSpeed.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Learning Indicators").foregroundColor(.kiteAmberDark)) {
                Toggle("Show Learning Progress on Keys", isOn: $preferences.keyConfidenceTintEnabled)
                    .accessibilityHint("Keys slowly turn amber as KITE learns your pattern for them.")
            }
        }
        .navigationTitle("Keyboard Feel")
        .onChange(of: preferences) { _, newValue in PreferencesStore.save(newValue) }
    }
}

#Preview { ComfortModeSettingsView() }
