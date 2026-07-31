import Combine
import SwiftUI
import WebKit

@MainActor
final class WebViewManager: NSObject, ObservableObject {
    static let homeURL = URL(string: "https://www.ea.com/ea-sports-fc/ultimate-team/web-app/")!

    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var currentURL: URL?
    @Published private(set) var scriptVersion = ScriptInjector.version
    @Published var lastError: String?

    let webView: WKWebView
    private let injector = ScriptInjector()
    private var observations = Set<AnyCancellable>()

    override init() {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = controller
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        controller.add(WeakScriptMessageHandler(delegate: self), name: "fcToolsConsole")
        do { try injector.install(into: controller) }
        catch { report(error, context: "Installing userscript") }
        installConsoleBridge(on: controller)

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.refreshControl = makeRefreshControl()
        observeWebView()
        scriptVersion = injector.version()
        loadHomeIfNeeded()
    }

    private func installConsoleBridge(on controller: WKUserContentController) {
        let source = """
        (() => {
          if (window.__fcToolsConsoleInstalled) return;
          window.__fcToolsConsoleInstalled = true;
          for (const level of ["log", "warn", "error"]) {
            const original = console[level].bind(console);
            console[level] = (...args) => {
              original(...args);
              try {
                window.webkit.messageHandlers.fcToolsConsole.postMessage({
                  level, message: args.map(v => {
                    try { return typeof v === "string" ? v : JSON.stringify(v); }
                    catch (_) { return String(v); }
                  }).join(" ")
                });
              } catch (_) {}
            };
          }
        })();
        """
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    private func observeWebView() {
        webView.publisher(for: \.estimatedProgress).receive(on: RunLoop.main)
            .sink { [weak self] in self?.progress = $0 }.store(in: &observations)
        webView.publisher(for: \.canGoBack).receive(on: RunLoop.main)
            .sink { [weak self] in self?.canGoBack = $0 }.store(in: &observations)
        webView.publisher(for: \.canGoForward).receive(on: RunLoop.main)
            .sink { [weak self] in self?.canGoForward = $0 }.store(in: &observations)
        webView.publisher(for: \.url).receive(on: RunLoop.main)
            .sink { [weak self] in self?.currentURL = $0 }.store(in: &observations)
    }

    private func makeRefreshControl() -> UIRefreshControl {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
        return control
    }

    @objc private func pulledToRefresh() { reload() }
    func loadHomeIfNeeded() {
        guard webView.url == nil, !webView.isLoading else { return }
        webView.load(URLRequest(url: Self.homeURL, cachePolicy: .useProtocolCachePolicy))
    }
    func reload() { webView.reload() }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }

    func injectScript(force: Bool = false) {
        guard SettingsManager.shared.scriptInjectionEnabled else {
            AppLogger.shared.log("Userscript injection is disabled.", level: .warning)
            return
        }
        let reset = force ? "window.\(ScriptInjector.marker)=false;" : ""
        do {
            webView.evaluateJavaScript(reset + (try injector.wrappedSource())) { _, error in
                Task { @MainActor in
                    if let error { self.report(error, context: "Injecting userscript") }
                    else { AppLogger.shared.log("Userscript \(ScriptInjector.version) injected.") }
                }
            }
        } catch { report(error, context: "Reading userscript") }
    }

    func reconfigureInjection() {
        do {
            try injector.install(into: webView.configuration.userContentController)
            installConsoleBridge(on: webView.configuration.userContentController)
            if SettingsManager.shared.scriptInjectionEnabled { injectScript(force: true) }
        } catch { report(error, context: "Updating injection") }
    }

    func updateUserscript() async {
        do {
            let source = try await ScriptUpdateService().refresh()
            scriptVersion = injector.version(in: source)
            reconfigureInjection()
            AppLogger.shared.log("Userscript updated to \(scriptVersion).")
        } catch {
            AppLogger.shared.log("Userscript update skipped: \(error.localizedDescription)", level: .warning)
        }
    }

    func clearWebsiteData() async {
        do {
            try await CookieManager().clearWebsiteData()
            AppLogger.shared.log("Cookies, cache, and website storage cleared.")
            webView.load(URLRequest(url: Self.homeURL))
        } catch { report(error, context: "Clearing website data") }
    }

    private func report(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        lastError = message
        AppLogger.shared.log(message, level: .error)
    }
}

extension WebViewManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        lastError = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
        injectScript()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
        report(error, context: "Navigation failed")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppLogger.shared.log("Web content process terminated; recovering.", level: .warning)
        webView.reload()
    }
}

extension WebViewManager: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

extension WebViewManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let text = body["message"] as? String else { return }
        let level: LogEntry.Level = switch body["level"] as? String {
        case "error": .error
        case "warn": .warning
        default: .info
        }
        AppLogger.shared.log("[Web] \(text)", level: level)
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
