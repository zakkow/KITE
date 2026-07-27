import SwiftUI

struct PrivacyView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "hand.raised.fill").font(.system(size: 60)).foregroundColor(.kiteAmber)
            ScaledText("Your Privacy", size: 32, weight: .bold, relativeTo: .largeTitle).foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 16) {
                ScaledText("KITE learns your typing patterns to improve accuracy. All data stays on your device — nothing is sent to external servers.", size: 16, relativeTo: .body)
                    .foregroundColor(.secondary)
                ScaledText("You can delete your motor profile at any time from the Settings screen.", size: 16, relativeTo: .body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button(action: onContinue) {
                ScaledText("Continue", size: 18, weight: .semibold, relativeTo: .title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.kiteAmber)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

#Preview { PrivacyView(onContinue: {}) }
