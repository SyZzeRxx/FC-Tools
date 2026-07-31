import SwiftUI

struct BrowserView: View {
    @ObservedObject var manager: WebViewManager
    @State private var showingSettings = false
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebViewContainer(manager: manager).ignoresSafeArea(edges: .bottom)
                if manager.isLoading {
                    ProgressView(value: manager.progress).progressViewStyle(.linear)
                }
                if let error = manager.lastError {
                    ContentUnavailableView("Couldn’t Load Page", systemImage: "wifi.exclamationmark",
                                           description: Text(error))
                        .background(.regularMaterial)
                }
            }
            .navigationTitle("FC Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: manager.goBack) { Image(systemName: "chevron.backward") }
                        .disabled(!manager.canGoBack)
                    Button(action: manager.goForward) { Image(systemName: "chevron.forward") }
                        .disabled(!manager.canGoForward)
                    Spacer()
                    Button(action: manager.reload) { Image(systemName: "arrow.clockwise") }
                    Button { showingShare = true } label: { Image(systemName: "square.and.arrow.up") }
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView(manager: manager) }
            .sheet(isPresented: $showingShare) { ShareSheet(items: [manager.currentURL ?? WebViewManager.homeURL]) }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

