import SwiftUI

// MARK: - Floating Terminal Button

/// A floating action button that opens the SSH terminal sheet.
/// Positioned bottom-right above the tab bar. Hidden in demo mode.
struct FloatingTerminalButton: View {
    @Binding var isShowingTerminal: Bool
    let isDemoMode: Bool
    let isConnected: Bool

    var body: some View {
        if !isDemoMode {
            Button {
                isShowingTerminal = true
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isConnected ? .black : .white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(isConnected ? Color.terminalGreen : Color(uiColor: .systemGray5))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80) // Above the tab bar
            .accessibilityLabel(isConnected ? "SSH Terminal (Connected)" : "SSH Terminal")
            .accessibilityHint("Opens the SSH terminal")
        }
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    ZStack(alignment: .bottomTrailing) {
        Color.black.ignoresSafeArea()
        FloatingTerminalButton(
            isShowingTerminal: .constant(false),
            isDemoMode: false,
            isConnected: false
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Connected") {
    ZStack(alignment: .bottomTrailing) {
        Color.black.ignoresSafeArea()
        FloatingTerminalButton(
            isShowingTerminal: .constant(false),
            isDemoMode: false,
            isConnected: true
        )
    }
    .preferredColorScheme(.dark)
}
