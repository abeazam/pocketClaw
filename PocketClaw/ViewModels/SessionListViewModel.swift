import Foundation

// MARK: - Session List ViewModel

@Observable
final class SessionListViewModel {
    // MARK: - State

    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    // MARK: - Public Methods

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

            for s in decoded {
                NSLog("[Sessions] id='%@' key='%@' title='%@'", s.id, s.key, s.title)
            }
            NSLog("[Sessions] total decoded: %d (from %d raw, %d unique)", decoded.count, sessionsArray.count, seenKeys.count)

            // Sort by updatedAt descending (most recent first)
            sessions = decoded.sorted { s1, s2 in
                guard let d1 = s1.updatedAt?.isoDate, let d2 = s2.updatedAt?.isoDate else {
                    return false
                }
                return d1 > d2
            }
        } catch {
            errorMessage = error.localizedDescription
            sessions = []
        }

        isLoading = false
    }
}
