import SwiftUI
import AppKit

struct LogsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLevel: LogLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(LogLevel?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button("Export Logs") { exportLogs() }
            }
            List(filteredEntries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("[\(entry.level.rawValue.uppercased())] \(entry.message)")
                    Text(entry.timestamp.formatted(date: .numeric, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var filteredEntries: [LogEntry] {
        if let level = selectedLevel {
            return appState.logStore.entries.filter { $0.level == level }
        }
        return appState.logStore.entries
    }

    private func exportLogs() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try appState.logStore.exportLogs(to: url)
            } catch {
                appState.logStore.log(.error, "Export logs failed", context: error.localizedDescription)
            }
        }
    }
}
