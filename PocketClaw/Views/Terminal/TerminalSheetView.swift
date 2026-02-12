import SwiftUI

// MARK: - Terminal Sheet View

/// Sheet content that switches between the SSH connection form and the live terminal.
/// The terminal session persists across sheet dismiss/re-open cycles.
struct TerminalSheetView: View {
    let viewModel: TerminalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isTerminalActive {
                    TerminalContainerView(viewModel: viewModel)
                } else {
                    SSHConnectionForm(viewModel: viewModel)
                }
            }
            .navigationTitle(viewModel.isTerminalActive ? viewModel.host : "SSH Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if viewModel.isTerminalActive {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Disconnect", role: .destructive) {
                            viewModel.disconnect()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isTerminalActive)
        .onDisappear {
            viewModel.saveCredentials()
        }
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    TerminalSheetView(viewModel: TerminalViewModel())
        .preferredColorScheme(.dark)
}
