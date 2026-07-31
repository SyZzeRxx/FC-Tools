import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var manager: WebViewManager
    func makeUIView(context: Context) -> WKWebView { manager.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

