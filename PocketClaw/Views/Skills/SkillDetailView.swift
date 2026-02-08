import SwiftUI

// MARK: - Skill Detail View

struct SkillDetailView: View {
    let skill: Skill
    @Bindable var viewModel: SkillListViewModel

    /// Local copy of enabled state for the toggle binding
    @State private var isEnabled: Bool = true

    var body: some View {
        List {
            headerSection
            statusGridSection

            if let homepage = skill.homepage, !homepage.isEmpty {
                documentationSection(homepage)
            }

            if skill.requirements != nil {
                requirementsSection
            }

            if skill.hasMissingDeps, let installOptions = skill.install, !installOptions.isEmpty {
                installSection(installOptions)
            }

            if let triggers = skill.triggers, !triggers.isEmpty {
                triggersSection(triggers)
            }

            if let filePath = skill.filePath, !filePath.isEmpty {
                filePathSection(filePath)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = skill.isEnabled
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                // Emoji icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(width: 64, height: 64)
                    Text(skill.displayEmoji)
                        .font(.system(size: 32))
                }

                Text(skill.name)
                    .font(.title2.weight(.semibold).monospaced())

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Toggle
                HStack(spacing: 12) {
                    Text(isEnabled ? "Enabled" : "Disabled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEnabled ? Color.green : Color.orange)

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(.terminalGreen)
                        .onChange(of: isEnabled) { _, newValue in
                            // Only toggle if value actually changed from skill state
                            guard newValue != skill.isEnabled else { return }
                            Task { await viewModel.toggleSkill(skill) }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Status Grid

    private var statusGridSection: some View {
        Section("Status") {
            statusRow(label: "Eligible", value: skill.isEligible ? "Yes" : "No",
                      color: skill.isEligible ? .green : .orange)
            statusRow(label: "Source", value: skill.source ?? "Unknown")

            if let bundled = skill.bundled {
                statusRow(label: "Bundled", value: bundled ? "Yes" : "No")
            }
            if let always = skill.always {
                statusRow(label: "Always Active", value: always ? "Yes" : "No")
            }
        }
    }

    // MARK: - Documentation

    private func documentationSection(_ homepage: String) -> some View {
        Section("Documentation") {
            if let url = URL(string: homepage) {
                Link(destination: url) {
                    HStack {
                        Label("View Documentation", systemImage: "safari")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(homepage)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Requirements

    private var requirementsSection: some View {
        Section("Requirements") {
            if let bins = skill.requirements?.bins, !bins.isEmpty {
                requirementGroup(title: "Binaries", items: bins, missingItems: skill.missing?.bins)
            }
            if let env = skill.requirements?.env, !env.isEmpty {
                requirementGroup(title: "Environment Variables", items: env, missingItems: skill.missing?.env)
            }
            if let config = skill.requirements?.config, !config.isEmpty {
                requirementGroup(title: "Configuration", items: config, missingItems: skill.missing?.config)
            }
            if let os = skill.requirements?.os, !os.isEmpty {
                requirementGroup(title: "Operating System", items: os, missingItems: nil)
            }
        }
    }

    private func requirementGroup(title: String, items: [String], missingItems: [String]?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let isMissing = missingItems?.contains(item) ?? false
                    HStack(spacing: 4) {
                        Image(systemName: isMissing ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption2)
                        Text(item)
                            .font(.caption.monospaced())
                    }
                    .foregroundStyle(isMissing ? Color.red : Color.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (isMissing ? Color.red : Color.green).opacity(0.1)
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Install Section

    private func installSection(_ options: [SkillInstallOption]) -> some View {
        Section("Install Missing Dependencies") {
            ForEach(options) { option in
                Button {
                    Task {
                        _ = await viewModel.installSkill(skill, installId: option.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label ?? option.id)
                                .font(.body)
                            if let kind = option.kind {
                                Text(kind)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.isInstalling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color.terminalGreen)
                        }
                    }
                }
                .disabled(viewModel.isInstalling)
            }
        }
    }

    // MARK: - Triggers

    private func triggersSection(_ triggers: [String]) -> some View {
        Section("Triggers") {
            FlowLayout(spacing: 8) {
                ForEach(triggers, id: \.self) { trigger in
                    Text(trigger)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - File Path

    private func filePathSection(_ path: String) -> some View {
        Section("File Location") {
            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Helpers

    private func statusRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SkillDetailView(
            skill: .preview,
            viewModel: {
                let vm = SkillListViewModel(client: OpenClawClient(url: URL(string: "wss://localhost")!))
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
