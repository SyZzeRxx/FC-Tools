import SwiftUI

@main
struct FCToolsApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var manager = WebViewManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(manager)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

