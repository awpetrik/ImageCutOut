import SwiftUI
import AppKit

struct LogsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLevel: LogLevel? = nil
    @State private var selection: LogEntry.ID?

    var body: some View {
        List(filteredEntries, selection: $selection) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text("[\(entry.level.rawValue.uppercased())] \(entry.message)")
                Text(entry.timestamp.formatted(date: .numeric, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contextMenu {
                Button("Copy") { copy(entry) }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(LogLevel?.some(level))
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copySelected()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    exportLogs()
                } label: {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var filteredEntries: [LogEntry] {
        if let level = selectedLevel {
            return appState.logStore.entries.filter { $0.level == level }
        }
        return appState.logStore.entries
    }

    private func copySelected() {
        guard let selection, let entry = appState.logStore.entries.first(where: { $0.id == selection }) else { return }
        copy(entry)
    }

    private func copy(_ entry: LogEntry) {
        let text = "[\(entry.level.rawValue.uppercased())] \(entry.message)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
