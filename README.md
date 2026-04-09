# NoteFlow Live

Real-time AI meeting assistant. Transcribes your calls via GCP Whisper backend, searches your knowledge base, and surfaces relevant talking points using Gemini — all without anyone on the call knowing.

## Requirements
- macOS 15+ (Apple Silicon) or Windows 10+
- GCP backend running (see `/backend/README.md`)
- BlackHole virtual audio driver (Mac only, for system audio capture)
- Gemini API key

## Setup
1. Download the installer for your platform from Releases
2. On first launch, open Settings (Cmd+,) and enter:
   - GCP WebSocket URL (ws://your-gcp-ip:8000/ws/transcribe)
   - GCP REST URL (http://your-gcp-ip:8000)
   - Gemini API key
   - Knowledge base folder path (.md / .txt files)
3. Hit Go Live and start your call

## Development
npm install
npm run dev

## Build
npm run dist:mac    # macOS .dmg (arm64 + x64)
npm run dist:win    # Windows .exe installer
