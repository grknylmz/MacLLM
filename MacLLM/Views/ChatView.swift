import SwiftUI

struct ChatView: View {
    let chatManager: ChatManager
    let serverManager: ServerManager

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !serverManager.isRunning {
                notRunningView
            } else {
                chatContent
            }
        }
    }

    private var notRunningView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Start a model to chat")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            messageList
            Divider()
            inputBar
        }
    }

    private var chatHeader: some View {
        HStack {
            Text(serverManager.activeModel?.split(separator: "/").last.map(String.init) ?? "Chat")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if !chatManager.messages.isEmpty {
                Button {
                    chatManager.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear chat")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chatManager.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if let streaming = chatManager.streamingContent {
                        MessageBubble(
                            message: ChatMessage(role: "assistant", content: streaming),
                            isStreaming: true
                        )
                        .id("streaming")
                    }

                    if let error = chatManager.errorMessage {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .id("error")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 280)
            .onChange(of: chatManager.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingContent) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if chatManager.streamingContent != nil {
            proxy.scrollTo("streaming", anchor: .bottom)
        } else if chatManager.errorMessage != nil {
            proxy.scrollTo("error", anchor: .bottom)
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .font(.system(size: 11))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit {
                    sendIfNeeded()
                }

            if chatManager.isGenerating {
                Button {
                    chatManager.stopGenerating()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            } else {
                Button {
                    sendIfNeeded()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundStyle(
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary : Color.blue
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func sendIfNeeded() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatManager.sendMessage(inputText)
        inputText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 40) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 0) {
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundStyle(message.role == "user" ? .white : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(message.role == "user" ? Color.blue : Color.gray.opacity(0.15))
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isStreaming {
                            Text("...")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(message.role == "user" ? .white : .secondary)
                                .offset(x: 2)
                        }
                    }
            }

            if message.role == "assistant" { Spacer(minLength: 40) }
        }
    }
}
