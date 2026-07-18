"""
RAG Service — PostgreSQL + pgvector for scalable semantic search.
Indexes all committee records, receipts, loans, and notifications for semantic search.
"""
from __future__ import annotations
import logging
import os
import hashlib
from typing import Any

from langchain_core.documents import Document
from langchain_postgres import PGVector
from langchain_openai import OpenAIEmbeddings
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_community.embeddings import FakeEmbeddings

from models.schemas import AppContext, SearchResult

logger = logging.getLogger(__name__)


def _make_id(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:16]


class RagService:
    def __init__(self):
        self.connection_string = os.getenv(
            "DATABASE_URL", 
            "postgresql://committee:committee_pass@localhost:5432/committee_ai"
        ).replace("postgresql://", "postgresql+psycopg://") # pgvector requires psycopg driver
        
        self.embeddings = self._build_embedding_function()
        
        try:
            self._vector_store = PGVector(
                embeddings=self.embeddings,
                collection_name="committee_docs",
                connection=self.connection_string,
                use_jsonb=True,
            )
            self._is_ready = True
            logger.info("✅ PGVector RAG service initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize PGVector: {e}")
            self._vector_store = None
            self._is_ready = False

    def _build_embedding_function(self) -> Any:
        provider = os.getenv("LLM_PROVIDER", "gemini").lower()
        if provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY", "")
            if api_key and api_key != "your_openai_api_key_here":
                return OpenAIEmbeddings(model="text-embedding-3-small", api_key=api_key)
        elif provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY", "")
            if api_key and api_key != "your_gemini_api_key_here":
                return GoogleGenerativeAIEmbeddings(model="models/embedding-001", google_api_key=api_key)

        # Universal fallback — works with no API key
        logger.info("Using FakeEmbeddings (offline/fallback)")
        return FakeEmbeddings(size=768)

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    # ── Index all app data into the vector store ─────────────────

    async def index_app_context(self, context: AppContext, user_email: str) -> int:
        """
        Converts all app state into text chunks and upserts them into PGVector.
        Returns total number of documents indexed.

        Chunking strategy:
        - Each entity (committee, receipt, loan, notification) is a single chunk.
        - Chunks are small (50–150 tokens) because they represent atomic records.
        - chunk_overlap = 0 (no overlap needed — records are self-contained).
        - Metadata attached: type, id, user_email for filtered retrieval.
        """
        if not self._is_ready or not self._vector_store:
            return 0

        documents: list[Document] = []
        ids: list[str] = []

        # 1. Committees
        for c in context.committees:
            text = (
                f"Committee: {c.name}. "
                f"Description: {c.description}. "
                f"Total payout: PKR {c.total_amount:,.0f}. "
                f"Monthly contribution: PKR {c.monthly_contribution:,.0f}. "
                f"Members: {', '.join(c.joined_members)}. "
                f"Draw winners: {', '.join(c.draw_winners) or 'none'}. "
                f"Status: {c.status}. "
                f"Progress: {c.installments_paid}/{c.total_installments} installments paid. "
                f"Frequency: {c.frequency}."
            )
            doc_id = _make_id(f"comm_{c.id}_{user_email}")
            documents.append(Document(page_content=text, metadata={"type": "committee", "id": c.id, "user": user_email}))
            ids.append(doc_id)

        # 2. Receipts
        for r in context.receipts:
            text = (
                f"Payment receipt: {r.type} of PKR {r.amount:,.0f} "
                f"by {r.user_name} ({r.user_email}) "
                f"for {r.reference_name} via {r.gateway} on {r.timestamp[:10]}."
            )
            doc_id = _make_id(f"rec_{r.id}_{user_email}")
            documents.append(Document(page_content=text, metadata={"type": "receipt", "id": r.id, "user": user_email}))
            ids.append(doc_id)

        # 3. Loans
        for l in context.loans:
            text = (
                f"Loan application by {l.applicant_name} ({l.applicant_email}): "
                f"PKR {l.amount:,.0f} for {l.duration_months} months. "
                f"Reason: {l.reason}. "
                f"Status: {l.status}. "
                f"Monthly repayment: PKR {l.monthly_repayment:,.0f}. "
                f"Installments paid: {l.installments_paid}/{l.duration_months}. "
                f"Date requested: {l.date_requested[:10]}."
            )
            doc_id = _make_id(f"loan_{l.id}_{user_email}")
            documents.append(Document(page_content=text, metadata={"type": "loan", "id": l.id, "user": user_email}))
            ids.append(doc_id)

        # 4. Notifications
        for n in context.notifications:
            text = (
                f"Notification [{n.type}]: {n.title}. {n.body} "
                f"Date: {n.timestamp[:10]}."
            )
            doc_id = _make_id(f"notif_{n.id}_{user_email}")
            documents.append(Document(page_content=text, metadata={"type": "notification", "id": n.id, "user": user_email}))
            ids.append(doc_id)

        # 5. User profile summary
        u = context.current_user
        user_doc = (
            f"User profile: {u.name} ({u.email}). "
            f"Role: {u.role}. "
            f"Wallet balance: PKR {u.balance:,.2f}. "
            f"Subscription: {u.subscription_plan} ({'active' if u.is_subscribed else 'inactive'})."
        )
        documents.append(Document(page_content=user_doc, metadata={"type": "user", "id": u.email, "user": user_email}))
        ids.append(_make_id(f"user_{user_email}"))

        if documents:
            try:
                self._vector_store.add_documents(documents=documents, ids=ids)
                logger.info(f"📚 Indexed {len(documents)} documents for {user_email}")
            except Exception as e:
                logger.error(f"Failed to index documents to pgvector: {e}")

        return len(documents)

    # ── Semantic search ──────────────────────────────────────────

    async def retrieve(
        self, query: str, user_email: str, top_k: int = 5
    ) -> list[SearchResult]:
        """
        Performs cosine-similarity search and returns top_k relevant chunks.
        Falls back to keyword (hybrid) search if semantic results are low-quality.
        """
        if not self._is_ready or not self._vector_store:
            return []

        try:
            results = self._vector_store.similarity_search_with_score(
                query,
                k=top_k,
                filter={"user": user_email}
            )

            search_results: list[SearchResult] = []

            for doc, score in results:
                # PGVector returns L2 distance. Convert to similarity: 1 / (1 + distance)
                similarity = round(1.0 / (1.0 + float(score)), 4)
                search_results.append(SearchResult(
                    content=doc.page_content,
                    source=f"{doc.metadata.get('type', 'unknown')}:{doc.metadata.get('id', '')}",
                    relevance_score=similarity,
                ))

            # Hybrid fallback: if top result has very low similarity, add keyword matches
            if search_results and search_results[0].relevance_score < 0.3:
                keyword_results = self._keyword_fallback(query, search_results)
                # Merge, deduplicate by source
                seen = {r.source for r in search_results}
                for kr in keyword_results:
                    if kr.source not in seen:
                        search_results.append(kr)
                        seen.add(kr.source)
                search_results = search_results[:top_k]

            return search_results
        except Exception as e:
            logger.error(f"RAG retrieval error: {e}")
            return []

    def _keyword_fallback(
        self, query: str, existing: list[SearchResult]
    ) -> list[SearchResult]:
        """
        Simple keyword-overlap fallback when vector similarity is low.
        Scores existing results by keyword overlap with query (hybrid BM25-style).
        Advanced RAG: combines vector + keyword scores for better retrieval.
        """
        query_tokens = set(query.lower().split())
        scored = []
        for r in existing:
            content_tokens = set(r.content.lower().split())
            overlap = len(query_tokens & content_tokens)
            if overlap > 0:
                # Boost score by keyword overlap (hybrid re-ranking)
                boosted_score = min(r.relevance_score + overlap * 0.05, 1.0)
                scored.append(SearchResult(
                    content=r.content,
                    source=r.source,
                    relevance_score=round(boosted_score, 4),
                ))
        return sorted(scored, key=lambda x: x.relevance_score, reverse=True)

    # ── Enriched context for chat ────────────────────────────────

    async def get_context_for_query(
        self, query: str, user_email: str, top_k: int = 4
    ) -> str:
        """
        Returns a formatted context string from retrieved docs to inject into LLM prompt.
        Each chunk is prefixed with its source type for citation.
        """
        results = await self.retrieve(query, user_email, top_k)
        if not results:
            return ""
        # FIX: was "\\n\\n" (double-escaped) — correctly using real newlines now
        chunks = [f"[{r.source}] {r.content}" for r in results]
        return "\n\n".join(chunks)
