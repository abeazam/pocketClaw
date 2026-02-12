# Terminal Integration Plan — Floating SSH Terminal

## Overview

Add a floating terminal button accessible from any tab that opens a full SSH terminal emulator in a sheet. Uses SwiftTerm for terminal UI and Citadel for SSH connectivity.

## UX

- Small floating button (SF Symbol `terminal`, terminal green) positioned bottom-right above tab bar
- Tapping opens a `.sheet` with either a connection form or live terminal
- SSH session persists when sheet is dismissed — re-opening resumes the session
- Host pre-filled from OpenClaw server URL (editable)
- Credentials saved in Keychain
- Single session, basic VT100/xterm emulation
- Hidden in demo mode

## New SPM Dependencies

| Package | URL | License |
|---|---|---|
| SwiftTerm | `https://github.com/migueldeicaza/SwiftTerm.git` | MIT |
| Citadel | `https://github.com/orlandos-nl/Citadel.git` | MIT |

## New Files

### 1. `Services/SSHService.swift`

Manages the Citadel SSH connection lifecycle.

```
final class SSHService {
    // Connection state
    enum State { case disconnected, connecting, connected, error(String) }

    // Connect with host, port, username, password
    func connect(host: String, port: Int, username: String, password: String) async throws

    // Disconnect and clean up
    func disconnect()

    // Send data from terminal keyboard to SSH PTY stdin
    func send(_ data: Data)

    // Callback: data received from SSH PTY stdout
    var onDataReceived: ((Data) -> Void)?

    // Callback: connection state changed
    var onStateChanged: ((State) -> Void)?

    // Resize PTY when terminal view resizes
    func resize(cols: Int, rows: Int)
}
```

Implementation notes:
- Use `SSHClient.connect(host:port:authenticationMethod:)` from Citadel
- Open a PTY channel via `client.requestPTY()` / `withPTY`
- Request shell on the channel
- Read loop: async read from channel, forward to `onDataReceived`
- Write: send keyboard input bytes to channel
- Handle disconnect/error gracefully

### 2. `ViewModels/TerminalViewModel.swift`

Bridges SSHService and the terminal view. Manages credentials and connection flow.

```
@Observable final class TerminalViewModel {
    // State
    var connectionState: SSHService.State = .disconnected
    var host: String = ""          // pre-filled from server URL
    var port: String = "22"
    var username: String = ""
    var password: String = ""
    var isShowingTerminal: Bool = false

    // References
    private let sshService = SSHService()
    private weak var terminalView: TerminalViewReference?

    // Actions
    func connect() async
    func disconnect()
    func loadSavedCredentials()
    func prefillHost(from serverURL: String)

    // Data flow
    func send(_ data: Data)             // terminal → SSH
    func handleDataReceived(_ data: Data) // SSH → terminal.feed()
}
```

Implementation notes:
- On connect success, save credentials to Keychain
- On disconnect, don't clear saved credentials (allow reconnect)
- Extract hostname from `wss://host:port` or `wss://host` URL format
- `terminalView` reference used to call `feed(byteArray:)` on data received

### 3. `Views/Terminal/TerminalContainerView.swift`

UIViewRepresentable wrapper around SwiftTerm's `TerminalView`.

```
struct TerminalContainerView: UIViewRepresentable {
    let viewModel: TerminalViewModel

    func makeUIView(context:) -> TerminalView
    func updateUIView(_:context:)

    class Coordinator: TerminalViewDelegate {
        // send(_:source:) — keyboard input → viewModel.send()
        // sizeChanged(source:newCols:newRows:) — resize → sshService.resize()
        // setTerminalTitle(source:title:) — optional, update nav title
    }
}
```

Implementation notes:
- Configure TerminalView appearance: dark background (#000), terminal green cursor, SF Mono font
- Set `TerminalViewDelegate` to the Coordinator
- Coordinator forwards keyboard bytes to TerminalViewModel
- TerminalViewModel calls `terminalView.feed(byteArray:)` when SSH data arrives
- Handle terminal resize events and propagate to SSH PTY

### 4. `Views/Terminal/SSHConnectionForm.swift`

Connection credential entry form.

```
struct SSHConnectionForm: View {
    @Bindable var viewModel: TerminalViewModel

    // Fields: host (pre-filled, editable), port (default 22), username, password (secure)
    // Connect button (disabled until valid)
    // Error message display
    // Loading state during connection
}
```

Implementation notes:
- Host field: pre-filled from `appVM.serverURL`, user can edit
- Port field: default "22", numeric keyboard
- Username field: text, no autocap
- Password field: SecureField
- Validate: host not empty, port is number, username not empty, password not empty
- On connect: call `viewModel.connect()`, show ProgressView
- Style: match existing app forms (monospaced URL fields, dark theme)

### 5. `Views/Terminal/TerminalSheetView.swift`

Sheet content that switches between form and terminal.

```
struct TerminalSheetView: View {
    let viewModel: TerminalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if viewModel.connectionState is .connected {
                TerminalContainerView(viewModel: viewModel)
                    .toolbar { disconnect button, dismiss button }
            } else {
                SSHConnectionForm(viewModel: viewModel)
                    .toolbar { dismiss button }
            }
        }
    }
}
```

Implementation notes:
- NavigationStack for toolbar buttons
- When connected: show terminal full-bleed, toolbar has "Disconnect" and "Done" (dismiss)
- When disconnected: show SSHConnectionForm
- When error: show form with error message
- Dark background, no safe area insets on terminal view

### 6. `Views/Terminal/FloatingTerminalButton.swift`

Overlay button displayed on MainTabView.

```
struct FloatingTerminalButton: View {
    @Binding var isShowingTerminal: Bool
    let isDemoMode: Bool

    var body: some View {
        if !isDemoMode {
            Button { isShowingTerminal = true } label: {
                Image(systemName: "terminal")
                    // 44pt circle, terminal green, slight shadow
                    // positioned bottom-right, above tab bar
            }
        }
    }
}
```

Implementation notes:
- Position: `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)`
- Padding: ~20pt from right edge, ~80pt from bottom (above tab bar)
- Style: filled circle background (dark gray/surface), terminal green icon
- Hidden when `isDemoMode == true`
- Optional: subtle pulse animation when SSH session is active

## Modified Files

### 7. `Services/KeychainService.swift`

Add SSH credential storage methods.

```swift
// MARK: - SSH Credentials

func saveSSHHost(_ host: String) throws
func loadSSHHost() -> String?
func saveSSHUsername(_ username: String) throws
func loadSSHUsername() -> String?
func saveSSHPassword(_ password: String) throws
func loadSSHPassword() -> String?
func saveSSHPort(_ port: Int) throws
func loadSSHPort() -> Int?
func deleteSSHCredentials() throws
```

Implementation notes:
- Use separate Keychain keys: `ssh_host`, `ssh_username`, `ssh_password`, `ssh_port`
- Same pattern as existing `saveToken`/`loadToken` methods
- `deleteSSHCredentials` clears all four

### 8. `Views/MainTabView.swift`

Add the floating button overlay and terminal sheet.

```swift
// Add to MainTabView:
@State private var isShowingTerminal = false

// In AppViewModel or MainTabView:
// Create TerminalViewModel (lazy, once)

// Add to body ZStack:
.overlay {
    FloatingTerminalButton(isShowingTerminal: $isShowingTerminal, isDemoMode: appVM.isDemoMode)
}
.sheet(isPresented: $isShowingTerminal) {
    TerminalSheetView(viewModel: terminalViewModel)
}
```

### 9. `PocketClaw.xcodeproj/project.pbxproj`

Add SwiftTerm and Citadel as SPM dependencies.

```
// XCRemoteSwiftPackageReference
SwiftTerm: https://github.com/migueldeicaza/SwiftTerm.git (upToNextMajor: 1.10.0)
Citadel: https://github.com/orlandos-nl/Citadel.git (upToNextMajor: 0.12.0)

// XCSwiftPackageProductDependency
SwiftTerm (product: SwiftTerm)
Citadel (product: Citadel)
```

## Data Flow

```
                    ┌─────────────────────────┐
                    │   TerminalContainerView  │
                    │   (UIViewRepresentable)  │
                    │                          │
  Keyboard input ──►│  SwiftTerm TerminalView  │◄── feed(byteArray:)
                    └──────────┬───────────────┘
                               │                         ▲
                          send(data)                     │
                               │                    handleDataReceived
                               ▼                         │
                    ┌──────────────────────────┐
                    │    TerminalViewModel      │
                    │    (@Observable)          │
                    └──────────┬───────────────┘
                               │                         ▲
                          send(data)              onDataReceived
                               │                         │
                               ▼                         │
                    ┌──────────────────────────┐
                    │      SSHService           │
                    │   (Citadel PTY channel)   │
                    └──────────┬───────────────┘
                               │                         ▲
                          stdin write              stdout read
                               │                         │
                               ▼                         │
                    ┌──────────────────────────┐
                    │    Remote SSH Server      │
                    └──────────────────────────┘
```

## Connection Flow

1. User taps floating terminal button
2. Sheet opens → checks for saved SSH credentials in Keychain
3. If saved: pre-fill form fields, user taps Connect
4. If not saved: show empty form (host pre-filled from server URL)
5. User fills credentials → taps Connect
6. TerminalViewModel saves to Keychain, calls SSHService.connect()
7. SSHService: Citadel SSHClient.connect() → requestPTY → shell
8. On success: state → .connected, sheet switches to TerminalContainerView
9. User interacts with terminal (full VT100 emulation)
10. Dismiss sheet → session stays alive in background
11. Re-open sheet → same terminal session, no reconnect needed
12. Disconnect button → SSHService.disconnect(), back to form

## Implementation Order

1. Add SwiftTerm + Citadel SPM dependencies to Xcode project
2. `KeychainService.swift` — add SSH credential methods
3. `SSHService.swift` — Citadel connection, PTY, data piping
4. `TerminalContainerView.swift` — UIViewRepresentable + delegate
5. `TerminalViewModel.swift` — state management, bridging
6. `SSHConnectionForm.swift` — credential entry UI
7. `TerminalSheetView.swift` — form/terminal switching
8. `FloatingTerminalButton.swift` — overlay button
9. `MainTabView.swift` — add overlay + sheet
10. Build, test SSH connection on simulator
11. Test on real device (SSH to local machine)

## Edge Cases to Handle

- SSH connection timeout (default 10s)
- Authentication failure → show error on form, don't clear fields
- Network loss during session → show reconnect prompt
- Terminal resize on device rotation
- Keyboard avoidance (terminal should resize, not scroll)
- Background/foreground → SSH connection may drop, handle gracefully
- Password with special characters → no escaping needed (Citadel handles raw)
- IPv6 addresses as host
- Non-standard SSH port
