import Foundation
import WebKit

enum ScriptInjectorError: LocalizedError {
    case resourceMissing
    case unreadable(Error)

    var errorDescription: String? {
        switch self {
        case .resourceMissing: "Bundled userscript is missing."
        case .unreadable(let error): "Could not read userscript: \(error.localizedDescription)"
        }
    }
}

struct ScriptInjector {
    static let version = "0.1.0"
    static let marker = "__fcToolsFodderInjected"
    static let updateURL = URL(string: "https://fodder.gg/fodder.user.js")!


    func source() throws -> String {
        if let updated = try? String(contentsOf: ScriptUpdateService.cachedScriptURL, encoding: .utf8),
           ScriptUpdateService.isValid(updated) {
            return updated
        }
        guard let url = Bundle.main.url(forResource: "Fodder", withExtension: "user.js") else {
            throw ScriptInjectorError.resourceMissing
        }
        do { return try String(contentsOf: url, encoding: .utf8) }
        catch { throw ScriptInjectorError.unreadable(error) }
    }

    func version(in script: String? = nil) -> String {
        let text = script ?? (try? source()) ?? ""
        guard let match = text.firstMatch(of: /\/\/\s*@version\s+([^\r\n]+)/) else {
            return Self.version
        }
        return String(match.1).trimmingCharacters(in: .whitespaces)
    }

    func wrappedSource() throws -> String {
        let script = try source()
        return """
        (() => {
          if (window.\(Self.marker)) return "already-injected";
          window.\(Self.marker) = true;
          try {
            \(script)
            return "injected";
          } catch (error) {
            window.\(Self.marker) = false;
            throw error;
          }
        })();
        """
    }

    @MainActor
    func install(into controller: WKUserContentController) throws {
        controller.removeAllUserScripts()
        guard SettingsManager.shared.scriptInjectionEnabled else { return }
        controller.addUserScript(WKUserScript(
            source: try wrappedSource(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true,
            in: .page
        ))
    }
}
