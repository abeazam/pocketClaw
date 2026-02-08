import Foundation

// MARK: - Message

struct Message: Codable, Identifiable, Sendable {
    let id: String
    let role: String  // "user", "assistant", "system"
    var content: String
    let timestamp: String?
    var thinking: String?

    init(id: String, role: String, content: String, timestamp: String? = nil, thinking: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.thinking = thinking
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
    var isSystem: Bool { role == "system" }

    /// Whether this message is heartbeat noise that should be filtered
    var isHeartbeat: Bool {
        let upper = content.uppercased()
        return Constants.heartbeatFilterPatterns.contains { pattern in
            upper.contains(pattern)
        }
    }

    /// Extract display text from content, which may be a plain string
    /// or a JSON array of content blocks
    var displayContent: String {
        content
    }

    // MARK: - Parse Content Blocks

    /// Content can be a string OR a JSON array of { type, text/thinking } blocks.
    /// Each item from the server may have data directly or nested under a "message" key.
    /// This handles both patterns: `{ id, role, content }` or `{ message: { id, role, content }, runId, ... }`.
    static func fromServerPayload(_ raw: [String: Any]) -> Message? {
        // The actual message data may be nested under "message" key
        let msg = (raw["message"] as? [String: Any]) ?? raw

        let role = (msg["role"] as? String) ?? "assistant"
        let id = (msg["id"] as? String)
            ?? (raw["runId"] as? String)
            ?? "history-\(UUID().uuidString)"

        var textContent = ""
        var thinkingContent: String?

        let rawContent = msg["content"]
        if let str = rawContent as? String {
            textContent = str
        } else if let blocks = rawContent as? [[String: Any]] {
            for block in blocks {
                let blockType = block["type"] as? String ?? ""
                if blockType == "text", let text = block["text"] as? String {
                    textContent += text
                } else if blockType == "thinking", let thinking = block["thinking"] as? String {
                    thinkingContent = (thinkingContent ?? "") + thinking
                }
            }
        } else if let obj = rawContent as? [String: Any] {
            textContent = (obj["text"] as? String)
                ?? (obj["content"] as? String)
                ?? String(describing: obj)
        }

        // Also check top-level thinking field
        if thinkingContent == nil, let thinking = msg["thinking"] as? String {
            thinkingContent = thinking
        }

        // Timestamp: try several field names from both wrapper and inner message
        let timestamp = (msg["timestamp"] as? String)
            ?? (raw["timestamp"] as? String)
            ?? (msg["ts"] as? String)
            ?? (raw["ts"] as? String)

        return Message(
            id: id,
            role: role,
            content: textContent,
            timestamp: timestamp,
            thinking: thinkingContent
        )
    }
}

// MARK: - Preview Data

extension Message {
    static let previewUser = Message(
        id: "msg-1",
        role: "user",
        content: "Can you explain async/await in Swift?",
        timestamp: "2026-02-07T10:30:00Z"
    )

    static let previewAssistant = Message(
        id: "msg-2",
        role: "assistant",
        content: "Here's how async/await works in Swift...\n\n```swift\nfunc fetchData() async throws -> Data {\n    let url = URL(string: \"https://api.example.com\")!\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return data\n}\n```",
        timestamp: "2026-02-07T10:30:05Z"
    )
}
