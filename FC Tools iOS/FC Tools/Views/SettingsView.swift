import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsManager
    @ObservedObject var manager: WebViewManager
    @State private var confirmClear = false
    @State private var showingLogs = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Userscript") {
                    Toggle("Enable injection", isOn: $settings.scriptInjectionEnabled)
                        .onChange(of: settings.scriptInjectionEnabled) { _, _ in manager.reconfigureInjection() }
                    LabeledContent("Version", value: manager.scriptVersion)
                    LabeledContent("Updates", value: "Automatic")
                    Button("Reload userscript", systemImage: "arrow.triangle.2.circlepath") {
                        manager.injectScript(force: true)
                    }.disabled(!settings.scriptInjectionEnabled)
                }
                Section("Browser") {
                    Button("Console logs", systemImage: "terminal") { showingLogs = true }
                    Button("Clear cookies and cache", systemImage: "trash", role: .destructive) {
                        confirmClear = true
                    }
                }
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }
                }
                Section {
                    Link("EA FC Web App", destination: WebViewManager.homeURL)
                } footer: {
                    Text("FC Tools is an independent browser wrapper and is not affiliated with Electronic Arts.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingLogs) { ConsoleLogView() }
            .confirmationDialog("Clear all website data?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Data", role: .destructive) { Task { await manager.clearWebsiteData() } }
            } message: { Text("This signs you out and removes cookies, cache, local storage, and IndexedDB.") }
        }
    }
}
