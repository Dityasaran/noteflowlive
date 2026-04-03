"""
ModelRegistry — loads faster-whisper and sentence-transformers once at startup.
All routers access models through this registry (no per-request model loading).
"""

import logging
from typing import Optional

from faster_whisper import WhisperModel
from sentence_transformers import SentenceTransformer

logger = logging.getLogger(__name__)

# ── Configuration ────────────────────────────────────────────────────────────
# Override via environment variables in Cloud Run / Compute Engine

import os

WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "large-v3")
WHISPER_DEVICE     = os.getenv("WHISPER_DEVICE", "cuda")          # "cuda" or "cpu"
WHISPER_COMPUTE    = os.getenv("WHISPER_COMPUTE_TYPE", "float16") # "float16" | "int8"

EMBED_MODEL_NAME   = os.getenv("EMBED_MODEL", "BAAI/bge-small-en-v1.5")
EMBED_DEVICE       = os.getenv("EMBED_DEVICE", "cuda")


class _ModelRegistry:
    _whisper: Optional[WhisperModel] = None
    _embedder: Optional[SentenceTransformer] = None

    async def load(self):
        """Blocking model loads — runs once at lifespan startup."""
        import asyncio

        loop = asyncio.get_event_loop()

        logger.info(f"Loading Whisper model: {WHISPER_MODEL_SIZE} on {WHISPER_DEVICE}")
        self._whisper = await loop.run_in_executor(
            None,
            lambda: WhisperModel(
                WHISPER_MODEL_SIZE,
                device=WHISPER_DEVICE,
                compute_type=WHISPER_COMPUTE,
            ),
        )

        logger.info(f"Loading embedding model: {EMBED_MODEL_NAME} on {EMBED_DEVICE}")
        self._embedder = await loop.run_in_executor(
            None,
            lambda: SentenceTransformer(EMBED_MODEL_NAME, device=EMBED_DEVICE),
        )

    async def unload(self):
        self._whisper = None
        self._embedder = None

    async def status(self) -> dict:
        return {
            "whisper": self._whisper is not None,
            "embedder": self._embedder is not None,
        }

    @property
    def whisper(self) -> WhisperModel:
        if self._whisper is None:
            raise RuntimeError("Whisper model not loaded — server still initializing?")
        return self._whisper

    @property
    def embedder(self) -> SentenceTransformer:
        if self._embedder is None:
            raise RuntimeError("Embedder not loaded — server still initializing?")
        return self._embedder


ModelRegistry = _ModelRegistry()
