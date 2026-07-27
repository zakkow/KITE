import SwiftUI

struct OnboardingView: View {
    var onGetStarted: () -> Void
    @State private var logoVisible = false
    @State private var titleVisible = false
    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero logo — the actual KITE brand identity
            Image("KITELogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Color.kiteAmber.opacity(0.35), radius: 16, x: 0, y: 6)
                .opacity(logoVisible ? 1 : 0)
                .scaleEffect(logoVisible ? 1 : 0.82)
                .animation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1), value: logoVisible)

            Spacer().frame(height: 24)

            ScaledText("KITE", size: 48, weight: .bold, relativeTo: .largeTitle)
                .foregroundColor(.primary)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: titleVisible)

            Spacer().frame(height: 8)

            ScaledText("Adaptive keyboard for motor accessibility", size: 18, relativeTo: .title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)

            Spacer().frame(height: 32)

            HStack(spacing: 12) {
                StepChip(number: 1, title: "Privacy")
                StepChip(number: 2, title: "Profile")
                StepChip(number: 3, title: "Calibrate")
            }
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.6), value: contentVisible)

            Spacer()

            Button(action: onGetStarted) {
                ScaledText("Get started", size: 18, weight: .semibold, relativeTo: .title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.kiteAmber)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.7), value: contentVisible)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            logoVisible = true
            titleVisible = true
            contentVisible = true
        }
    }
}

struct StepChip: View {
    let number: Int
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            ScaledText("\(number)", size: 14, weight: .bold, relativeTo: .subheadline).foregroundColor(.white)
                .frame(width: 24, height: 24).background(Color.kiteAmber).clipShape(Circle())
            ScaledText(title, size: 14, relativeTo: .subheadline).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(.systemGray6)).cornerRadius(20)
    }
}

#Preview { OnboardingView(onGetStarted: {}) }
