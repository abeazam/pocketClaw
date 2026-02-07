import Foundation

// MARK: - Agent

struct Agent: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    var status: String?  // "online", "offline", "busy"
    let avatar: String?
    let emoji: String?
    let theme: String?

    var isOnline: Bool { status == "online" }
    var isBusy: Bool { status == "busy" }

    var displayEmoji: String {
        emoji ?? "🤖"
    }
}

// MARK: - Preview Data

extension Agent {
    static let preview = Agent(
        id: "claude",
        name: "Claude",
        description: "General purpose assistant",
        status: "online",
        avatar: nil,
        emoji: "🤖",
        theme: "Helpful and thorough"
    )
}
