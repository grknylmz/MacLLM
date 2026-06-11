import Foundation
import Observation

@Observable
@MainActor
class ChatManager {
    var messages: [ChatMessage] = []
    var isGenerating = false
    var streamingContent: String?
    var errorMessage: String?

    @ObservationIgnored private weak var serverManager: ServerManager?
    @ObservationIgnored private var currentTask: Task<Void, Never>?

    init(serverManager: ServerManager) {
        self.serverManager = serverManager
    }

    var canChat: Bool {
        serverManager?.isRunning == true
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canChat, !isGenerating else { return }

        messages.append(ChatMessage(role: "user", content: trimmed))
        isGenerating = true
        streamingContent = ""
        errorMessage = nil

        currentTask = Task { @MainActor in
            await performStreamingRequest()
        }
    }

    func stopGenerating() {
        currentTask?.cancel()
        currentTask = nil
        if let partial = streamingContent, !partial.isEmpty {
            messages.append(ChatMessage(role: "assistant", content: partial))
        }
        streamingContent = nil
        isGenerating = false
    }

    func clearChat() {
        currentTask?.cancel()
        currentTask = nil
        messages = []
        streamingContent = nil
        isGenerating = false
        errorMessage = nil
    }

    private func performStreamingRequest() async {
        guard let serverManager else { return }
        let port = serverManager.serverPort
        let model = serverManager.activeModel ?? ""

        let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let apiMessages = messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "stream": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            handleError("Failed to build request")
            return
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line
                    if errorBody.count > 1024 { break }
                }
                handleError("Server error (\(httpResponse.statusCode)): \(errorBody)")
                return
            }

            var accumulated = ""
            for try await line in bytes.lines {
                guard !Task.isCancelled else { return }

                guard line.hasPrefix("data: ") else { continue }
                let dataStr = String(line.dropFirst(6))

                if dataStr.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                    break
                }

                guard let jsonData = dataStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String
                else { continue }

                accumulated += content
                streamingContent = accumulated
            }

            if !accumulated.isEmpty {
                messages.append(ChatMessage(role: "assistant", content: accumulated))
            }
            streamingContent = nil
            isGenerating = false
        } catch is CancellationError {
            if let partial = streamingContent, !partial.isEmpty {
                messages.append(ChatMessage(role: "assistant", content: partial))
            }
            streamingContent = nil
            isGenerating = false
        } catch {
            handleError("Connection failed: \(error.localizedDescription)")
        }
    }

    private func handleError(_ message: String) {
        errorMessage = message
        streamingContent = nil
        isGenerating = false
    }
}
