import SwiftUI

// MARK: - Input Bar View

struct InputBarView: View {
    @Binding var text: String
    let isStreaming: Bool
    var thinkingEnabled: Bool = false
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Thinking mode indicator
            if thinkingEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption2)
                    Text("Thinking mode on")
                        .font(.caption2)
                }
                .foregroundStyle(Color.terminalGreen.opacity(0.7))
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Auto-resizing text editor
                TextField("Message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend {
                            sendWithHaptic()
                        }
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type a message to send")

                // Send button
                Button(action: sendWithHaptic) {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend || isStreaming ? Color.terminalGreen : Color.secondary)
                }
                .disabled(!canSend && !isStreaming)
                .animation(.easeInOut(duration: 0.15), value: canSend)
                .accessibilityLabel(isStreaming ? "Stop response" : "Send message")
                .accessibilityHint(isStreaming ? "Stop the current streaming response" : "Send the message you typed")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Character counter (shows near limit)
            if showCharacterCounter {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(Constants.maxMessageLength)")
                        .font(.caption2)
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                        .padding(.trailing, 16)
                        .padding(.bottom, 4)
                }
                .transition(.opacity)
            }
        }
        .background(.bar)
    }

    // MARK: - Computed

    private var canSend: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isStreaming && !isOverLimit
    }

    private var isOverLimit: Bool {
        text.count > Constants.maxMessageLength
    }

    private var showCharacterCounter: Bool {
        Double(text.count) >= Double(Constants.maxMessageLength) * Constants.messageWarningThreshold
    }

    // MARK: - Actions

    private func sendWithHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        onSend()
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack {
                Spacer()
                InputBarView(text: $text, isStreaming: false) {
                    print("Send: \(text)")
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}

#Preview("Near Limit") {
    struct PreviewWrapper: View {
        @State private var text = String(repeating: "a", count: 3800)

        var body: some View {
            VStack {
                Spacer()
                InputBarView(text: $text, isStreaming: false) {}
            }
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}

#Preview("Streaming") {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack {
                Spacer()
                InputBarView(text: $text, isStreaming: true) {}
            }
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
