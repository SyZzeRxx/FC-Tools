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
    private var authWebView: WKWebView?
    private var authContainer: UIView?
    private weak var authAddressLabel: UILabel?

    override init() {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = controller
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        controller.add(WeakScriptMessageHandler(delegate: self), name: "fcToolsConsole")
        do { try injector.install(into: controller) }
        catch { report(error, context: "Installing userscript") }
        installConsoleBridge(on: controller)
        installAutofillScript(on: controller)

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        // Horizontal edge swipes are easy to trigger while using the FC interface and
        // can unexpectedly return to an old EA login page. Navigation remains available
        // through the explicit Back/Forward controls in Settings.
        webView.allowsBackForwardNavigationGestures = false
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

    private func installAutofillScript(on controller: WKUserContentController) {
        guard SettingsManager.shared.quickLoginEnabled,
              let credentials = KeychainManager().read(),
              let email = jsonString(credentials.email),
              let password = jsonString(credentials.password) else { return }
        controller.addUserScript(WKUserScript(
            source: Self.autofillSource(email: email, password: password),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false,
            in: .page
        ))
    }

    private func jsonString(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func autofillSource(email: String, password: String) -> String {
        """
        (() => {
          if (!location.hostname.endsWith("ea.com")) return;
          const savedEmail = \(email), savedPassword = \(password);
          const setValue = (element, value) => {
            if (!element || element.value) return;
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")?.set;
            if (setter) setter.call(element, value); else element.value = value;
            for (const name of ["input", "change", "blur"]) {
              element.dispatchEvent(new Event(name, { bubbles: true }));
            }
          };
          const fill = () => {
            const emailInput = document.querySelector(
              'input[type="email"],#email,input[name="email"],input[name="username"],input[autocomplete="username"],input[id*="email" i]');
            const passwordInput = document.querySelector(
              'input[type="password"],#password,input[name="password"],input[autocomplete="current-password"],input[id*="password" i]');
            setValue(emailInput, savedEmail);
            setValue(passwordInput, savedPassword);
            return Boolean(emailInput?.value && passwordInput?.value);
          };
          fill();
          let attempts = 0;
          const timer = setInterval(() => {
            if (fill() || ++attempts >= 120) clearInterval(timer);
          }, 500);
        })();
        """
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
            installAutofillScript(on: webView.configuration.userContentController)
            if SettingsManager.shared.scriptInjectionEnabled { injectScript(force: true) }
        } catch { report(error, context: "Updating injection") }
    }

    func reconfigureAutofill(reload: Bool) {
        reconfigureInjection()
        if reload { webView.reload() }
        else { fillSavedLogin() }
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

    func fillSavedLogin() {
        guard SettingsManager.shared.quickLoginEnabled,
              let credentials = KeychainManager().read(),
              let email = jsonString(credentials.email),
              let password = jsonString(credentials.password) else { return }
        webView.evaluateJavaScript(Self.autofillSource(email: email, password: password)) { _, error in
            if let error { AppLogger.shared.log("iOS account autofill failed: \(error.localizedDescription)", level: .warning) }
            else { AppLogger.shared.log("Saved account fields filled; sign-in was not submitted.") }
        }
    }

    private func report(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        lastError = message
        AppLogger.shared.log(message, level: .error)
    }

    private func presentAuthWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        closeAuthView()

        let container = UIView(frame: webView.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.055, alpha: 1)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: container.bounds.width, height: 50))
        header.autoresizingMask = [.flexibleWidth]
        header.backgroundColor = UIColor(red: 0.08, green: 0.095, blue: 0.125, alpha: 1)

        let label = UILabel(frame: CGRect(x: 54, y: 0, width: header.bounds.width - 108, height: 50))
        label.autoresizingMask = [.flexibleWidth]
        label.text = "Secure sign-in"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        header.addSubview(label)

        let close = UIButton(type: .system)
        close.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.accessibilityLabel = "Cancel sign-in"
        close.addTarget(self, action: #selector(closeAuthViewFromButton), for: .touchUpInside)
        header.addSubview(close)

        let popup = WKWebView(
            frame: CGRect(x: 0, y: 50, width: container.bounds.width, height: container.bounds.height - 50),
            configuration: configuration
        )
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = false
        container.addSubview(popup)
        container.addSubview(header)
        webView.addSubview(container)

        authContainer = container
        authWebView = popup
        authAddressLabel = label
        AppLogger.shared.log("Opened an in-app account sign-in view.")
        return popup
    }

    @objc private func closeAuthViewFromButton() { closeAuthView() }

    private func closeAuthView() {
        authWebView?.stopLoading()
        authWebView?.navigationDelegate = nil
        authWebView?.uiDelegate = nil
        authWebView?.removeFromSuperview()
        authContainer?.removeFromSuperview()
        authWebView = nil
        authContainer = nil
        authAddressLabel = nil
    }

    private func authDisplayName(for url: URL?) -> String {
        switch url?.host?.lowercased() {
        case "accounts.google.com": "Google Account"
        case "discord.com": "Discord"
        case "fodder.gg": "fodder.gg"
        case .some(let host): host
        case nil: "Secure sign-in"
        }
    }

    @discardableResult
    private func completeAuthIfPresent(in url: URL?) -> Bool {
        guard let url,
              url.host?.lowercased().hasSuffix("ea.com") == true,
              let fragment = url.fragment,
              let components = URLComponents(string: "https://callback.invalid/?\(fragment)"),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty,
              let encoded = jsonString(token) else { return false }

        let source = """
        (() => {
          const token = \(encoded);
          localStorage.setItem("fodder_gg_token", token);
          if (window.FodderGG?.setAuthToken) window.FodderGG.setAuthToken(token);
          if (window.FodderGG?.getMe) window.FodderGG.getMe().catch(() => {});
          return true;
        })();
        """
        webView.evaluateJavaScript(source) { [weak self] value, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.report(error, context: "Completing account sign-in")
                    return
                }
                guard value as? Bool == true else {
                    self.report(AuthHandoffError.rejected, context: "Completing account sign-in")
                    return
                }
                AppLogger.shared.log("Account sign-in completed and returned to FC Tools.")
                self.closeAuthView()
            }
        }
        return true
    }
}

private enum AuthHandoffError: LocalizedError {
    case rejected
    var errorDescription: String? { "The main page rejected the account token." }
}

extension WebViewManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView === authWebView {
            authAddressLabel?.text = authDisplayName(for: webView.url)
            return
        }
        isLoading = true
        lastError = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === authWebView {
            authAddressLabel?.text = authDisplayName(for: webView.url)
            if completeAuthIfPresent(in: webView.url) { webView.stopLoading() }
            return
        }
        isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
        injectScript()
        fillSavedLogin()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView === authWebView {
            AppLogger.shared.log("Account sign-in navigation failed: \(error.localizedDescription)", level: .warning)
            return
        }
        isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
        report(error, context: "Navigation failed")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === authWebView {
            AppLogger.shared.log("Account sign-in view closed unexpectedly.", level: .warning)
            closeAuthView()
            return
        }
        AppLogger.shared.log("Web content process terminated; recovering.", level: .warning)
        webView.reload()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard webView === authWebView else { return .allow }
        authAddressLabel?.text = authDisplayName(for: navigationAction.request.url)
        return completeAuthIfPresent(in: navigationAction.request.url) ? .cancel : .allow
    }
}

extension WebViewManager: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, webView === self.webView else { return nil }
        return presentAuthWebView(configuration: configuration)
    }


    func webViewDidClose(_ webView: WKWebView) {
        if webView === authWebView { closeAuthView() }
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
