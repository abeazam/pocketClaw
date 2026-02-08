import SwiftUI

// MARK: - Chat Detail View

struct ChatDetailView: View {
    @Environment(AppViewModel.self) private var appVM

    let session: Session

    @State private var viewModel: ChatViewModel?
    @State private var messageText = ""
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showAgentDetail = false

    var body: some View {
        Group {
            if let vm = viewModel {
                chatContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toolbarMenu
            }
        }
        .task {
            // Get or create a cached ViewModel — only load history once
            if viewModel == nil {
                if let vm = appVM.chatViewModel(for: session.key) {
                    viewModel = vm
                    await vm.loadHistory(for: session.key)
                }
            }
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Session name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                guard let client = appVM.client else { return }
                let newName = renameText
                let key = session.key
                Task {
                    _ = try? await client.sendRequestPayload(
                        method: "sessions.patch",
                        params: ["key": key, "label": newName]
                    )
                }
            }
        } message: {
            Text("Enter a new name for this session.")
        }
        .sheet(isPresented: $showAgentDetail) {
            if let agentVM = appVM.agentListViewModel,
               let agent = agentVM.currentAgent {
                NavigationStack {
                    AgentDetailView(agent: agent, viewModel: agentVM)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showAgentDetail = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Chat Content

    private func chatContent(vm: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            messageList(vm: vm)
            InputBarView(
                text: $messageText,
                isStreaming: vm.isStreaming,
                thinkingEnabled: appVM.thinkingModeEnabled
            ) {
                let text = messageText
                messageText = ""
                Task {
                    await vm.sendMessage(text)
                }
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
                        VStack(alignment: .leading, spacing: 4) {
                            // Thinking block (if present)
                            if let thinking = message.thinking, !thinking.isEmpty {
                                ThinkingBlockView(
                                    thinking: thinking,
                                    isStreaming: vm.isStreaming
                                        && message.id.hasPrefix("streaming-")
                                        && vm.isThinkingStreaming
                                )
                            }

                            // Message bubble
                            MessageBubbleView(message: message)
                        }
                        .id(message.id)
                    }

                    // Typing indicator while streaming and no content yet
                    if vm.isStreaming && vm.streamingContent.isEmpty {
                        TypingIndicatorView()
                            .id("typing-indicator")
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
                if let error = vm.errorMessage, !vm.isStreaming {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                }
            }
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: vm.streamingContent) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Scroll To Bottom

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let targetId: String
        if let vm = viewModel, vm.isStreaming, vm.streamingContent.isEmpty {
            targetId = "typing-indicator"
        } else if let lastId = viewModel?.messages.last?.id {
            targetId = lastId
        } else {
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(targetId, anchor: .bottom)
        }
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
        Menu {
            Button {
                renameText = session.title
                showRenameAlert = true
            } label: {
                Label("Rename Session", systemImage: "pencil")
            }

            if appVM.agentListViewModel?.currentAgent != nil {
                Button {
                    showAgentDetail = true
                } label: {
                    Label("View Agent Info", systemImage: "person.circle")
                }
            }

            Toggle(isOn: Binding(
                get: { appVM.thinkingModeEnabled },
                set: { newValue in
                    appVM.updateThinkingMode(newValue)
                    viewModel?.setThinkingEnabled(newValue)
                }
            )) {
                Label("Thinking Mode", systemImage: "brain")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
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
