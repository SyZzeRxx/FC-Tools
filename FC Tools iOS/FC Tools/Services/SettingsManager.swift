import SwiftUI

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("scriptInjectionEnabled") var scriptInjectionEnabled = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("appearance") var appearance = "system" {
        willSet { objectWillChange.send() }
    }

    var colorScheme: ColorScheme? {
        appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }

    private init() {}
}

