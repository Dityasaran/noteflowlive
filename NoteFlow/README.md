# NoteFlow — macOS Client

This is the macOS client for NoteFlow, a meeting assistant that transcribes both your microphone and system audio (via virtual driver).

## Prerequisites

- **macOS 15+** (Sequoia)
- **Apple Silicon** (M1/M2/M3/M4)
- **Xcode 16+**

## Configuration

### GCP Project ID
The `GCP_PROJECT_ID` is currently a placeholder in `Sources/NoteFlowCore/Config.swift`. 
To deploy the backend and have the client connect, you must:
1. Replace `GCP_PROJECT_ID` in `deploy_gcp.sh` (backend root) or set it as an environment variable.
2. Update `Config.Default.wsURL` in `Sources/NoteFlowCore/Config.swift` with your deployed Cloud Run URL.

### Audio Setup (BlackHole)
For system audio capture (e.g., Zoom/Teams audio coming through speakers):
1. Download and install **BlackHole 2ch** from [existential.audio/blackhole](https://existential.audio/blackhole).
2. Set your **System Sound Output** to "BlackHole 2ch" or create a "Multi-Output Device" in Audio MIDI Setup.
3. The app will detect BlackHole at launch and show a setup banner if missing.

## Security

- **Keychain**: All sensitive URLs and API keys (Gemini, Backend) are stored in the macOS Keychain for security.
- **Privacy**: The main window has `NSWindow.sharingType = .none` set to prevent it from being seen in screen shares or recordings.
- **Entitlements**: App Sandbox is enabled with `network.client`, `audio-input`, and `files.user-selected.read-only` entitlements.
