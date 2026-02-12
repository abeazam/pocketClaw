import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack(alignment: .top) {
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

            // Demo mode banner
            if appVM.isDemoMode {
                demoBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Reconnection banner
            if appVM.isReconnecting {
                reconnectionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Error banner for connection errors
            if case .error(let msg) = appVM.connectionState, !appVM.isReconnecting {
                errorBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.isReconnecting)
        .animation(.easeInOut(duration: 0.3), value: appVM.isDemoMode)
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.caption)
                .foregroundStyle(.white)
            Text("Demo Mode")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Button {
                appVM.exitDemoMode()
            } label: {
                Text("Exit")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Exit demo mode")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.terminalGreen.gradient)
    }

    // MARK: - Reconnection Banner

    private var reconnectionBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("Reconnecting...")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.orange.gradient)
        .accessibilityLabel("Reconnecting to server")
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                Task { await appVM.reconnectIfNeeded() }
            } label: {
                Text("Retry")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Retry connection")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.red.gradient)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
