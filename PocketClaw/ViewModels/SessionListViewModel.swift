import Foundation

// MARK: - Session List ViewModel

@Observable
final class SessionListViewModel {
    // MARK: - State

    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
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
            sessions = decoded.sorted { s1, s2 in
                guard let d1 = s1.updatedAt?.isoDate, let d2 = s2.updatedAt?.isoDate else {
                    return false
                }
                return d1 > d2
            }
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
