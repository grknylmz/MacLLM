import SwiftUI

struct ServerStatusView: View {
    let serverManager: ServerManager
    let memoryMonitor: SystemMemoryMonitor

    var body: some View {
        VStack(spacing: 0) {
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
                        .lineLimit(1)
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
                    } else if serverManager.isStarting {
                        Button {
                            serverManager.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Kill stuck process")
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
            .padding(.top, 8)
            .padding(.bottom, 4)

            if serverManager.isStarting {
                StartupProgressView(stage: serverManager.startupStage)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            MemoryBarView(memoryMonitor: memoryMonitor)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            TopProcessesView(memoryMonitor: memoryMonitor)
                .padding(.bottom, 4)

            if memoryMonitor.warningLevel != .normal && serverManager.isRunning {
                MemoryWarningBanner(
                    warningLevel: memoryMonitor.warningLevel,
                    onFreeMemory: { Task { await serverManager.freeMemory() } }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
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

struct StartupProgressView: View {
    let stage: StartupStage

    private let stages: [(StartupStage, String)] = [
        (.loadingWeights, "Loading weights"),
        (.buildingModel, "Building model"),
        (.warmingUp, "Warming up"),
        (.ready, "Server ready")
    ]

    private func stageIndex(_ s: StartupStage) -> Int {
        switch s {
        case .idle: return -1
        case .loadingWeights: return 0
        case .buildingModel: return 1
        case .warmingUp: return 2
        case .ready: return 3
        case .failed: return -1
        }
    }

    var body: some View {
        let currentIdx = stageIndex(stage)

        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.offset) { idx, step in
                if idx > 0 {
                    Spacer(minLength: 2)
                    Rectangle()
                        .fill(idx <= currentIdx ? Color.green.opacity(0.5) : Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Spacer(minLength: 2)
                }

                HStack(spacing: 3) {
                    if idx < currentIdx {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    } else if idx == currentIdx {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                    Text(step.1)
                        .font(.system(size: 8))
                        .foregroundStyle(idx <= currentIdx ? .primary : .tertiary)
                }
            }
        }
    }
}

struct MemoryBarView: View {
    let memoryMonitor: SystemMemoryMonitor

    private var barColor: Color {
        switch memoryMonitor.warningLevel {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.7))
                        .frame(
                            width: memoryMonitor.totalGB > 0
                                ? geo.size.width * min(memoryMonitor.usedPercentage, 1.0)
                                : 0,
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            HStack {
                Text("RAM: \(String(format: "%.1f", memoryMonitor.usedGB))/\(String(format: "%.0f", memoryMonitor.totalGB)) GB")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.0f%%", memoryMonitor.usedPercentage * 100))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(barColor)
            }
        }
    }
}

struct MemoryWarningBanner: View {
    let warningLevel: MemoryWarningLevel
    let onFreeMemory: () -> Void

    private var bgColor: Color {
        warningLevel == .critical ? Color.red.opacity(0.12) : Color.yellow.opacity(0.12)
    }

    private var iconColor: Color {
        warningLevel == .critical ? .red : .yellow
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: warningLevel == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundStyle(iconColor)
            Text(warningLevel == .critical ? "Memory critical" : "Memory warning")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button("Free Memory") {
                onFreeMemory()
            }
            .font(.system(size: 9))
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 4).fill(bgColor))
    }
}
