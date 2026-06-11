import SwiftUI

struct MemoryControlsView: View {
    let memoryMonitor: SystemMemoryMonitor
    let serverManager: ServerManager

    @AppStorage("cacheLimitGB") private var cacheLimitGB: Double = 0
    @AppStorage("memoryWarningThreshold") private var memoryWarningThreshold: Double = 0.9
    @State private var showFreeMemoryConfirmation = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Cache Limit")
                    .font(.system(size: 11))
                Spacer()
                if cacheLimitGB == 0 {
                    Text("Auto")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(cacheLimitGB)) GB")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 8) {
                Text("Auto")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Slider(value: $cacheLimitGB, in: 0...64, step: 1) {
                    Text("Cache Limit")
                }
                Text("64 GB")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Memory Warning")
                    .font(.system(size: 11))
                Spacer()
                Text("\(Int(memoryWarningThreshold * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(memoryMonitor.usedPercentage >= memoryWarningThreshold ? .red : .primary)
            }

            HStack(spacing: 8) {
                Text("50%")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Slider(value: $memoryWarningThreshold, in: 0.5...0.95, step: 0.05) {
                    Text("Memory Warning Threshold")
                }
                Text("95%")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Memory")
                        .font(.system(size: 11, weight: .medium))
                    Text("Restart server to release allocated memory")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Free Now") {
                    showFreeMemoryConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 10))
                .disabled(!serverManager.isRunning)
                .alert("Free Memory", isPresented: $showFreeMemoryConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Restart Server") {
                        Task { await serverManager.freeMemory() }
                    }
                } message: {
                    Text("This will restart the server to free memory. Any active requests will be interrupted.")
                }
            }
        }
    }
}
