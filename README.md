# NoteFlow: Real-Time Meeting Assistant

NoteFlow is a professional macOS application designed to sit invisibly beside your video calls, providing real-time transcription and semantic suggestions from your personal knowledge base.

## 1. Prerequisites
- **macOS 14+**: Leverages modern SwiftUI and Accelerate framework.
- **BlackHole 2ch**: [Download here](https://existential.audio/blackhole). Required to route system audio (Zoom/Teams/Meet) into for transcription.
- **GCP Project**: A Google Cloud Project with the Gemini API enabled.
- **Compute**: A machine (local or GPU VM) to run the `faster-whisper` backend.

## 2. GCP Backend Deployment

### Local Docker Build
```bash
cd backend
docker build -t noteflow-backend .
docker run -p 8080:8080 -e WHISPER_MODEL=tiny -e EMBEDDING_MODEL=nomic-embed-text noteflow-backend
```

### Cloud Run / VM Requirements
- **VCPUs**: 4+ recommended for real-time transcription.
- **Memory**: 4GB+
- **GPU (Optional)**: If using `device="cuda"`, ensure NVIDIA drivers are installed.

## 3. Mac App Setup

### Build

# Full build → sign → install
./scripts/build_swift_app.sh

# Package as DMG for distribution
./scripts/make_dmg.sh

### Security Configuration
NoteFlow uses the macOS Keychain to store sensitive URLs and API keys. Use the included utility to set your keys before the first run:
```bash
# Set your Gemini API Key
swift set_gemini_key.swift YOUR_GEMINI_KEY

# Set your Backend URLs
# (These can also be set via Cmd + , in the app)
```

## 4. First Run Walkthrough
1. **Index your KB**: Open Settings (**Cmd + ,**), choose your Markdown/Text folder, and click "Re-index KB now". Wait for the "847 chunks ready" status.
2. **Setup Audio**: Ensure your Meeting software output is set to "BlackHole 2ch".
3. **Go Live**: Click the green "Go Live" button.
4. **Speak**: As speakers talk, transcripts will appear. If a topic matches your KB, a suggestion card will slide in from the top.
5. **Auto-Save**: Click "Stop" to finish. The session is saved to `~/Documents/NoteFlow/`.

## 5. Troubleshooting

| Issue | Solution |
|-------|----------|
| **No "Them" Audio** | Verify your Mac Speaker output is set to "BlackHole 2ch". |
| **GCP Connection Error** | Confirm your WebSocket URL (ws://...) in Settings is correct and the backend is running. |
| **No Suggestions** | Check if the KB indexing finished and your Gemini API Key is valid. |
| **Keychain Prompt** | Click "Always Allow" when macOS asks for permission to read NoteFlow secrets. |
| **Transcription Delay** | Ensure your backend server has at least 4 vCPUs or a GPU. |

---
*NoteFlow ensures privacy by setting `NSWindow.sharingType = .none`, preventing it from ever appearing in screen shares.*
