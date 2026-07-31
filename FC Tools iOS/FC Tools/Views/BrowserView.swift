import SwiftUI

struct BrowserView: View {
    @ObservedObject var manager: WebViewManager
    @State private var showingSettings = false
    @State private var showingShare = false

    var body: some View {
        ZStack {
            WebViewContainer(manager: manager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                Spacer()
                bottomChrome
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .ignoresSafeArea(edges: .vertical)

            if manager.isLoading {
                VStack {
                    ProgressView(value: manager.progress)
                        .tint(.green)
                        .frame(width: 150)
                        .padding(.top, 4)
                    Spacer()
                }
            }
            if let error = manager.lastError {
                ContentUnavailableView("Couldn’t Load Page", systemImage: "wifi.exclamationmark",
                                       description: Text(error))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(24)
            }
        }
        .background(.black)
        .statusBarHidden(true)
        .sheet(isPresented: $showingSettings) { SettingsView(manager: manager) }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [manager.currentURL ?? WebViewManager.homeURL])
                .presentationDetents([.medium])
        }
    }

    private var topChrome: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .font(.caption.bold()).foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.green, in: RoundedRectangle(cornerRadius: 9))
                Text("FC TOOLS").font(.caption.bold()).tracking(1.2)
                Circle().fill(.green).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.13)))
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ChromeButtonStyle())
        }
    }

    private var bottomChrome: some View {
        HStack(spacing: 8) {
            Button(action: manager.goBack) { Image(systemName: "chevron.left") }
                .disabled(!manager.canGoBack)
            Button(action: manager.goForward) { Image(systemName: "chevron.right") }
                .disabled(!manager.canGoForward)
            Spacer()
            Button(action: manager.reload) { Image(systemName: "arrow.clockwise") }
            Button { showingShare = true } label: { Image(systemName: "square.and.arrow.up") }
        }
        .padding(8)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.13)))
        .buttonStyle(ChromeButtonStyle())
    }
}

private struct ChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 36, height: 30)
            .background(configuration.isPressed ? .green.opacity(0.35) : .white.opacity(0.10), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
