import SwiftUI

struct SettingsView: View {
    @Bindable var serverManager: ServerManager
    @AppStorage("serverPort") private var serverPort: Int = Constants.defaultServerPort
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("autoStartServer") private var autoStartServer: Bool = false
    var pythonEnvManager: PythonEnvManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                HStack {
                    Text("Server Port")
                        .font(.system(size: 11))
                    Spacer()
                    TextField("", value: $serverPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.system(size: 11))
                        .onChange(of: serverPort) { _, newValue in
                            serverManager.serverPort = newValue
                        }
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("Auto-start last model on launch", isOn: $autoStartServer)
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Python Environment")
                            .font(.system(size: 11, weight: .medium))
                        Text(Constants.venvURL.path)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    if pythonEnvManager.isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Reinstall") {
                            Task { await pythonEnvManager.fullSetup() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.system(size: 10))
                    }
                }

                if pythonEnvManager.isInstalling {
                    ScrollView {
                        Text(pythonEnvManager.installOutput)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 80)
                    .padding(8)
                    .background(.gray.opacity(0.06))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 12)

            Divider()

            HStack {
                Button("Quit MLX Model Manager") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 10))
                Spacer()
                Text("v1.0.0")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
        }
    }
}
