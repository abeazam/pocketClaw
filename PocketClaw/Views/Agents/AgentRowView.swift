import SwiftUI

// MARK: - Agent Row View

struct AgentRowView: View {
    let agent: Agent
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar / Emoji
            agentAvatar
                .frame(width: 44, height: 44)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.terminalGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.terminalGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if let desc = agent.description ?? agent.theme, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    StatusDotView(status: agent.status ?? "offline")
                    Text(agent.status?.capitalized ?? "Offline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // ID badge
            Text(agent.id)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(agent.name), \(agent.status?.capitalized ?? "Offline")\(isActive ? ", Active agent" : "")")
    }

    // MARK: - Avatar

    @ViewBuilder
    private var agentAvatar: some View {
        if let avatarURL = agent.avatar, let url = resolveAvatarURL(avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                case .failure:
                    emojiFallback
                default:
                    ProgressView()
                        .frame(width: 44, height: 44)
                }
            }
        } else {
            emojiFallback
        }
    }

    private var emojiFallback: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            Text(agent.displayEmoji)
                .font(.title2)
        }
    }

    // MARK: - URL Resolution

    private func resolveAvatarURL(_ rawURL: String) -> URL? {
        // Already a full URL
        if rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://") || rawURL.hasPrefix("data:") {
            return URL(string: rawURL)
        }
        // Server-relative path — would need the server base URL to resolve
        // For now, return nil and use emoji fallback
        return nil
    }
}

// MARK: - Status Dot View

struct StatusDotView: View {
    let status: String

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    private var dotColor: Color {
        switch status {
        case "online": .green
        case "busy": .orange
        default: .gray
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        AgentRowView(agent: .preview, isActive: true)
        AgentRowView(agent: Agent(
            id: "coder",
            name: "Coder",
            description: "Specialized in code review",
            status: "offline",
            emoji: "💻"
        ))
        AgentRowView(agent: Agent(
            id: "writer",
            name: "Writer",
            description: "Creative writing assistant",
            status: "busy",
            emoji: "✍️"
        ))
    }
    .preferredColorScheme(.dark)
}
