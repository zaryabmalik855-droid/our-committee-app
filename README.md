# 🏦 Our Committee AI — ہماری کمیٹی

> **AI-Powered Bilingual Assistant for Pakistan's Kameti/Bisi Savings & Micro-Loan System**

[![FastAPI](https://img.shields.io/badge/FastAPI-0.111-009688?style=flat&logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python)](https://python.org)
[![Gemini](https://img.shields.io/badge/LLM-Gemini%201.5%20Flash-4285F4?style=flat&logo=google)](https://ai.google.dev)
[![LangChain](https://img.shields.io/badge/LangChain-0.2-1C3C3C?style=flat)](https://langchain.com)
[![Streamlit](https://img.shields.io/badge/Frontend-Streamlit-FF4B4B?style=flat&logo=streamlit)](https://streamlit.io)

---

## 📋 Problem Statement

Millions of Pakistani women and small-scale vendors participate in informal savings circles called **Kameti or Bisi** — rotating pools where members contribute fixed amounts monthly and take turns receiving the pool. These are managed manually through notebooks and WhatsApp, leading to errors, disputes, and no credit history.

**Our Committee AI** provides a bilingual (Urdu/English) AI assistant that helps members and managers track payments, understand committee status, assess loan risk, and receive smart notifications — all through natural language conversation.

---

## 🎬 Demo

| Feature | Description |
|---|---|
| **💬 AI Chat** | Ask questions in Urdu or English about your committees, loans, and payments |
| **📊 Committee Insights** | Visual progress cards with AI-generated insights |
| **🔔 Notification Lab** | Generate personalized AI notifications for any event |
| **⚠️ Loan Risk Analyzer** | Manager tool: AI-powered loan risk assessment |
| **🔍 Semantic Search** | Natural language search across all financial data |

> **Live Demo**: `http://localhost:8501` (local) | Deploy to Render + Streamlit Cloud (see `docs/deployment_guide.md`)

---

## 🏗️ System Architecture

```
Flutter App / Streamlit UI
         │ HTTP REST
         ▼
   FastAPI Backend (Python)
   ├── /chat        → ReAct Agent (Member/Manager)
   ├── /chat/stream → Streaming SSE response
   ├── /search      → RAG semantic search
   ├── /loan/analyze → AI risk assessment
   ├── /notifications → AI notification generator
   ├── /health      → Status check
   └── /metrics     → LLMOps observability
         │
   ┌─────┼──────────────────┐
   ▼     ▼                  ▼
Gemini  PGVector        PostgreSQL
1.5    (RAG store)      (App data)
Flash
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **LLM** | Google Gemini 1.5 Flash (primary) / OpenAI GPT-4o (alternative) |
| **Orchestration** | LangChain 0.2 |
| **Vector DB** | PostgreSQL + pgvector (`langchain-postgres`) |
| **Embeddings** | Google `embedding-001` / `text-embedding-3-small` |
| **Backend** | FastAPI + Uvicorn (async) |
| **Database** | PostgreSQL + SQLAlchemy ORM |
| **Frontend** | Streamlit (dark theme, bilingual) |
| **Mobile App** | Flutter/Dart |
| **Monitoring** | LangSmith + `/metrics` endpoint |
| **Container** | Docker + docker-compose |

---

## 🤖 AI Features

### Prompt Engineering (v2 — 7 Techniques)
1. System prompt design (role + context + constraints)
2. Few-shot prompting (5 bilingual Q&A examples)
3. Chain-of-Thought reasoning
4. Role prompting
5. Negative prompting (explicit DO NOT rules)
6. Structured output (JSON schema)
7. Language instruction (Urdu/English switching)

### RAG Pipeline
- Index: all committee, loan, receipt, notification data → PGVector
- Retrieve: cosine similarity search (top-k=3)
- Advanced: hybrid search (vector + keyword) fallback
- Grounded answers: retrieved chunks injected with `[source:id]` citations

### ReAct Agents
| Agent | Tools | Use Case |
|---|---|---|
| Member Agent | 6 tools | Balance, receipts, loans, committees, draw, subscription |
| Manager Agent | 6 tools | All committees, all loans, member history, draw eligibility |

### Safety & Guardrails
- Prompt injection blocklist (14 patterns)
- Keyword moderation (English + Urdu offensive terms)
- OpenAI Moderation API (when using OpenAI provider)
- Rate limiting: 20 requests/minute per IP (sliding window)

---

## ⚡ Quick Start

### Prerequisites
- Python 3.11+
- PostgreSQL with pgvector extension
- Google Gemini API key (free at [aistudio.google.com](https://aistudio.google.com))

### 1. Clone & Setup
```bash
git clone https://github.com/YOUR_USERNAME/our-committee-ai.git
cd our-committee-ai/backend

python -m venv venv
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your actual API keys
```

### 3. Start Backend
```bash
python -m uvicorn main:app --reload --port 8000
# API docs: http://localhost:8000/docs
# Health check: http://localhost:8000/health
```

### 4. Start Streamlit Demo
```bash
cd ../streamlit_app
pip install streamlit requests
streamlit run app.py
# UI: http://localhost:8501
```

### 5. Run with Docker (Full Stack)
```bash
# From project root
cp backend/.env.example backend/.env
# Edit backend/.env
docker-compose up --build
```

---

## 📁 Project Structure

```
project/
├── backend/                   # FastAPI Python backend
│   ├── main.py               # All API endpoints + middleware
│   ├── prompts.yaml          # Prompt library (v2, versioned)
│   ├── database.py           # PostgreSQL connection
│   ├── models/
│   │   ├── schemas.py        # Pydantic request/response models
│   │   └── db.py             # SQLAlchemy ORM models
│   ├── services/
│   │   ├── llm_service.py    # Gemini/OpenAI wrapper
│   │   ├── rag_service.py    # PGVector RAG pipeline
│   │   └── agent_service.py  # ReAct agents + tools
│   ├── eval/
│   │   ├── test_set.json     # 23 diverse test cases
│   │   └── run_evaluation.py # Evaluation runner + metrics
│   ├── docs/                 # Documentation
│   │   ├── project_concept.md
│   │   ├── model_selection.md
│   │   ├── rag_design.md
│   │   ├── fine_tuning_decision.md
│   │   ├── architecture.md
│   │   ├── responsible_ai.md
│   │   ├── deployment_guide.md
│   │   └── technical_report_outline.md
│   ├── .env.example          # Environment template (NO real keys)
│   ├── requirements.txt
│   └── Dockerfile
├── streamlit_app/
│   ├── app.py               # Streamlit demo frontend
│   └── Dockerfile
├── lib/                     # Flutter app source
├── docker-compose.yml
└── README.md
```

---

## 🧪 Running Evaluation

```bash
# Ensure backend is running on localhost:8000
cd backend
python eval/run_evaluation.py

# Output: eval/results.json + console summary table
```

---

## 📊 Evaluation Metrics

| Metric | Description |
|---|---|
| **Keyword Coverage** | % of expected financial terms found in response |
| **LLM-as-Judge** | 1–5 score on relevance, accuracy, tone, length |
| **Safety Block Rate** | % of injection/adversarial attempts correctly blocked |
| **Avg Latency** | p50 response time per chat call |

---

## 🚀 Deployment

See [`docs/deployment_guide.md`](backend/docs/deployment_guide.md) for:
- Render (recommended — free tier)
- Streamlit Cloud
- Docker Compose (local)
- Hugging Face Spaces

---

## ⚠️ Responsible AI

- **Hallucination mitigation**: RAG grounding + negative prompting
- **Content moderation**: Two-layer (rule-based + API)
- **Data privacy**: No CNIC/bank account data; user-scoped retrieval
- **AI Disclosure**: Shown in UI — all responses are AI-generated

See [`docs/responsible_ai.md`](backend/docs/responsible_ai.md) for full analysis.

---

## 📝 License

MIT License — for academic use.

---

*Built with 🤖 Google Gemini + LangChain + PGVector | Made for Pakistan's Kameti/Bisi community 🇵🇰*
