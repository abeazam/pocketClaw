import Foundation
import Citadel
import NIO
import NIOSSH

// MARK: - SSH Connection State

enum SSHConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

// MARK: - SSH Service

/// Manages an SSH connection with PTY support using Citadel.
final class SSHService {

    // MARK: - Callbacks

    var onDataReceived: ((_ data: Data) -> Void)?
    var onStateChanged: ((_ state: SSHConnectionState) -> Void)?

    // MARK: - Private State

    private var client: SSHClient?
    private var stdinWriter: TTYStdinWriter?
    private var ptyTask: Task<Void, Never>?
    private(set) var state: SSHConnectionState = .disconnected

    // MARK: - Connect

    func connect(host: String, port: Int, username: String, password: String) async throws {
        updateState(.connecting)

        do {
            let settings = SSHClientSettings(
                host: host,
                port: port,
                authenticationMethod: {
                    .passwordBased(username: username, password: password)
                },
                hostKeyValidator: .acceptAnything()
            )

            let sshClient = try await SSHClient.connect(to: settings)
            self.client = sshClient

            sshClient.onDisconnect { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleDisconnect()
                }
            }

            updateState(.connected)

            // Start PTY session in a background task
            ptyTask = Task { [weak self] in
                await self?.runPTYSession(client: sshClient)
            }
        } catch {
            updateState(.error(error.localizedDescription))
            throw error
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        ptyTask?.cancel()
        ptyTask = nil
        stdinWriter = nil

        Task {
            try? await client?.close()
            client = nil
        }

        updateState(.disconnected)
    }

    // MARK: - Send Data (keyboard → SSH stdin)

    func send(_ data: Data) {
        guard let writer = stdinWriter else { return }
        Task {
            var buffer = ByteBuffer()
            buffer.writeBytes(data)
            try? await writer.write(buffer)
        }
    }

    // MARK: - Resize PTY

    func resize(cols: Int, rows: Int) {
        guard let writer = stdinWriter else { return }
        Task {
            try? await writer.changeSize(
                cols: cols,
                rows: rows,
                pixelWidth: 0,
                pixelHeight: 0
            )
        }
    }

    // MARK: - Private: PTY Session

    private func runPTYSession(client: SSHClient) async {
        do {
            let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: 80,
                terminalRowHeight: 24,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: .init([
                    .ECHO: 1,
                    .ICANON: 1
                ])
            )

            try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
                guard let self else { return }
                self.stdinWriter = outbound

                for try await output in inbound {
                    if Task.isCancelled { break }
                    switch output {
                    case .stdout(let buffer):
                        if let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) {
                            let data = Data(bytes)
                            self.onDataReceived?(data)
                        }
                    case .stderr(let buffer):
                        if let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) {
                            let data = Data(bytes)
                            self.onDataReceived?(data)
                        }
                    }
                }
            }
        } catch {
            if !Task.isCancelled {
                updateState(.error("PTY session ended: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Private: State

    private func updateState(_ newState: SSHConnectionState) {
        state = newState
        onStateChanged?(newState)
    }

    private func handleDisconnect() {
        stdinWriter = nil
        ptyTask?.cancel()
        ptyTask = nil
        client = nil
        updateState(.disconnected)
    }
}
