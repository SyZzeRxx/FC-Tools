import Foundation

struct LogEntry: Identifiable, Hashable {
    enum Level: String { case info = "INFO", warning = "WARN", error = "ERROR" }
    let id = UUID()
    let date: Date
    let level: Level
    let message: String
}

