//
//  KITE_Final_App.swift
//  KITE(Final)
//
//  Created by Apple on 7/7/26.
//

import SwiftUI
import SwiftData

@main
struct KITE_Final_App: App {
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTestSkipOnboarding") {
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
