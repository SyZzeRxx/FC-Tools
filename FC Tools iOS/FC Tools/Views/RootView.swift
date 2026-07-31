import SwiftUI

struct RootView: View {
    @EnvironmentObject private var manager: WebViewManager
    @State private var splashVisible = true

    var body: some View {
        ZStack {
            BrowserView(manager: manager)
            if splashVisible {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.35)) { splashVisible = false }
        }
        .task { await manager.updateUserscript() }
    }
}
