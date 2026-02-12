import Foundation

// MARK: - Channel Group

struct ChannelGroup: Identifiable, Sendable {
    let channel: String
    let icon: String
    let label: String
    let sessions: [Session]

    var id: String { channel }
}

// MARK: - Session List ViewModel

@Observable
final class SessionListViewModel {
    // MARK: - State

    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false

    // MARK: - Filtering

    private static let showAutomatedKey = "PocketClaw.showAutomatedSessions"

    /// Whether to show automated sessions (cron, hooks, subagent, ACP). Default: hidden.
    var showAutomated: Bool {
        didSet { UserDefaults.standard.set(showAutomated, forKey: Self.showAutomatedKey) }
    }

    /// Count of hidden automated sessions (for the filter badge)
    var hiddenAutomatedCount: Int {
        showAutomated ? 0 : sessions.filter(\.isAutomated).count
    }

    /// Sessions after applying the automated filter
    private var filteredSessions: [Session] {
        showAutomated ? sessions : sessions.filter { !$0.isAutomated }
    }

    // MARK: - Pinning

    private static let pinnedKeysKey = "PocketClaw.pinnedSessionKeys"

    var pinnedSessionKeys: Set<String> {
        didSet {
            let array = Array(pinnedSessionKeys)
            UserDefaults.standard.set(array, forKey: Self.pinnedKeysKey)
        }
    }

    // MARK: - Computed Sections

    /// Pinned sessions: main session (always) + user-pinned sessions, sorted by updatedAt
    var pinnedSessions: [Session] {
        filteredSessions.filter { $0.isMainSession || pinnedSessionKeys.contains($0.key) }
            .sorted(byUpdatedAt: true)
    }

    /// App/webchat sessions that are NOT pinned, sorted by updatedAt
    var appSessions: [Session] {
        filteredSessions.filter {
            $0.isAppSession && !$0.isMainSession && !pinnedSessionKeys.contains($0.key)
        }
        .sorted(byUpdatedAt: true)
    }

    /// Sessions grouped by channel (excluding app sessions and pinned sessions)
    var channelGroups: [ChannelGroup] {
        let channelSessions = filteredSessions.filter {
            !$0.isAppSession && !$0.isMainSession && !pinnedSessionKeys.contains($0.key)
        }

        // Group by effective channel
        let grouped = Dictionary(grouping: channelSessions) { $0.effectiveChannel ?? "unknown" }

        return grouped.map { channel, sessions in
            let representative = sessions.first!
            return ChannelGroup(
                channel: channel,
                icon: representative.channelIcon,
                label: representative.channelLabel,
                sessions: sessions.sorted(byUpdatedAt: true)
            )
        }
        .sorted { $0.label < $1.label }
    }

    /// Whether there are any channel sessions to show
    var hasChannelSessions: Bool {
        filteredSessions.contains { !$0.isAppSession && !$0.isMainSession }
    }

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
        let stored = UserDefaults.standard.stringArray(forKey: Self.pinnedKeysKey) ?? []
        self.pinnedSessionKeys = Set(stored)
        self.showAutomated = UserDefaults.standard.bool(forKey: Self.showAutomatedKey)
    }

    // MARK: - Pinning Actions

    func pinSession(_ key: String) {
        pinnedSessionKeys.insert(key)
    }

    func unpinSession(_ key: String) {
        // Main session can't be unpinned
        guard !key.hasSuffix(":main") else { return }
        pinnedSessionKeys.remove(key)
    }

    func isPinned(_ session: Session) -> Bool {
        session.isMainSession || pinnedSessionKeys.contains(session.key)
    }

    func canUnpin(_ session: Session) -> Bool {
        !session.isMainSession && pinnedSessionKeys.contains(session.key)
    }

    // MARK: - Fetch

    func fetchSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "sessions.list",
                params: [
                    "includeDerivedTitles": true,
                    "includeLastMessage": true,
                    "limit": 50
                ]
            )

            // Server may return a top-level array or { sessions: [...] }
            let sessionsArray: [Any]
            if let arr = raw as? [Any] {
                sessionsArray = arr
            } else if let dict = raw as? [String: Any], let arr = dict["sessions"] as? [Any] {
                sessionsArray = arr
            } else {
                sessionsArray = []
            }

            // Decode sessions individually to skip malformed entries
            var decoded: [Session] = []
            var seenKeys = Set<String>()
            for item in sessionsArray {
                guard let itemData = try? JSONSerialization.data(withJSONObject: item),
                      let session = try? JSONDecoder().decode(Session.self, from: itemData) else {
                    continue
                }
                // Deduplicate by key — server may return multiple entries for the same session
                guard seenKeys.insert(session.key).inserted else { continue }
                decoded.append(session)
            }

            // Sort by updatedAt descending (most recent first)
            sessions = decoded.sorted(byUpdatedAt: true)
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
            sessions = []
        }

        isLoading = false
    }

    // MARK: - Delete

    func deleteSession(_ session: Session) async -> Bool {
        do {
            _ = try await client.sendRequestPayload(
                method: "sessions.delete",
                params: ["key": session.key]
            )
            // Remove locally immediately
            sessions.removeAll { $0.key == session.key }
            pinnedSessionKeys.remove(session.key)
            return true
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Rename

    func renameSession(_ session: Session, to newLabel: String) async -> Bool {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        do {
            _ = try await client.sendRequestPayload(
                method: "sessions.patch",
                params: ["key": session.key, "label": trimmed]
            )
            // Update locally — replace the session to ensure SwiftUI detects the change
            if let index = sessions.firstIndex(where: { $0.key == session.key }) {
                var updated = sessions[index]
                updated.title = trimmed
                sessions[index] = updated
            }
            return true
        } catch {
            errorMessage = "Failed to rename: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Array Sorting Extension

extension Array where Element == Session {
    func sorted(byUpdatedAt descending: Bool) -> [Session] {
        sorted { s1, s2 in
            guard let d1 = s1.updatedAt?.isoDate, let d2 = s2.updatedAt?.isoDate else {
                return false
            }
            return descending ? d1 > d2 : d1 < d2
        }
    }
}
