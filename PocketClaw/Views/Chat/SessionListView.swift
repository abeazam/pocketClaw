import SwiftUI

// MARK: - Session List View

struct SessionListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: SessionListViewModel?

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
        .navigationDestination(for: Session.self) { session in
            ChatDetailView(session: session)
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
        }
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
