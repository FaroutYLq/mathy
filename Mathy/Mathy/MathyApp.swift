import SwiftUI
import KeyboardShortcuts

@main
struct MathyApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Ensure bundle identifier exists (SPM executables lack one)
        if Bundle.main.bundleIdentifier == nil {
            let info = Bundle.main.infoDictionary ?? [:]
            var mutable = info
            mutable["CFBundleIdentifier"] = "com.mathy.Mathy"
            // Use class_getInstanceVariable to set _infoDictionary is fragile;
            // instead, register via UserDefaults as a fallback identifier source.
            UserDefaults.standard.register(defaults: ["__CFBundleIdentifier": "com.mathy.Mathy"])
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
