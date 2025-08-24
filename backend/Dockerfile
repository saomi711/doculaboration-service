# --------------------------------------------------------------
# Build the API container (fastapi + uvicorn + celery client)
# --------------------------------------------------------------
FROM python:3.9-slim

# ---- Install runtime deps (including ffmpeg if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    && rm -rf /var/lib/apt/lists/*

# ---- Create non‑root user (optional but good)
RUN useradd -m appuser
WORKDIR /app

# ---- Python deps
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Copy source
COPY backend/app ./app

# ---- Run as non‑root
USER appuser

EXPOSE 7000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7000"]