"""
NoteFlow GCP Backend — main entrypoint
Handles: WebSocket transcription (faster-whisper) + REST embeddings (sentence-transformers)
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import transcribe, embeddings, rerank
from app.core.model_registry import ModelRegistry

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ML models once at startup; release on shutdown."""
    logger.info("Loading models…")
    await ModelRegistry.load()
    logger.info("Models ready ✓")
    yield
    logger.info("Shutting down — releasing models")
    await ModelRegistry.unload()


app = FastAPI(
    title="NoteFlow Backend",
    description="Real-time transcription + embeddings for the NoteFlow macOS meeting assistant",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # tighten in production to your Mac's IP
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transcribe.router)
app.include_router(embeddings.router, prefix="/v1")
app.include_router(rerank.router, prefix="/v1")


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "models": await ModelRegistry.status(),
    }
