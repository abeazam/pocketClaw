# PocketClaw

A native iOS client for [OpenClaw](https://openclaw.ai) — the open-source, self-hosted AI assistant platform.

PocketClaw connects to your own OpenClaw server over WebSocket and gives you full mobile access to chat, agents, skills, and scheduled tasks.

## Features

**Real-time Chat**
- Streaming responses — watch answers appear word by word
- Thinking Mode — see the AI's reasoning process in collapsible blocks
- Session management — create, rename, and delete conversations
- Copy and share any message
- 4,000 character input with live counter

**Agent Management**
- Browse all agents with live online/offline/busy status
- Switch the active agent on the fly
- View and edit agent configuration files (IDENTITY.md, etc.) with a built-in text editor

**Skill Control**
- Search, enable, and disable skills
- Inspect requirements and install missing dependencies
- View triggers, documentation links, and status

**Cron Job Monitoring**
- Human-readable schedule descriptions
- Pause and resume jobs with a tap
- View delivery targets (Telegram, Email, Slack, Webhook)

**Connection**
- Secure WebSocket (wss://) with token or password authentication
- iOS Keychain credential storage
- Auto-reconnection with visual status banners
- Self-signed certificate support

## Screenshots

*Coming soon*

## Requirements

- iOS 18.0+
- Xcode 16+
- A running [OpenClaw](https://openclaw.ai) server accessible from your device (see [Connecting to Your Server](#connecting-to-your-server) below)

## Building

Clone the repo and open in Xcode:

```bash
git clone https://github.com/abeazam/pocketClaw.git
cd pocketClaw
open PocketClaw.xcodeproj
```

Dependencies are managed via Swift Package Manager and will resolve automatically:

| Package | Version | Purpose |
|---------|---------|---------|
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | 0.7.3 | Markdown parsing |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | 4.2.2 | Secure credential storage |

Build and run on the simulator:

```bash
xcodebuild -scheme PocketClaw -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Run tests:

```bash
xcodebuild test -scheme PocketClaw -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Setup

On first launch, PocketClaw shows an onboarding screen:

1. Tap **Get Started**
2. Enter your OpenClaw server's WebSocket URL (e.g. `wss://your-server:18789`)
3. Choose authentication mode — **Token** or **Password**
4. Enter your credentials
5. Tap **Connect**

Settings can be changed later from the Settings tab.

## Architecture

```
Views (SwiftUI) <-> ViewModels (@Observable) <-> Services -> OpenClaw Server
                                                    |
                                                  Models (Codable)
```

- **MVVM + Observation** — `@Observable` ViewModels, no Combine
- **Swift 6 strict concurrency** — `MainActor` default isolation, all models are `Sendable`
- **Native networking** — `URLSessionWebSocketTask`, no third-party WebSocket libraries
- **OpenClaw Protocol v3** — typed JSON frames (`req`, `res`, `event`) over WebSocket

### Data Flow

| Data | Storage |
|------|---------|
| Server URL, theme, thinking mode | UserDefaults |
| Token / password | iOS Keychain |
| Sessions, messages, agents, skills, crons | Fetched from server (not persisted locally) |

## Protocol

PocketClaw speaks OpenClaw's JSON frame protocol v3:

- **`req`** — Client to server requests with `method` and `params`
- **`res`** — Server responses with `ok` boolean and `payload` or `error`
- **`event`** — Server push events (`chat`, `agent`, `connect.challenge`, `presence`)

### Authentication Handshake

1. Client opens WebSocket connection
2. Server sends `connect.challenge` event
3. Client responds with `connect` request containing protocol version, client info, and credentials
4. Server responds with `hello-ok` — authenticated

### RPC Methods Used

| Method | Purpose |
|--------|---------|
| `sessions.list` | List chat sessions |
| `sessions.delete` | Delete a session |
| `sessions.patch` | Rename a session |
| `chat.history` | Fetch message history |
| `chat.send` | Send a message |
| `agents.list` | List agents |
| `agents.files.list` | List agent config files |
| `agents.files.get` | Read a config file |
| `agents.files.set` | Write a config file |
| `skills.status` | List skills |
| `skills.update` | Enable/disable a skill |
| `skills.install` | Install skill dependencies |
| `cron.list` | List cron jobs |
| `cron.update` | Enable/disable a cron job |

---

## Connecting to Your Server

By default, OpenClaw's WebSocket endpoint listens on `localhost:18789` and is **not exposed to your network**. Your iPhone needs to be able to reach this endpoint for PocketClaw to work.

There are several ways to make your server accessible. Choose whichever fits your setup.

### Option 1: Same Wi-Fi Network

If your phone and server are on the same local network, use your server's local IP:

```
ws://192.168.1.100:18789
```

Note: This uses unencrypted `ws://`. Fine for a trusted home network, not recommended otherwise.

### Option 2: Reverse Proxy with TLS

Put OpenClaw behind a reverse proxy (Caddy, nginx, Traefik) with a domain and TLS certificate to get a proper `wss://` endpoint. This is the standard approach for exposing any service to the internet.

### Option 3: SSH Tunnel

For temporary access, forward the port over SSH from your phone (using an app like Termius or Blink):

```bash
ssh -L 18789:localhost:18789 user@your-server
```

Then connect to `ws://localhost:18789` on your phone.

---

### Option 4: Tailscale (Detailed Guide)

> **Disclaimer:** By following these instructions, you are exposing a service on your machine to your Tailscale network. Make sure you understand what Tailscale does, how your tailnet is configured, and who has access to it. Misconfiguration could expose your OpenClaw server to unintended parties. **This is entirely at your own risk.** The PocketClaw project is not responsible for any security issues arising from your network configuration.

[Tailscale](https://tailscale.com) creates a private mesh VPN between your devices. No port forwarding, no public exposure. Your server gets a stable hostname that only devices on your tailnet can reach.

#### Step 1: Install Tailscale on Your Server

On the machine running OpenClaw:

**macOS:**
```bash
# Install via Homebrew
brew install tailscale

# Or download from https://tailscale.com/download/mac
```

**Linux (Debian/Ubuntu):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

**Linux (other distros):** See https://tailscale.com/download/linux

Start Tailscale and authenticate:

```bash
sudo tailscale up
```

This opens a browser link to log in to your Tailscale account. Once authenticated, your machine joins your tailnet.

#### Step 2: Find Your Server's Tailscale Hostname

```bash
tailscale status
```

You'll see output like:

```
100.x.y.z    your-machine    your-email@  linux   -
```

Your Tailscale hostname is typically `your-machine` or you can use the MagicDNS name which looks like:

```
your-machine.tail-abcdef.ts.net
```

You can also find this in the [Tailscale admin console](https://login.tailscale.com/admin/machines).

#### Step 3: Install Tailscale on Your iPhone

1. Download **Tailscale** from the App Store
2. Open it and sign in with the same account you used on your server
3. Toggle the VPN on

Your phone is now on the same tailnet as your server.

#### Step 4: Verify Connectivity

On your iPhone, open Safari and navigate to:

```
http://your-machine.tail-abcdef.ts.net:18789
```

If OpenClaw is running and the port is accessible, you should get some kind of response (even an error page is fine — it means the connection works).

If it doesn't connect, make sure:
- OpenClaw is actually running on your server
- OpenClaw is listening on `0.0.0.0:18789` (not just `127.0.0.1:18789` — check your OpenClaw config)
- Both devices show as connected in the Tailscale admin console

#### Step 5: Connect PocketClaw

Open PocketClaw and enter your server URL:

```
wss://your-machine.tail-abcdef.ts.net:18789
```

Or if your OpenClaw instance doesn't have TLS:

```
ws://your-machine.tail-abcdef.ts.net:18789
```

Enter your token or password and tap Connect.

#### Important Notes

- **Tailscale must be active on both devices.** If the VPN is off on your phone, the connection will fail.
- **Binding address matters.** If OpenClaw is configured to listen on `127.0.0.1` (localhost only), Tailscale traffic won't reach it. You need it bound to `0.0.0.0` or the Tailscale IP specifically.
- **Tailscale HTTPS (optional).** Tailscale can provision TLS certificates for your machines via `tailscale cert`. This lets you use `wss://` without setting up your own certificates. See the [Tailscale HTTPS docs](https://tailscale.com/kb/1153/enabling-https).
- **ACLs.** If you have Tailscale ACLs (access control lists) configured, make sure your phone is allowed to reach the server on port 18789.
- **Battery.** Tailscale's VPN runs in the background on iOS. Battery impact is minimal but not zero.

---

## Privacy

PocketClaw connects directly to your server. There is no intermediary service, no cloud relay, no analytics, and no telemetry. Your conversations and data stay between your phone and your machine.

## Contributing

Contributions are welcome. Fork the repo, create a branch, and open a pull request.

Please follow existing code conventions:
- MVVM pattern with `@Observable` ViewModels
- Swift 6 strict concurrency (`Sendable` models, `MainActor` default isolation)
- No force unwraps or force try
- `final` on all classes
- One primary type per file

## License

[MIT](LICENSE)
