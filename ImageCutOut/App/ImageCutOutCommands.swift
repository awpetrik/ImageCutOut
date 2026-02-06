import SwiftUI

struct ImageCutOutCommands: Commands {
    @EnvironmentObject private var appState: AppState

    var body: some Commands {
        CommandMenu("ImageCutOut") {
            Button("Open Files") { appState.openFiles() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Open Folder") { appState.openFolder() }
                .keyboardShortcut("O", modifiers: [.command, .shift])
            Divider()
            Button("Export Selected") { appState.exportSelected(includeOnlyApproved: false) }
                .keyboardShortcut("e", modifiers: .command)
            Button("Export All") { appState.exportAssets(includeOnlyApproved: false) }
                .keyboardShortcut("E", modifiers: [.command, .shift])
            Divider()
            Button("Settings") { appState.currentSection = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .textEditing) {
            Button("Reprocess Selected") { appState.startBatch() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Remove Selected") { removeSelected() }
                .keyboardShortcut(.delete)
            Button("Select All") { selectAll() }
                .keyboardShortcut("a", modifiers: .command)
        }

        CommandGroup(after: .toolbar) {
            Button("Quick Preview") { appState.currentSection = .preview }
                .keyboardShortcut(" ", modifiers: [])
        }
    }

    private func removeSelected() {
        let selected = appState.assetStore.selectedAssetIDs
        guard !selected.isEmpty else { return }
        for id in selected {
            appState.assetStore.remove(assetID: id)
        }
        appState.assetStore.selectedAssetIDs.removeAll()
    }

    private func selectAll() {
        let ids = appState.assetStore.allAssets().map { $0.id }
        appState.assetStore.selectedAssetIDs = Set(ids)
    }
}
