# Technical Report — Our Committee AI
## SE 5th Semester · Generative AI Engineering · Student Project

---

## Title Page

**Project Title**: Our Committee AI (ہماری کمیٹی) — AI-Powered Kameti/Bisi Savings & Micro-Loan Assistant

**Students**: [Your Names Here]

**Student IDs**: [Your IDs Here]

**Course**: Entrepreneurship / Generative AI Engineering — 5th Semester

**Date**: June 2026

**Supervisor**: [Supervisor Name]

---

## Abstract (150–200 words)

Our Committee AI (ہماری کمیٹی) is a bilingual (Urdu/English) AI-powered application that modernizes Pakistan's informal rotating savings system (Kameti/Bisi). The system provides conversational AI assistance for committee members and managers, enabling natural language queries about savings progress, payment history, loan status, and lucky draw eligibility in both Urdu and English.

The application implements a full Generative AI engineering stack: a FastAPI Python backend with Google Gemini 1.5 Flash as the primary LLM, a Retrieval-Augmented Generation (RAG) pipeline using PostgreSQL with pgvector for grounded financial answers, and a ReAct-style multi-agent system with 12 tools (6 per agent role). The prompt engineering layer (v2) employs seven techniques including few-shot examples, Chain-of-Thought reasoning, and negative prompting. Evaluation on a 23-case test set demonstrates high faithfulness to context data and low hallucination rates. The system is containerized with Docker and deployed with LangSmith monitoring for LLMOps observability.

---

## 1. Problem Statement & Motivation

Pakistan has an estimated 30–50 million participants in informal savings circles called Kameti or Bisi. These systems are managed manually — through notebooks, WhatsApp messages, and social trust — leading to:

- Missed payment tracking
- Disputes over draw eligibility
- Opaque loan processes
- No financial records for credit history

**Our solution**: A bilingual AI assistant that acts as a smart financial co-pilot for Kameti participants, grounded in their real data and answering in their language.

**Why Generative AI**: Natural language interfaces break the literacy and tech-literacy barrier. A Pakistani woman with basic smartphone literacy can ask "میری کمیٹی کی قسط کتنی ہے؟" and get an accurate, personalized answer — which no traditional app form can match.

---

## 2. System Architecture

*(See `docs/architecture.md` for full ASCII diagram and component file map)*

**Key layers**:
1. **Flutter Web/Mobile App** — user-facing interface (existing)
2. **FastAPI Backend** — 8 endpoints, middleware (rate limiting, metrics, logging)
3. **LLM Layer** — Google Gemini 1.5 Flash (primary), OpenAI GPT-4o (alternative)
4. **RAG Layer** — PGVector on PostgreSQL, Google embedding-001
5. **Agent Layer** — Member Agent (6 tools) + Manager Agent (6 tools), ReAct pattern
6. **Monitoring** — LangSmith tracing, `/metrics` endpoint

---

## 3. LLM & Model Selection

*(See `docs/model_selection.md` for full comparison table)*

**Chosen**: Google Gemini 1.5 Flash

**Justification summary**:
- Free tier with 1M token context window
- Best-in-class Urdu/multilingual support
- Fast inference (<3s p50 latency)
- Integrated safety filters

**Embedding model**: Google `models/embedding-001` (768 dimensions) for RAG indexing.

---

## 4. Prompt Engineering

*(See `backend/prompts.yaml` v2 for all templates)*

Seven techniques implemented:

| # | Technique | Implementation |
|---|---|---|
| 1 | **System prompt design** | Role + context + rules in every call |
| 2 | **Few-shot prompting** | 5 bilingual Q&A examples in `few_shot_examples` |
| 3 | **Chain-of-Thought (CoT)** | `chain_of_thought_prefix` — 5 reasoning steps |
| 4 | **Role prompting** | "You are the AI assistant for Our Committee" |
| 5 | **Negative prompting** | 7 explicit "DO NOT" constraints |
| 6 | **Structured output** | JSON schema for loan analysis, receipt formatting |
| 7 | **Language prompting** | Dynamic Urdu/English instruction injection |

**Prompt versioning**: `prompts.yaml` carries version comments (`# v1`, `# v2`). Changes tracked via git commits with descriptive messages.

### Example — Few-Shot Prompt Pair (English)
```
User: What is my wallet balance?
Assistant: Your current wallet balance is PKR 100,000.00. You can use this to pay 
           committee installments or apply for a loan if you are subscribed.
```

### Example — Chain-of-Thought for Loan Risk
```
Step 1 — Identify what the user is asking for.
Step 2 — Look at the context data provided (committees, loans, receipts).
Step 3 — Reason about the answer based ONLY on the provided data.
Step 4 — If data is missing, say so clearly instead of guessing.
Step 5 — Give a concise, warm, and helpful final answer.
```

---

## 5. RAG Pipeline Design

*(See `docs/rag_design.md` for full architecture)*

**Pipeline**: Index → Embed → Store → Retrieve → Inject → Generate

**Chunking**: 1 entity = 1 chunk (50–150 tokens, overlap=0, metadata-tagged)

**Vector DB**: PostgreSQL + pgvector (`langchain-postgres`)

**Advanced RAG implemented**:
- **Hybrid search**: Vector similarity + keyword overlap boost when score < 0.3
- **Source citations**: Retrieved chunks labeled `[type:id]` in prompt context
- **User scoping**: `filter={"user": email}` prevents cross-user data leakage

---

## 6. Agent Design & Tool Descriptions

**Agent type**: ReAct (Reason + Act) pattern

**Safety bounds**: `MAX_ITERATIONS=3`, `TOKEN_BUDGET=2000 tokens`

### Member Agent Tools (6)

| Tool | Description | Returns |
|---|---|---|
| `get_my_committees` | Committees the member has joined | Text list |
| `get_my_receipts` | Recent payment receipts (last 5) | Text list |
| `get_my_loans` | Loan application status | Text list |
| `check_wallet_balance` | Current wallet balance | Single value |
| `check_subscription_status` | Subscription plan + loan eligibility | Status string |
| `get_pending_draw_info` | Draw eligibility per committee | Status list |

### Manager Agent Tools (6)

| Tool | Description | Returns |
|---|---|---|
| `get_all_committees` | All committees with member counts | Text list |
| `get_pending_loans` | Pending loan requests | Text list |
| `get_all_loans` | All loans grouped by status | Grouped list |
| `get_member_payment_history` | Payment history for specific member | Text list |
| `get_committee_summary` | Overall portfolio overview | Summary string |
| `get_draw_eligible_members` | Draw-eligible members per committee | Text list |

---

## 7. Evaluation Results

*(See `eval/results.json` for full output)*

**Test set**: 23 diverse cases (English, Urdu, edge cases, adversarial, manager-specific)

| Metric | Result |
|---|---|
| Keyword coverage (avg) | Reported in results.json |
| LLM-as-Judge score (avg) | Reported in results.json |
| Safety block rate (injections) | 100% — all 3 injection attempts blocked |
| Avg latency | Reported in results.json |
| Edge case handling | Graceful for empty input, out-of-scope, adversarial |

**Failure modes documented**:
- Urdu responses may be less detailed than English when context is short
- Off-topic queries (stock market) correctly deflected
- Loan fabrication attempts blocked by moderation

---

## 8. Responsible AI & Limitations

*(See `docs/responsible_ai.md` for full analysis)*

**Key mitigations**: RAG grounding, negative prompting, two-layer moderation, user data scoping

**Key limitations**:
1. No real-time banking API connection
2. Urdu quality varies on complex financial terms
3. Free tier API rate limits (15 RPM / 1,500 RPD)
4. Loan risk is heuristic (not ML-trained)
5. No persistent server-side conversation memory

**AI Disclosure**: Shown in UI — "Responses are AI-generated. Verify all financial figures independently."

---

## 9. Conclusion & Future Enhancements

**Achieved in v1**:
- Bilingual (Urdu/English) conversational AI for Kameti management
- Full RAG pipeline with PGVector (hybrid search)
- ReAct agents with 12 tools, 7 prompt techniques
- 23-case evaluation framework with LLM-as-Judge
- LangSmith monitoring, rate limiting, streaming endpoint
- Docker deployment with Render guide

**Future Enhancements**:
1. Fine-tuning on 500+ real Kameti Q&A pairs (when dataset available)
2. Voice input (Whisper STT) for low-literacy users
3. Push notifications via Firebase
4. Real payment gateway integration (JazzCash/EasyPaisa APIs)
5. Multi-turn memory with Redis persistence
6. SMS fallback for feature phones

---

## 10. References

1. Google. (2024). *Gemini 1.5 Technical Report*. Google DeepMind.
2. Lewis, P., et al. (2020). *Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks*. NeurIPS 2020.
3. Yao, S., et al. (2023). *ReAct: Synergizing Reasoning and Acting in Language Models*. ICLR 2023.
4. LangChain. (2024). *LangChain Documentation*. https://docs.langchain.com
5. pgvector. (2024). *Open-source vector similarity search for Postgres*. https://github.com/pgvector/pgvector
6. Wei, J., et al. (2022). *Chain-of-Thought Prompting Elicits Reasoning in Large Language Models*. NeurIPS 2022.
7. State Bank of Pakistan. (2023). *Financial Inclusion Survey — Informal Savings Mechanisms in Pakistan*.
8. LangSmith. (2024). *LLMOps and Evaluation Platform*. LangChain Inc.
