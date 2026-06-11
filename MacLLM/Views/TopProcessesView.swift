import SwiftUI

struct TopProcessesView: View {
    let memoryMonitor: SystemMemoryMonitor

    @State private var killConfirmation: AppProcessInfo?

    var body: some View {
        VStack(spacing: 0) {
            if !memoryMonitor.topProcesses.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text("TOP CONSUMERS")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 2)

                ForEach(memoryMonitor.topProcesses) { proc in
                    ProcessRow(
                        process: proc,
                        onKill: { killConfirmation = proc }
                    )
                }
            }
        }
        .alert("Kill Process?", isPresented: Binding(
            get: { killConfirmation != nil },
            set: { if !$0 { killConfirmation = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                killConfirmation = nil
            }
            Button("Kill", role: .destructive) {
                if let proc = killConfirmation {
                    _ = memoryMonitor.killProcess(pid: proc.pid)
                    killConfirmation = nil
                }
            }
        } message: {
            if let proc = killConfirmation {
                Text("\"\(proc.name)\" (PID: \(proc.pid)) is using \(proc.formattedMemory). This will force-quit the process.")
            }
        }
    }
}

struct ProcessRow: View {
    let process: AppProcessInfo
    let onKill: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: process.isMLX ? "brain" : "app.dashed")
                .font(.system(size: 9))
                .foregroundStyle(process.isMLX ? .blue : .secondary)
                .frame(width: 14)

            Text(process.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if process.isMLX {
                Text("MLX")
                    .font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(2)
            }

            Spacer()

            Text(process.formattedMemory)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(memoryColor(for: process.memoryMB).opacity(0.12))
                .cornerRadius(3)
                .foregroundStyle(memoryColor(for: process.memoryMB))

            Button {
                onKill()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(process.isMLX ? Color.blue.opacity(0.04) : Color.clear)
        )
    }

    private func memoryColor(for mb: Double) -> Color {
        if mb >= 2048 { return .red }
        if mb >= 512 { return .orange }
        return .secondary
    }
}
