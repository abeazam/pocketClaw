import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        TabView {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right") {
                SessionListView()
            }

            Tab("Agents", systemImage: "person.2") {
                AgentListView()
            }

            Tab("Skills", systemImage: "puzzlepiece") {
                SkillListView()
            }

            Tab("Cron Jobs", systemImage: "clock.arrow.circlepath") {
                CronsTabPlaceholder()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.terminalGreen)
    }
}

// MARK: - Placeholder Views

private struct CronsTabPlaceholder: View {
    var body: some View {
        NavigationStack {
            PlaceholderContent(
                icon: "clock.arrow.circlepath",
                title: "Cron Jobs",
                subtitle: "Scheduled jobs will appear here"
            )
            .navigationTitle("Cron Jobs")
        }
    }
}

// MARK: - Shared Placeholder Content

private struct PlaceholderContent: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
