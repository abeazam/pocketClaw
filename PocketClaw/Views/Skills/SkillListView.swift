import SwiftUI

// MARK: - Skill List View

struct SkillListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: SkillListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.skills.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        skillList(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Skills")
            .navigationDestination(for: Skill.self) { skill in
                if let vm = viewModel {
                    SkillDetailView(skill: skill, viewModel: vm)
                }
            }
            .task {
                if let client = appVM.client, appVM.connectionState.isConnected {
                    if viewModel == nil {
                        viewModel = SkillListViewModel(client: client)
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        await vm.fetchSkills()
                    }
                }
            }
            .onChange(of: appVM.connectionState.isConnected) { _, isConnected in
                if isConnected, let client = appVM.client {
                    if viewModel == nil {
                        viewModel = SkillListViewModel(client: client)
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        Task { await vm.fetchSkills() }
                    }
                }
            }
        }
    }

    // MARK: - Skill List

    @ViewBuilder
    private func skillList(vm: SkillListViewModel) -> some View {
        @Bindable var vm = vm
        List {
            // Summary header
            Section {
                HStack {
                    Label("\(vm.enabledCount) enabled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(vm.skills.count) total", systemImage: "puzzlepiece")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Skills
            ForEach(vm.filteredSkills) { skill in
                NavigationLink(value: skill) {
                    SkillRowView(skill: skill)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $vm.searchText, prompt: "Search skills")
        .refreshable {
            await vm.fetchSkills()
        }
        .overlay {
            if vm.isLoading && vm.skills.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Skills", systemImage: "puzzlepiece")
        } description: {
            Text("No skills found on the server")
        }
    }
}

// MARK: - Preview

#Preview {
    SkillListView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
