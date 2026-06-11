import SwiftUI

struct ServerStatusView: View {
    let serverManager: ServerManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .scaleEffect(serverManager.isRunning ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: serverManager.isRunning)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(serverManager.statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                if let model = serverManager.activeModel {
                    Text(model)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if serverManager.isRunning {
                    Button {
                        serverManager.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        Task { await serverManager.restart() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        if let model = serverManager.activeModel {
                            Task { await serverManager.start(model: model) }
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(serverManager.activeModel == nil)
                }

                if serverManager.isRunning {
                    Button {
                        if let url = URL(string: "http://127.0.0.1:\(serverManager.serverPort)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var statusColor: Color {
        switch serverManager.status {
        case .stopped: return .red
        case .starting: return .yellow
        case .running: return .green
        case .error: return .red
        }
    }
}
