import Foundation

@MainActor
final class BrowserViewModel: ObservableObject {
    let manager: WebViewManager
    init(manager: WebViewManager) { self.manager = manager }
    var shareURL: URL { manager.currentURL ?? WebViewManager.homeURL }
}

