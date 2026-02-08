import Foundation

// MARK: - Agent

struct Agent: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var description: String?
    var status: String?  // "online", "offline", "busy"
    var avatar: String?
    var emoji: String?
    var theme: String?

    var isOnline: Bool { status == "online" }
    var isBusy: Bool { status == "busy" }

    var displayEmoji: String {
        // Clean up emoji — filter out invalid values like ClawControl does
        if let emoji, !emoji.isEmpty,
           !emoji.contains("none"), !emoji.contains("*"),
           emoji.count <= 4 {
            return emoji
        }
        return "🤖"
    }

    var statusColor: String {
        switch status {
        case "online": "green"
        case "busy": "orange"
        default: "gray"
        }
    }

    // MARK: - Custom Decoding

    // Server returns agents with nested identity: { agentId, identity: { name, emoji, avatar }, status, ... }
    // We flatten this into a single Agent struct.

    enum CodingKeys: String, CodingKey {
        case id, agentId
        case name, description, status
        case avatar, avatarUrl
        case emoji, theme
        case identity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID: try agentId first, then id
        id = try container.decodeIfPresent(String.self, forKey: .agentId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString

        // Identity may be nested
        let identity = try? container.decodeIfPresent(AgentIdentity.self, forKey: .identity)

        // Name: identity.name > top-level name > id
        name = identity?.name
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? id

        // Description: top-level description > identity theme
        description = try? container.decodeIfPresent(String.self, forKey: .description)

        status = try? container.decodeIfPresent(String.self, forKey: .status)

        // Avatar: identity.avatarUrl > identity.avatar > top-level avatarUrl > top-level avatar
        avatar = identity?.avatarUrl
            ?? identity?.avatar
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatarUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatar))

        // Emoji: identity.emoji > top-level emoji
        emoji = identity?.emoji
            ?? (try? container.decodeIfPresent(String.self, forKey: .emoji))

        // Theme: identity.theme > top-level theme
        theme = identity?.theme
            ?? (try? container.decodeIfPresent(String.self, forKey: .theme))

        // If no description but theme exists, use theme as description
        if description == nil, let theme {
            description = theme
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(theme, forKey: .theme)
    }

    // Manual init for previews and local construction
    init(id: String, name: String, description: String? = nil, status: String? = nil,
         avatar: String? = nil, emoji: String? = nil, theme: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.avatar = avatar
        self.emoji = emoji
        self.theme = theme
    }
}

// MARK: - Agent Identity (nested server field)

private struct AgentIdentity: Codable, Sendable {
    let name: String?
    let emoji: String?
    let avatar: String?
    let avatarUrl: String?
    let theme: String?
}

// MARK: - Hashable

extension Agent: Hashable {
    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Data

extension Agent {
    static let preview = Agent(
        id: "main",
        name: "Claude",
        description: "General purpose assistant",
        status: "online",
        avatar: nil,
        emoji: "🤖",
        theme: "Helpful and thorough"
    )

    static let previewList: [Agent] = [
        Agent(id: "main", name: "Main Agent", description: "General purpose assistant", status: "online", emoji: "🤖"),
        Agent(id: "coder", name: "Coder", description: "Specialized in code review", status: "offline", emoji: "💻"),
        Agent(id: "writer", name: "Writer", description: "Creative writing assistant", status: "busy", emoji: "✍️")
    ]
}
