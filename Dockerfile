# ─────────────────────────────────────────────────────────────────
# Our Committee AI Backend — Dockerfile
# Target: Hugging Face Spaces (port 7860) / Render / Railway
# ─────────────────────────────────────────────────────────────────
FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port (7860 for HF Spaces, 8000 for local/Render)
EXPOSE 7860

# Start the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860", "--workers", "2"]
