# RAG Pipeline Design — Our Committee AI

## Overview

Our Committee AI uses **Retrieval-Augmented Generation (RAG)** to ensure the AI assistant never hallucinates financial data. Instead of relying on the LLM's internal knowledge, all answers about committees, payments, and loans are grounded in real user data retrieved from a vector database.

---

## RAG Architecture

```
User Query
    │
    ▼
[Intent Classifier] → picks relevant tool
    │
    ▼
[Tool Execution] → gets structured DB data
    │
    ▼
[Vector Similarity Search] ─── PGVector (PostgreSQL)
    │                               │
    │                        [Embedding Model]
    │                     Google embedding-001
    ▼
[Context Injection]
"[committee:c1] Committee: Roshan Savings 2026..."
"[receipt:rec1] Payment receipt: PKR 10,000..."
    │
    ▼
[LLM Generation] — Gemini 1.5 Flash
    │
    ▼
[Grounded Response]
```

---

## Data Sources

All data comes from the **Flutter app's state** sent with every `/chat` request:

| Data Type | Examples |
|---|---|
| Committees | Name, contribution, members, draw winners, installments |
| Receipts | Type, amount, gateway, timestamp, reference |
| Loans | Applicant, amount, reason, status, repayment schedule |
| Notifications | Event type, title, body, timestamp |
| User profile | Name, role, balance, subscription status |

---

## Chunking Strategy

Each entity (committee, receipt, loan, notification) becomes **one chunk**:

```
chunk = "Committee: Roshan Savings 2026. Description: Monthly rotating savings pool.
         Total payout: PKR 100,000. Monthly contribution: PKR 10,000.
         Members: Ali Ahmed, Fatima Khan, Zainab Bibi. Draw winners: Zainab Bibi.
         Status: active. Progress: 4/10 installments paid."
```

**Rationale**:
- `chunk_size` ≈ 50–150 tokens (small — each record is self-contained)
- `chunk_overlap` = 0 (records don't need overlap — not narrative text)
- Metadata: `{"type": "committee", "id": "c1", "user": "fatima@gmail.com"}`
- User-scoped filtering: `filter={"user": user_email}` ensures users only see their own data

---

## Embedding Model

| Provider | Model | Dimensions |
|---|---|---|
| Google (default) | `models/embedding-001` | 768 |
| OpenAI (alternative) | `text-embedding-3-small` | 1536 |
| Fallback (no key) | `FakeEmbeddings` | 768 (random — demo only) |

---

## Vector Database: PostgreSQL + pgvector

**Chosen**: `PGVector` (LangChain integration with PostgreSQL)

**Why pgvector over Chroma/FAISS**:
- Already have PostgreSQL for the app database — reuse same server
- Production-grade, persistent, supports filtering
- `langchain-postgres` library provides clean integration
- Scales to thousands of records without separate server

**Setup**:
```sql
-- PostgreSQL requires pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
```

---

## Retrieval Configuration

- **similarity search**: Cosine distance (via pgvector)
- **top_k = 3** for chat context injection (k=5 for `/search` endpoint)
- **Similarity threshold**: Results with score < 0.3 trigger hybrid fallback

---

## Advanced RAG — Hybrid Search (Implemented)

When vector similarity is low (< 0.3), the system falls back to a **keyword overlap boost**:

```python
# Vector score: 0.25 (low)
# Query: "Roshan committee payment"
# Content tokens ∩ query tokens = {"roshan", "committee", "payment"} → overlap=3
# Boosted score: 0.25 + 3*0.05 = 0.40
```

This combines vector retrieval + BM25-style keyword scoring, implementing **hybrid search** as required by the advanced RAG checklist.

---

## Faithfulness / Groundedness

The system enforces faithfulness via:
1. **Context injection**: Retrieved chunks injected into prompt with `[source:id]` prefix
2. **Negative prompting**: System prompt says "Never hallucinate financial figures not in the context"
3. **Tool data injection**: Agent tools query the actual PostgreSQL database
4. **Evaluation**: `eval/run_evaluation.py` checks keyword coverage (groundedness proxy)

---

## End-to-End RAG Flow Example

**Query**: "What is my committee balance?"

1. `index_app_context()` — user's committees, receipts, loans indexed into PGVector
2. `get_context_for_query("committee balance", "fatima@gmail.com", top_k=3)`
3. Returns: `"[committee:c1] Committee: Roshan Savings 2026. Monthly contribution: PKR 10,000..."`
4. Injected into LLM prompt: `[CONTEXT FROM DATABASE]\n[committee:c1] ...`
5. LLM responds: "Your Roshan Savings 2026 committee requires PKR 10,000/month. You've paid 4/10 installments."
