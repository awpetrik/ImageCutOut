import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
        case .home: return "house"
        case .batchQueue: return "tray.full"
        case .preview: return "photo.on.rectangle"
        case .settings: return "gearshape"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted: Bool = false
    @State private var selection: AppSection? = .home
    @State private var showInspector: Bool = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = section
                        }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            HStack(spacing: 0) {
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
                .frame(minWidth: 700, minHeight: 600)

                if showInspector {
                    Divider()
                    InspectorPanelView()
                        .environmentObject(appState)
                }
            }
        }
        .onChange(of: selection) { newValue in
            appState.currentSection = newValue ?? .home
        }
        .onReceive(appState.$currentSection) { newValue in
            if selection != newValue {
                selection = newValue
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel("Toggle Inspector")
            }
        }
        .overlay(alignment: Alignment.top) {
            if isDropTargeted {
                DropZoneBannerView()
                    .padding()
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers -> Bool in
            providers.loadFileURLs { urls in
                appState.handleDrop(urls: urls)
            }
            return true
        }
        .sheet(isPresented: $appState.showResumePrompt) {
            ResumeBatchSheet()
        }
    }

    private func toggleSidebar() {
        #if os(macOS)
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
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
