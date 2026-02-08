import SwiftUI

// MARK: - File Editor View

struct FileEditorView: View {
    let agentId: String
    let file: AgentFile
    @Bindable var viewModel: AgentListViewModel

    @State private var editContent: String = ""
    @State private var isSaving = false
    @State private var hasUnsavedChanges = false
    @State private var showDiscardAlert = false
    @State private var saveSuccess: Bool?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            editor
            bottomBar
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                saveButton
            }
        }
        .onAppear {
            editContent = file.content ?? ""
        }
        .alert("Unsaved Changes", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Discard them?")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: $editContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(.systemBackground))
            .onChange(of: editContent) { _, newValue in
                hasUnsavedChanges = newValue != (file.content ?? "")
                saveSuccess = nil
            }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // File info
            VStack(alignment: .leading, spacing: 2) {
                if file.isMissing {
                    Label("New file — will be created on save", systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("\(editContent.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status indicator
            if let success = saveSuccess {
                Label(
                    success ? "Saved" : "Save failed",
                    systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(success ? .green : .red)
            } else if hasUnsavedChanges {
                Label("Modified", systemImage: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Save")
                    .fontWeight(.medium)
            }
        }
        .disabled(!hasUnsavedChanges || isSaving)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        let success = await viewModel.saveFile(
            agentId: agentId,
            fileName: file.name,
            content: editContent
        )
        isSaving = false
        saveSuccess = success

        if success {
            hasUnsavedChanges = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FileEditorView(
            agentId: "main",
            file: AgentFile(
                name: "IDENTITY.md",
                path: "/home/claw/agents/main/IDENTITY.md",
                missing: false,
                size: 256,
                updatedAtMs: nil,
                content: "# Identity\n\nName: Claude\nEmoji: 🤖\n\n## About\n\nA helpful AI assistant."
            ),
            viewModel: {
                let vm = AgentListViewModel(client: OpenClawClient(url: URL(string: "wss://localhost")!))
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
