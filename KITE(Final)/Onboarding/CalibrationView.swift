import SwiftUI
import Combine

struct CalibrationView: View {
    let profileType: ProfileType
    var onComplete: () -> Void

    @State private var currentSentenceIndex = 0
    @State private var typedText = ""
    @State private var correctionEngine: CorrectionEngine
    @State private var didCompleteNormally = false
    @Environment(\.scenePhase) private var scenePhase

    let calibrationSentences = [
        "The quick brown fox jumps over the lazy dog.",
        "Pack my box with five dozen liquor jugs.",
        "How vexingly quick daft zebras jump.",
        "Sphinx of black quartz, judge my vow.",
        "Bright vixens jump dozy fowl quack."
    ]

    init(profileType: ProfileType, onComplete: @escaping () -> Void) {
        self.profileType = profileType
        self.onComplete = onComplete
        _correctionEngine = State(initialValue: CorrectionEngine(
            profile: MotorProfile.fresh(profileType: profileType),
            preferences: PreferencesStore.load()
        ))
    }

    var currentSentence: String { calibrationSentences[currentSentenceIndex] }
    var progress: Double { Double(currentSentenceIndex) / Double(calibrationSentences.count) }

    private var hasMismatch: Bool {
        let typedLower = Array(typedText.lowercased())
        let targetLower = Array(currentSentence.lowercased())
        for i in 0..<min(typedLower.count, targetLower.count) where typedLower[i] != targetLower[i] {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: KiteSpacing.l) {
            VStack(spacing: KiteSpacing.s) {
                HStack {
                    ScaledText("Calibration", size: 18, weight: .semibold, relativeTo: .title3)
                    Spacer()
                    ScaledText("\(currentSentenceIndex + 1)/\(calibrationSentences.count)", size: 14, relativeTo: .subheadline, color: .secondary)
                }
                ProgressView(value: progress).tint(.kiteAmber)
            }
            .padding(.horizontal, KiteSpacing.xl)

            Spacer()
            SentenceDisplay(targetSentence: currentSentence, typedText: typedText)
                .padding(.horizontal, KiteSpacing.xl)

            if hasMismatch {
                ScaledText("Some letters don't match yet — use Clear to start this sentence over, or Skip if you'd rather move on.", size: 13, relativeTo: .footnote, color: .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KiteSpacing.xl)
            }

            HStack(spacing: KiteSpacing.m) {
                Button(action: { typedText = "" }) {
                    ScaledText("Clear", size: 15, weight: .medium, relativeTo: .subheadline, color: .secondary)
                }

                Spacer()

                Button(action: { advanceOrFinish() }) {
                    ScaledText("Skip this sentence", size: 15, weight: .medium, relativeTo: .subheadline, color: .kiteAmber)
                }
            }
            .padding(.horizontal, KiteSpacing.xl)

            Spacer()
            CalibrationKeyboardView(typedText: $typedText, correctionEngine: correctionEngine)
                .frame(height: 216 + KeyboardCoreView.topStripHeight)
        }
        .padding()
        .onChange(of: typedText) { _, newValue in
            if newValue.lowercased() == currentSentence.lowercased() {
                advanceOrFinish()
            }
        }
        .onDisappear {
            guard !didCompleteNormally else { return }
            correctionEngine.saveProfile()
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !didCompleteNormally, newPhase == .background else { return }
            correctionEngine.saveProfile()
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
        }
    }

    private func advanceOrFinish() {
        if currentSentenceIndex < calibrationSentences.count - 1 {
            currentSentenceIndex += 1
            typedText = ""
        } else {
            completeCalibration()
        }
    }

    private func completeCalibration() {
        didCompleteNormally = true
        correctionEngine.saveProfile()
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onComplete()
    }
}

struct SentenceDisplay: View {
    let targetSentence: String
    let typedText: String
    @ScaledMetric(relativeTo: .title2) private var fontSize: CGFloat = 24
    @State private var cursorVisible = true
    private let timer = Timer.publish(every: 0.53, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScaledText("Type this sentence:", size: 14, relativeTo: .subheadline, color: .secondary)
            
            buildHighlightedText()
                .font(.system(size: fontSize, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Active Typed Box with Multiline-Safe Blinking Cursor
            VStack(alignment: .leading, spacing: 0) {
                (Text(typedText)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                + Text("│")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(cursorVisible ? .kiteAmber : .clear)
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(KiteRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: KiteRadius.medium)
                    .stroke(Color.kiteAmber.opacity(0.40), lineWidth: 1.5)
            )
            .onReceive(timer) { _ in
                cursorVisible.toggle()
            }
        }
    }

    private func buildHighlightedText() -> Text {
        let typedLower = Array(typedText.lowercased())
        let targetLower = Array(targetSentence.lowercased())

        var attributed = AttributedString()
        for (index, character) in targetSentence.enumerated() {
            if index == typedLower.count && cursorVisible {
                var cursorRun = AttributedString("│")
                cursorRun.foregroundColor = .kiteAmber
                cursorRun.font = .system(size: fontSize, weight: .bold)
                attributed.append(cursorRun)
            }

            var run = AttributedString(String(character))
            if index < typedLower.count {
                run.foregroundColor = (typedLower[index] == targetLower[index]) ? .kiteAmber : .red
            } else {
                run.foregroundColor = .secondary.opacity(0.6)
            }
            attributed.append(run)
        }

        if typedLower.count >= targetSentence.count && cursorVisible {
            var cursorRun = AttributedString("│")
            cursorRun.foregroundColor = .kiteAmber
            cursorRun.font = .system(size: fontSize, weight: .bold)
            attributed.append(cursorRun)
        }

        return Text(attributed)
    }
}

#Preview { CalibrationView(profileType: .general, onComplete: {}) }
