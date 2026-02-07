import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case batchQueue
    case preview
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .batchQueue: return "Batch Queue"
        case .preview: return "Preview"
        case .settings: return "Settings"
        case .logs: return "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .batchQueue: return "tray.full"
        case .preview: return "photo.on.rectangle"
        case .settings: return "gearshape"
        case .logs: return "text.book.closed"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted: Bool = false
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch selection ?? .home {
                case .home:
                    HomeView()
                case .batchQueue:
                    BatchQueueView()
                case .preview:
                    PreviewView()
                case .settings:
                    SettingsView()
                case .logs:
                    LogsView()
                }
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .onChange(of: selection) { _, newValue in
            appState.currentSection = newValue ?? .home
        }
        .onReceive(appState.$currentSection) { newValue in
            if selection != newValue {
                selection = newValue
            }
        }
        .overlay(alignment: .top) {
            if isDropTargeted {
                DropZoneBannerView()
                    .padding()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            providers.loadFileURLs { urls in
                appState.handleDrop(urls: urls)
            }
            return true
        }
        .sheet(isPresented: $appState.showResumePrompt) {
            ResumeBatchSheet()
        }
    }
}

struct DropZoneBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "square.and.arrow.down")
            Text("Drop images or folders to add to queue")
        }
        .padding(12)
        .background(.ultraThickMaterial)
        .cornerRadius(10)
    }
}

struct ResumeBatchSheet: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Resume previous batch?")
                .font(.headline)
            Text("We found an unfinished batch from the last session. Resume processing or start fresh.")
                .font(.subheadline)
            HStack {
                Button("Start Fresh") {
                    appState.clearQueue()
                    appState.showResumePrompt = false
                }
                Button("Resume") {
                    appState.showResumePrompt = false
                    appState.startBatch()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
