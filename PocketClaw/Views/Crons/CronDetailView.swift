import SwiftUI

// MARK: - Cron Detail View

struct CronDetailView: View {
    let job: CronJob
    @Bindable var viewModel: CronListViewModel

    @State private var isActive: Bool = true

    var body: some View {
        List {
            headerSection
            scheduleSection

            if let content = job.content, !content.isEmpty {
                contentSection(content)
            }

            if let delivery = job.delivery {
                deliverySection(delivery)
            }

            metadataSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(job.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isActive = job.isActive
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                // Clock icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
                }

                Text(job.name)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                // Toggle
                HStack(spacing: 12) {
                    Text(isActive ? "Active" : "Disabled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isActive ? Color.green : Color.orange)

                    Toggle("", isOn: $isActive)
                        .labelsHidden()
                        .tint(.terminalGreen)
                        .onChange(of: isActive) { _, newValue in
                            guard newValue != job.isActive else { return }
                            Task { await viewModel.toggleJob(job) }
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

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        Section("Schedule") {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.schedule.displayExpression)
                        .font(.body.monospaced())
                    Text(job.schedule.humanReadable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let tz = job.schedule.timezone {
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    Text(tz)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if job.isActive, let nextRun = job.nextRunDisplay {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Run")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(nextRun)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Content Section (Payload Message)

    private func contentSection(_ content: String) -> some View {
        Section("Payload") {
            Text(content)
                .font(.subheadline)
                .textSelection(.enabled)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Delivery Section

    private func deliverySection(_ delivery: CronDelivery) -> some View {
        Section("Delivery") {
            if let channel = delivery.channel {
                HStack {
                    Image(systemName: deliveryIcon(channel))
                        .foregroundStyle(.purple)
                    Text(channel.capitalized)
                        .font(.body)
                }
            }
            if let to = delivery.to {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)
                    Text(to)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if let mode = delivery.mode {
                HStack {
                    Image(systemName: "megaphone")
                        .foregroundStyle(.secondary)
                    Text(mode.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func deliveryIcon(_ channel: String) -> String {
        switch channel.lowercased() {
        case "telegram": "paperplane.fill"
        case "email": "envelope.fill"
        case "slack": "number"
        case "webhook": "link"
        default: "bell.fill"
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        Section("Details") {
            if let agentId = job.agentId {
                HStack {
                    Text("Agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(agentId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if let session = job.sessionTarget {
                HStack {
                    Text("Session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(session)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if let wakeMode = job.wakeMode {
                HStack {
                    Text("Wake Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(wakeMode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if let kind = job.payload?.kind {
                HStack {
                    Text("Payload Kind")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(kind)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CronDetailView(
            job: .preview,
            viewModel: {
                let vm = CronListViewModel(client: OpenClawClient(url: URL(string: "wss://localhost")!))
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
