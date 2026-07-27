import SwiftUI

struct ContentView: View {
    @State private var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")

    var body: some View {
        if onboardingComplete {
            MainTabView()
        } else {
            OnboardingCoordinatorView(onFinished: {
                // Single source of truth for "onboarding is done," regardless
                // of which path got here (full calibration, skip, or trial
                // skip) — this was previously scattered and one path (Skip)
                // never actually persisted it to disk, only to in-memory state.
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                onboardingComplete = true
            })
        }
    }
}

#Preview { ContentView() }
