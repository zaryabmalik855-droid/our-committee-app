"""
Our Committee AI Backend — FastAPI Application
Endpoints: /chat, /chat/stream, /notifications/generate, /receipts/format,
           /loan/analyze, /search, /health, /metrics
"""
from __future__ import annotations
import os
import time
import logging
import asyncio
from collections import defaultdict, deque
from contextlib import asynccontextmanager

# Load env variables from absolute path
from dotenv import load_dotenv
backend_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(backend_dir, ".env"))

from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.orm import Session

from models.schemas import (
    ChatRequest, ChatResponse,
    NotificationRequest, NotificationResponse,
    ReceiptRequest, ReceiptResponse,
    LoanAnalysisRequest, LoanAnalysisResponse,
    SearchRequest, SearchResponse,
    HealthResponse,
)
from database import engine, get_db, Base
from models.db import UserDB, CommitteeDB, LoanDB, ReceiptDB
from services.llm_service import LLMService
from services.rag_service import RagService
from services.agent_service import AgentService

# ─────────────────────────────────────────────────────────────────
# Logging setup
# ─────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("our_committee")

# ─────────────────────────────────────────────────────────────────
# Singletons (initialized on startup)
# ─────────────────────────────────────────────────────────────────
llm_service: LLMService | None = None
rag_service: RagService | None = None
agent_service: AgentService | None = None

# Initialize DB tables
Base.metadata.create_all(bind=engine)

# Dependency to get DB session
db_dependency = Depends(get_db)

# ─────────────────────────────────────────────────────────────────
# Rate limiting (sliding window: 20 req/min per IP)
# ─────────────────────────────────────────────────────────────────
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "20"))  # max per window
RATE_LIMIT_WINDOW   = int(os.getenv("RATE_LIMIT_WINDOW", "60"))    # seconds
_rate_limit_store: dict[str, deque] = defaultdict(deque)

def _is_rate_limited(client_ip: str) -> bool:
    """
    Sliding window rate limiter. Returns True if the IP has exceeded the limit.
    Each entry in the deque is a timestamp of a recent request.
    """
    now = time.time()
    window = _rate_limit_store[client_ip]
    # Remove timestamps older than the window
    while window and window[0] < now - RATE_LIMIT_WINDOW:
        window.popleft()
    if len(window) >= RATE_LIMIT_REQUESTS:
        return True
    window.append(now)
    return False

# ─────────────────────────────────────────────────────────────────
# Observability — request metrics store
# ─────────────────────────────────────────────────────────────────
_metrics = {
    "total_requests": 0,
    "total_errors": 0,
    "total_latency_ms": 0.0,
    "endpoint_counts": defaultdict(int),
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    global llm_service, rag_service, agent_service
    logger.info("🚀 Starting Our Committee AI backend…")
    llm_service = LLMService()
    rag_service = RagService()
    agent_service = AgentService(llm_service, rag_service)
    logger.info("✅ All services initialized")
    yield
    logger.info("👋 Shutting down…")


# ─────────────────────────────────────────────────────────────────
# FastAPI app
# ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title=os.getenv("APP_TITLE", "Our Committee AI Backend"),
    version=os.getenv("APP_VERSION", "1.0.0"),
    description=(
        "Generative AI backend for Our Committee — "
        "a Pakistani Kameti/Bisi savings & micro-loan app. "
        "Provides smart chat (Urdu/English), RAG search, "
        "AI notifications, and loan risk analysis."
    ),
    lifespan=lifespan,
)

# CORS — allow Flutter web + Streamlit
allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────
# Request logging + metrics middleware
# ─────────────────────────────────────────────────────────────────
@app.middleware("http")
async def logging_and_metrics_middleware(request: Request, call_next):
    """
    Middleware that:
    1. Enforces rate limiting (20 req/min per client IP)
    2. Logs every request with: timestamp, method, path, latency, status
    3. Tracks aggregate metrics (total requests, errors, avg latency)
    """
    client_ip = request.client.host if request.client else "unknown"
    endpoint = request.url.path

    # Rate limit check (skip health/metrics endpoints)
    if endpoint not in ("/health", "/metrics", "/"):
        if _is_rate_limited(client_ip):
            logger.warning(f"⚠️ Rate limit exceeded: {client_ip} on {endpoint}")
            return JSONResponse(
                status_code=429,
                content={"detail": f"Rate limit exceeded: {RATE_LIMIT_REQUESTS} requests per {RATE_LIMIT_WINDOW}s. Try again later."},
            )

    t0 = time.perf_counter()
    response = await call_next(request)
    latency_ms = round((time.perf_counter() - t0) * 1000, 1)

    # Update metrics
    _metrics["total_requests"] += 1
    _metrics["total_latency_ms"] += latency_ms
    _metrics["endpoint_counts"][endpoint] += 1
    if response.status_code >= 400:
        _metrics["total_errors"] += 1

    logger.info(
        f"📡 {request.method} {endpoint} → {response.status_code} | "
        f"{latency_ms}ms | IP={client_ip}"
    )
    response.headers["X-Process-Time"] = str(latency_ms)
    return response


# ─────────────────────────────────────────────────────────────────
# Global error handler
# ─────────────────────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {type(exc).__name__}"},
    )


# ─────────────────────────────────────────────────────────────────
# Health Check
# ─────────────────────────────────────────────────────────────────
@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health_check():
    return HealthResponse(
        status="ok",
        version=os.getenv("APP_VERSION", "1.0.0"),
        llm_provider=os.getenv("LLM_PROVIDER", "gemini"),
        rag_ready=rag_service.is_ready if rag_service else False,
    )


# ─────────────────────────────────────────────────────────────────
# /metrics — LLMOps observability dashboard
# ─────────────────────────────────────────────────────────────────
@app.get("/metrics", tags=["System"])
async def get_metrics():
    """
    LLMOps monitoring endpoint. Returns:
    - Total request count
    - Error rate
    - Average latency (ms)
    - Per-endpoint call counts
    - Rate limit configuration
    """
    total = _metrics["total_requests"]
    avg_latency = (
        round(_metrics["total_latency_ms"] / total, 1) if total > 0 else 0
    )
    error_rate = (
        round(_metrics["total_errors"] / total, 3) if total > 0 else 0
    )
    return {
        "total_requests": total,
        "total_errors": _metrics["total_errors"],
        "error_rate": error_rate,
        "avg_latency_ms": avg_latency,
        "endpoint_counts": dict(_metrics["endpoint_counts"]),
        "rate_limit": {
            "max_requests_per_window": RATE_LIMIT_REQUESTS,
            "window_seconds": RATE_LIMIT_WINDOW,
        },
    }


# ─────────────────────────────────────────────────────────────────
# /chat — Smart AI Assistant (Member & Manager Agents)
# ─────────────────────────────────────────────────────────────────
@app.post("/chat", response_model=ChatResponse, tags=["AI Chat"])
async def chat(request: ChatRequest, db: Session = db_dependency):
    """
    Main conversational AI endpoint.
    Supports Urdu/English, member & manager agents, RAG-enriched responses.

    - **message**: User's question or command
    - **history**: Previous conversation turns (max last 10 used)
    - **context**: Current app state (committees, loans, receipts, etc.)
    - **agent_type**: "member" or "manager"
    """
    if not agent_service or not rag_service:
        raise HTTPException(status_code=503, detail="AI services not ready")

    # 1. Sync context to PostgreSQL Database
    u = request.context.current_user
    db_user = db.query(UserDB).filter(UserDB.email == u.email).first()
    if not db_user:
        db_user = UserDB(email=u.email, name=u.name, role=u.role, balance=u.balance, is_subscribed=u.is_subscribed)
        db.add(db_user)
    else:
        db_user.balance = u.balance
        db_user.is_subscribed = u.is_subscribed

    for c in request.context.committees:
        db_c = db.query(CommitteeDB).filter(CommitteeDB.id == c.id).first()
        if not db_c:
            db_c = CommitteeDB(
                id=c.id, name=c.name, description=c.description,
                total_amount=c.total_amount, monthly_contribution=c.monthly_contribution,
                members_limit=c.members_limit, joined_members=",".join(c.joined_members),
                installments_paid=c.installments_paid, total_installments=c.total_installments,
                draw_winners=",".join(c.draw_winners), status=c.status, frequency=c.frequency
            )
            db.add(db_c)
        else:
            db_c.installments_paid = c.installments_paid
            db_c.status = c.status
            db_c.draw_winners = ",".join(c.draw_winners)
            db_c.joined_members = ",".join(c.joined_members)

    for l in request.context.loans:
        db_l = db.query(LoanDB).filter(LoanDB.id == l.id).first()
        if not db_l:
            db_l = LoanDB(
                id=l.id, applicant_name=l.applicant_name, applicant_email=l.applicant_email,
                amount=l.amount, reason=l.reason, monthly_repayment=l.monthly_repayment,
                duration_months=l.duration_months, status=l.status, date_requested=l.date_requested,
                installments_paid=l.installments_paid, total_repayable=l.total_repayable
            )
            db.add(db_l)
        else:
            db_l.status = l.status
            db_l.installments_paid = l.installments_paid

    for r in request.context.receipts:
        db_r = db.query(ReceiptDB).filter(ReceiptDB.id == r.id).first()
        if not db_r:
            db_r = ReceiptDB(
                id=r.id, user_email=r.user_email, user_name=r.user_name,
                type=r.type, amount=r.amount, reference_name=r.reference_name,
                gateway=r.gateway, timestamp=r.timestamp
            )
            db.add(db_r)

    db.commit()

    # 2. Index context into RAG on each request
    await rag_service.index_app_context(
        request.context,
        request.context.current_user.email,
    )

    result = await agent_service.run(
        message=request.message,
        history=request.history,
        context=request.context,
        agent_type=request.agent_type,
    )

    return ChatResponse(
        reply=result["reply"],
        sources=result.get("sources", []),
        intent=result.get("intent"),
        actions_taken=result.get("actions_taken", []),
        language=result.get("language", request.context.language),
    )


# ─────────────────────────────────────────────────────────────────
# /chat/stream — Streaming AI Chat (Server-Sent Events)
# ─────────────────────────────────────────────────────────────────
@app.post("/chat/stream", tags=["AI Chat"])
async def chat_stream(request: ChatRequest):
    """
    Streaming chat endpoint using Server-Sent Events (SSE).
    Returns the AI response word-by-word for a typewriter effect in the UI.

    Response format (text/event-stream):
        data: {"token": "Hello"}\n\n
        data: {"token": " world"}\n\n
        data: {"done": true, "intent": "...", "sources": [...]}\n\n
    """
    if not agent_service or not rag_service:
        raise HTTPException(status_code=503, detail="AI services not ready")

    async def token_generator():
        """Runs the agent, then streams the reply token by token with delays."""
        try:
            # Index context into RAG
            await rag_service.index_app_context(
                request.context,
                request.context.current_user.email,
            )

            result = await agent_service.run(
                message=request.message,
                history=request.history,
                context=request.context,
                agent_type=request.agent_type,
            )

            reply = result["reply"]
            words = reply.split(" ")

            # Stream word by word
            for i, word in enumerate(words):
                token = word if i == 0 else " " + word
                import json as _json
                yield f"data: {_json.dumps({'token': token})}\n\n"
                await asyncio.sleep(0.025)  # 25ms between words — natural typing speed

            # Send completion event with metadata
            import json as _json
            yield f"data: {_json.dumps({'done': True, 'intent': result.get('intent'), 'sources': result.get('sources', []), 'actions_taken': result.get('actions_taken', [])})}\n\n"

        except Exception as e:
            import json as _json
            logger.error(f"Streaming error: {e}", exc_info=True)
            yield f"data: {_json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(
        token_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # Disable Nginx buffering
        },
    )


# ─────────────────────────────────────────────────────────────────
# /notifications/generate — AI-generated notification text
# ─────────────────────────────────────────────────────────────────
@app.post("/notifications/generate", response_model=NotificationResponse, tags=["Notifications"])
async def generate_notification(request: NotificationRequest):
    """
    Generate a human-friendly notification message for a committee event.
    Supports Urdu and English output.
    
    - **event_type**: payment_due, loan_approved, draw_winner, etc.
    - **data**: Event-specific data (amount, due_date, committee name, etc.)
    - **language**: "en" or "ur"
    """
    if not llm_service:
        raise HTTPException(status_code=503, detail="LLM service not ready")
    result = await llm_service.generate_notification(request)
    return NotificationResponse(**result)


# ─────────────────────────────────────────────────────────────────
# /receipts/format — Structured receipt formatter
# ─────────────────────────────────────────────────────────────────
@app.post("/receipts/format", response_model=ReceiptResponse, tags=["Receipts"])
async def format_receipt(request: ReceiptRequest):
    """
    Format a payment receipt as Markdown or JSON.
    Supports Urdu (Nastaliq) and English output.
    
    - **receipt**: Receipt data object
    - **language**: "en" or "ur"
    - **format**: "markdown" or "json"
    """
    if not llm_service:
        raise HTTPException(status_code=503, detail="LLM service not ready")
    formatted = await llm_service.format_receipt(
        request.receipt, request.language, request.format
    )
    return ReceiptResponse(
        formatted=formatted,
        format=request.format,
        language=request.language,
    )


# ─────────────────────────────────────────────────────────────────
# /loan/analyze — Loan Risk Assessment (Manager Agent)
# ─────────────────────────────────────────────────────────────────
@app.post("/loan/analyze", response_model=LoanAnalysisResponse, tags=["Loans"])
async def analyze_loan(request: LoanAnalysisRequest):
    """
    AI-powered loan risk assessment for the Manager.
    Returns risk level, recommendation, and reasoning.
    
    - **loan**: Loan application details
    - **applicant_history**: Applicant's payment receipts
    - **committee_membership**: Committees the applicant has joined
    - **language**: Response language
    """
    if not llm_service:
        raise HTTPException(status_code=503, detail="LLM service not ready")
    return await llm_service.analyze_loan_risk(
        request.loan,
        request.applicant_history,
        request.committee_membership,
        request.language,
    )


# ─────────────────────────────────────────────────────────────────
# /search — Semantic RAG Search
# ─────────────────────────────────────────────────────────────────
@app.post("/search", response_model=SearchResponse, tags=["Search"])
async def semantic_search(request: SearchRequest):
    """
    Semantic search over the user's committee data using RAG.
    Example queries:
    - "show my last 3 payments"
    - "find pending committees"
    - "which loans are approved?"
    """
    if not rag_service:
        raise HTTPException(status_code=503, detail="RAG service not ready")

    # Ensure context is indexed
    await rag_service.index_app_context(
        request.context,
        request.context.current_user.email,
    )

    results = await rag_service.retrieve(
        query=request.query,
        user_email=request.context.current_user.email,
        top_k=request.top_k,
    )

    return SearchResponse(
        results=results,
        query=request.query,
        total_found=len(results),
    )


# ─────────────────────────────────────────────────────────────────
# Root redirect
# ─────────────────────────────────────────────────────────────────
@app.get("/", include_in_schema=False)
async def root():
    return {
        "name": "Our Committee AI Backend",
        "docs": "/docs",
        "health": "/health",
        "version": os.getenv("APP_VERSION", "1.0.0"),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
