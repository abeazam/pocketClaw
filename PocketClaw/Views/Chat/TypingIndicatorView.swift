import SwiftUI

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationPhase = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assistant")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.terminalGreen.opacity(0.7))
                            .frame(width: 6, height: 6)
                            .offset(y: dotOffset(for: index))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.assistantBubble)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 12)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 1.0
            }
        }
    }

    // MARK: - Private

    private func dotOffset(for index: Int) -> CGFloat {
        let phase = animationPhase
        let delay = Double(index) * 0.15
        let adjustedPhase = max(0, min(1, phase - delay))
        return -adjustedPhase * 4
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        TypingIndicatorView()
        Spacer()
    }
    .preferredColorScheme(.dark)
}
