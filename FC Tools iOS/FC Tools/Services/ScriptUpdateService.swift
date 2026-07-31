import Foundation

enum ScriptUpdateError: LocalizedError {
    case invalidResponse
    case invalidScript

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The userscript server returned an invalid response."
        case .invalidScript: "The downloaded file was not a valid EA userscript."
        }
    }
}

struct ScriptUpdateService {
    static var cachedScriptURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "FC Tools", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Fodder.user.js")
    }

    static func isValid(_ source: String) -> Bool {
        source.contains("// ==UserScript==") &&
        source.contains("https://www.ea.com/*") &&
        source.contains("// ==/UserScript==")
    }

    func refresh() async throws -> String {
        var request = URLRequest(url: ScriptInjector.updateURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        request.setValue("FC Tools iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ScriptUpdateError.invalidResponse
        }
        guard let source = String(data: data, encoding: .utf8), Self.isValid(source) else {
            throw ScriptUpdateError.invalidScript
        }
        try data.write(to: Self.cachedScriptURL, options: .atomic)
        return source
    }
}
