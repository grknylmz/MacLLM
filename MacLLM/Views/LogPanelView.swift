import SwiftUI

struct LogPanelView: View {
    let serverManager: ServerManager
    let isVisible: Bool

    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("LOGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(serverManager.serverLogLines.count)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Button {
                        copyLogs()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Button {
                        serverManager.clearLogs()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(serverManager.serverLogLines) { line in
                                HStack(spacing: 4) {
                                    Text(timeFormatter.string(from: line.timestamp))
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(colorForType(line.type).opacity(0.6))
                                        .frame(width: 44, alignment: .leading)
                                    Text(line.text)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(colorForType(line.type))
                                        .textSelection(.enabled)
                                    Spacer()
                                }
                                .id(line.id)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .frame(height: 120)
                    .background(Color.black.opacity(0.85))
                    .onChange(of: serverManager.serverLogLines.count) { _, _ in
                        if autoScroll, let lastId = serverManager.serverLogLines.last?.id {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isVisible)
    }

    private func colorForType(_ type: LogLineType) -> Color {
        switch type {
        case .info: return .green.opacity(0.9)
        case .warning: return .yellow
        case .error: return .red
        case .debug: return .gray
        }
    }

    private func copyLogs() {
        let text = serverManager.serverLogLines.map { line in
            "\(timeFormatter.string(from: line.timestamp)) \(line.text)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }
}
