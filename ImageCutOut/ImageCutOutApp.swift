import SwiftUI

@main
struct ImageCutOutApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.settings.uiSettings.theme == .system ? nil : (appState.settings.uiSettings.theme == .dark ? .dark : .light))
        }
        .commands {
            ImageCutOutCommands()
        }
    }
}
