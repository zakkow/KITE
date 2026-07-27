import SwiftUI

struct ProfileSelectorView: View {
    var onContinueToCalibration: (ProfileType) -> Void
    var onSkip: (ProfileType) -> Void

    @State private var selectedProfile: ProfileType = .general

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ScaledText("Choose Your Profile", size: 32, weight: .bold, relativeTo: .largeTitle).foregroundColor(.primary)
            ScaledText("Select the profile that best describes your motor pattern", size: 16, relativeTo: .body)
                .foregroundColor(.secondary).multilineTextAlignment(.center)

            VStack(spacing: 16) {
                ProfileCard(profile: .general, title: "General", description: "For most users with typical motor patterns", isSelected: selectedProfile == .general) { selectedProfile = .general }
                ProfileCard(profile: .tremor, title: "Tremor", description: "For users with hand tremor or oscillation", isSelected: selectedProfile == .tremor) { selectedProfile = .tremor }
                ProfileCard(profile: .spasticity, title: "Spasticity / CP", description: "My hand pulls in one direction", isSelected: selectedProfile == .spasticity) { selectedProfile = .spasticity }
                ProfileCard(profile: .notSure, title: "Not Sure Yet", description: "Start with defaults and adapt", isSelected: selectedProfile == .notSure) { selectedProfile = .notSure }
            }
            .padding(.horizontal, 16)

            Spacer()
            Button(action: { onContinueToCalibration(selectedProfile) }) {
                ScaledText("Continue to calibration", size: 18, weight: .semibold, relativeTo: .title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.kiteAmber)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Button(action: { onSkip(selectedProfile) }) {
                ScaledText("Skip calibration", size: 16, relativeTo: .body).foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

struct ProfileCard: View {
    let profile: ProfileType
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    ScaledText(title, size: 18, weight: .semibold, relativeTo: .title3).foregroundColor(.primary)
                    ScaledText(description, size: 14, relativeTo: .subheadline).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundColor(.kiteAmber)
                }
            }
            .padding(16)
            .background(isSelected ? Color.kiteAmber.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.kiteAmber : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview { ProfileSelectorView(onContinueToCalibration: { _ in }, onSkip: { _ in }) }
