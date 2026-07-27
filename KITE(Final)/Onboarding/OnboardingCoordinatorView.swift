import SwiftUI

enum OnboardingStep: Equatable {
    case intro
    case privacy
    case profileSelector
    case calibration(ProfileType)
    case calibrationComplete
    case trial
}

struct OnboardingCoordinatorView: View {
    @State private var step: OnboardingStep = .intro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onFinished: () -> Void

    var body: some View {
        Group {
            switch step {
            case .intro:
                OnboardingView(onGetStarted: { step = .privacy })
            case .privacy:
                PrivacyView(onContinue: { step = .profileSelector })
            case .profileSelector:
                ProfileSelectorView(
                    onContinueToCalibration: { profile in step = .calibration(profile) },
                    onSkip: { profile in
                        let fresh = MotorProfile.fresh(profileType: profile)
                        if let data = try? JSONEncoder().encode(fresh),
                           (try? JSONDecoder().decode(MotorProfile.self, from: data)) != nil {
                            SharedStore.defaults?.set(data, forKey: SharedStore.Keys.motorProfile)
                        }
                        step = .trial
                    }
                )
            case .calibration(let profile):
                CalibrationView(profileType: profile, onComplete: { step = .calibrationComplete })
            case .calibrationComplete:
                CalibrationCompleteView(onFinished: { step = .trial })
            case .trial:
                TrialView(onContinue: onFinished)
            }
        }
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.35), value: step)
    }
}
