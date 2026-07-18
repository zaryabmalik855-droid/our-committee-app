"""
Pydantic schemas for Our Committee AI API
"""
from __future__ import annotations
from typing import Any, Literal, Optional
from datetime import datetime
from pydantic import BaseModel, Field


# ─────────────────────────────────────────────────────────────────
# Common domain models (mirrors Flutter app data structures)
# ─────────────────────────────────────────────────────────────────

class UserContext(BaseModel):
    name: str
    email: str
    role: Literal["member", "manager"]
    is_subscribed: bool = False
    balance: float = 0.0
    subscription_plan: str = "none"


class CommitteeContext(BaseModel):
    id: str
    name: str
    description: str
    total_amount: float
    monthly_contribution: float
    members_limit: int
    joined_members: list[str]
    installments_paid: int
    total_installments: int
    draw_winners: list[str]
    status: str
    frequency: str


class LoanContext(BaseModel):
    id: str
    applicant_name: str
    applicant_email: str
    amount: float
    reason: str
    monthly_repayment: float
    duration_months: int
    status: str
    date_requested: str
    installments_paid: int
    total_repayable: float


class ReceiptContext(BaseModel):
    id: str
    user_email: str
    user_name: str
    type: str
    amount: float
    reference_name: str
    gateway: str
    timestamp: str


class NotificationContext(BaseModel):
    id: str
    title: str
    body: str
    timestamp: str
    type: str


# ─────────────────────────────────────────────────────────────────
# Full App Context — sent by Flutter to the AI backend
# ─────────────────────────────────────────────────────────────────

class AppContext(BaseModel):
    current_user: UserContext
    committees: list[CommitteeContext] = []
    loans: list[LoanContext] = []
    receipts: list[ReceiptContext] = []
    notifications: list[NotificationContext] = []
    language: Literal["en", "ur"] = "en"
    emergency_pool_balance: float = 0.0  # Sent from Flutter AppStateService


# ─────────────────────────────────────────────────────────────────
# /chat  endpoint
# ─────────────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str
    timestamp: Optional[str] = None


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    history: list[ChatMessage] = []
    context: AppContext
    agent_type: Literal["member", "manager"] = "member"


class ChatResponse(BaseModel):
    reply: str
    sources: list[str] = []
    intent: Optional[str] = None
    actions_taken: list[str] = []
    language: str = "en"
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


# ─────────────────────────────────────────────────────────────────
# /notifications/generate  endpoint
# ─────────────────────────────────────────────────────────────────

class NotificationRequest(BaseModel):
    event_type: Literal["payment_due", "loan_approved", "loan_rejected", "draw_winner",
                        "installment_paid", "penalty_warning", "welcome", "subscription"]
    data: dict[str, Any] = {}
    language: Literal["en", "ur"] = "en"
    user_name: str = ""


class NotificationResponse(BaseModel):
    title: str
    body: str
    type: str
    language: str


# ─────────────────────────────────────────────────────────────────
# /receipts/format  endpoint
# ─────────────────────────────────────────────────────────────────

class ReceiptRequest(BaseModel):
    receipt: ReceiptContext
    language: Literal["en", "ur"] = "en"
    format: Literal["markdown", "json"] = "markdown"


class ReceiptResponse(BaseModel):
    formatted: str
    format: str
    language: str


# ─────────────────────────────────────────────────────────────────
# /loan/analyze  endpoint (Manager Agent)
# ─────────────────────────────────────────────────────────────────

class LoanAnalysisRequest(BaseModel):
    loan: LoanContext
    applicant_history: list[ReceiptContext] = []
    committee_membership: list[CommitteeContext] = []
    language: Literal["en", "ur"] = "en"


class LoanAnalysisResponse(BaseModel):
    risk_level: Literal["low", "medium", "high"]
    recommendation: Literal["approve", "reject", "review"]
    reasoning: str
    confidence_score: float = Field(ge=0.0, le=1.0)
    language: str


# ─────────────────────────────────────────────────────────────────
# /search  endpoint (RAG semantic search)
# ─────────────────────────────────────────────────────────────────

class SearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    context: AppContext
    top_k: int = Field(default=5, ge=1, le=20)


class SearchResult(BaseModel):
    content: str
    source: str
    relevance_score: float


class SearchResponse(BaseModel):
    results: list[SearchResult]
    query: str
    total_found: int


# ─────────────────────────────────────────────────────────────────
# Health Check
# ─────────────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str = "ok"
    version: str
    llm_provider: str
    rag_ready: bool
