"""
POST /v1/rerank

Cosine rerank endpoint — used by the Mac when it wants the server to
score a set of candidate KB chunks against a query embedding.

Request:
  {
    "query": "tell me about pricing",
    "candidates": [
      { "id": "uuid", "text": "...", "embedding": [0.1, ...] }
    ],
    "top_n": 3
  }

Response:
  {
    "results": [
      { "id": "uuid", "score": 0.87, "rank": 0 }
    ]
  }

The Mac can also do this locally with pure Swift — this endpoint is
provided for cases where the embedding dimension is large and Swift
SIMD math is slower than a GPU dot-product batch.
"""

import logging
from typing import Optional

import numpy as np
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.model_registry import ModelRegistry

logger = logging.getLogger(__name__)
router = APIRouter()


class Candidate(BaseModel):
    id: str
    text: Optional[str] = None       # optional — embed on server if no embedding provided
    embedding: Optional[list[float]] = None


class RerankRequest(BaseModel):
    query: str
    query_embedding: Optional[list[float]] = None   # skip embedding step if provided
    candidates: list[Candidate]
    top_n: int = 3


class RerankResult(BaseModel):
    id: str
    score: float
    rank: int


class RerankResponse(BaseModel):
    results: list[RerankResult]


@router.post("/rerank", response_model=RerankResponse)
async def rerank(req: RerankRequest):
    if not req.candidates:
        raise HTTPException(status_code=400, detail="candidates must not be empty")
    if req.top_n < 1:
        raise HTTPException(status_code=400, detail="top_n must be >= 1")

    embedder = ModelRegistry.embedder

    # ── Embed query if not provided ──────────────────────────────────────────
    if req.query_embedding:
        q_vec = np.array(req.query_embedding, dtype=np.float32)
    else:
        q_vec = embedder.encode(
            [req.query], normalize_embeddings=True, show_progress_bar=False
        )[0]

    # ── Embed any candidates that don't have pre-computed embeddings ─────────
    needs_embed = [c for c in req.candidates if c.embedding is None]
    if needs_embed:
        texts = [c.text or "" for c in needs_embed]
        vecs = embedder.encode(texts, normalize_embeddings=True, show_progress_bar=False)
        for c, vec in zip(needs_embed, vecs):
            c.embedding = vec.tolist()

    # ── Cosine scores (dot product since both are L2-normed) ────────────────
    scores = []
    for candidate in req.candidates:
        c_vec = np.array(candidate.embedding, dtype=np.float32)
        score = float(np.dot(q_vec, c_vec))
        scores.append((candidate.id, score))

    scores.sort(key=lambda x: x[1], reverse=True)
    top = scores[: req.top_n]

    results = [
        RerankResult(id=cid, score=score, rank=rank)
        for rank, (cid, score) in enumerate(top)
    ]
    return RerankResponse(results=results)
