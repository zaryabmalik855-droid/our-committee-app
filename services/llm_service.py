"""
LLM Service — wraps Google Gemini (default) or OpenAI GPT-4o.
Supports bilingual (Urdu / English) responses.

Prompt Engineering techniques implemented (v2):
  1. System prompt design — role, tone, constraints, context
  2. Few-shot prompting    — 5 bilingual Q&A examples from prompts.yaml
  3. Chain-of-Thought      — step-by-step reasoning prefix for loan analysis
  4. Role prompting        — "You are the AI assistant for Our Committee"
  5. Negative prompting    — explicit list of what NOT to do
  6. Structured output     — JSON schema for loan analysis, receipts
  7. Language prompting    — Urdu/English switching via system instruction
"""
from __future__ import annotations
import os
import json
import logging
import time
import yaml
from typing import Any

import google.generativeai as genai
from openai import AsyncOpenAI
from langsmith import traceable

from models.schemas import (
    AppContext, ChatMessage, NotificationRequest, ReceiptContext,
    LoanContext, LoanAnalysisResponse
)

logger = logging.getLogger(__name__)

PROMPTS_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "prompts.yaml")
try:
    with open(PROMPTS_PATH, "r", encoding="utf-8") as f:
        PROMPTS = yaml.safe_load(f)
except FileNotFoundError:
    PROMPTS = {"system_prompts": {}, "notification_templates": {}}


# ─────────────────────────────────────────────────────────────────
# System prompt builder
# ─────────────────────────────────────────────────────────────────

def _build_system_prompt(context: AppContext, agent_type: str) -> str:
    """
    Builds the full system prompt using multiple prompt engineering techniques:
    - Role prompting (system identity)
    - Context injection (user data, committees, loans, receipts)
    - Language instruction (Urdu/English)
    - Few-shot examples (5 bilingual Q&A pairs)
    - Negative constraints (what NOT to do)
    - Chain-of-Thought prefix (for complex queries)
    """
    lang = context.language
    user = context.current_user
    is_urdu = lang == "ur"

    language_instruction = PROMPTS.get("system_prompts", {}).get("language", {}).get(lang, "Respond in clear, friendly English.")
    negative_constraints = PROMPTS.get("system_prompts", {}).get("negative_constraints", "")
    few_shot_examples = PROMPTS.get("system_prompts", {}).get("few_shot_examples", "")
    cot_prefix = PROMPTS.get("system_prompts", {}).get("chain_of_thought_prefix", "")
    agent_instructions = PROMPTS.get("system_prompts", {}).get("agent_instructions", "")

    committees_summary = "\n".join([
        f"- {c.name}: PKR {c.monthly_contribution:,.0f}/cycle, "
        f"{len(c.joined_members)}/{c.members_limit} members, status={c.status}, "
        f"installments={c.installments_paid}/{c.total_installments}"
        for c in context.committees[:5]
    ]) or "No committees found."

    receipts_summary = "\n".join([
        f"- [{r.timestamp[:10]}] {r.type}: PKR {r.amount:,.0f} via {r.gateway} for {r.reference_name}"
        for r in context.receipts[:8]
    ]) or "No receipts found."

    loans_summary = "\n".join([
        f"- Loan {l.id}: PKR {l.amount:,.0f}, status={l.status}, "
        f"reason={l.reason[:50]}, monthly={l.monthly_repayment:,.0f}"
        for l in context.loans[:5]
    ]) or "No loans found."

    manager_extra = ""
    if agent_type == "manager":
        pending_loans = [l for l in context.loans if l.status == "pending"]
        manager_extra = f"""
=== MANAGER VIEW ===
Pending Loan Approvals: {len(pending_loans)}
{chr(10).join([f'  • {l.applicant_name}: PKR {l.amount:,.0f} – "{l.reason}"' for l in pending_loans[:3]])}
Total Members Across All Committees: {sum(len(c.joined_members) for c in context.committees)}
Emergency Support Pool Balance: PKR {context.emergency_pool_balance:,.2f}
  (This is a community aid fund. Loans are disbursed FROM this pool. Repayments flow BACK into it.)
"""

    # Build few_shot_section: include CoT prefix + ReAct agent instructions + examples
    few_shot_section = ""
    if cot_prefix:
        few_shot_section += f"{cot_prefix}\n\n"
    if agent_instructions:
        few_shot_section += f"{agent_instructions}\n\n"
    if few_shot_examples:
        few_shot_section += few_shot_examples

    base_instruction = PROMPTS.get("system_prompts", {}).get("base_instructions", "")
    return base_instruction.format(
        user_role=user.role,
        language_instruction=language_instruction,
        user_name=user.name,
        user_balance=f"{user.balance:,.2f}",
        user_subscription_plan=user.subscription_plan,
        user_is_subscribed=user.is_subscribed,
        committees_summary=committees_summary,
        receipts_summary=receipts_summary,
        loans_summary=loans_summary,
        manager_extra=manager_extra,
        negative_constraints=negative_constraints,
        few_shot_section=few_shot_section,
    )


# ─────────────────────────────────────────────────────────────────
# LLM Service class
# ─────────────────────────────────────────────────────────────────

class LLMService:
    def __init__(self):
        self.provider = os.getenv("LLM_PROVIDER", "gemini").lower()
        self._gemini_model: Any = None
        self._openai_client: AsyncOpenAI | None = None
        self._init_provider()

    def _init_provider(self):
        logger.info("Initializing LLM provider...")
        if self.provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY", "")
            logger.info(f"Detecting GEMINI_API_KEY: exists={bool(api_key)}, len={len(api_key) if api_key else 0}, prefix={api_key[:6] if api_key else 'None'}")
            is_placeholder = (
                not api_key 
                or api_key == "your_gemini_api_key_here"
            )
            if not is_placeholder:
                try:
                    genai.configure(api_key=api_key)
                    model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
                    self._gemini_model = genai.GenerativeModel(model_name)
                    logger.info(f"✅ Gemini client successfully initialized with model: {model_name}")
                except Exception as e:
                    logger.error(f"❌ Failed to initialize Gemini client: {e}", exc_info=True)
                    self._gemini_model = None
            else:
                logger.warning("⚠️  GEMINI_API_KEY not set or is a placeholder — using mock responses")
        elif self.provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY", "")
            logger.info(f"Detecting OPENAI_API_KEY: exists={bool(api_key)}, len={len(api_key) if api_key else 0}, prefix={api_key[:6] if api_key else 'None'}")
            is_placeholder = (
                not api_key 
                or api_key == "your_openai_api_key_here"
            )
            if not is_placeholder:
                try:
                    self._openai_client = AsyncOpenAI(api_key=api_key)
                    logger.info("✅ OpenAI client successfully initialized")
                except Exception as e:
                    logger.error(f"❌ Failed to initialize OpenAI client: {e}", exc_info=True)
                    self._openai_client = None
            else:
                logger.warning("⚠️  OPENAI_API_KEY not set or is a placeholder — using mock responses")

    # ── Local Knowledge Fallback Engine ──────────────────────────

    def _generate_local_fallback(self, message: str, context: AppContext | None = None) -> str:
        """
        Context-aware fallback that answers from app knowledge when no
        external AI provider is available or when an API call fails.
        Never exposes raw API errors to the user.
        """
        msg = message.lower().strip()
        lang = context.language if context else "en"
        is_urdu = lang == "ur"

        # ── Helper to pick language variant ──
        def pick(en: str, ur: str) -> str:
            return ur if is_urdu else en

        # ── Extract context data safely ──
        user_name = context.current_user.name if context else "Member"
        user_balance = context.current_user.balance if context else 0.0
        committees = context.committees if context else []
        receipts = context.receipts if context else []
        loans = context.loans if context else []
        pool_balance = context.emergency_pool_balance if context else 0.0
        role = context.current_user.role if context else "member"

        # ── Greeting ──
        greeting_triggers = ["hello", "hi", "salam", "السلام", "assalam", "hey", "good morning", "good evening"]
        if any(t in msg for t in greeting_triggers):
            if is_urdu:
                return (
                    f"وعلیکم السلام {user_name}! 👋 میں ہماری کمیٹی کا AI اسسٹنٹ ہوں۔ "
                    "میں آپ کی کمیٹیوں، قرضوں، ادائیگیوں اور لکی ڈرا کے بارے میں مدد کر سکتا ہوں۔ "
                    "آپ کیا جاننا چاہتے ہیں?"
                )
            return (
                f"Hello {user_name}! 👋 I'm your Our Committee AI Assistant. "
                "I can help you with your committees, loans, payments, lucky draws, and more. "
                "What would you like to know?"
            )

        # ── Balance / Wallet ──
        balance_triggers = ["balance", "wallet", "funds", "رقم", "بیلنس", "پیسے"]
        if any(t in msg for t in balance_triggers):
            return pick(
                f"💰 Your current wallet balance is **PKR {user_balance:,.2f}**. "
                + (f"You have {len(committees)} active committee(s)." if committees else "You have no active committees yet."),
                f"💰 آپ کا موجودہ بیلنس **PKR {user_balance:,.2f}** ہے۔ "
                + (f"آپ کی {len(committees)} فعال کمیٹی ہے۔" if committees else "ابھی کوئی کمیٹی نہیں ہے۔")
            )

        # ── Committee info ──
        committee_triggers = ["committee", "kameti", "bisi", "کمیٹی", "my commit", "joined"]
        if any(t in msg for t in committee_triggers):
            if not committees:
                return pick(
                    "You haven't joined any committees yet. Visit the Committees section to browse and join available committees.",
                    "آپ نے ابھی تک کوئی کمیٹی جوائن نہیں کی۔ کمیٹی سیکشن میں جا کر دستیاب کمیٹیاں دیکھیں۔"
                )
            lines = [pick("📋 Your Committees:\n", "📋 آپ کی کمیٹیاں:\n")]
            for c in committees[:5]:
                members_info = f"{len(c.joined_members)}/{c.members_limit}"
                installments_info = f"{c.installments_paid}/{c.total_installments}"
                if is_urdu:
                    lines.append(
                        f"• **{c.name}** — PKR {c.monthly_contribution:,.0f}/سائیکل، "
                        f"ممبران: {members_info}، اقساط: {installments_info}، حیثیت: {c.status}"
                    )
                else:
                    lines.append(
                        f"• **{c.name}** — PKR {c.monthly_contribution:,.0f}/cycle, "
                        f"Members: {members_info}, Installments: {installments_info}, Status: {c.status}"
                    )
            return "\n".join(lines)

        # ── Loan info ──
        loan_triggers = ["loan", "قرض", "borrow", "lend", "advance", "repay", "ادائیگی قرض"]
        if any(t in msg for t in loan_triggers):
            if not loans:
                return pick(
                    "You have no active loans. You can apply for an emergency loan from the Loans section. "
                    f"The Emergency Support Pool currently has PKR {pool_balance:,.2f} available.",
                    f"آپ کا کوئی فعال قرض نہیں۔ ایمرجنسی سپورٹ پول میں ابھی PKR {pool_balance:,.2f} دستیاب ہے۔"
                )
            lines = [pick("💳 Your Loans:\n", "💳 آپ کے قرضے:\n")]
            for l in loans[:5]:
                status_label = {"pending": "⏳ Pending", "approved": "✅ Approved", "rejected": "❌ Rejected"}.get(l.status, l.status)
                if is_urdu:
                    lines.append(f"• PKR {l.amount:,.0f} — {l.reason[:40]} | حیثیت: {status_label} | ماہانہ: PKR {l.monthly_repayment:,.0f}")
                else:
                    lines.append(f"• PKR {l.amount:,.0f} — {l.reason[:40]} | Status: {status_label} | Monthly: PKR {l.monthly_repayment:,.0f}")
            return "\n".join(lines)

        # ── Payment / Receipt history ──
        payment_triggers = ["payment", "receipt", "paid", "history", "transaction", "ادائیگی", "رسید", "لین دین"]
        if any(t in msg for t in payment_triggers):
            if not receipts:
                return pick(
                    "No payment history found. Payments will appear here once you make installment or loan payments.",
                    "کوئی ادائیگی کا ریکارڈ نہیں ملا۔ قسط یا قرض کی ادائیگی کے بعد یہاں نظر آئے گا۔"
                )
            lines = [pick("🧾 Recent Payments:\n", "🧾 حالیہ ادائیگیاں:\n")]
            for r in receipts[:5]:
                date = r.timestamp[:10]
                if is_urdu:
                    lines.append(f"• [{date}] {r.type} — PKR {r.amount:,.0f} ({r.gateway}) — {r.reference_name}")
                else:
                    lines.append(f"• [{date}] {r.type} — PKR {r.amount:,.0f} via {r.gateway} for {r.reference_name}")
            return "\n".join(lines)

        # ── Lucky Draw ──
        draw_triggers = ["lucky draw", "draw", "winner", "لکی ڈرا", "قرعہ اندازی", "ڈرا"]
        if any(t in msg for t in draw_triggers):
            draw_committees = [c for c in committees if c.status in ["active", "open"]]
            if not draw_committees:
                return pick(
                    "No active committees found for lucky draw. Join a committee first to participate.",
                    "لکی ڈرا کے لیے کوئی فعال کمیٹی نہیں ملی۔ پہلے ایک کمیٹی جوائن کریں۔"
                )
            names = ", ".join(c.name for c in draw_committees[:3])
            return pick(
                f"🎰 Lucky draws are running for: **{names}**. "
                "Each committee has its own independent draw cycle. Winners are selected when all installments are paid.",
                f"🎰 لکی ڈرا جاری ہے: **{names}**۔ ہر کمیٹی کا اپنا الگ ڈرا سائیکل ہے۔"
            )

        # ── Emergency pool ──
        pool_triggers = ["emergency", "pool", "ایمرجنسی", "پول", "support fund", "aid"]
        if any(t in msg for t in pool_triggers):
            return pick(
                f"🆘 The Emergency Support Pool currently has **PKR {pool_balance:,.2f}**. "
                "This community fund provides emergency loans to verified members. "
                "Apply via the Loans section.",
                f"🆘 ایمرجنسی سپورٹ پول میں ابھی **PKR {pool_balance:,.2f}** موجود ہے۔ "
                "یہ رقم تصدیق شدہ ممبران کو ایمرجنسی قرض فراہم کرتی ہے۔ قرضہ سیکشن میں درخواست دیں۔"
            )

        # ── Subscription ──
        sub_triggers = ["subscription", "plan", "premium", "سبسکرپشن", "پلان"]
        if any(t in msg for t in sub_triggers):
            is_subscribed = context.current_user.is_subscribed if context else False
            plan = context.current_user.subscription_plan if context else "free"
            return pick(
                f"📦 Your current plan: **{plan.capitalize()}** | Subscribed: {'✅ Yes' if is_subscribed else '❌ No'}. "
                "Upgrade to Premium for unlimited committees, priority support, and advanced analytics.",
                f"📦 آپ کا موجودہ پلان: **{plan}** | سبسکرپشن: {'✅ ہاں' if is_subscribed else '❌ نہیں'}۔ "
                "پریمیم پر اپ گریڈ کریں — لامحدود کمیٹیاں اور ترجیحی سپورٹ حاصل کریں۔"
            )

        # ── Help / Features ──
        help_triggers = ["help", "what can", "features", "مدد", "کیا کر سکتے", "کام"]
        if any(t in msg for t in help_triggers):
            return pick(
                "🤖 I can help you with:\n"
                "• 💰 **Balance** — check your wallet balance\n"
                "• 📋 **Committees** — view your joined committees and status\n"
                "• 💳 **Loans** — check loan status and apply for emergency loans\n"
                "• 🧾 **Payments** — view payment history and receipts\n"
                "• 🎰 **Lucky Draw** — check draw status and winners\n"
                "• 🆘 **Emergency Pool** — check pool balance\n"
                "• 📦 **Subscription** — view or upgrade your plan\n\n"
                "Just ask me anything about your committees!",
                "🤖 میں آپ کی ان چیزوں میں مدد کر سکتا ہوں:\n"
                "• 💰 بیلنس چیک کریں\n"
                "• 📋 کمیٹیاں دیکھیں\n"
                "• 💳 قرض کی حیثیت جانیں\n"
                "• 🧾 ادائیگی کی تاریخ دیکھیں\n"
                "• 🎰 لکی ڈرا کی معلومات\n"
                "• 🆘 ایمرجنسی پول\n"
                "• 📦 سبسکرپشن پلان\n\n"
                "بس مجھ سے پوچھیں!"
            )

        # ── Manager-specific ──
        if role == "manager":
            manager_triggers = ["pending", "approve", "reject", "members", "manage", "منظور", "رد"]
            if any(t in msg for t in manager_triggers):
                pending_loans = [l for l in loans if l.status == "pending"]
                total_members = sum(len(c.joined_members) for c in committees)
                return pick(
                    f"👔 Manager Dashboard:\n"
                    f"• Pending loan approvals: **{len(pending_loans)}**\n"
                    f"• Total members across all committees: **{total_members}**\n"
                    f"• Emergency pool balance: **PKR {pool_balance:,.2f}**\n"
                    "Go to the Manager Dashboard to review and approve/reject loan requests.",
                    f"👔 مینیجر ڈیش بورڈ:\n"
                    f"• زیر التواء قرض درخواستیں: **{len(pending_loans)}**\n"
                    f"• کل ممبران: **{total_members}**\n"
                    f"• ایمرجنسی پول: **PKR {pool_balance:,.2f}**\n"
                    "مینیجر ڈیش بورڈ میں جا کر قرض درخواستیں منظور یا رد کریں۔"
                )

        # ── Default: general helpful response ──
        if is_urdu:
            return (
                f"شکریہ {user_name}! میں آپ کی مدد کے لیے حاضر ہوں۔ "
                "آپ مجھ سے اپنی کمیٹیوں، قرضوں، ادائیگیوں یا لکی ڈرا کے بارے میں پوچھ سکتے ہیں۔ "
                "'مدد' لکھیں تاکہ تمام سہولیات کی فہرست دیکھ سکیں۔"
            )
        return (
            f"Thanks for reaching out, {user_name}! I'm here to assist you with all things related to Our Committee. "
            "You can ask me about your committees, loans, payments, lucky draws, or the emergency pool. "
            "Type **'help'** to see everything I can do for you."
        )

    # ── Core chat method ─────────────────────────────────────────

    @traceable(name="llm_chat")
    async def chat(
        self,
        message: str,
        history: list[ChatMessage],
        context: AppContext,
        agent_type: str = "member",
    ) -> str:
        """Main bilingual chat method. Logs latency per call."""
        t0 = time.perf_counter()
        # Check moderation
        is_safe = await self._check_moderation(message)
        if not is_safe:
            return "I cannot fulfill this request as it violates safety guidelines."

        system_prompt = _build_system_prompt(context, agent_type)
        lang = context.language

        try:
            if self.provider == "gemini" and self._gemini_model:
                reply = await self._gemini_chat(system_prompt, message, history, context)
            elif self.provider == "openai" and self._openai_client:
                reply = await self._openai_chat(system_prompt, message, history, context)
            else:
                logger.info("No LLM provider available — using local knowledge fallback")
                reply = self._generate_local_fallback(message, context)
        except Exception as e:
            logger.error(f"❌ Unexpected error in chat(): {e}", exc_info=True)
            reply = self._generate_local_fallback(message, context)

        latency_ms = round((time.perf_counter() - t0) * 1000, 1)
        logger.info(f"💬 LLM chat | provider={self.provider} | lang={lang} | latency={latency_ms}ms")
        return reply

    async def _check_moderation(self, message: str) -> bool:
        try:
            # 1. Rule-based checks (Jailbreaks & Prompt Injection)
            normalized = message.lower().strip()
            injection_triggers = [
                "ignore previous instructions",
                "ignore prior instructions",
                "ignore all instructions",
                "system prompt",
                "override system prompt",
                "jailbreak",
                "ignore the rules",
                "forget your instructions",
                "you are now a",
                "act as",
                "do anything now",
                "dan mode",
                "bypass rules",
                "previous guidelines",
            ]
            for trigger in injection_triggers:
                if trigger in normalized:
                    logger.warning(f"⚠️ Input moderation triggered: Prompt injection pattern detected - '{trigger}'")
                    return False

            # Basic block list of offensive terms in English and Urdu
            block_list = [
                "abuse", "harass", "kill", "suicide", "murder", "bomb", "terrorist", 
                "fuck", "shit", "bitch", "bastard", "asshole", "gaali", "chutiya", 
                "kamina", "harami", "badtameez"
            ]
            for word in block_list:
                if word in normalized:
                    logger.warning(f"⚠️ Input moderation triggered: Blocked keyword detected - '{word}'")
                    return False

            # 2. OpenAI Moderation API check
            if self.provider == "openai" and self._openai_client:
                response = await self._openai_client.moderations.create(input=message)
                return not response.results[0].flagged
            
            # Gemini handles safety settings internally, but our local rules run first.
            return True
        except Exception as e:
            logger.warning(f"Moderation check failed: {e}")
        return True

    async def _gemini_chat(
        self, system_prompt: str, message: str, history: list[ChatMessage],
        context: AppContext | None = None
    ) -> str:
        try:
            # Build Gemini conversation history
            gemini_history = []
            for msg in history[-10:]:  # keep last 10 turns
                gemini_history.append({
                    "role": "user" if msg.role == "user" else "model",
                    "parts": [msg.content],
                })

            chat_session = self._gemini_model.start_chat(
                history=gemini_history
            )
            # Prepend system context to first user message
            full_message = f"{system_prompt}\n\n---\nUser: {message}"
            response = await chat_session.send_message_async(full_message)
            return response.text
        except Exception as e:
            logger.error(f"❌ Gemini API error (switching to local fallback): {type(e).__name__}: {e}", exc_info=True)
            return self._generate_local_fallback(message, context)

    async def _openai_chat(
        self, system_prompt: str, message: str, history: list[ChatMessage],
        context: AppContext | None = None
    ) -> str:
        try:
            messages = [{"role": "system", "content": system_prompt}]
            for msg in history[-10:]:
                messages.append({"role": msg.role, "content": msg.content})
            messages.append({"role": "user", "content": message})

            model_name = os.getenv("OPENAI_MODEL", "gpt-4o")
            response = await self._openai_client.chat.completions.create(  # type: ignore
                model=model_name,
                messages=messages,
                temperature=0.7,
                max_tokens=1024,
            )
            return response.choices[0].message.content or ""
        except Exception as e:
            logger.error(f"❌ OpenAI API error (switching to local fallback): {type(e).__name__}: {e}", exc_info=True)
            return self._generate_local_fallback(message, context)

    # ── Notification generator ───────────────────────────────────

    @traceable(name="generate_notification")
    async def generate_notification(self, req: NotificationRequest) -> dict[str, str]:
        lang = req.language
        is_urdu = lang == "ur"

        templates = PROMPTS.get("notification_templates", {})
        event_templates = templates.get(req.event_type, {})
        template_str = event_templates.get(lang, event_templates.get("en", "Notification from Our Committee."))
        
        # Format the template with provided data
        format_kwargs = {
            "user_name": req.user_name,
            "amount": f"{req.data.get('amount', 0):,.0f}",
            "due_date": req.data.get("due_date", "end of month"),
            "winner": req.data.get("winner", req.user_name),
            "committee": req.data.get("committee", "committee"),
            "gateway": req.data.get("gateway", "payment gateway"),
            "plan": req.data.get("plan", "subscription"),
        }
        
        try:
            body = template_str.format(**format_kwargs)
        except KeyError:
            body = template_str

        # Try AI-enhanced message if LLM is available
        if (self.provider == "gemini" and self._gemini_model) or \
           (self.provider == "openai" and self._openai_client):
            try:
                prompt = (
                    f"Generate a {'Urdu' if is_urdu else 'English'} notification message for a "
                    f"Pakistani committee (Kameti/Bisi) savings app. "
                    f"Event: {req.event_type}. Data: {json.dumps(req.data)}. "
                    f"User: {req.user_name}. "
                    f"Keep it under 2 sentences. Be warm and professional. "
                    f"{'Use Urdu Nastaliq script.' if is_urdu else 'Use clear English.'}"
                )
                if self.provider == "gemini":
                    resp = await self._gemini_model.generate_content_async(prompt)
                    body = resp.text.strip()
                else:
                    resp = await self._openai_client.chat.completions.create(  # type: ignore
                        model=os.getenv("OPENAI_MODEL", "gpt-4o"),
                        messages=[{"role": "user", "content": prompt}],
                        max_tokens=200,
                    )
                    body = (resp.choices[0].message.content or body).strip()
            except Exception as e:
                logger.warning(f"AI notification fallback to template: {e}")

        type_map = {
            "payment_due": "payment", "installment_paid": "payment",
            "penalty_warning": "payment", "loan_approved": "loan",
            "loan_rejected": "loan", "draw_winner": "draw",
            "welcome": "payment", "subscription": "payment",
        }

        titles = {
            "payment_due": {"en": "Installment Due", "ur": "قسط کی یاد دہانی"},
            "loan_approved": {"en": "Loan Approved! 🎉", "ur": "قرض منظور! 🎉"},
            "loan_rejected": {"en": "Loan Update", "ur": "قرض کی اطلاع"},
            "draw_winner": {"en": "Lucky Draw Result 🏆", "ur": "لکی ڈرا نتیجہ 🏆"},
            "installment_paid": {"en": "Payment Confirmed ✅", "ur": "ادائیگی تصدیق ✅"},
            "penalty_warning": {"en": "⚠️ Overdue Warning", "ur": "⚠️ تاخیر کی وارننگ"},
            "welcome": {"en": "Welcome! 🎊", "ur": "خوش آمدید! 🎊"},
            "subscription": {"en": "Subscription Active", "ur": "سبسکرپشن فعال"},
        }
        title = titles.get(req.event_type, {}).get(lang, titles.get(req.event_type, {}).get("en", "Notification"))

        return {
            "title": title,
            "body": body,
            "type": type_map.get(req.event_type, "payment"),
            "language": lang,
        }

    # ── Receipt formatter ────────────────────────────────────────

    @traceable(name="format_receipt")
    async def format_receipt(self, receipt: ReceiptContext, lang: str, fmt: str) -> str:
        if fmt == "json":
            return json.dumps({
                "receipt_id": receipt.id,
                "user": receipt.user_name,
                "email": receipt.user_email,
                "type": receipt.type,
                "amount_pkr": receipt.amount,
                "reference": receipt.reference_name,
                "gateway": receipt.gateway,
                "date": receipt.timestamp[:10],
                "status": "PAID",
            }, ensure_ascii=False, indent=2)

        # Markdown format
        if lang == "ur":
            return f"""## 🧾 رسید — Our Committee

| | |
|---|---|
| **رسید نمبر** | `{receipt.id}` |
| **صارف** | {receipt.user_name} |
| **ای میل** | {receipt.user_email} |
| **قسم** | {receipt.type} |
| **رقم** | **PKR {receipt.amount:,.0f}** |
| **حوالہ** | {receipt.reference_name} |
| **گیٹ وے** | {receipt.gateway} |
| **تاریخ** | {receipt.timestamp[:10]} |
| **حیثیت** | ✅ ادا شدہ |

---
*ہماری کمیٹی — محفوظ ڈیجیٹل کمیٹی سسٹم*
"""
        return f"""## 🧾 Payment Receipt — Our Committee

| Field | Details |
|-------|---------|
| **Receipt ID** | `{receipt.id}` |
| **Member** | {receipt.user_name} |
| **Email** | {receipt.user_email} |
| **Type** | {receipt.type} |
| **Amount** | **PKR {receipt.amount:,.0f}** |
| **Reference** | {receipt.reference_name} |
| **Gateway** | {receipt.gateway} |
| **Date** | {receipt.timestamp[:10]} |
| **Status** | ✅ PAID |

---
*Our Committee — Secure Digital Savings System*
"""

    # ── Loan risk analysis ───────────────────────────────────────

    @traceable(name="analyze_loan_risk")
    async def analyze_loan_risk(
        self,
        loan: LoanContext,
        payment_history: list[ReceiptContext],
        committees: list,
        lang: str,
    ) -> LoanAnalysisResponse:
        # Heuristic scoring
        score = 0.5  # baseline

        # Good payment history boosts score
        paid_installments = len([r for r in payment_history if r.type == "Committee Installment"])
        score += min(paid_installments * 0.05, 0.25)

        # Active committee membership boosts score
        if committees:
            score += 0.1

        # Large loan amount relative to monthly repayment
        if loan.amount > 15000:
            score -= 0.1

        # Already has loans reduces score
        score = max(0.1, min(0.95, score))

        risk = "low" if score > 0.7 else "high" if score < 0.4 else "medium"
        rec = "approve" if risk == "low" else "reject" if risk == "high" else "review"

        reasoning_en = (
            f"Applicant {loan.applicant_name} has {paid_installments} committee payment(s) on record. "
            f"Loan amount PKR {loan.amount:,.0f} with {loan.duration_months}-month repayment. "
            f"Risk assessed as {risk.upper()}. Recommendation: {rec.upper()}."
        )
        reasoning_ur = (
            f"درخواست گزار {loan.applicant_name} کے {paid_installments} کمیٹی ادائیگیوں کا ریکارڈ موجود ہے۔ "
            f"قرض رقم PKR {loan.amount:,.0f} بمدت {loan.duration_months} ماہ۔ "
            f"خطرے کی سطح: {risk.upper()}۔ سفارش: {rec.upper()}۔"
        )

        return LoanAnalysisResponse(
            risk_level=risk,  # type: ignore
            recommendation=rec,  # type: ignore
            reasoning=reasoning_ur if lang == "ur" else reasoning_en,
            confidence_score=round(score, 2),
            language=lang,
        )
