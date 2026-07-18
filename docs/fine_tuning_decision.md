# Fine-Tuning Decision Gate — Our Committee AI

## Decision: NOT Fine-Tuning (Justified)

After evaluating the decision gate criteria from the checklist, we have decided **NOT** to fine-tune a model for this project. Here is the full justification:

---

## Decision Gate Evaluation

| Criterion | Status | Notes |
|---|---|---|
| Prompt engineering alone cannot achieve quality | ❌ False | Gemini + our prompts produce high-quality bilingual responses |
| Have 50–500 high-quality labelled examples | ❌ False | We have 23 test cases — insufficient for fine-tuning |
| Task is highly domain-specific | ⚠️ Partially | Kameti/Bisi is niche, but Gemini already understands financial concepts |
| Latency/cost savings justify effort | ❌ False | Gemini free tier latency is acceptable (<3s); cost is near-zero |

**All four gate criteria must be true to proceed with fine-tuning. None are fully met. Decision: Skip fine-tuning.**

---

## Why Prompt Engineering Is Sufficient

Our `prompts.yaml` v2 implements 7 prompt engineering techniques that together achieve the required quality:

1. **System prompt with role identity** — "You are the AI assistant for Our Committee"
2. **Context injection** — full user financial data in every prompt
3. **Few-shot examples** — 5 bilingual Q&A pairs covering common patterns
4. **Chain-of-Thought** — step-by-step reasoning for complex queries
5. **Negative constraints** — explicit list of what NOT to do
6. **Language instruction** — Urdu/English switching
7. **Tool data injection** — agent tools provide real DB data before LLM generates

This is substantially more sophisticated than a base model call, making fine-tuning redundant.

---

## What Fine-Tuning Would Require (If Needed in Future)

If we were to fine-tune in a future version:

### Dataset Requirements
- Minimum 100–500 labelled examples in `{messages}` format (OpenAI) or `{prompt, completion}` (HuggingFace)
- 80/20 train/validation split
- Diverse coverage: Urdu + English, all intents, edge cases

### Approach (If Needed)
- **For Gemini**: Use Google's Vertex AI fine-tuning API
- **For open-source alternative**: LoRA/QLoRA on `Llama 3 8B` via HuggingFace PEFT on Google Colab T4
- **Baseline**: Record performance before fine-tuning; compare on held-out test set
- **Registration**: HuggingFace Hub or W&B for model versioning

### When to Revisit
Fine-tuning should be reconsidered if:
- App scales to 10,000+ users with consistent query patterns to learn from
- A specific domain capability (e.g., reading CNIC/bank documents) requires custom training
- Latency SLA drops below 1s (smaller fine-tuned model could be faster)

---

## Conclusion

Prompt engineering with Gemini 1.5 Flash + RAG + agents achieves the required quality for this student project scope. Fine-tuning would add significant complexity and time cost with minimal benefit at this stage.
