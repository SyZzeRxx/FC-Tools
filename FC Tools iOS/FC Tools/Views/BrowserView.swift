import SwiftUI

struct BrowserView: View {
    @ObservedObject var manager: WebViewManager
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebViewContainer(manager: manager)
                .padding(.bottom, 6)

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 3)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.trailing, 6)
            .accessibilityLabel("FC Tools settings")

            if manager.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.green)
                    .padding(.top, 40)
                    .padding(.trailing, 14)
            }

            if let error = manager.lastError {
                ContentUnavailableView(
                    "Couldn’t Connect",
                    systemImage: "wifi.exclamationmark",
                    description: Text(error)
                )
                .background(.regularMaterial)
                .padding(20)
            }
        }
        .background(.black)
        .statusBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            SettingsView(manager: manager)
        }
    }
}
