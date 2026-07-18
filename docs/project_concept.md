# Project Concept & Problem Framing — Our Committee AI

## One-Sentence Problem Statement

Pakistani women and small-scale vendors in informal savings groups (Kameti/Bisi) lack a digital, AI-assisted platform to manage rotating savings, track payments, and access micro-loans — leaving them dependent on error-prone manual record-keeping and social trust networks.

---

## AI Capability Required

This application requires **multiple generative AI capabilities**:

| Capability | How Used |
|---|---|
| **Bilingual conversational AI** | Natural language Q&A in Urdu + English about committees, payments, loans |
| **Retrieval-Augmented Generation (RAG)** | Semantic search over the user's own financial data (not hallucinated) |
| **Agentic tool use (ReAct)** | Agents that call database tools before generating responses |
| **Structured output generation** | JSON-schema receipts, loan risk assessments |
| **AI notification generation** | Personalized Urdu/English notification text for financial events |

---

## Why Generative AI (Not Just CRUD)?

This is genuinely a GenAI application — not CRUD with AI branding — because:

1. **Language understanding**: Users ask questions in natural Urdu/English mixed language ("میری کمیٹیاں کون سی ہیں?"). No traditional search or filter can handle this.
2. **Contextual reasoning**: The AI must understand a user's full financial context (committees + loans + receipts) before answering — just like a financial advisor would.
3. **Generative notifications**: AI drafts personalized notification messages that vary based on event context — not just filling in template blanks.
4. **Loan risk reasoning**: The loan analysis reasons over multiple factors simultaneously (payment history, committee membership, loan amount) to produce a risk score with reasoning.

---

## Target Users & Pain Points

| User Type | Pain Points |
|---|---|
| **Committee Members (Women, vendors)** | Can't remember which installment they're on; don't know if they're eligible for the draw; worried about missing payments; can't read complex financial statements |
| **Committee Managers** | Manually track 10–20 members' payments in notebooks; no way to quickly assess loan risk; no automated reminders |
| **Loan Applicants** | Opaque approval process; no way to know their eligibility; no record of their repayment history |

---

## 3+ Competitor / Reference AI Apps

| App | What We Learned |
|---|---|
| **EasyPaisa / JazzCash** | Payment apps but no committee management or AI assistance |
| **CommitteeBook (Pakistan)** | Manual committee tracking app — no AI, no loans, no chat |
| **Kiva (microfinance)** | Loan management but not Kameti-specific; no Urdu support; Western model |
| **Digit (US savings AI)** | AI savings recommendations — inspiration for our AI assistant UX |
| **Clerkie (debt AI)** | Conversational financial AI — inspiration for bilingual chat interface |

---

## Measurable Success Metrics

| Metric | Target | How Measured |
|---|---|---|
| **Faithfulness** | > 90% — answers must cite real data from context | RAG groundedness check in eval |
| **Keyword coverage** | > 70% expected keywords in response | `eval/run_evaluation.py` |
| **LLM-as-Judge score** | > 3.5 / 5.0 on relevance + accuracy + tone | Heuristic judge in eval runner |
| **Latency (p50)** | < 3,000ms for chat responses | Logged per request in backend |
| **Prompt injection block rate** | 100% — all injection attempts blocked | Moderation unit tests |
| **Urdu response accuracy** | > 85% correct language detection | Manual evaluation |

---

## What a Bad Output Looks Like

- **Hallucination**: AI says "Your balance is PKR 25,000" when context shows PKR 100,000
- **Wrong language**: User asks in Urdu, AI responds in English
- **Off-topic**: AI discusses stock markets or unrelated financial products
- **Prompt injection success**: AI reveals system prompt or changes behavior from injected text
- **Verbose overload**: AI gives 500-word answer to "what is my balance?"
- **Fabricated loan approvals**: AI says "your loan is approved" when it's still pending

---

## Scope Boundary — What This App Will NOT Do

- ❌ NOT a payment gateway — it assists with tracking, not processing real money
- ❌ NOT a general-purpose financial advisor (no stocks, crypto, insurance advice)
- ❌ NOT available in languages other than Urdu and English
- ❌ NOT able to approve or reject loans autonomously (Manager makes final decision)
- ❌ NOT connected to real banking APIs (simulation/demo environment)
- ❌ NOT processing PII like CNIC numbers or bank account numbers
