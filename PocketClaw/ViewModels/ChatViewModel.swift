import Foundation

// MARK: - Stream Source

/// Tracks which event source is delivering the current stream.
/// First source to send a delta wins — the other is ignored to prevent duplicates.
enum StreamSource {
    case chat
    case agent
}

// MARK: - Chat ViewModel

@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?
    var isStreaming = false
    var streamingContent = ""
    var streamingThinking = ""
    var isThinkingStreaming = false

    /// Whether history has been loaded at least once (prevents re-fetch on re-navigation)
    var hasLoadedHistory = false

    // MARK: - Private

    private let client: OpenClawClient
    private var sessionKey: String = ""
    private var activeStreamSource: StreamSource?
    private let listenerId = UUID().uuidString
    private var thinkingEnabled: Bool = false

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    deinit {
        client.removeEventListener(id: listenerId)
    }

    // MARK: - Public Methods

    func setThinkingEnabled(_ enabled: Bool) {
        thinkingEnabled = enabled
    }

    func startListening(for sessionKey: String) {
        self.sessionKey = sessionKey
        client.addEventListener(id: listenerId) { [weak self] eventName, payload in
            Task { @MainActor [weak self] in
                self?.handleEvent(eventName: eventName, payload: payload)
            }
        }
    }

    func stopListening() {
        client.removeEventListener(id: listenerId)
    }

    func loadHistory(for sessionKey: String) async {
        guard !hasLoadedHistory else { return }
        self.sessionKey = sessionKey
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "chat.history",
                params: ["sessionKey": sessionKey]
            )

            // Server may return a top-level array or { messages: [...] }
            let messagesArray: [Any]
            if let arr = raw as? [Any] {
                messagesArray = arr
            } else if let dict = raw as? [String: Any], let arr = dict["messages"] as? [Any] {
                messagesArray = arr
            } else {
                messagesArray = []
            }

            var parsed: [Message] = []
            for item in messagesArray {
                guard let dict = item as? [String: Any] else { continue }
                if let msg = Message.fromServerPayload(dict) {
                    // Filter heartbeat messages
                    if !msg.isHeartbeat && (!msg.content.isEmpty || msg.thinking != nil) {
                        parsed.append(msg)
                    }
                }
            }

            messages = parsed
            hasLoadedHistory = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message to the list immediately
        let userMessage = Message(
            id: "user-\(UUID().uuidString)",
            role: "user",
            content: trimmed,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(userMessage)

        // Reset streaming state
        streamingContent = ""
        streamingThinking = ""
        isThinkingStreaming = false
        activeStreamSource = nil
        isStreaming = true

        // Send to server
        do {
            var params: [String: Any] = [
                "sessionKey": sessionKey,
                "message": trimmed,
                "idempotencyKey": UUID().uuidString
            ]
            if thinkingEnabled {
                params["thinking"] = "normal"
            }
            _ = try await client.sendRequestPayload(method: "chat.send", params: params)
        } catch {
            // The RPC response just acknowledges the send — streaming comes via events.
            // A timeout here is expected since the server doesn't respond until the full
            // response is generated. Only treat non-timeout errors as failures.
            if case OpenClawError.requestTimeout = error {
                // Expected — response comes via streaming events
            } else {
                errorMessage = "Failed to send: \(error.localizedDescription)"
                isStreaming = false
            }
        }
    }

    // MARK: - Event Handling

    private func handleEvent(eventName: String, payload: [String: Any]) {
        switch eventName {
        case "chat":
            handleChatEvent(payload)
        case "agent":
            handleAgentEvent(payload)
        default:
            break
        }
    }

    // MARK: - Chat Events

    private func handleChatEvent(_ payload: [String: Any]) {
        let state = payload["state"] as? String

        if state == "delta" {
            // If agent stream is already active, ignore chat deltas to prevent duplicates
            if activeStreamSource == .agent { return }
            activeStreamSource = .chat

            // Use delta field for incremental content, NOT message.content which is accumulated
            let chunk = (payload["delta"] as? String)
                ?? ((payload["message"] as? [String: Any])?["delta"] as? String)
                ?? (payload["errorMessage"] as? String)

            if let chunk, !isHeartbeatContent(chunk) {
                streamingContent += chunk
                updateStreamingMessage()
            }
        } else if state == "final" {
            // Only process final if agent wasn't the active source
            if activeStreamSource != .agent, let messageData = payload["message"] as? [String: Any] {
                let text = extractTextFromContent(messageData["content"])
                let thinking = extractThinkingFromContent(messageData["content"])
                    ?? (messageData["thinking"] as? String)

                if !text.isEmpty, !isHeartbeatContent(text) {
                    // Replace streaming message with the final version
                    let finalMessage = Message(
                        id: (messageData["id"] as? String) ?? "msg-\(UUID().uuidString)",
                        role: (messageData["role"] as? String) ?? "assistant",
                        content: text,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        thinking: thinking
                    )
                    replaceStreamingMessage(with: finalMessage)
                }
            }
            finishStreaming()
        }
    }

    // MARK: - Agent Events

    private func handleAgentEvent(_ payload: [String: Any]) {
        let stream = payload["stream"] as? String

        if stream == "assistant" {
            // If chat stream is already active, ignore agent events to prevent duplicates
            if activeStreamSource == .chat { return }
            activeStreamSource = .agent

            // payload.data is { text: string, delta: string }
            let data = payload["data"] as? [String: Any]
            let delta = data?["delta"] as? String

            if let delta, !isHeartbeatContent(delta) {
                streamingContent += delta
                updateStreamingMessage()
            }
        } else if stream == "lifecycle" {
            let phase = (payload["data"] as? [String: Any])?["phase"] as? String
            if phase == "end" || phase == "error" {
                // Don't reset activeStreamSource here — let the chat final event handle cleanup
                // so it knows whether to skip its duplicate message.
                if phase == "error" {
                    let errorData = (payload["data"] as? [String: Any])?["error"] as? String
                    if let errorData {
                        errorMessage = errorData
                    }
                }
            }
        }
    }

    // MARK: - Streaming Helpers

    private func updateStreamingMessage() {
        // Find or create the streaming assistant message
        let streamingId = "streaming-\(sessionKey)"

        if let index = messages.firstIndex(where: { $0.id == streamingId }) {
            messages[index].content = streamingContent
            if !streamingThinking.isEmpty {
                messages[index].thinking = streamingThinking
            }
        } else {
            let msg = Message(
                id: streamingId,
                role: "assistant",
                content: streamingContent,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                thinking: streamingThinking.isEmpty ? nil : streamingThinking
            )
            messages.append(msg)
        }
    }

    private func replaceStreamingMessage(with finalMessage: Message) {
        let streamingId = "streaming-\(sessionKey)"
        if let index = messages.firstIndex(where: { $0.id == streamingId }) {
            messages[index] = finalMessage
        } else {
            // No streaming message exists, just append
            messages.append(finalMessage)
        }
    }

    private func finishStreaming() {
        // If we have streaming content but no final message arrived, keep what we have
        // and give it a permanent ID
        let streamingId = "streaming-\(sessionKey)"
        if let index = messages.firstIndex(where: { $0.id == streamingId }) {
            let existing = messages[index]
            messages[index] = Message(
                id: "msg-\(UUID().uuidString)",
                role: existing.role,
                content: existing.content,
                timestamp: existing.timestamp,
                thinking: existing.thinking
            )
        }

        isStreaming = false
        streamingContent = ""
        streamingThinking = ""
        isThinkingStreaming = false
        activeStreamSource = nil
    }

    // MARK: - Content Extraction

    private func extractTextFromContent(_ content: Any?) -> String {
        if let str = content as? String { return str }
        if let blocks = content as? [[String: Any]] {
            return blocks
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
        if let obj = content as? [String: Any] {
            return (obj["text"] as? String) ?? (obj["content"] as? String) ?? ""
        }
        return ""
    }

    private func extractThinkingFromContent(_ content: Any?) -> String? {
        guard let blocks = content as? [[String: Any]] else { return nil }
        let thinkingTexts = blocks
            .filter { ($0["type"] as? String) == "thinking" }
            .compactMap { $0["thinking"] as? String }
        return thinkingTexts.isEmpty ? nil : thinkingTexts.joined()
    }

    private func isHeartbeatContent(_ text: String) -> Bool {
        let upper = text.uppercased()
        return Constants.heartbeatFilterPatterns.contains { pattern in
            upper.contains(pattern)
        }
    }
}
