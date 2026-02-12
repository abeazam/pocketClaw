import Foundation

// MARK: - Demo Client

/// A subclass of OpenClawClient that returns canned data for Apple App Review.
/// No real WebSocket connection is made — all data comes from DemoData.
class DemoClient: OpenClawClient {

    // Own listener storage since parent's _eventListeners is private
    private let _demoListeners = MutableBox<[String: EventHandler]>([:])

    // Store connection/event handlers locally (parent's are private)
    private let _demoConnectionHandler = MutableBox<(@Sendable (ConnectionState) -> Void)?>(nil)
    private let _demoEventHandler = MutableBox<EventHandler?>(nil)

    // MARK: - Init

    init() {
        super.init(url: URL(string: "wss://demo.local")!, token: nil, password: nil)
    }

    // MARK: - Connection (no-op)

    override func connect() async throws {
        // No real connection — AppViewModel sets connectionState directly
    }

    override func disconnect() {
        // No real connection to tear down
    }

    // MARK: - Callback Overrides

    override func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void) {
        _demoConnectionHandler.value = handler
    }

    override func setEventHandler(_ handler: @escaping EventHandler) {
        _demoEventHandler.value = handler
    }

    // MARK: - Event Listeners (own storage)

    @discardableResult
    override func addEventListener(id: String, handler: @escaping EventHandler) -> String {
        _demoListeners.mutate { listeners in
            listeners[id] = handler
        }
        return id
    }

    override func removeEventListener(id: String) {
        _demoListeners.mutate { listeners in
            listeners.removeValue(forKey: id)
        }
    }

    // MARK: - RPC Override (raw)

    override func sendRequestRaw(method: String, params: [String: Any] = [:]) async throws -> Any {
        // Small delay to feel realistic
        try? await Task.sleep(for: .milliseconds(80))

        switch method {
        case "sessions.list":
            return DemoData.sessions

        case "chat.history":
            let sessionKey = params["sessionKey"] as? String ?? ""
            return DemoData.messagesBySession[sessionKey] ?? []

        case "chat.send":
            let message = params["message"] as? String ?? ""
            let sessionKey = params["sessionKey"] as? String ?? ""
            // Fire streaming events asynchronously, then return
            simulateStreaming(response: DemoData.responseFor(message), sessionKey: sessionKey)
            return [String: Any]()

        case "agents.list":
            return DemoData.agents

        case "agents.files.list":
            let agentId = params["agentId"] as? String ?? ""
            return DemoData.agentFiles[agentId] ?? []

        case "agents.files.get":
            let agentId = params["agentId"] as? String ?? ""
            let name = params["name"] as? String ?? ""
            let key = "\(agentId):\(name)"
            return ["content": DemoData.agentFileContents[key] ?? ""] as [String: Any]

        case "skills.status":
            return DemoData.skills

        case "cron.list":
            return DemoData.cronJobs

        default:
            // sessions.delete, sessions.patch, agents.files.set, skills.update,
            // skills.install, cron.update — all return empty success
            return [String: Any]()
        }
    }

    // MARK: - RPC Override (payload)

    override func sendRequestPayload(
        method: String,
        params: [String: Any] = [:]
    ) async throws -> [String: Any] {
        let raw = try await sendRequestRaw(method: method, params: params)
        return raw as? [String: Any] ?? [:]
    }

    // MARK: - Streaming Simulation

    nonisolated private func simulateStreaming(response: String, sessionKey: String) {
        Task { [weak self] in
            guard let self else { return }

            // Split response into small chunks (word-by-word for natural feel)
            let words = response.split(separator: " ", omittingEmptySubsequences: false)
            var accumulated = ""

            for (index, word) in words.enumerated() {
                if index > 0 { accumulated += " " }
                accumulated += String(word)

                let delta = (index > 0 ? " " : "") + String(word)

                let chatPayload: [String: Any] = [
                    "state": "delta",
                    "sessionKey": sessionKey,
                    "delta": delta,
                    "message": [
                        "role": "assistant",
                        "content": accumulated
                    ] as [String: Any]
                ]

                self.dispatchEvent(name: "chat", payload: chatPayload)

                // ~30ms per word for snappy streaming
                try? await Task.sleep(for: .milliseconds(30))
            }

            // Send final event
            let messageId = "demo-\(UUID().uuidString)"
            let finalPayload: [String: Any] = [
                "state": "final",
                "sessionKey": sessionKey,
                "message": [
                    "id": messageId,
                    "role": "assistant",
                    "content": accumulated,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ] as [String: Any]
            ]

            self.dispatchEvent(name: "chat", payload: finalPayload)
        }
    }

    // MARK: - Event Dispatch

    nonisolated private func dispatchEvent(name: String, payload: [String: Any]) {
        // Dispatch to primary event handler
        _demoEventHandler.value?(name, payload)

        // Dispatch to all registered listeners
        let listeners = _demoListeners.value
        for (_, handler) in listeners {
            handler(name, payload)
        }
    }
}
