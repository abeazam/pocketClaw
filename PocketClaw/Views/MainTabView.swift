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
                CronListView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.terminalGreen)
    }
}

// MARK: - Placeholder Views



// MARK: - Preview

#Preview {
    MainTabView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
