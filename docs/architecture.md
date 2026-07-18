# System Architecture — Our Committee AI

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACES                              │
│                                                                       │
│   Flutter Web App (Mobile/Web)        Streamlit Demo UI              │
│   lib/ — Dart/Flutter                 streamlit_app/app.py           │
└───────────────────────┬───────────────────────┬─────────────────────┘
                        │ HTTP REST              │ HTTP REST
                        │ JSON payloads          │ JSON payloads
                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     FastAPI Backend (Python)                          │
│                     backend/main.py — Port 8000                       │
│                                                                       │
│   POST /chat          → Agent Service (ReAct)                        │
│   POST /chat/stream   → Streaming SSE response                       │
│   POST /search        → RAG Service (semantic search)                │
│   POST /loan/analyze  → LLM Service (risk assessment)                │
│   POST /notifications → LLM Service (notification gen)               │
│   POST /receipts      → LLM Service (receipt formatter)              │
│   GET  /health        → Status check                                 │
│   GET  /metrics       → LLMOps observability                         │
│                                                                       │
│   Middleware: Rate limiting (20 req/min) + Request logging           │
└───────┬──────────────────┬───────────────────┬──────────────────────┘
        │                  │                    │
        ▼                  ▼                    ▼
┌─────────────┐   ┌─────────────────┐   ┌──────────────────────┐
│  LLM Layer  │   │   RAG Layer     │   │   Database Layer     │
│             │   │                 │   │                      │
│ Google      │   │ PGVector        │   │ PostgreSQL           │
│ Gemini 1.5  │   │ (langchain-     │   │ - users             │
│ Flash       │   │  postgres)      │   │ - committees         │
│             │   │                 │   │ - loans             │
│ OR          │   │ Embeddings:     │   │ - receipts          │
│ OpenAI      │   │ Google          │   │                      │
│ GPT-4o      │   │ embedding-001   │   │ SQLAlchemy ORM      │
└─────────────┘   └─────────────────┘   └──────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        LLMOps Monitoring                              │
│                                                                       │
│  LangSmith (@traceable decorators)                                   │
│  - Traces: llm_chat, generate_notification, format_receipt           │
│  - Evaluation: eval/run_evaluation.py                                │
│  /metrics endpoint — in-memory request stats                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Agent Architecture (ReAct Pattern)

```
User Message
     │
     ▼
Intent Classifier (keyword-based)
     │
     ├─── "loan" → get_my_loans / get_pending_loans
     ├─── "committee" → get_my_committees / get_all_committees
     ├─── "payment" → get_my_receipts / get_member_payment_history
     ├─── "balance" → check_wallet_balance
     ├─── "draw" → get_pending_draw_info / get_draw_eligible_members
     └─── "general" → no tool (RAG only)
              │
              ▼
        Tool Execution (MAX_ITERATIONS=3, TOKEN_BUDGET=2000)
              │
              ▼
        RAG Retrieval (PGVector, top_k=3)
              │
              ▼
        Context Assembly:
        [TOOL DATA] + [CONTEXT FROM DATABASE]
              │
              ▼
        LLM Generation (Gemini 1.5 Flash)
              │
              ▼
        Response + Sources + Actions Taken
```

---

## Conversation Memory Strategy

- **Type**: In-memory window buffer (last 10 turns)
- **Implementation**: `history: list[ChatMessage]` sent by client on each request
- **Storage**: Client-side (Flutter session state / Streamlit `st.session_state`)
- **Why client-side**: Stateless backend is easier to scale; no session server needed
- **Max history**: 10 turns (controlled in `_gemini_chat` and `_openai_chat`)

**Trade-off**: In-memory means history is lost on page refresh. For production, this would be upgraded to Redis-backed sessions.

---

## Data Flow: /chat Request

```
1. Flutter sends:
   POST /chat
   {
     "message": "What is my balance?",
     "history": [...last 10 turns...],
     "context": {user, committees, loans, receipts, notifications},
     "agent_type": "member"
   }

2. Backend:
   a. Input moderation (blocklist + OpenAI moderation API)
   b. Sync context → PostgreSQL (upsert all entities)
   c. Index context → PGVector (embed + store)
   d. Intent classification → tool selection
   e. Tool execution → DB query result
   f. RAG retrieval → semantic search results
   g. LLM call (Gemini) → bilingual response
   h. Return: {reply, sources, intent, actions_taken, language}

3. Streamlit/Flutter displays reply with sources
```

---

## Component File Map

| Component | File | Role |
|---|---|---|
| API router | `backend/main.py` | All endpoints, middleware, rate limiting |
| LLM wrapper | `services/llm_service.py` | Gemini/OpenAI calls, prompt building |
| RAG engine | `services/rag_service.py` | PGVector indexing + retrieval |
| Agent logic | `services/agent_service.py` | ReAct agent, tools, intent classification |
| Data schemas | `models/schemas.py` | Pydantic request/response models |
| DB models | `models/db.py` | SQLAlchemy ORM table definitions |
| DB connection | `database.py` | PostgreSQL session management |
| Prompt library | `prompts.yaml` | All prompt templates (versioned) |
| Evaluation | `eval/run_evaluation.py` | 23-example test runner |
| Frontend | `streamlit_app/app.py` | Demo UI (dark theme, bilingual) |

---

## Technology Stack Summary

| Layer | Technology | Why |
|---|---|---|
| Language | Python 3.11+ | Mature AI/ML ecosystem |
| API Framework | FastAPI | Async, Pydantic validation, auto-docs |
| LLM | Gemini 1.5 Flash | Free tier, Urdu support, fast |
| Orchestration | LangChain | RAG pipelines, embeddings, traceable |
| Vector DB | PGVector (PostgreSQL) | Reuse existing DB, production-grade |
| App DB | PostgreSQL + SQLAlchemy | Relational data with strong ORM |
| Evaluation | LangSmith + custom runner | Tracing, test set, metrics |
| Frontend | Streamlit | Fast demo UI with dark theme |
| Mobile app | Flutter/Dart | Cross-platform mobile (existing) |
| Container | Docker + docker-compose | Reproducible deployment |
