import SwiftUI

// MARK: - Cron List View

struct CronListView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var viewModel: CronListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if let error = vm.errorMessage, vm.cronJobs.isEmpty {
                        errorState(error) { Task { await vm.fetchCronJobs() } }
                    } else if vm.cronJobs.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        cronList(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Cron Jobs")
            .navigationDestination(for: CronJob.self) { job in
                if let vm = viewModel {
                    CronDetailView(job: job, viewModel: vm)
                }
            }
            .task {
                if let client = appVM.client, appVM.connectionState.isConnected {
                    if viewModel == nil {
                        viewModel = CronListViewModel(client: client)
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        await vm.fetchCronJobs()
                    }
                }
            }
            .onChange(of: appVM.connectionState.isConnected) { _, isConnected in
                if isConnected, let client = appVM.client {
                    if viewModel == nil {
                        viewModel = CronListViewModel(client: client)
                    }
                    if let vm = viewModel, !vm.hasLoadedOnce {
                        Task { await vm.fetchCronJobs() }
                    }
                }
            }
        }
    }

    // MARK: - Cron List

    @ViewBuilder
    private func cronList(vm: CronListViewModel) -> some View {
        @Bindable var vm = vm
        List {
            // Summary header
            Section {
                HStack {
                    Label("\(vm.activeCount) active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(vm.cronJobs.count) total", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Jobs
            ForEach(vm.filteredJobs) { job in
                NavigationLink(value: job) {
                    CronRowView(job: job) {
                        Task { await vm.toggleJob(job) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $vm.searchText, prompt: "Search cron jobs")
        .refreshable {
            await vm.fetchCronJobs()
        }
        .overlay {
            if vm.isLoading && vm.cronJobs.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cron Jobs", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("No scheduled jobs found on the server")
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
    CronListView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
