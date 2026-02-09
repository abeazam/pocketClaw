import SwiftUI

// MARK: - Skill Row View

struct SkillRowView: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 12) {
            // Emoji icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Text(skill.displayEmoji)
                    .font(.title3)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.body.weight(.medium).monospaced())
                        .lineLimit(1)

                    statusBadge
                }

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Trigger capsules
                if let triggers = skill.triggers, !triggers.isEmpty {
                    triggerCapsules(triggers)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name), \(skill.isEnabled ? "Enabled" : "Disabled")")
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(skill.isEnabled ? "Enabled" : "Disabled")
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(skill.isEnabled ? Color.green : Color.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                (skill.isEnabled ? Color.green : Color.orange).opacity(0.15)
            )
            .clipShape(Capsule())
    }

    // MARK: - Trigger Capsules

    private func triggerCapsules(_ triggers: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(triggers.prefix(3), id: \.self) { trigger in
                Text(trigger)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if triggers.count > 3 {
                Text("+\(triggers.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        SkillRowView(skill: .preview)
        SkillRowView(skill: Skill(
            id: "disabled-skill",
            name: "image-gen",
            description: "Generate images from text descriptions",
            triggers: ["/imagine", "/draw", "/art", "/pic"],
            enabled: false,
            emoji: "🎨"
        ))
    }
    .preferredColorScheme(.dark)
}
