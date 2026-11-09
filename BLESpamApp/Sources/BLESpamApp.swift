// BLESpamApp.swift — App entry point

import SwiftUI

@main
struct BLESpamApp: App {
    init() {
        AppTheme.configureSystemBars()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AppTheme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
