import SwiftUI

// MARK: - Chat Detail View

struct ChatDetailView: View {
    @Environment(AppViewModel.self) private var appVM

    let session: Session

    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                messageList(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let client = appVM.client {
                let vm = ChatViewModel(client: client)
                viewModel = vm
                await vm.loadHistory(for: session.key)
            }
        }
    }

    // MARK: - Message List

    private func messageList(vm: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Date header for first message
                    if let firstTimestamp = vm.messages.first?.timestamp {
                        dateSeparator(firstTimestamp.dateHeaderFormatted)
                    }

                    ForEach(vm.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if vm.isLoading && vm.messages.isEmpty {
                    ProgressView("Loading messages...")
                }
            }
            .overlay {
                if let error = vm.errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                }
            }
            .onChange(of: vm.messages.count) { _, _ in
                // Scroll to bottom when messages load
                if let lastId = vm.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Date Separator

    private func dateSeparator(_ text: String) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatDetailView(session: .preview)
            .environment(AppViewModel.preview)
    }
    .preferredColorScheme(.dark)
}
