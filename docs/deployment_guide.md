# Deployment Guide — Our Committee AI

## Architecture Overview

```
[GitHub Repo]
      │
      ▼ (auto-deploy on push)
[Render.com] ← Docker container
      │
      ├── FastAPI backend (port 8000)
      └── Connected to → [PostgreSQL DB (Render or Supabase)]
                    └── pgvector extension enabled

[Streamlit Cloud] ← streamlit_app/app.py
      │
      └── Connects to backend URL via BACKEND_URL env var
```

---

## Option 1: Deploy to Render (Recommended — Free Tier)

### Step 1: Prepare Repository
```bash
# Make sure .env is in .gitignore
echo ".env" >> .gitignore
echo "venv/" >> .gitignore
echo "__pycache__/" >> .gitignore

# Push to GitHub
git add .
git commit -m "feat: complete GenAI implementation"
git push origin main
```

### Step 2: Create PostgreSQL Database on Render
1. Go to [render.com](https://render.com) → New → PostgreSQL
2. Name: `committee-ai-db`
3. Plan: Free (90-day limit) or Starter ($7/month)
4. Copy the **Internal Database URL** — format: `postgresql://user:pass@host/db`
5. Enable pgvector:
   ```sql
   -- Connect to your Render DB and run:
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

### Step 3: Deploy FastAPI Backend
1. Render → New → Web Service
2. Connect your GitHub repository
3. **Settings**:
   - Name: `committee-ai-backend`
   - Runtime: `Docker`
   - Dockerfile path: `backend/Dockerfile`
   - Root directory: (leave blank)
4. **Environment Variables** (set in Render dashboard — never in code):
   ```
   LLM_PROVIDER=gemini
   GEMINI_API_KEY=your_actual_key
   GEMINI_MODEL=gemini-1.5-flash
   DATABASE_URL=postgresql://user:pass@host/db  ← from Step 2
   LANGCHAIN_TRACING_V2=true
   LANGCHAIN_API_KEY=your_langsmith_key
   LANGCHAIN_PROJECT=our-committee-ai
   ALLOWED_ORIGINS=https://your-streamlit-app.streamlit.app
   RATE_LIMIT_REQUESTS=20
   RATE_LIMIT_WINDOW=60
   APP_TITLE=Our Committee AI Backend
   APP_VERSION=1.0.0
   ```
5. Click **Create Web Service**
6. Wait for build (~3–5 minutes)
7. Note your backend URL: `https://committee-ai-backend.onrender.com`

### Step 4: Verify Backend Health
```bash
curl https://committee-ai-backend.onrender.com/health
# Expected: {"status":"ok","version":"1.0.0","llm_provider":"gemini","rag_ready":true}

curl https://committee-ai-backend.onrender.com/metrics
# Expected: {"total_requests":1,"error_rate":0,...}
```

---

## Option 2: Deploy Streamlit Frontend to Streamlit Cloud (Free)

1. Go to [share.streamlit.io](https://share.streamlit.io)
2. Connect GitHub → Select repo
3. **Settings**:
   - Main file: `streamlit_app/app.py`
   - Python version: 3.11
4. **Secrets** (Settings → Secrets):
   ```toml
   BACKEND_URL = "https://committee-ai-backend.onrender.com"
   ```
5. Deploy → Get URL: `https://your-app.streamlit.app`

---

## Option 3: Local Docker Compose (Full Stack)

```bash
# 1. Set up .env in backend/
cp backend/.env.example backend/.env
# Edit backend/.env with your actual API keys

# 2. Start everything
docker-compose up --build

# 3. Access:
# Backend: http://localhost:8000
# Streamlit: http://localhost:8501
# API docs: http://localhost:8000/docs
```

### docker-compose.yml services:
- `backend` — FastAPI (port 8000)
- `db` — PostgreSQL + pgvector (port 5432)
- `streamlit` — Streamlit UI (port 8501)

---

## Option 4: Deploy to Hugging Face Spaces (Free — Great for Demo)

1. Create account at [huggingface.co](https://huggingface.co)
2. New Space → Streamlit → Connect GitHub
3. Add `BACKEND_URL` to Space secrets
4. The Streamlit app will deploy automatically

> **Note**: HuggingFace Spaces only hosts the frontend. The FastAPI backend still needs to be deployed separately (Render recommended).

---

## Verify Deployment Checklist

```
[ ] Backend /health returns {"status": "ok"}
[ ] Backend /docs accessible (FastAPI Swagger UI)
[ ] Streamlit app loads and connects to backend
[ ] Chat message returns AI response (not error)
[ ] Urdu mode works (switch language toggle)
[ ] Manager mode shows pending loans
[ ] /metrics endpoint returns request stats
[ ] Rate limiting works (hit /chat 21 times quickly → 429 response)
```

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `LLM_PROVIDER` | Yes | `gemini` or `openai` |
| `GEMINI_API_KEY` | If Gemini | From Google AI Studio |
| `GEMINI_MODEL` | No | Default: `gemini-1.5-flash` |
| `OPENAI_API_KEY` | If OpenAI | From OpenAI Platform |
| `DATABASE_URL` | Yes | `postgresql://user:pass@host:port/db` |
| `LANGCHAIN_API_KEY` | Optional | LangSmith tracing |
| `LANGCHAIN_TRACING_V2` | Optional | `true` to enable LangSmith |
| `LANGCHAIN_PROJECT` | Optional | LangSmith project name |
| `ALLOWED_ORIGINS` | Yes | CORS origins (comma-separated) |
| `RATE_LIMIT_REQUESTS` | No | Default: 20 per minute |
| `RATE_LIMIT_WINDOW` | No | Default: 60 seconds |
| `APP_VERSION` | No | Shown in /health response |

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `pgvector not found` | Run `CREATE EXTENSION IF NOT EXISTS vector;` in PostgreSQL |
| `GEMINI_API_KEY not set — using mock` | Add key to `.env` and restart server |
| `RAG service not ready` | Check `DATABASE_URL` — pgvector must be reachable |
| `429 Too Many Requests` | Rate limit hit — wait 60s or increase `RATE_LIMIT_REQUESTS` |
| `Streamlit can't connect to backend` | Verify `BACKEND_URL` env var in Streamlit secrets |
| Docker build fails on Windows | Ensure Docker Desktop is running; use WSL2 backend |
