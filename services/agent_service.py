"""
Agent Service — ReAct-style agents for Member and Manager.
Each agent has Tools it can call before generating a final answer.
Uses a custom ReAct pattern: Classify intent → Run tool → Retrieve RAG → Generate.

Agent configuration:
  MAX_ITERATIONS = 3   — prevents infinite loops and runaway API costs
  TOKEN_BUDGET    = 2000 — approximate max tokens for injected context
"""
from __future__ import annotations
import logging
import time
import json
from typing import Callable, Any

from models.schemas import AppContext, ChatMessage, LoanContext, ReceiptContext
from services.llm_service import LLMService
from services.rag_service import RagService
from database import SessionLocal
from models.db import UserDB, CommitteeDB, LoanDB, ReceiptDB

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────
# Agent safety constants
# ─────────────────────────────────────────────────────────────────
MAX_ITERATIONS = 3      # Maximum tool calls per agent turn
TOKEN_BUDGET   = 2000   # Approximate max tokens of injected context (characters ÷ 4)


# ─────────────────────────────────────────────────────────────────
# Tool definitions
# ─────────────────────────────────────────────────────────────────

class Tool:
    """
    A named, typed tool callable by the agent.

    Attributes:
        name (str): Unique tool identifier — used by intent classifier.
        description (str): Human/LLM-readable purpose — used for tool selection.
        fn (Callable): The function to execute. May be sync or async.
    """
    def __init__(self, name: str, description: str, fn: Callable):
        self.name = name
        self.description = description
        self.fn = fn

    async def run(self, **kwargs) -> str:
        """
        Execute the tool and return its string output.
        Logs tool name, latency, and output length for observability.

        Returns:
            str: Tool output as a plain string (max TOKEN_BUDGET characters).
        """
        t0 = time.perf_counter()
        result = self.fn(**kwargs)
        if hasattr(result, "__await__"):
            result = await result
        output = str(result)
        latency_ms = round((time.perf_counter() - t0) * 1000, 1)
        # Truncate to token budget to avoid exceeding LLM context
        if len(output) > TOKEN_BUDGET * 4:
            output = output[: TOKEN_BUDGET * 4] + "... [truncated]"
        logger.info(
            f"🔧 Tool '{self.name}' | latency={latency_ms}ms | output_len={len(output)} chars"
        )
        return output


def _make_member_tools(context: AppContext, rag: RagService) -> list[Tool]:
    """Tools available to the Member Agent."""

    def get_my_committees() -> str:
        member_name = context.current_user.name
        with SessionLocal() as db:
            comms = db.query(CommitteeDB).all()
            my_comms = [c for c in comms if c.joined_members and member_name in c.joined_members.split(",")]
        if not my_comms:
            return "You are not enrolled in any committees."
        lines = []
        for c in my_comms:
            lines.append(
                f"• {c.name}: PKR {c.monthly_contribution:,.0f}/{c.frequency}, "
                f"{c.installments_paid}/{c.total_installments} paid, status={c.status}"
            )
        return "Your committees:\n" + "\n".join(lines)

    def get_my_receipts(limit: int = 5) -> str:
        email = context.current_user.email
        with SessionLocal() as db:
            my_receipts = db.query(ReceiptDB).filter(ReceiptDB.user_email == email).order_by(ReceiptDB.timestamp.desc()).limit(limit).all()
        if not my_receipts:
            return "No payment receipts found."
        lines = [
            f"• [{r.timestamp[:10]}] {r.type}: PKR {r.amount:,.0f} via {r.gateway} – {r.reference_name}"
            for r in my_receipts
        ]
        return f"Last {len(my_receipts)} receipts:\n" + "\n".join(lines)

    def get_my_loans() -> str:
        email = context.current_user.email
        with SessionLocal() as db:
            my_loans = db.query(LoanDB).filter(LoanDB.applicant_email == email).all()
        if not my_loans:
            return "You have no loan applications."
        lines = [
            f"• Loan {l.id}: PKR {l.amount:,.0f}, status={l.status}, "
            f"monthly=PKR {l.monthly_repayment:,.0f}, paid={l.installments_paid}/{l.duration_months}"
            for l in my_loans
        ]
        return "Your loans:\n" + "\n".join(lines)

    def check_wallet_balance() -> str:
        email = context.current_user.email
        with SessionLocal() as db:
            user = db.query(UserDB).filter(UserDB.email == email).first()
            balance = user.balance if user else context.current_user.balance
        return f"Your current wallet balance is PKR {balance:,.2f}."

    def check_subscription_status() -> str:
        email = context.current_user.email
        with SessionLocal() as db:
            user = db.query(UserDB).filter(UserDB.email == email).first()
            is_subscribed = user.is_subscribed if user else context.current_user.is_subscribed
            sub_plan = user.subscription_plan if user else context.current_user.subscription_plan
        if is_subscribed:
            return f"You are subscribed to the {sub_plan} plan. Loan eligibility: ✅"
        return "You are NOT subscribed. Subscribe first to request loans."

    def get_pending_draw_info() -> str:
        member_name = context.current_user.name
        with SessionLocal() as db:
            comms = db.query(CommitteeDB).all()
            my_comms = [c for c in comms if c.joined_members and member_name in c.joined_members.split(",")]
        results = []
        for c in my_comms:
            winners = c.draw_winners.split(",") if c.draw_winners else []
            if member_name not in winners:
                results.append(f"• {c.name}: You haven't won the draw yet. Eligible!")
            else:
                results.append(f"• {c.name}: You already won the draw.")
        return "\n".join(results) if results else "No committee draw info available."

    return [
        Tool("get_my_committees", "Get committees the current member has joined", get_my_committees),
        Tool("get_my_receipts", "Get recent payment receipts", get_my_receipts),
        Tool("get_my_loans", "Get loan application status", get_my_loans),
        Tool("check_wallet_balance", "Check the member's wallet balance", check_wallet_balance),
        Tool("check_subscription_status", "Check subscription plan and loan eligibility", check_subscription_status),
        Tool("get_pending_draw_info", "Check lucky draw eligibility status", get_pending_draw_info),
    ]


def _make_manager_tools(context: AppContext, rag: RagService) -> list[Tool]:
    """Tools available to the Manager Agent."""

    def get_all_committees() -> str:
        with SessionLocal() as db:
            comms = db.query(CommitteeDB).all()
        if not comms:
            return "No committees found."
        lines = []
        for c in comms:
            members = c.joined_members.split(",") if c.joined_members else []
            lines.append(
                f"• {c.name}: {len(members)}/{c.members_limit} members, "
                f"PKR {c.monthly_contribution:,.0f}/{c.frequency}, "
                f"status={c.status}, installments={c.installments_paid}/{c.total_installments}"
            )
        return f"All committees ({len(comms)}):\n" + "\n".join(lines)

    def get_pending_loans() -> str:
        with SessionLocal() as db:
            pending = db.query(LoanDB).filter(LoanDB.status == "pending").all()
        if not pending:
            return "No pending loan requests."
        lines = [
            f"• {l.applicant_name}: PKR {l.amount:,.0f}, reason: {l.reason[:60]}, "
            f"monthly=PKR {l.monthly_repayment:,.0f}, duration={l.duration_months}mo"
            for l in pending
        ]
        return f"Pending loans ({len(pending)}):\n" + "\n".join(lines)

    def get_all_loans() -> str:
        with SessionLocal() as db:
            loans = db.query(LoanDB).all()
        if not loans:
            return "No loans found."
        by_status: dict[str, list] = {}
        for l in loans:
            by_status.setdefault(l.status, []).append(l)
        lines = []
        for status, status_loans in by_status.items():
            lines.append(f"\n{status.upper()} ({len(status_loans)}):")
            for l in status_loans:
                lines.append(f"  • {l.applicant_name}: PKR {l.amount:,.0f}")
        return "Loan summary:" + "\n".join(lines)

    def get_member_payment_history(member_name: str = "") -> str:
        if not member_name:
            return "Please specify a member name."
        with SessionLocal() as db:
            receipts = db.query(ReceiptDB).filter(ReceiptDB.user_name.ilike(f"%{member_name}%")).all()
        if not receipts:
            return f"No payment history found for {member_name}."
        lines = [
            f"• [{r.timestamp[:10]}] {r.type}: PKR {r.amount:,.0f} for {r.reference_name}"
            for r in receipts
        ]
        return f"Payment history for {member_name}:\n" + "\n".join(lines)

    def get_committee_summary() -> str:
        with SessionLocal() as db:
            comms = db.query(CommitteeDB).all()
            pending_loans_count = db.query(LoanDB).filter(LoanDB.status == "pending").count()
        total_members = set()
        total_pool = 0.0
        for c in comms:
            if c.joined_members:
                total_members.update(c.joined_members.split(","))
            total_pool += c.total_amount
        return (
            f"Overview: {len(comms)} active committees, "
            f"{len(total_members)} unique members, "
            f"PKR {total_pool:,.0f} total pool value. "
            f"Pending loans: {pending_loans_count}."
        )

    def get_draw_eligible_members(committee_id: str = "") -> str:
        with SessionLocal() as db:
            if committee_id:
                comms = db.query(CommitteeDB).filter(CommitteeDB.id == committee_id).all()
            else:
                comms = db.query(CommitteeDB).all()
        if not comms:
            return "Committee not found."
        results = []
        for c in comms:
            members = c.joined_members.split(",") if c.joined_members else []
            winners = c.draw_winners.split(",") if c.draw_winners else []
            eligible = [m for m in members if m not in winners]
            results.append(
                f"• {c.name}: Eligible={eligible or ['None']}, Already won={winners or ['None']}"
            )
        return "\n".join(results)

    def get_emergency_pool_status() -> str:
        """Returns the current Emergency Support Pool balance and statistics."""
        with SessionLocal() as db:
            approved_loans = db.query(LoanDB).filter(LoanDB.status == "approved").all()
            completed_loans = db.query(LoanDB).filter(LoanDB.status == "completed").all()
            pending_loans = db.query(LoanDB).filter(LoanDB.status == "pending").all()
        total_disbursed = sum(l.amount for l in approved_loans)
        total_repaid = sum(l.monthly_repayment * l.installments_paid for l in approved_loans)
        pool_balance = context.emergency_pool_balance
        return (
            f"Emergency Support Pool Status:\n"
            f"  Current Balance: PKR {pool_balance:,.2f}\n"
            f"  Active approved loans: {len(approved_loans)} (disbursed PKR {total_disbursed:,.0f} total)\n"
            f"  Completed loans: {len(completed_loans)}\n"
            f"  Pending loan requests: {len(pending_loans)}\n"
            f"  Total repaid so far: PKR {total_repaid:,.0f}\n"
            f"How it works: Approved loans are paid OUT from this pool. "
            f"Member repayments flow BACK IN, replenishing it for future loans."
        )

    return [
        Tool("get_all_committees", "Get all committees with member counts and status", get_all_committees),
        Tool("get_pending_loans", "Get all pending loan requests awaiting approval", get_pending_loans),
        Tool("get_all_loans", "Get all loans grouped by status", get_all_loans),
        Tool("get_member_payment_history", "Get payment history for a specific member", get_member_payment_history),
        Tool("get_committee_summary", "Get overall committee portfolio summary", get_committee_summary),
        Tool("get_draw_eligible_members", "Get lucky draw eligible members per committee", get_draw_eligible_members),
        Tool("get_emergency_pool_status", "Get the Emergency Support Pool balance and loan disbursement statistics", get_emergency_pool_status),
    ]


# ─────────────────────────────────────────────────────────────────
# Intent Classifier
# ─────────────────────────────────────────────────────────────────

def _classify_intent(message: str) -> tuple[str, str | None]:
    """Simple keyword-based intent routing → (intent, tool_name)."""
    msg = message.lower()
    
    if any(w in msg for w in ["emergency", "pool", "support pool", "community fund", "emergency pool",
                               "ایمرجنسی", "پول", "امدادی فنڈ"]):
        return "emergency_pool_query", "get_emergency_pool_status"
    if any(w in msg for w in ["payment", "receipt", "paid", "pay", "installment", "قسط", "ادائیگی", "رسید"]):
        return "payment_query", "get_my_receipts"
    if any(w in msg for w in ["loan", "borrow", "qarz", "قرض", "loan status"]):
        return "loan_query", "get_my_loans"
    if any(w in msg for w in ["committee", "kameti", "bisi", "savings", "کمیٹی", "بی سی"]):
        return "committee_query", "get_my_committees"
    if any(w in msg for w in ["balance", "wallet", "balance", "بیلنس", "رقم"]):
        return "balance_query", "check_wallet_balance"
    if any(w in msg for w in ["subscribe", "plan", "subscription", "سبسکرپشن", "پلان"]):
        return "subscription_query", "check_subscription_status"
    if any(w in msg for w in ["draw", "lucky", "winner", "spin", "لکی", "ڈرا"]):
        return "draw_query", "get_pending_draw_info"
    if any(w in msg for w in ["pending", "approve", "reject", "loan request", "قرض کی درخواست"]):
        return "manager_loan_query", "get_pending_loans"
    if any(w in msg for w in ["summary", "overview", "all members", "total", "خلاصہ"]):
        return "manager_summary", "get_committee_summary"
    
    return "general", None


# ─────────────────────────────────────────────────────────────────
# Agent class
# ─────────────────────────────────────────────────────────────────

class CommitteeAgent:
    def __init__(
        self,
        agent_type: str,  # "member" | "manager"
        llm: LLMService,
        rag: RagService,
    ):
        self.agent_type = agent_type
        self.llm = llm
        self.rag = rag

    async def run(
        self,
        message: str,
        history: list[ChatMessage],
        context: AppContext,
    ) -> dict[str, Any]:
        """
        ReAct-style agent loop (bounded by MAX_ITERATIONS):
        1. Classify intent → pick tool
        2. Run tool to gather structured data (up to MAX_ITERATIONS attempts)
        3. Retrieve RAG context for semantic enrichment
        4. Inject tool output + RAG context into LLM prompt
        5. Return final response with metadata

        Safety bounds:
          - MAX_ITERATIONS=3 prevents infinite looping
          - TOKEN_BUDGET=2000 truncates oversized tool outputs
        """
        intent, tool_name = _classify_intent(message)
        actions_taken: list[str] = []
        tool_output = ""
        sources: list[str] = []
        iterations = 0
        agent_start = time.perf_counter()

        # Step 1: Build tool registry
        if self.agent_type == "manager":
            tools = {t.name: t for t in _make_manager_tools(context, self.rag)}
        else:
            tools = {t.name: t for t in _make_member_tools(context, self.rag)}

        # Step 2: Execute the most relevant tool (bounded by MAX_ITERATIONS)
        if tool_name and tool_name in tools:
            while iterations < MAX_ITERATIONS:
                iterations += 1
                try:
                    tool_output = await tools[tool_name].run()
                    actions_taken.append(f"Tool used: {tool_name} (iteration {iterations})")
                    logger.info(
                        f"🤖 Agent({self.agent_type}) | intent={intent} | "
                        f"tool={tool_name} | iter={iterations}/{MAX_ITERATIONS}"
                    )
                    break  # Success — exit the loop
                except Exception as e:
                    logger.warning(f"Tool {tool_name} failed on attempt {iterations}: {e}")
                    tool_output = ""
                    if iterations >= MAX_ITERATIONS:
                        actions_taken.append(f"Tool {tool_name} failed after {MAX_ITERATIONS} attempts")
        elif tool_name:
            logger.warning(f"Tool '{tool_name}' not found in {self.agent_type} registry")

        # Step 3: RAG retrieval
        rag_context = ""
        if self.rag.is_ready:
            try:
                rag_context = await self.rag.get_context_for_query(
                    message, context.current_user.email, top_k=3
                )
                if rag_context:
                    actions_taken.append("RAG context retrieved")
                    sources = [
                        f"rag:{i+1}:{chunk.split(']')[0].lstrip('[')}"
                        for i, chunk in enumerate(rag_context.split("\n\n"))
                        if chunk.strip()
                    ]
            except Exception as e:
                logger.warning(f"RAG retrieval failed: {e}")

        # Step 4: Enrich user message with tool output + RAG context
        enriched_message = message
        if tool_output:
            enriched_message += f"\n\n[TOOL DATA]\n{tool_output}"
        if rag_context:
            enriched_message += f"\n\n[CONTEXT FROM DATABASE]\n{rag_context}"

        # Step 5: LLM call
        reply = await self.llm.chat(
            message=enriched_message,
            history=history,
            context=context,
            agent_type=self.agent_type,
        )

        total_latency_ms = round((time.perf_counter() - agent_start) * 1000, 1)
        logger.info(
            f"✅ Agent({self.agent_type}) done | intent={intent} | "
            f"tools_used={len([a for a in actions_taken if 'Tool used' in a])} | "
            f"rag={'yes' if rag_context else 'no'} | total_latency={total_latency_ms}ms"
        )

        return {
            "reply": reply,
            "intent": intent,
            "actions_taken": actions_taken,
            "sources": sources,
            "language": context.language,
        }


# ─────────────────────────────────────────────────────────────────
# Agent Factory
# ─────────────────────────────────────────────────────────────────

class AgentService:
    def __init__(self, llm: LLMService, rag: RagService):
        self._member_agent = CommitteeAgent("member", llm, rag)
        self._manager_agent = CommitteeAgent("manager", llm, rag)

    def get_agent(self, agent_type: str) -> CommitteeAgent:
        return self._manager_agent if agent_type == "manager" else self._member_agent

    async def run(
        self,
        message: str,
        history: list[ChatMessage],
        context: AppContext,
        agent_type: str = "member",
    ) -> dict[str, Any]:
        agent = self.get_agent(agent_type)
        return await agent.run(message, history, context)
