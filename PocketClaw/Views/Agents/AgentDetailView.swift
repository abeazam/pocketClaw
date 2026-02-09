import SwiftUI

// MARK: - Agent Detail View

struct AgentDetailView: View {
    let agent: Agent
    @Bindable var viewModel: AgentListViewModel

    @State private var hasLoadedFiles = false

    var body: some View {
        List {
            profileSection
            metadataSection

            if !viewModel.agentWorkspace.isEmpty {
                workspaceSection
            }

            filesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refreshFiles() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingFiles)
            }
        }
        .task {
            guard !hasLoadedFiles else { return }
            hasLoadedFiles = true
            await viewModel.loadAgentDetail(agent)
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            VStack(spacing: 12) {
                // Large avatar
                agentAvatarLarge
                    .frame(width: 80, height: 80)

                Text(agent.name)
                    .font(.title2.weight(.semibold))

                if let theme = agent.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Status badge
                HStack(spacing: 6) {
                    StatusDotView(status: agent.status ?? "offline")
                    Text(agent.status?.capitalized ?? "Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        Section("Details") {
            metadataRow(label: "ID", value: agent.id, monospaced: true)

            if let emoji = agent.emoji, !emoji.isEmpty {
                metadataRow(label: "Emoji", value: emoji)
            }

            if let desc = agent.description, !desc.isEmpty {
                metadataRow(label: "Description", value: desc)
            }

            if let avatar = agent.avatar, !avatar.isEmpty {
                HStack {
                    Text("Avatar")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(avatar)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    // MARK: - Workspace Section

    private var workspaceSection: some View {
        Section("Workspace") {
            Text(viewModel.agentWorkspace)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Files Section

    private var filesSection: some View {
        Section("Configuration Files") {
            if viewModel.isLoadingFiles {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let fileError = viewModel.fileLoadError {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Failed to load files", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(fileError)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.refreshFiles() }
                    }
                    .font(.caption)
                    .tint(Color.terminalGreen)
                }
            } else if viewModel.agentFiles.isEmpty {
                Text("No configuration files found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.agentFiles) { file in
                    NavigationLink {
                        FileEditorView(
                            agentId: agent.id,
                            file: file,
                            viewModel: viewModel
                        )
                    } label: {
                        fileRow(file)
                    }
                }
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ file: AgentFile) -> some View {
        HStack {
            Image(systemName: file.isMissing ? "doc.badge.plus" : "doc.text")
                .foregroundStyle(file.isMissing ? Color.orange : Color.terminalGreen)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body.monospaced())

                if file.isMissing {
                    Text("Not created")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text(file.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(file.isMissing ? "Create" : "Edit")
                .font(.caption)
                .foregroundStyle(Color.terminalGreen)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var agentAvatarLarge: some View {
        if let avatarURL = agent.avatar,
           let url = URL(string: avatarURL),
           avatarURL.hasPrefix("http") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                case .failure:
                    emojiAvatarLarge
                default:
                    ProgressView()
                        .frame(width: 80, height: 80)
                }
            }
        } else {
            emojiAvatarLarge
        }
    }

    private var emojiAvatarLarge: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            Text(agent.displayEmoji)
                .font(.system(size: 40))
        }
    }

    private func metadataRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .body.monospaced() : .body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AgentDetailView(
            agent: .preview,
            viewModel: {
                let vm = AgentListViewModel(client: OpenClawClient(url: URL(string: "wss://localhost")!))
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
