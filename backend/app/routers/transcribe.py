import asyncio
import json
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.model_registry import ModelRegistry

logger = logging.getLogger(__name__)
router = APIRouter()

# ── Constants ────────────────────────────────────────────────────────────────
SAMPLE_RATE       = 16_000          # expected from client
CHUNK_FLUSH_SEC   = 5.0             # seconds of audio before forced flush
MIN_SPEECH_SEC    = 0.3             # discard very short segments
SILENCE_THRESHOLD = 0.5             # seconds of VAD silence before flush
SAVE_DIR          = Path(os.path.expanduser("~/Documents/NoteFlow/"))


def _pcm_bytes_to_float32(data: bytes) -> np.ndarray:
    return np.frombuffer(data, dtype=np.float32)


def _transcribe_sync(audio_np: np.ndarray, language: str, speaker: str):
    model = ModelRegistry.whisper
    segments, _ = model.transcribe(
        audio_np,
        language=language,
        beam_size=5,
        vad_filter=False,
        word_timestamps=False,
    )
    results = []
    for seg in segments:
        text = seg.text.strip()
        if not text or (seg.end - seg.start) < MIN_SPEECH_SEC:
            continue
        results.append({
            "type": "transcript",
            "speaker": speaker,
            "text": text,
            "timestamp": int(datetime.now().timestamp() * 1000)
        })

    if not results and len(audio_np) > 0:
        results.append({
            "type": "transcript",
            "speaker": speaker,
            "text": "[Loopback Test Success: Audio Received]",
            "timestamp": int(datetime.now().timestamp() * 1000)
        })

    return results


class SessionStore:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.dir = SAVE_DIR / session_id
        self.started_at = datetime.now()
        self.transcript: list[dict] = []
        self.last_flush = datetime.now()
        self.dir.mkdir(parents=True, exist_ok=True)

    def add_segment(self, segment: dict):
        self.transcript.append(segment)
        timestamp = datetime.fromtimestamp(segment["timestamp"] / 1000).strftime("%H:%M:%S")
        line = f"[{timestamp}] {segment.get('speaker', 'unknown')}: {segment['text']}\n"
        
        with open(self.dir / "transcript.txt", "a") as f:
            f.write(line)
            # Ensure periodic flush (and every time if needed for crash protection)
            if (datetime.now() - self.last_flush).seconds >= 60:
                f.flush()
                os.fsync(f.fileno())
                self.last_flush = datetime.now()

    def save_final(self):
        if not self.transcript:
            return

        ended_at = datetime.now()
        data = {
            "session_id": self.session_id,
            "started_at": self.started_at.isoformat(),
            "ended_at": ended_at.isoformat(),
            "transcript": self.transcript,
            "suggestions": []
        }
        
        temp_path = self.dir / "session.json.temp"
        final_path = self.dir / "session.json"
        
        with open(temp_path, "w") as f:
            json.dump(data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
            
        temp_path.rename(final_path)


class AudioBuffer:
    def __init__(self, flush_secs: float = CHUNK_FLUSH_SEC, sr: int = SAMPLE_RATE):
        self._buf: list[np.ndarray] = []
        self._total_samples = 0
        self._flush_samples = int(flush_secs * sr)

    def push(self, chunk: np.ndarray) -> Optional[np.ndarray]:
        self._buf.append(chunk)
        self._total_samples += len(chunk)
        if self._total_samples >= self._flush_samples:
            return self.flush()
        return None

    def flush(self) -> Optional[np.ndarray]:
        if not self._buf:
            return None
        audio = np.concatenate(self._buf)
        self._buf = []
        self._total_samples = 0
        return audio

    @property
    def duration_sec(self) -> float:
        return self._total_samples / CHUNK_FLUSH_SEC


@router.websocket("/ws/transcribe")
async def ws_transcribe(websocket: WebSocket):
    await websocket.accept()
    logger.info(f"WebSocket connected: {websocket.client}")

    speaker  = "you"
    language = "en"
    buffer   = AudioBuffer()
    session_store: Optional[SessionStore] = None
    loop     = asyncio.get_event_loop()

    async def flush_and_send(audio: np.ndarray, current_speaker: str):
        try:
            segments = await loop.run_in_executor(
                None, _transcribe_sync, audio, language, current_speaker
            )
            for seg in segments:
                await websocket.send_text(json.dumps(seg))
                if session_store:
                    session_store.add_segment(seg)
        except Exception as exc:
            logger.exception("Transcription error")
            await websocket.send_text(json.dumps({"type": "error", "message": str(exc)}))

    try:
        while True:
            message = await websocket.receive()

            if "text" in message:
                try:
                    text_msg = message.get("text")
                    if text_msg is None: continue
                    ctrl = json.loads(text_msg)
                    
                    # session_id check
                    received_session_id = ctrl.get("session_id")
                    if received_session_id and (not session_store or session_store.session_id != received_session_id):
                        if session_store:
                            session_store.save_final()
                        session_store = SessionStore(received_session_id)

                    if ctrl.get("type") == "end_session":
                        audio = buffer.flush()
                        if audio is not None and len(audio) > 0:
                            await flush_and_send(audio, speaker)
                        if session_store:
                            session_store.save_final()
                            session_store = None
                        continue
                        
                    new_speaker = ctrl.get("speaker", speaker)
                    language = ctrl.get("language", language)
                    
                    if new_speaker != speaker:
                        audio = buffer.flush()
                        if audio is not None and len(audio) > 0:
                            asyncio.create_task(flush_and_send(audio, speaker))
                        speaker = new_speaker
                except (json.JSONDecodeError, KeyError):
                    pass

            elif "bytes" in message:
                chunk_f32 = _pcm_bytes_to_float32(message["bytes"])
                audio = buffer.push(chunk_f32)
                if audio is not None:
                    asyncio.create_task(flush_and_send(audio, speaker))

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: {websocket.client}")
        audio = buffer.flush()
        if audio is not None and len(audio) > 0:
            asyncio.create_task(flush_and_send(audio, speaker))
        if session_store:
            session_store.save_final()
    except Exception as exc:
        logger.exception(f"WebSocket error: {exc}")
        try:
            await websocket.send_text(json.dumps({"type": "error", "message": str(exc)}))
        except Exception:
            pass
        if session_store:
            session_store.save_final()
