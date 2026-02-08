import SwiftUI

// MARK: - Session List View

struct SessionListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: SessionListViewModel?
    @State private var navigateToNewChat = false
    @State private var newChatSession: Session?

    // Rename state
    @State private var sessionToRename: Session?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    // Delete state
    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if let error = vm.errorMessage, vm.sessions.isEmpty {
                        errorState(error) { Task { await vm.fetchSessions() } }
                    } else if vm.sessions.isEmpty && !vm.isLoading {
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
                    if viewModel == nil {
                        let vm = SessionListViewModel(client: client)
                        viewModel = vm
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        await vm.fetchSessions()
                    }
                }
            }
            .onChange(of: appVM.connectionState.isConnected) { _, isConnected in
                if isConnected, let client = appVM.client {
                    if viewModel == nil {
                        let vm = SessionListViewModel(client: client)
                        viewModel = vm
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        Task { await vm.fetchSessions() }
                    }
                }
            }
            .alert("Rename Session", isPresented: $showRenameAlert) {
                TextField("Session name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    guard let session = sessionToRename, let vm = viewModel else { return }
                    let newName = renameText
                    Task { await vm.renameSession(session, to: newName) }
                }
            } message: {
                Text("Enter a new name for this session.")
            }
            .alert("Delete Session", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    guard let session = sessionToDelete, let vm = viewModel else { return }
                    Task {
                        let success = await vm.deleteSession(session)
                        if success {
                            appVM.removeChatViewModel(for: session.key)
                        }
                    }
                }
            } message: {
                if let session = sessionToDelete {
                    Text("Are you sure you want to delete \"\(session.title)\"? This cannot be undone.")
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
                .contextMenu {
                    Button {
                        beginRename(session)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        beginDelete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        beginDelete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        beginRename(session)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
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

    // MARK: - Error State

    private func errorState(_ message: String, retry: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(action: retry) {
                Text("Try Again")
            }
            .buttonStyle(.borderedProminent)
            .tint(.terminalGreen)
        }
    }

    // MARK: - Actions

    private func createNewChat() {
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

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func beginRename(_ session: Session) {
        sessionToRename = session
        renameText = session.title
        showRenameAlert = true
    }

    private func beginDelete(_ session: Session) {
        sessionToDelete = session
        showDeleteConfirmation = true
    }
}

// MARK: - Make Session Hashable for NavigationLink

extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.lastMessage == rhs.lastMessage
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
