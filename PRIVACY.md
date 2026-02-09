# Privacy Policy

**PocketClaw**
Last updated: February 9, 2026

## Overview

PocketClaw is a self-hosted AI client. It connects directly to a server that you own and operate. PocketClaw does not collect, store, transmit, or share any personal data with the developer or any third party.

## Data Collection

PocketClaw collects **no data whatsoever**. Specifically:

- No analytics or telemetry
- No crash reporting
- No usage tracking
- No advertising identifiers
- No device fingerprinting
- No cookies or web tracking

## Data Storage

All data is stored locally on your device:

| Data | Storage Location | Purpose |
|------|-----------------|---------|
| Server URL | Device (UserDefaults) | Connecting to your server |
| Authentication credentials | Device (iOS Keychain) | Authenticating with your server |
| Theme and display preferences | Device (UserDefaults) | Remembering your settings |

No data is stored on any external server controlled by the developer. Chat messages, agent configurations, skills, and cron jobs are fetched from and stored on your own self-hosted OpenClaw server.

## Network Communication

PocketClaw communicates exclusively with the server URL you provide during setup. All network traffic goes directly between your device and your server. There are no intermediate servers, relays, proxies, or third-party services involved.

The app does not contact any other server for any reason.

## Third-Party Services

PocketClaw uses no third-party services, SDKs, or APIs. The only external dependencies are open-source libraries used for code functionality:

- **swift-markdown** (Apple) — Markdown text rendering
- **KeychainAccess** — iOS Keychain wrapper for secure credential storage

Neither of these libraries transmit any data.

## Children's Privacy

PocketClaw does not knowingly collect any information from anyone, including children under the age of 13.

## Changes to This Policy

If this privacy policy changes, the updated version will be posted in this repository with an updated date.

## Contact

If you have questions about this privacy policy, you can open an issue on the [GitHub repository](https://github.com/abeazam/pocketClaw).
