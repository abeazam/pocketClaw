import Foundation

// MARK: - Session

struct Session: Codable, Identifiable, Sendable {
    let id: String
    let key: String
    var title: String
    let agentId: String?
    let createdAt: String?
    let updatedAt: String?
    var lastMessage: String?

    // Server field names vary — handle all known aliases
    enum CodingKeys: String, CodingKey {
        case id, key, sessionId
        case title, label, derivedTitle, displayName
        case agentId
        case createdAt, updatedAt
        case lastMessage, lastMessagePreview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID: try id, sessionId, key
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .sessionId)
            ?? container.decodeIfPresent(String.self, forKey: .key)
            ?? UUID().uuidString
        key = try container.decodeIfPresent(String.self, forKey: .key)
            ?? container.decodeIfPresent(String.self, forKey: .sessionId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? id

        // Title: try title, derivedTitle, displayName, label, fall back to key
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .derivedTitle)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? key

        agentId = try container.decodeIfPresent(String.self, forKey: .agentId)

        // Timestamps: server sends either ISO string or epoch number (milliseconds)
        createdAt = Self.decodeFlexibleTimestamp(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleTimestamp(from: container, forKey: .updatedAt)

        // Last message preview
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
            ?? container.decodeIfPresent(String.self, forKey: .lastMessage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
    }

    // Manual init for previews
    init(id: String, key: String, title: String, agentId: String? = nil,
         createdAt: String? = nil, updatedAt: String? = nil, lastMessage: String? = nil) {
        self.id = id
        self.key = key
        self.title = title
        self.agentId = agentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessage = lastMessage
    }

    // MARK: - Flexible Timestamp Decoding

    /// Decodes a timestamp that could be an ISO string or a numeric epoch (milliseconds or seconds).
    private static func decodeFlexibleTimestamp(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        // Try string first
        if let str = try? container.decodeIfPresent(String.self, forKey: key) {
            return str
        }
        // Try as number (epoch milliseconds)
        if let epochMs = try? container.decodeIfPresent(Double.self, forKey: key) {
            // Heuristic: if > 1e12 it's milliseconds, otherwise seconds
            let seconds = epochMs > 1e12 ? epochMs / 1000.0 : epochMs
            let date = Date(timeIntervalSince1970: seconds)
            return ISO8601DateFormatter().string(from: date)
        }
        // Try as Int epoch
        if let epochInt = try? container.decodeIfPresent(Int.self, forKey: key) {
            let seconds = epochInt > 1_000_000_000_000 ? Double(epochInt) / 1000.0 : Double(epochInt)
            let date = Date(timeIntervalSince1970: seconds)
            return ISO8601DateFormatter().string(from: date)
        }
        return nil
    }
}

// MARK: - Preview Data

extension Session {
    static let preview = Session(
        id: "session-1",
        key: "session-1",
        title: "Help me with Swift code",
        agentId: "claude",
        createdAt: "2026-02-07T10:00:00Z",
        updatedAt: "2026-02-07T12:30:00Z",
        lastMessage: "Sure, I can help with that..."
    )
}
