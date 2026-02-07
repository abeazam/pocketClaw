import SwiftUI

@main
struct PocketClawApp: App {
    @State private var appVM = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if appVM.onboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appVM)
            .preferredColorScheme(appVM.themeMode.colorScheme)
            .task {
                // Auto-connect on launch if we have saved credentials
                if appVM.onboardingCompleted, !appVM.serverURL.isEmpty {
                    await appVM.connect()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, appVM.onboardingCompleted {
                    Task {
                        await appVM.reconnectIfNeeded()
                    }
                }
            }
        }
    }
}
