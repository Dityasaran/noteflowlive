"""
POST /v1/embeddings

OpenAI-compatible embeddings endpoint.
Request body matches OpenAI's embeddings API so the Mac client can switch
between this GCP endpoint and any OpenAI-compatible provider without code changes.

Request:
  { "input": "some text" | ["batch", "of", "strings"], "model": "bge-small-en" }

Response:
  {
    "object": "list",
    "data": [
      { "object": "embedding", "index": 0, "embedding": [0.123, ...] }
    ],
    "model": "bge-small-en",
    "usage": { "prompt_tokens": N, "total_tokens": N }
  }
"""

import logging
from typing import Union

import numpy as np
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator

from app.core.model_registry import ModelRegistry

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_BATCH = 512  # max strings per request


class EmbeddingRequest(BaseModel):
    input: Union[str, list[str]]
    model: str = "bge-small-en"
    encoding_format: str = "float"

    @field_validator("input")
    @classmethod
    def coerce_to_list(cls, v):
        if isinstance(v, str):
            return [v]
        return v


class EmbeddingObject(BaseModel):
    object: str = "embedding"
    index: int
    embedding: list[float]


class EmbeddingResponse(BaseModel):
    object: str = "list"
    data: list[EmbeddingObject]
    model: str
    usage: dict


@router.post("/embeddings", response_model=EmbeddingResponse)
async def create_embeddings(req: EmbeddingRequest):
    texts: list[str] = req.input

    if len(texts) > MAX_BATCH:
        raise HTTPException(
            status_code=400,
            detail=f"Batch size {len(texts)} exceeds maximum {MAX_BATCH}",
        )
    if not texts or any(not t.strip() for t in texts):
        raise HTTPException(status_code=400, detail="Empty strings are not allowed")

    try:
        embedder = ModelRegistry.embedder
        # normalize=True → cosine similarity == dot product
        vecs: np.ndarray = embedder.encode(
            texts,
            normalize_embeddings=True,
            show_progress_bar=False,
            batch_size=64,
        )
    except Exception as exc:
        logger.exception("Embedding error")
        raise HTTPException(status_code=500, detail=str(exc))

    data = [
        EmbeddingObject(index=i, embedding=vec.tolist())
        for i, vec in enumerate(vecs)
    ]

    # Rough token count approximation (4 chars ≈ 1 token)
    total_tokens = sum(len(t) // 4 for t in texts)

    return EmbeddingResponse(
        data=data,
        model=req.model,
        usage={"prompt_tokens": total_tokens, "total_tokens": total_tokens},
    )
