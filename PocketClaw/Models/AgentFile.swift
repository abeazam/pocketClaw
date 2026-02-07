import Foundation

// MARK: - Agent File

struct AgentFile: Codable, Identifiable, Sendable {
    let name: String
    let path: String?
    let missing: Bool?
    let size: Int?
    let updatedAtMs: Int?
    var content: String?

    var id: String { name }

    var isMissing: Bool { missing ?? false }

    var formattedSize: String {
        guard let size else { return "—" }
        if size < 1024 {
            return "\(size) B"
        } else {
            let kb = Double(size) / 1024.0
            return String(format: "%.1f KB", kb)
        }
    }
}

// MARK: - Preview Data

extension AgentFile {
    static let preview = AgentFile(
        name: "IDENTITY.md",
        path: "/home/claw/agents/claude/IDENTITY.md",
        missing: false,
        size: 2100,
        updatedAtMs: 1738900000000,
        content: nil
    )
}
