import SwiftUI

// MARK: - Agent List View

struct AgentListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: AgentListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if let error = vm.errorMessage, vm.agents.isEmpty {
                        errorState(error) { Task { await vm.fetchAgents() } }
                    } else if vm.agents.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        agentList(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Agents")
            .navigationDestination(for: Agent.self) { agent in
                if let vm = viewModel {
                    AgentDetailView(agent: agent, viewModel: vm)
                }
            }
            .task {
                if let client = appVM.client, appVM.connectionState.isConnected {
                    if viewModel == nil {
                        let vm = AgentListViewModel(client: client)
                        viewModel = vm
                        appVM.agentListViewModel = vm
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        await vm.fetchAgents()
                    }
                }
            }
            .onChange(of: appVM.connectionState.isConnected) { _, isConnected in
                if isConnected, let client = appVM.client {
                    if viewModel == nil {
                        let vm = AgentListViewModel(client: client)
                        viewModel = vm
                        appVM.agentListViewModel = vm
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        Task { await vm.fetchAgents() }
                    }
                }
            }
        }
    }

    // MARK: - Agent List

    private func agentList(vm: AgentListViewModel) -> some View {
        List {
            // Active Agent Section
            if let active = vm.currentAgent {
                Section {
                    NavigationLink(value: active) {
                        AgentRowView(agent: active, isActive: true)
                    }
                    .contextMenu {
                        Button {
                            // Already active
                        } label: {
                            Label("Active Agent", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(true)
                    }
                } header: {
                    Text("Active Agent")
                }
            }

            // Other Agents Section
            if !vm.otherAgents.isEmpty {
                Section {
                    ForEach(vm.otherAgents) { agent in
                        NavigationLink(value: agent) {
                            AgentRowView(agent: agent, isActive: false)
                        }
                        .contextMenu {
                            Button {
                                vm.setActiveAgent(agent)
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            } label: {
                                Label("Set as Active", systemImage: "checkmark.circle")
                            }
                        }
                    }
                } header: {
                    Text("Other Agents")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await vm.fetchAgents()
        }
        .overlay {
            if vm.isLoading && vm.agents.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Agents", systemImage: "person.2")
        } description: {
            Text("No agents found on the server")
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String, retry: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
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
}

// MARK: - Preview

#Preview {
    AgentListView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
