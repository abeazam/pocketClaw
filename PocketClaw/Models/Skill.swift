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

    var isEnabled: Bool { enabled ?? false }
    var isEligible: Bool { eligible ?? true }

    var displayEmoji: String {
        emoji ?? "🔧"
    }

    // id may come as "key" from some endpoints
    enum CodingKeys: String, CodingKey {
        case id, name, description, triggers, enabled, content, emoji
        case homepage, source, bundled, filePath, eligible, always
        case requirements, missing, install, key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .key)
            ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        triggers = try container.decodeIfPresent([String].self, forKey: .triggers)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
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
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(bundled, forKey: .bundled)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(eligible, forKey: .eligible)
        try container.encodeIfPresent(always, forKey: .always)
        try container.encodeIfPresent(requirements, forKey: .requirements)
        try container.encodeIfPresent(missing, forKey: .missing)
        try container.encodeIfPresent(install, forKey: .install)
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
    static let preview: Skill = {
        let json = """
        {"id":"web-search","name":"web-search","description":"Search the web for information","triggers":["search","web"],"enabled":true,"emoji":"🔍","source":"bundled","bundled":true,"eligible":true}
        """
        return try! JSONDecoder().decode(Skill.self, from: json.data(using: .utf8)!)
    }()
}
