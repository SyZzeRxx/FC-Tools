import SwiftUI

struct ConsoleLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logger = AppLogger.shared

    var body: some View {
        NavigationStack {
            Group {
                if logger.entries.isEmpty {
                    ContentUnavailableView("No Logs", systemImage: "terminal")
                } else {
                    List(logger.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.level.rawValue)  \(entry.date.formatted(date: .omitted, time: .standard))")
                                .font(.caption.monospaced()).foregroundStyle(color(for: entry.level))
                            Text(entry.message).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Console")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Clear") { logger.clear() } }
            }
        }
    }

    private func color(for level: LogEntry.Level) -> Color {
        switch level { case .info: .secondary; case .warning: .orange; case .error: .red }
    }
}

