# ── Base image ────────────────────────────────────────────────────────────────
# CUDA 12.4 + cuDNN 9, Python 3.11 — matches GCP Deep Learning VM defaults
FROM nvidia/cuda:12.4.1-cudnn9-runtime-ubuntu22.04

# ── System deps ───────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3-pip \
    ffmpeg \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# ── Workdir ───────────────────────────────────────────────────────────────────
WORKDIR /app

# ── Python deps ───────────────────────────────────────────────────────────────
# Copy requirements first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir torch==2.3.0 --index-url https://download.pytorch.org/whl/cu121 \
    && pip install --no-cache-dir -r requirements.txt

# ── Pre-download models at build time ─────────────────────────────────────────
# This avoids cold-start delays in Cloud Run; models are baked into the image layer.
# Set WHISPER_MODEL_SIZE / EMBED_MODEL via build args to customise.
ARG WHISPER_MODEL_SIZE=large-v3
ARG EMBED_MODEL=BAAI/bge-small-en-v1.5

# Cache faster-whisper model weights
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('${WHISPER_MODEL_SIZE}', device='cpu', compute_type='int8')"

# Cache sentence-transformers model weights
RUN python3 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('${EMBED_MODEL}')"

# ── App source ────────────────────────────────────────────────────────────────
COPY app/ ./app/

# ── Runtime config ────────────────────────────────────────────────────────────
ENV WHISPER_MODEL_SIZE=${WHISPER_MODEL_SIZE}
ENV EMBED_MODEL=${EMBED_MODEL}
ENV WHISPER_DEVICE=cuda
ENV WHISPER_COMPUTE_TYPE=float16
ENV EMBED_DEVICE=cuda

# Cloud Run sends HTTP traffic to $PORT (default 8080)
ENV PORT=8080
EXPOSE 8080

# ── Entrypoint ────────────────────────────────────────────────────────────────
# --workers 1: keep models in a single process (they use 6–10 GB GPU VRAM)
CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8080", \
     "--workers", "1", \
     "--loop", "uvloop", \
     "--http", "h11"]
