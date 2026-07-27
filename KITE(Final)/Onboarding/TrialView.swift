import SwiftUI

struct TrialView: View {
    var onContinue: () -> Void
    @State private var keyOffsets: [String: KeyOffset] = [:]
    @State private var keyboardDetected = false
    @State private var pollTimer: Timer?

    private let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"]
    ]

    var body: some View {
        VStack(spacing: KiteSpacing.m) {
            Spacer()
            Image("KITELogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.kiteAmber.opacity(0.25), radius: 8, x: 0, y: 3)
            ScaledText("Here's What KITE Learned", size: 24, weight: .bold, relativeTo: .title)
            ScaledText("A starting point from your calibration — it'll keep refining as you type.", size: 14, relativeTo: .subheadline, color: .secondary)
                .multilineTextAlignment(.center).padding(.horizontal, KiteSpacing.xl)

            miniHeatmap
                .frame(height: 130)
                .padding(.horizontal, KiteSpacing.xl)

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: 1, text: "Tap 'Open Keyboard Settings' below to jump directly into KITE's page in iOS Settings")
                stepRow(number: 2, text: "Tap Keyboards → turn ON KITE & Allow Full Access")
                stepRow(number: 3, text: "Return here or open any app, tap a text field, and select KITE from the globe icon")
            }
            .padding(.horizontal, KiteSpacing.l)

            Button(action: {
                openKeyboardSettings()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                    ScaledText("Open Keyboard Settings", size: 15, weight: .semibold, relativeTo: .subheadline, color: .kiteAmber)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.kiteAmber.opacity(0.12))
                .cornerRadius(KiteRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: KiteRadius.medium)
                        .stroke(Color.kiteAmber.opacity(0.40), lineWidth: 1)
                )
            }

            if keyboardDetected {
                Label {
                    ScaledText("KITE keyboard detected", size: 14, weight: .medium, relativeTo: .subheadline, color: .kiteSuccess)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.kiteSuccess)
                }
            }

            Spacer()

            Button(action: onContinue) {
                ScaledText("Continue to KITE", size: 18, weight: .semibold, relativeTo: .title3, color: .white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.kiteAmber).cornerRadius(KiteRadius.large)
            }
            .padding(.horizontal, KiteSpacing.xl)
            .padding(.bottom, 20)
        }
        .padding()
        .onAppear {
            loadKeyOffsets()
            checkForKeyboardActivity()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in checkForKeyboardActivity() }
        }
        .onDisappear { pollTimer?.invalidate() }
    }

    private var miniHeatmap: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                let cellWidth = max((geo.size.width - 11 * 3) / 10, 14)
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(row, id: \.self) { key in
                            let offset = keyOffsets[key]
                            Text(key)
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: cellWidth, height: 22)
                                .background(Color.heatmapColor(forConfidence: offset?.confidence ?? 0, hasData: (offset?.sampleCount ?? 0) > 0))
                                .foregroundColor(.white).cornerRadius(KiteRadius.tiny)
                        }
                    }
                }
            }
        }
    }

    private func loadKeyOffsets() {
        let preferences = PreferencesStore.load()
        if preferences.isDemoMode {
            keyOffsets = MotorProfile.demo.keyOffsets
            return
        }
        if let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.motorProfile),
           let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            keyOffsets = profile.keyOffsets
        }
    }

    private func checkForKeyboardActivity() {
        keyboardDetected = SharedStore.defaults?.data(forKey: SharedStore.Keys.currentSession) != nil
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ScaledText("\(number)", size: 13, weight: .bold, relativeTo: .footnote, color: .white)
                .frame(width: 20, height: 20).background(Color.kiteAmber).clipShape(Circle())
            ScaledText(text, size: 13, relativeTo: .footnote, color: .secondary)
        }
    }
    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview { TrialView(onContinue: {}) }
