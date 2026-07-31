import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsManager
    @ObservedObject var manager: WebViewManager
    @State private var confirmClear = false
    @State private var showingLogs = false
    @State private var accountEmail = ""
    @State private var accountPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account autofill") {
                    Toggle("Enable account autofill", isOn: $settings.quickLoginEnabled)
                    TextField("EA email", text: $accountEmail)
                        .textContentType(.username).textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("EA password", text: $accountPassword)
                        .textContentType(.password)
                    Text("Credentials are stored in the iPhone Keychain. FC Tools fills the EA login form but never taps Sign In.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Save account", systemImage: "lock.fill") { saveCredentials() }
                    Button("Remove saved account", systemImage: "trash", role: .destructive) {
                        KeychainManager().delete()
                        settings.quickLoginEnabled = false
                    }
                }
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
            .onAppear {
                if let credentials = KeychainManager().read() {
                    accountEmail = credentials.email
                    accountPassword = credentials.password
                }
            }
            .confirmationDialog("Clear all website data?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Data", role: .destructive) { Task { await manager.clearWebsiteData() } }
            } message: { Text("This signs you out and removes cookies, cache, local storage, and IndexedDB.") }
        }
    }

    private func saveCredentials() {
        do {
            try KeychainManager().save(email: accountEmail, password: accountPassword)
            settings.quickLoginEnabled = true
            accountPassword = ""
            AppLogger.shared.log("EA account saved securely in the iPhone Keychain.")
        } catch {
            AppLogger.shared.log(error.localizedDescription, level: .error)
        }
    }
}
