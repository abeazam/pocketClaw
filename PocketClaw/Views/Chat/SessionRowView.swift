import SwiftUI

// MARK: - Session Row View

struct SessionRowView: View {
    let session: Session
    var isPinned: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Channel icon for non-app sessions
            if !session.isAppSession {
                Image(systemName: session.channelIcon)
                    .font(.caption)
                    .foregroundStyle(channelColor)
                    .frame(width: 20, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack(spacing: 6) {
                    if session.isMainSession {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.terminalGreen)
                    } else if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(session.displayTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // DM / Group badge for channel sessions
                    if let badge = session.chatTypeLabel, !session.isAppSession {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(badgeColor.opacity(0.2))
                            .foregroundStyle(badgeColor)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let updatedAt = session.updatedAt {
                        Text(updatedAt.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Last message preview
                if let lastMessage = session.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Colors

    private var channelColor: Color {
        switch session.effectiveChannel {
        case "telegram": .blue
        case "whatsapp": .green
        case "discord": .purple
        case "slack": .orange
        case "signal": .blue
        case "imessage": .green
        default: .secondary
        }
    }

    private var badgeColor: Color {
        session.isGroup ? .orange : .blue
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = []
        if session.isMainSession { parts.append("Main session") }
        if isPinned { parts.append("Pinned") }
        if !session.isAppSession { parts.append(session.channelLabel) }
        if let badge = session.chatTypeLabel { parts.append(badge) }
        parts.append(session.displayTitle)
        if let msg = session.lastMessage { parts.append("Last message: \(msg)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("App Sessions") {
            SessionRowView(session: .preview)
            SessionRowView(
                session: Session(
                    id: "main", key: "agent:main:main", title: "Main Session",
                    updatedAt: "2026-02-09T10:00:00Z", lastMessage: "Welcome back!"
                ),
                isPinned: true
            )
        }
        Section("Telegram") {
            SessionRowView(session: Session(
                id: "tg1", key: "agent:main:telegram:direct:123", title: "Alice",
                updatedAt: "2026-02-09T08:00:00Z", lastMessage: "Got it, thanks!",
                kind: "direct", channel: "telegram", chatType: "direct"
            ))
            SessionRowView(session: Session(
                id: "tg2", key: "agent:main:telegram:group:-100999", title: "Dev Team",
                updatedAt: "2026-02-09T07:00:00Z", lastMessage: "Deploy is done",
                kind: "group", channel: "telegram", chatType: "group", subject: "Dev Team Chat"
            ))
        }
        Section("Discord") {
            SessionRowView(session: Session(
                id: "dc1", key: "agent:main:discord:channel:general", title: "#general",
                updatedAt: "2026-02-08T18:00:00Z", lastMessage: "New release is out",
                kind: "group", channel: "discord", chatType: "channel", groupChannel: "#general"
            ))
        }
    }
    .preferredColorScheme(.dark)
}
