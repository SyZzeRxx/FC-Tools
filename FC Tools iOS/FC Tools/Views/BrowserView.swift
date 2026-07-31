import SwiftUI

struct BrowserView: View {
    @ObservedObject var manager: WebViewManager
    @State private var showingSettings = false
    @State private var showingShare = false

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            ZStack(alignment: .top) {
                WebViewContainer(manager: manager)
                    .ignoresSafeArea(edges: .bottom)

                if manager.isLoading {
                    ProgressView(value: manager.progress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                }

                if let error = manager.lastError {
                    ContentUnavailableView(
                        "Couldn’t Connect",
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                    .background(.regularMaterial)
                }
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

    private var appHeader: some View {
        HStack(spacing: 8) {
            Button(action: manager.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!manager.canGoBack)

            Button(action: manager.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!manager.canGoForward)

            HStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.green, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 0) {
                    Text("FC TOOLS").font(.caption.bold()).tracking(1)
                    Text("ULTIMATE TEAM").font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button(action: manager.reload) {
                Image(systemName: "arrow.clockwise")
            }
            Button { showingShare = true } label: {
                Image(systemName: "square.and.arrow.up")
            }
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
            }
        }
        .buttonStyle(HeaderButtonStyle())
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.green.opacity(0.55)).frame(height: 1)
        }
    }
}

private struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .background(configuration.isPressed ? .green.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
