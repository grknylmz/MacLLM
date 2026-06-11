import SwiftUI

struct PopoverView: View {
    let serverManager: ServerManager
    let modelManager: ModelManager
    let hfClient: HuggingFaceClient
    let pythonEnvManager: PythonEnvManager

    @State private var selectedTab: Tab = .models

    enum Tab: String, CaseIterable {
        case models = "Models"
        case download = "Download"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .models: return "cpu"
            case .download: return "arrow.down.circle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ServerStatusView(serverManager: serverManager)

            Divider()

            TabSelector(selectedTab: $selectedTab)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    switch selectedTab {
                    case .models:
                        ModelListView(modelManager: modelManager, serverManager: serverManager)
                    case .download:
                        DownloadView(
                            hfClient: hfClient,
                            modelManager: modelManager,
                            serverManager: serverManager,
                            pythonEnvManager: pythonEnvManager
                        )
                    case .settings:
                        SettingsView(
                            serverManager: serverManager,
                            pythonEnvManager: pythonEnvManager
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 340)
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
