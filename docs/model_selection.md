# LLM & Foundation Model Selection — Our Committee AI

## Models Compared

| Model | Best For | Context Window | Cost | Urdu Support | Verdict |
|---|---|---|---|---|---|
| **Gemini 1.5 Flash** | Fast, multilingual, free tier | 1M tokens | Free / very low | ✅ Excellent | ✅ **CHOSEN** |
| **GPT-4o** | Reasoning, coding, safety | 128K tokens | ~$5/1M tokens in | ⚠️ Good | Alt. provider |
| **Llama 3 (8B/70B)** | Open-source, self-hosted | 8K tokens | Free (compute cost) | ⚠️ Fair | Not chosen |
| **Claude Sonnet 3.5** | Long context, nuanced | 200K tokens | ~$3/1M tokens in | ⚠️ Good | Not chosen |
| **Mistral 7B** | Code, small footprint | 32K tokens | Free | ❌ Poor | Not chosen |

---

## Final Model Choice: Google Gemini 1.5 Flash

**Justification:**

1. **Urdu/multilingual support**: Gemini 1.5 Flash has strong multilingual capability, including Urdu (نستعلیق script), which is essential for our Pakistani user base.
2. **Free tier**: Google AI Studio provides a generous free tier — critical for a student project with no API budget.
3. **Speed**: Flash variant optimized for low-latency responses — important for chat UX.
4. **Context window**: 1M token context window means we can inject full user financial context without truncation.
5. **Safety built-in**: Google's safety filters provide baseline content moderation.

**Alternative**: OpenAI GPT-4o is supported as a drop-in alternative via `LLM_PROVIDER=openai` in `.env`.

---

## Embedding Model Selection

| Model | Dimensions | Cost | Performance |
|---|---|---|---|
| **Google embedding-001** | 768 | Free with Gemini key | ✅ Good |
| **text-embedding-3-small** | 1536 | ~$0.02/1M tokens | ✅ Good |
| **FakeEmbeddings (fallback)** | 768 | Free (random vectors) | ❌ Demo only |

**Chosen**: `models/embedding-001` (Google) when `LLM_PROVIDER=gemini`, `text-embedding-3-small` (OpenAI) when `LLM_PROVIDER=openai`.

**Fallback**: `FakeEmbeddings` used when no API key is configured — this allows the app to run in demo mode without real embeddings (RAG retrieval quality degrades).

---

## API & Access Setup

```
# .env configuration
LLM_PROVIDER=gemini
GEMINI_API_KEY=your_key_from_aistudio.google.com
GEMINI_MODEL=gemini-1.5-flash
```

**Rate Limits (Gemini free tier)**:
- 15 RPM (requests per minute)
- 1 million TPM (tokens per minute)
- 1,500 RPD (requests per day)

**Token counting strategy**:
- Prompt tokens: ~500–800 per chat turn (system prompt + history + user message)
- Completion tokens: ~100–300 per response
- Estimated cost at paid tier: ~$0.002–0.005 per conversation turn

---

## Hello World Test (Verified ✅)

```python
import google.generativeai as genai
genai.configure(api_key="YOUR_KEY")
model = genai.GenerativeModel("gemini-1.5-flash")
response = model.generate_content("Say hello in Urdu")
print(response.text)  # → "السلام علیکم!"
```

---

## LangSmith (LLMOps)

- **Tool**: LangSmith (free tier)
- **Purpose**: Trace every LLM call — prompt, response, tokens, latency, cost
- **Integration**: `@traceable` decorators on `llm_chat`, `generate_notification`, `format_receipt`, `analyze_loan_risk`
- **Dashboard**: `https://smith.langchain.com` → Project: `our-committee-ai`
