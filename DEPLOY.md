# NoteFlow GCP Deployment Guide

## VM: dextora-gpu
## Repo: https://github.com/Dityasaran/noteflowlive.git

## Current Status (as of Sat Apr  4 09:55:58 UTC 2026)
- GPU Service: Running on port 8000 (systemd: noteflow-backend)
- CPU Test Service: Running on port 8001 (manual, for testing)

## To go fully live, colleague needs to:

### 1. Open GCP Firewall Rules
- Port 8000 (TCP, 0.0.0.0/0) — NoteFlow GPU backend
- Port 3000 (TCP, 0.0.0.0/0) — Dextora3D frontend

### 2. Verify both services after firewall:
curl -k https://34.87.86.220:8000/health
curl http://34.87.86.220:3000

### 3. Mac App Settings (Cmd+,):
- WebSocket URL: wss://34.87.86.220:8000/ws/transcribe
- REST base URL: https://34.87.86.220:8000
- Gemini API key: set via swift set_gemini_key.swift YOUR_KEY

### 4. Services survive reboot automatically:
- noteflow-backend (systemd, enabled)
- Dextora3D needs: cd ~/dextora3d && npm start

## Project Structure
- ~/notetaker/noteflowlive — NoteFlow (port 8000/8001)
- ~/dextora3d — Dextora3D (port 3000)

## Sessions saved to:
~/Documents/NoteFlow/{session_id}/transcript.txt
~/Documents/NoteFlow/{session_id}/session.json
