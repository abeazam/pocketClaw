import SwiftUI

// MARK: - Session List View

struct SessionListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: SessionListViewModel?
    @State private var navigateToNewChat = false
    @State private var newChatSession: Session?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.sessions.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        sessionList(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!appVM.connectionState.isConnected)
                }
            }
            .navigationDestination(for: Session.self) { session in
                ChatDetailView(session: session)
            }
            .navigationDestination(isPresented: $navigateToNewChat) {
                if let session = newChatSession {
                    ChatDetailView(session: session)
                }
            }
            .task {
                if let client = appVM.client, appVM.connectionState.isConnected {
                    let vm = SessionListViewModel(client: client)
                    viewModel = vm
                    await vm.fetchSessions()
                }
            }
            .onChange(of: appVM.connectionState.isConnected) { _, isConnected in
                if isConnected, let client = appVM.client {
                    if let vm = viewModel {
                        Task { await vm.fetchSessions() }
                    } else {
                        let vm = SessionListViewModel(client: client)
                        viewModel = vm
                        Task { await vm.fetchSessions() }
                    }
                }
            }
        }
    }

    // MARK: - Session List

    private func sessionList(vm: SessionListViewModel) -> some View {
        List {
            ForEach(vm.sessions) { session in
                NavigationLink(value: session) {
                    SessionRowView(session: session)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await vm.fetchSessions()
        }
        .overlay {
            if vm.isLoading && vm.sessions.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start a Conversation", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Your chat sessions will appear here")
        } actions: {
            Button {
                createNewChat()
            } label: {
                Text("New Chat")
            }
            .buttonStyle(.borderedProminent)
            .tint(.terminalGreen)
            .disabled(!appVM.connectionState.isConnected)
        }
    }

    // MARK: - New Chat

    private func createNewChat() {
        // Create a local session with a new key — the server will create it
        // when the first message is sent via chat.send.
        // Use the agent:main: prefix to match the server's naming convention.
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let sessionKey = "agent:main:session-\(timestamp)"
        let session = Session(
            id: sessionKey,
            key: sessionKey,
            title: "New Chat",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        newChatSession = session
        navigateToNewChat = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Make Session Hashable for NavigationLink

extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview

#Preview {
    SessionListView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
