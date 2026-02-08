import Foundation

// MARK: - OpenClaw Error

enum OpenClawError: Error, LocalizedError {
    case notConnected
    case authenticationFailed(String)
    case requestTimeout(method: String)
    case serverError(String)
    case decodingError(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to server"
        case .authenticationFailed(let msg): "Authentication failed: \(msg)"
        case .requestTimeout(let method): "Request timed out: \(method)"
        case .serverError(let msg): "Server error: \(msg)"
        case .decodingError(let msg): "Decoding error: \(msg)"
        case .connectionFailed(let msg): "Connection failed: \(msg)"
        }
    }
}

// MARK: - Event Handler

typealias EventHandler = @Sendable (String, [String: Any]) -> Void

// MARK: - OpenClaw Client

final class OpenClawClient: NSObject, Sendable {
    // Connection config
    private let url: URL
    private let authToken: String?
    private let authPassword: String?

    // Nonisolated mutable state protected by locks
    private let _webSocketTask = MutableBox<URLSessionWebSocketTask?>(nil)
    private let _pendingRequests = MutableBox<[String: CheckedContinuation<ResponseFrame, Error>]>([:])
    private let _nextRequestId = MutableBox<Int>(1)
    private let _isConnected = MutableBox<Bool>(false)
    private let _receiveLoopTask = MutableBox<Task<Void, Never>?>(nil)

    // Callbacks (set once, then read from receive loop)
    private let _onConnectionStateChanged = MutableBox<(@Sendable (ConnectionState) -> Void)?>(nil)
    private let _onEvent = MutableBox<EventHandler?>(nil)

    // Multi-listener support for event dispatch (keyed by listener ID)
    private let _eventListeners = MutableBox<[String: EventHandler]>([:])

    // MARK: - Init

    init(url: URL, token: String? = nil, password: String? = nil) {
        self.url = url
        self.authToken = token
        self.authPassword = password
        super.init()
    }

    // MARK: - Callbacks

    func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void) {
        _onConnectionStateChanged.value = handler
    }

    func setEventHandler(_ handler: @escaping EventHandler) {
        _onEvent.value = handler
    }

    /// Add a named event listener. Returns the listener ID for removal.
    @discardableResult
    func addEventListener(id: String, handler: @escaping EventHandler) -> String {
        _eventListeners.mutate { listeners in
            listeners[id] = handler
        }
        return id
    }

    /// Remove a previously added event listener by ID.
    func removeEventListener(id: String) {
        _eventListeners.mutate { listeners in
            listeners.removeValue(forKey: id)
        }
    }

    // MARK: - Connect

    func connect() async throws {
        _onConnectionStateChanged.value?(.connecting)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        _webSocketTask.value = task
        task.resume()

        // Start the receive loop
        let loopTask = Task { [weak self] in
            await self?.receiveLoop()
            return
        }
        _receiveLoopTask.value = loopTask

        // Wait for challenge event, then authenticate
        try await waitForChallengeAndAuth()
    }

    // MARK: - Disconnect

    func disconnect() {
        _receiveLoopTask.value?.cancel()
        _receiveLoopTask.value = nil
        _webSocketTask.value?.cancel(with: .goingAway, reason: nil)
        _webSocketTask.value = nil
        _isConnected.value = false
        _onConnectionStateChanged.value?(.disconnected)

        // Cancel all pending requests
        let pending = _pendingRequests.value
        _pendingRequests.value = [:]
        for (_, continuation) in pending {
            continuation.resume(throwing: OpenClawError.notConnected)
        }
    }

    // MARK: - Send Request (RPC)

    func sendRequest(method: String, params: [String: Any] = [:]) async throws -> ResponseFrame {
        guard _webSocketTask.value != nil, _isConnected.value else {
            throw OpenClawError.notConnected
        }

        let requestId = String(_nextRequestId.mutate { id in
            let current = id
            id += 1
            return current
        })

        let codableParams = params.mapValues { AnyCodable($0) }
        let frame = RequestFrame(id: requestId, method: method, params: codableParams.isEmpty ? nil : codableParams)

        let data = try JSONEncoder().encode(frame)
        let message = URLSessionWebSocketTask.Message.data(data)
        try await _webSocketTask.value?.send(message)

        // Wait for response with timeout
        return try await withCheckedThrowingContinuation { continuation in
            _pendingRequests.mutate { pending in
                pending[requestId] = continuation
            }

            // Timeout after configured seconds
            Task {
                try? await Task.sleep(for: .seconds(Constants.requestTimeoutSeconds))
                let removed = _pendingRequests.mutate { pending -> CheckedContinuation<ResponseFrame, Error>? in
                    pending.removeValue(forKey: requestId)
                }
                removed?.resume(throwing: OpenClawError.requestTimeout(method: method))
            }
        }
    }

    // MARK: - Convenience RPC

    func sendRequestPayload(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let response = try await sendRequest(method: method, params: params)
        guard response.ok else {
            let errMsg = response.error?.message ?? "Unknown error"
            throw OpenClawError.serverError(errMsg)
        }
        return response.payload?.dictValue ?? [:]
    }

    /// Returns the raw payload value — may be an array, dict, or primitive.
    /// Use this when the server response could be a top-level array (e.g. sessions.list, chat.history).
    func sendRequestRaw(method: String, params: [String: Any] = [:]) async throws -> Any {
        let response = try await sendRequest(method: method, params: params)
        guard response.ok else {
            let errMsg = response.error?.message ?? "Unknown error"
            throw OpenClawError.serverError(errMsg)
        }
        return response.payload?.value ?? [String: Any]()
    }

    // MARK: - Private: Receive Loop

    private func receiveLoop() async {
        guard let task = _webSocketTask.value else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .data(let d):
                    data = d
                case .string(let s):
                    data = Data(s.utf8)
                @unknown default:
                    continue
                }

                let frame = ServerFrame.parse(from: data)
                switch frame {
                case .response(let res):
                    handleResponse(res)
                case .event(let evt):
                    handleEvent(evt)
                case .unknown:
                    break
                }
            } catch {
                // WebSocket disconnected
                if !Task.isCancelled {
                    _isConnected.value = false
                    _onConnectionStateChanged.value?(.error("Connection lost"))
                }
                break
            }
        }
    }

    // MARK: - Private: Handle Response

    private func handleResponse(_ response: ResponseFrame) {
        let continuation = _pendingRequests.mutate { pending in
            pending.removeValue(forKey: response.id)
        }
        continuation?.resume(returning: response)
    }

    // MARK: - Private: Handle Event

    private func handleEvent(_ event: EventFrame) {
        let eventName = event.event
        let payload = event.payload?.dictValue ?? [:]

        // Dispatch to primary handler
        _onEvent.value?(eventName, payload)

        // Dispatch to all registered listeners
        let listeners = _eventListeners.value
        for (_, handler) in listeners {
            handler(eventName, payload)
        }
    }

    // MARK: - Private: Challenge & Auth

    private func waitForChallengeAndAuth() async throws {
        // Set up a temporary event handler to catch the challenge
        let challengeReceived = MutableBox<Bool>(false)
        let previousHandler = _onEvent.value

        _onEvent.value = { [weak self] eventName, payload in
            if eventName == "connect.challenge" {
                challengeReceived.value = true
            }
            // Also forward to any existing handler
            previousHandler?(eventName, payload)
        }

        // Wait for challenge (up to 10 seconds)
        for _ in 0..<100 {
            if challengeReceived.value { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        // Restore original handler
        _onEvent.value = previousHandler

        guard challengeReceived.value else {
            _onConnectionStateChanged.value?(.error("No challenge received"))
            throw OpenClawError.connectionFailed("Server did not send challenge")
        }

        // Send connect request
        var authDict: [String: Any] = [:]
        if let token = authToken, !token.isEmpty {
            authDict["token"] = token
        } else if let password = authPassword, !password.isEmpty {
            authDict["password"] = password
        }

        let params: [String: Any] = [
            "minProtocol": Constants.protocolVersion,
            "maxProtocol": Constants.protocolVersion,
            "role": Constants.clientRole,
            "client": [
                "id": Constants.clientId,
                "displayName": Constants.clientDisplayName,
                "version": Constants.appVersion,
                "platform": Constants.clientPlatform,
                "mode": Constants.clientMode
            ] as [String: Any],
            "auth": authDict
        ]

        let response = try await sendRequestInternal(method: "connect", params: params)

        guard response.ok else {
            let errMsg = response.error?.message ?? "Authentication failed"
            _onConnectionStateChanged.value?(.error(errMsg))
            throw OpenClawError.authenticationFailed(errMsg)
        }

        // Check for hello-ok
        let payloadType = response.payload?.dictValue?["type"] as? String
        guard payloadType == "hello-ok" else {
            let errMsg = "Unexpected response type: \(payloadType ?? "nil")"
            _onConnectionStateChanged.value?(.error(errMsg))
            throw OpenClawError.authenticationFailed(errMsg)
        }

        _isConnected.value = true
        _onConnectionStateChanged.value?(.connected)
    }

    /// Send a request without requiring isConnected (used during handshake)
    private func sendRequestInternal(method: String, params: [String: Any]) async throws -> ResponseFrame {
        let requestId = String(_nextRequestId.mutate { id in
            let current = id
            id += 1
            return current
        })

        let codableParams = params.mapValues { AnyCodable($0) }
        let frame = RequestFrame(id: requestId, method: method, params: codableParams.isEmpty ? nil : codableParams)

        let data = try JSONEncoder().encode(frame)
        let message = URLSessionWebSocketTask.Message.data(data)
        try await _webSocketTask.value?.send(message)

        return try await withCheckedThrowingContinuation { continuation in
            _pendingRequests.mutate { pending in
                pending[requestId] = continuation
            }

            Task {
                try? await Task.sleep(for: .seconds(Constants.requestTimeoutSeconds))
                let removed = _pendingRequests.mutate { pending -> CheckedContinuation<ResponseFrame, Error>? in
                    pending.removeValue(forKey: requestId)
                }
                removed?.resume(throwing: OpenClawError.requestTimeout(method: method))
            }
        }
    }
}

// MARK: - URLSession Delegate (Certificate Trust)

extension OpenClawClient: URLSessionDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Accept self-signed certs for local development
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Thread-Safe Mutable Box

final class MutableBox<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        _value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }

    @discardableResult
    func mutate<R>(_ transform: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return transform(&_value)
    }
}
