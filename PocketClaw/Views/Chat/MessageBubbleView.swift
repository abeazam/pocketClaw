import SwiftUI

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Role label + time
                HStack(spacing: 4) {
                    if !message.isUser {
                        Text(message.role.capitalized)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let ts = message.timestamp {
                        Text(ts.timeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if message.isUser {
                        Text("You")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Message content
                Text(LocalizedStringKey(message.displayContent))
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser ? Color.userBubble : Color.assistantBubble
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("\(message.isUser ? "You" : "Assistant") said: \(message.content)")
                    .accessibilityHint("Long press for options")
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }

                        ShareLink(item: message.content) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Preview

#Preview("User Message") {
    MessageBubbleView(message: .previewUser)
        .preferredColorScheme(.dark)
}

#Preview("Assistant Message") {
    MessageBubbleView(message: .previewAssistant)
        .preferredColorScheme(.dark)
}
