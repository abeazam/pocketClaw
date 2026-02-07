import Foundation

// MARK: - Chat ViewModel

@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    // MARK: - Public Methods

    func loadHistory(for sessionKey: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "chat.history",
                params: ["sessionKey": sessionKey]
            )

            // Server may return a top-level array or { messages: [...] }
            let messagesArray: [Any]
            if let arr = raw as? [Any] {
                messagesArray = arr
            } else if let dict = raw as? [String: Any], let arr = dict["messages"] as? [Any] {
                messagesArray = arr
            } else {
                messagesArray = []
            }

            var parsed: [Message] = []
            for item in messagesArray {
                guard let dict = item as? [String: Any] else { continue }
                if let msg = Message.fromServerPayload(dict) {
                    // Filter heartbeat messages
                    let upper = msg.content.uppercased()
                    let isHeartbeat = Constants.heartbeatFilterPatterns.contains { pattern in
                        upper.contains(pattern)
                    }
                    if !isHeartbeat && (!msg.content.isEmpty || msg.thinking != nil) {
                        parsed.append(msg)
                    }
                }
            }

            messages = parsed
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
