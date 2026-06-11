import SwiftUI

struct PopoverView: View {
    let serverManager: ServerManager
    let modelManager: ModelManager
    let hfClient: HuggingFaceClient
    let pythonEnvManager: PythonEnvManager
    let memoryMonitor: SystemMemoryMonitor
    let downloadManager: DownloadManager
    let chatManager: ChatManager

    @State private var selectedTab: Tab = .models

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case models = "Models"
        case download = "Download"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.fill"
            case .models: return "cpu"
            case .download: return "arrow.down.circle"
            case .settings: return "gearshape"
            }
        }
    }

    private var showLogPanel: Bool {
        serverManager.isActive
    }

    var body: some View {
        VStack(spacing: 0) {
            ServerStatusView(serverManager: serverManager, memoryMonitor: memoryMonitor)

            Divider()

            TabSelector(selectedTab: $selectedTab)

            Divider()

            ScrollView {
                ZStack {
                    ChatView(chatManager: chatManager, serverManager: serverManager)
                        .opacity(selectedTab == .chat ? 1 : 0)
                        .frame(height: selectedTab == .chat ? nil : 0)

                    ModelListView(modelManager: modelManager, serverManager: serverManager, memoryMonitor: memoryMonitor)
                        .opacity(selectedTab == .models ? 1 : 0)
                        .frame(height: selectedTab == .models ? nil : 0)

                    DownloadView(
                        hfClient: hfClient,
                        modelManager: modelManager,
                        serverManager: serverManager,
                        pythonEnvManager: pythonEnvManager,
                        downloadManager: downloadManager
                    )
                    .opacity(selectedTab == .download ? 1 : 0)
                    .frame(height: selectedTab == .download ? nil : 0)

                    SettingsView(
                        serverManager: serverManager,
                        pythonEnvManager: pythonEnvManager,
                        memoryMonitor: memoryMonitor
                    )
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .frame(height: selectedTab == .settings ? nil : 0)
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: showLogPanel ? 280 : 400)

            LogPanelView(
                serverManager: serverManager,
                isVisible: showLogPanel
            )
        }
        .frame(width: 380)
        .animation(.easeInOut(duration: 0.25), value: showLogPanel)
    }
}

struct TabSelector: View {
    @Binding var selectedTab: PopoverView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PopoverView.Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
