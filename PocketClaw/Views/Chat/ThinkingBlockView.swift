import SwiftUI

// MARK: - Thinking Block View

struct ThinkingBlockView: View {
    let thinking: String
    let isStreaming: Bool

    @State private var isExpanded = true

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(isStreaming ? "Thinking..." : "Thinking")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if isStreaming {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                // Expandable content
                if isExpanded {
                    Text(thinking)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .frame(maxWidth: 280, alignment: .leading)

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Preview

#Preview("Collapsed") {
    ThinkingBlockView(
        thinking: "Let me analyze the user's question about Swift concurrency...",
        isStreaming: false
    )
    .preferredColorScheme(.dark)
}

#Preview("Expanded") {
    ThinkingBlockView(
        thinking: "Let me analyze the user's question about Swift concurrency. I need to consider async/await patterns, structured concurrency with task groups, and the actor isolation model. The user seems to be asking specifically about data races...",
        isStreaming: false
    )
    .preferredColorScheme(.dark)
}

#Preview("Streaming") {
    ThinkingBlockView(
        thinking: "Analyzing the code structure...",
        isStreaming: true
    )
    .preferredColorScheme(.dark)
}
