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
                ToolbarItem(placement: .topBarLeading) {
                    if let vm = viewModel, vm.hiddenAutomatedCount > 0 || vm.showAutomated {
                        Button {
                            vm.showAutomated.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: vm.showAutomated
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle")
                                if !vm.showAutomated, vm.hiddenAutomatedCount > 0 {
                                    Text("\(vm.hiddenAutomatedCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .accessibilityLabel(vm.showAutomated
                            ? "Hide automated sessions"
                            : "Show \(vm.hiddenAutomatedCount) automated sessions")
                    }
                }
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

    // MARK: - Session List (Sectioned)

    private func sessionList(vm: SessionListViewModel) -> some View {
        List {
            // Pinned section
            let pinned = vm.pinnedSessions
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { session in
                        sessionRow(session, vm: vm)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // App sessions section
            let app = vm.appSessions
            if !app.isEmpty {
                Section {
                    ForEach(app) { session in
                        sessionRow(session, vm: vm)
                    }
                } header: {
                    if vm.hasChannelSessions {
                        Label("App", systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Channel groups
            ForEach(vm.channelGroups) { group in
                Section {
                    ForEach(group.sessions) { session in
                        sessionRow(session, vm: vm)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: group.icon)
                        Text(group.label)
                        Spacer()
                        Text("\(group.sessions.count)")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    // MARK: - Session Row with Context Menu

    private func sessionRow(_ session: Session, vm: SessionListViewModel) -> some View {
        NavigationLink(value: session) {
            SessionRowView(session: session, isPinned: vm.isPinned(session))
        }
        .contextMenu {
            // Pin / Unpin
            if vm.canUnpin(session) {
                Button {
                    vm.unpinSession(session.key)
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }
            } else if !vm.isPinned(session) {
                Button {
                    vm.pinSession(session.key)
                } label: {
                    Label("Pin", systemImage: "pin")
                }
            }

            Button {
                beginRename(session)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            // Don't allow deleting main session
            if !session.isMainSession {
                Button(role: .destructive) {
                    beginDelete(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !session.isMainSession {
                Button(role: .destructive) {
                    beginDelete(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button {
                beginRename(session)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if vm.canUnpin(session) {
                Button {
                    vm.unpinSession(session.key)
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }
                .tint(.gray)
            } else if !vm.isPinned(session) {
                Button {
                    vm.pinSession(session.key)
                } label: {
                    Label("Pin", systemImage: "pin")
                }
                .tint(Color.terminalGreen)
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
            .tint(Color.terminalGreen)
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
            .tint(Color.terminalGreen)
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
