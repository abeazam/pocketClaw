import Foundation

// MARK: - Skill

struct Skill: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let triggers: [String]?
    var enabled: Bool?
    let content: String?
    let emoji: String?
    let homepage: String?
    let source: String?
    let bundled: Bool?
    let filePath: String?
    let eligible: Bool?
    let always: Bool?
    let requirements: SkillRequirements?
    let missing: SkillRequirements?
    let install: [SkillInstallOption]?

    // ClawControl treats undefined enabled as true: `enabled !== false`
    var isEnabled: Bool { enabled != false }
    var isEligible: Bool { eligible ?? true }
    var hasMissingDeps: Bool {
        guard let missing else { return false }
        return !(missing.bins ?? []).isEmpty
            || !(missing.env ?? []).isEmpty
            || !(missing.config ?? []).isEmpty
    }

    var displayEmoji: String {
        emoji ?? "🔧"
    }

    // id may come as "skillKey" or "key" from server
    enum CodingKeys: String, CodingKey {
        case id, name, description, triggers, enabled, disabled, content, emoji
        case homepage, source, bundled, filePath, eligible, always
        case requirements, missing, install, key, skillKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID: try skillKey, id, key, name
        id = try container.decodeIfPresent(String.self, forKey: .skillKey)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .key)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UUID().uuidString

        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        triggers = try container.decodeIfPresent([String].self, forKey: .triggers)

        // ClawControl: enabled = !s.disabled — server may send `disabled` instead of `enabled`
        if let explicitEnabled = try? container.decodeIfPresent(Bool.self, forKey: .enabled) {
            enabled = explicitEnabled
        } else if let disabled = try? container.decodeIfPresent(Bool.self, forKey: .disabled) {
            enabled = !disabled
        } else {
            enabled = nil // treated as enabled by isEnabled
        }

        content = try container.decodeIfPresent(String.self, forKey: .content)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        bundled = try container.decodeIfPresent(Bool.self, forKey: .bundled)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        eligible = try container.decodeIfPresent(Bool.self, forKey: .eligible)
        always = try container.decodeIfPresent(Bool.self, forKey: .always)
        requirements = try container.decodeIfPresent(SkillRequirements.self, forKey: .requirements)
        missing = try container.decodeIfPresent(SkillRequirements.self, forKey: .missing)
        install = try container.decodeIfPresent([SkillInstallOption].self, forKey: .install)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(triggers, forKey: .triggers)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(homepage, forKey: .homepage)
    }

    // Manual init for previews
    init(id: String, name: String, description: String? = nil, triggers: [String]? = nil,
         enabled: Bool? = nil, content: String? = nil, emoji: String? = nil,
         homepage: String? = nil, source: String? = nil, bundled: Bool? = nil,
         filePath: String? = nil, eligible: Bool? = nil, always: Bool? = nil,
         requirements: SkillRequirements? = nil, missing: SkillRequirements? = nil,
         install: [SkillInstallOption]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.triggers = triggers
        self.enabled = enabled
        self.content = content
        self.emoji = emoji
        self.homepage = homepage
        self.source = source
        self.bundled = bundled
        self.filePath = filePath
        self.eligible = eligible
        self.always = always
        self.requirements = requirements
        self.missing = missing
        self.install = install
    }
}

// MARK: - Hashable

extension Skill: Hashable {
    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id && lhs.enabled == rhs.enabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Skill Requirements

struct SkillRequirements: Codable, Sendable {
    let bins: [String]?
    let anyBins: [String]?
    let env: [String]?
    let config: [String]?
    let os: [String]?
}

// MARK: - Skill Install Option

struct SkillInstallOption: Codable, Identifiable, Sendable {
    let id: String
    let kind: String?
    let label: String?
    let bins: [String]?
}

// MARK: - Preview Data

extension Skill {
    static let preview = Skill(
        id: "web-search",
        name: "web-search",
        description: "Search the web for information",
        triggers: ["/search", "@web"],
        enabled: true,
        emoji: "🔍",
        source: "bundled",
        bundled: true,
        eligible: true
    )

    static let previewList: [Skill] = [
        Skill(id: "web-search", name: "web-search", description: "Search the web",
              triggers: ["/search"], enabled: true, emoji: "🔍", eligible: true),
        Skill(id: "code-exec", name: "code-exec", description: "Execute code snippets",
              triggers: ["/run", "/exec"], enabled: true, emoji: "💻", eligible: true),
        Skill(id: "image-gen", name: "image-gen", description: "Generate images from text",
              triggers: ["/imagine"], enabled: false, emoji: "🎨", eligible: false,
              missing: SkillRequirements(bins: ["imagemagick"], anyBins: nil, env: ["OPENAI_KEY"], config: nil, os: nil))
    ]
}
