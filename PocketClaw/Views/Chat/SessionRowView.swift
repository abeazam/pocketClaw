import SwiftUI

// MARK: - Session Row View

struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if let updatedAt = session.updatedAt {
                    Text(updatedAt.relativeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastMessage = session.lastMessage, !lastMessage.isEmpty {
                Text(lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    List {
        SessionRowView(session: .preview)
    }
    .preferredColorScheme(.dark)
}
