import SwiftUI

struct MainTabView: View {
    @State private var preferences = PreferencesStore.load()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }
                .accessibilityLabel("Dashboard")
            HeatmapView()
                .tabItem { Label("Heatmap", systemImage: "keyboard") }
                .accessibilityLabel("Heatmap")
            if preferences.comfortModeEnabled {
                ComfortModeSettingsView()
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .accessibilityLabel("Settings")
            } else {
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .accessibilityLabel("Settings")
            }
        }
        .tint(.kiteAmber)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            preferences = PreferencesStore.load()
        }
    }
}
