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

    // Channel & classification fields from server
    let kind: String?          // "direct", "group", "global", "unknown"
    let channel: String?       // "telegram", "whatsapp", "discord", "slack", "signal", "imessage", "webchat", etc.
    let chatType: String?      // "direct", "group", "channel"
    let subject: String?       // Group subject line
    let groupChannel: String?  // e.g. "#general" for Slack/Discord
    let lastChannel: String?   // Last delivery channel used

    // Server field names vary — handle all known aliases
    enum CodingKeys: String, CodingKey {
        case id, key, sessionId
        case title, label, derivedTitle, displayName
        case agentId
        case createdAt, updatedAt
        case lastMessage, lastMessagePreview
        case kind, channel, chatType, subject, groupChannel, lastChannel
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

        // Title: prefer user-set label over derived/auto-generated title
        // ClawControl uses: s.title || s.label || s.key
        // Server returns label (user-set) separately from derivedTitle (AI-generated).
        // When user renames via sessions.patch({label}), the label field reflects it.
        let label = try container.decodeIfPresent(String.self, forKey: .label)
        let serverTitle = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .derivedTitle)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
        title = label ?? serverTitle ?? key

        agentId = try container.decodeIfPresent(String.self, forKey: .agentId)

        // Timestamps: server sends either ISO string or epoch number (milliseconds)
        createdAt = Self.decodeFlexibleTimestamp(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleTimestamp(from: container, forKey: .updatedAt)

        // Last message preview — filter out heartbeat noise
        let rawPreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
            ?? container.decodeIfPresent(String.self, forKey: .lastMessage)
        if let preview = rawPreview {
            let upper = preview.uppercased()
            let isHeartbeat = Constants.heartbeatFilterPatterns.contains { upper.contains($0) }
            lastMessage = isHeartbeat ? nil : preview
        } else {
            lastMessage = nil
        }

        // Channel & classification
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        chatType = try container.decodeIfPresent(String.self, forKey: .chatType)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        groupChannel = try container.decodeIfPresent(String.self, forKey: .groupChannel)
        lastChannel = try container.decodeIfPresent(String.self, forKey: .lastChannel)

        // Channel: try explicit field first, then infer from lastChannel, then from session key
        let explicitChannel = try container.decodeIfPresent(String.self, forKey: .channel)
        channel = explicitChannel ?? lastChannel ?? Self.inferChannel(from: key)
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
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(channel, forKey: .channel)
        try container.encodeIfPresent(chatType, forKey: .chatType)
    }

    // Manual init for previews and local creation
    init(id: String, key: String, title: String, agentId: String? = nil,
         createdAt: String? = nil, updatedAt: String? = nil, lastMessage: String? = nil,
         kind: String? = nil, channel: String? = nil, chatType: String? = nil,
         subject: String? = nil, groupChannel: String? = nil, lastChannel: String? = nil) {
        self.id = id
        self.key = key
        self.title = title
        self.agentId = agentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessage = lastMessage
        self.kind = kind
        self.channel = channel
        self.chatType = chatType
        self.subject = subject
        self.groupChannel = groupChannel
        self.lastChannel = lastChannel
    }

    // MARK: - Computed Properties

    /// Smart display title — replaces ugly server titles with descriptive names
    var displayTitle: String {
        // Main session: show agent name (e.g. "Main" for agent:main, "Mini" for agent:mini)
        if isMainSession {
            return mainSessionTitle
        }

        // Use subject if available (e.g. group chat subject)
        if let subject, !subject.isEmpty { return subject }

        // Use groupChannel if available (e.g. "#general")
        if let groupChannel, !groupChannel.isEmpty { return groupChannel }

        // Strip timestamp prefix like "[Mon 2026-02-09 19:32 GMT] How many claws..."
        let cleaned = Self.stripTimestampPrefix(title)

        // Check if the cleaned title looks like garbage (hex IDs, raw keys)
        if looksLikeGarbage(cleaned) {
            return friendlyFallbackTitle
        }

        return cleaned
    }

    /// The agent ID extracted from the session key (position 1)
    var agentName: String? {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count >= 2, parts[0] == "agent" else { return nil }
        return parts[1]
    }

    /// Title for main sessions — includes agent name and channel if present
    private var mainSessionTitle: String {
        let agent = agentName ?? "main"
        let name = agent == "main" ? "Main" : agent.capitalized

        // If the main session has a channel (e.g. Telegram DMs routed to main), show it
        if let ch = effectiveChannel, ch != "webchat", ch != "gateway" {
            return "\(name) (\(channelLabel))"
        }
        return name
    }

    /// Whether this is the main/default session (e.g. "agent:main:main")
    /// Only matches keys like "agent:<agentId>:main" — exactly 3 parts
    var isMainSession: Bool {
        let parts = key.split(separator: ":")
        return parts.count == 3 && parts.last == "main"
    }

    /// Whether this is an app/webchat session (created from PocketClaw or ClawControl)
    var isAppSession: Bool {
        let ch = effectiveChannel
        return ch == nil || ch == "webchat" || ch == "gateway"
    }

    /// The effective channel for grouping — uses explicit channel, lastChannel, or infers from key
    var effectiveChannel: String? {
        channel
    }

    /// Whether this is a group chat
    var isGroup: Bool {
        chatType == "group" || chatType == "channel" || kind == "group"
            || key.contains(":group:") || key.contains(":channel:")
    }

    /// SF Symbol icon for the channel
    var channelIcon: String {
        switch effectiveChannel {
        case "telegram": "paperplane.fill"
        case "whatsapp": "phone.fill"
        case "discord": "gamecontroller.fill"
        case "slack": "number"
        case "signal": "lock.shield.fill"
        case "imessage": "message.fill"
        case "googlechat": "bubble.left.and.text.bubble.right.fill"
        case "email": "envelope.fill"
        case "webchat", "gateway": "globe"
        default: "bubble.left.fill"
        }
    }

    /// Display label for the channel
    var channelLabel: String {
        switch effectiveChannel {
        case "telegram": "Telegram"
        case "whatsapp": "WhatsApp"
        case "discord": "Discord"
        case "slack": "Slack"
        case "signal": "Signal"
        case "imessage": "iMessage"
        case "googlechat": "Google Chat"
        case "email": "Email"
        case "webchat", "gateway": "Web"
        case let ch?: ch.capitalized
        case nil: "App"
        }
    }

    /// Chat type label (DM vs Group)
    var chatTypeLabel: String? {
        if isGroup { return "Group" }
        if chatType == "direct" || kind == "direct" { return "DM" }
        return nil
    }

    // MARK: - Title Helpers

    /// Strips timestamp prefixes like "[Mon 2026-02-09 19:32 GMT] " from server-generated titles
    private static func stripTimestampPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Pattern: "[Day YYYY-MM-DD HH:MM ...] actual title"
        if trimmed.hasPrefix("["), let closeBracket = trimmed.firstIndex(of: "]") {
            let afterBracket = trimmed.index(after: closeBracket)
            let rest = String(trimmed[afterBracket...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty {
                return rest
            }
            // The entire title was inside brackets — treat as garbage
        }
        return trimmed
    }

    /// Detects ugly/meaningless server-generated titles
    private func looksLikeGarbage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty or just the key
        if trimmed.isEmpty || trimmed == key { return true }
        // Hex IDs like "6ff4e889" or "6ff4e889 (2026-02-08)"
        let hexPart = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        if hexPart.count >= 6, hexPart.unicodeScalars.allSatisfy({ hexChars.contains($0) }) {
            return true
        }
        // Raw agent key patterns
        if trimmed.hasPrefix("agent:") { return true }
        return false
    }

    /// Whether this is a cron job session
    var isCronSession: Bool {
        key.contains(":cron:")
    }

    /// Whether this session was created by an automated/non-human source
    /// (cron jobs, webhooks, subagents, ACP agents)
    var isAutomated: Bool {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count >= 3, parts[0] == "agent" else { return false }
        // The "rest" portion starts at parts[2]
        let rest = parts[2]
        return rest == "cron" || rest == "hook" || rest == "subagent" || rest == "acp"
    }

    /// Label for the automation source type
    var automationSourceLabel: String? {
        guard isAutomated else { return nil }
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count >= 3 else { return nil }
        switch parts[2] {
        case "cron": return "Cron"
        case "hook":
            if parts.count >= 4, parts[3] == "gmail" { return "Gmail" }
            return "Webhook"
        case "subagent": return "Subagent"
        case "acp": return "ACP"
        default: return nil
        }
    }

    /// Builds a friendly fallback title from channel + chat type
    private var friendlyFallbackTitle: String {
        // Cron sessions with garbage titles
        if isCronSession {
            let agent = agentName ?? "main"
            let name = agent == "main" ? "" : " (\(agent.capitalized))"
            return "Cron Job\(name)"
        }
        if let ch = effectiveChannel, ch != "webchat", ch != "gateway" {
            let label = channelLabel
            if let typeLabel = chatTypeLabel {
                return "\(label) \(typeLabel)"
            }
            return label
        }
        return "Untitled Chat"
    }

    // MARK: - Channel Inference from Session Key

    /// Infer channel from session key patterns like "agent:main:telegram:direct:123"
    private static func inferChannel(from key: String) -> String? {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count >= 3, parts[0] == "agent" else { return nil }
        // parts[0] = "agent", parts[1] = agentId, parts[2+] = rest
        // Known channel names that appear in position 2
        let knownChannels: Set<String> = [
            "telegram", "whatsapp", "discord", "slack", "signal",
            "imessage", "googlechat", "email", "msteams", "matrix"
        ]
        if parts.count > 2, knownChannels.contains(parts[2]) {
            return parts[2]
        }
        // "session-TIMESTAMP" pattern = app session
        if parts.count >= 3, parts[2].hasPrefix("session-") {
            return nil // app session
        }
        // "main" = main session
        if parts.count == 3, parts[2] == "main" {
            return nil
        }
        return nil
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
        key: "agent:main:session-1",
        title: "Help me with Swift code",
        agentId: "main",
        createdAt: "2026-02-07T10:00:00Z",
        updatedAt: "2026-02-07T12:30:00Z",
        lastMessage: "Sure, I can help with that..."
    )

    static let previewList: [Session] = [
        Session(id: "main", key: "agent:main:main", title: "Main Session",
                updatedAt: "2026-02-09T10:00:00Z", lastMessage: "Welcome back!",
                kind: "direct"),
        Session(id: "s1", key: "agent:main:session-1770510145233", title: "Swift async/await help",
                updatedAt: "2026-02-09T09:30:00Z", lastMessage: "Here's how async works..."),
        Session(id: "s2", key: "agent:main:session-1770510145234", title: "Code review",
                updatedAt: "2026-02-08T14:00:00Z", lastMessage: "The PR looks good overall"),
        Session(id: "tg1", key: "agent:main:telegram:direct:123456", title: "Alice",
                updatedAt: "2026-02-09T08:00:00Z", lastMessage: "Got it, thanks!",
                kind: "direct", channel: "telegram", chatType: "direct"),
        Session(id: "tg2", key: "agent:main:telegram:group:-100999", title: "Dev Team",
                updatedAt: "2026-02-09T07:00:00Z", lastMessage: "Deploy is done",
                kind: "group", channel: "telegram", chatType: "group",
                subject: "Dev Team Chat"),
        Session(id: "wa1", key: "agent:main:whatsapp:direct:+15551234", title: "Bob",
                updatedAt: "2026-02-08T20:00:00Z", lastMessage: "See you tomorrow",
                kind: "direct", channel: "whatsapp", chatType: "direct"),
        Session(id: "dc1", key: "agent:main:discord:channel:general", title: "#general",
                updatedAt: "2026-02-08T18:00:00Z", lastMessage: "New release is out",
                kind: "group", channel: "discord", chatType: "channel",
                groupChannel: "#general")
    ]
}
