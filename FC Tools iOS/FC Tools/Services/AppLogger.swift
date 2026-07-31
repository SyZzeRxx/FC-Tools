import Foundation
import os

@MainActor
final class AppLogger: ObservableObject {
    static let shared = AppLogger()
    @Published private(set) var entries: [LogEntry] = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FCTools", category: "App")

    func log(_ message: String, level: LogEntry.Level = .info) {
        entries.append(LogEntry(date: .now, level: level, message: message))
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }

    func clear() { entries.removeAll() }
}

