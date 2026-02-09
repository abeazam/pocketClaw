import SwiftUI

// MARK: - Cron Row View

struct CronRowView: View {
    let job: CronJob
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(job.isActive ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .shadow(color: job.isActive ? .green.opacity(0.5) : .clear, radius: 3)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                // Schedule — human readable
                Text(job.schedule.humanReadable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Next run / Disabled
                if job.isActive {
                    if let nextRun = job.nextRunDisplay {
                        Text("Next: \(nextRun)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Disabled")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Toggle button
            Button {
                onToggle?()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } label: {
                Image(systemName: job.isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(job.isActive ? Color.orange : Color.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(job.isActive ? "Pause \(job.name)" : "Resume \(job.name)")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    List {
        CronRowView(job: .preview)
        CronRowView(job: CronJob(
            id: "paused-job",
            name: "Weekly report",
            schedule: .cron(expr: "0 9 * * 1", tz: nil),
            enabled: false
        ))
    }
    .preferredColorScheme(.dark)
}
