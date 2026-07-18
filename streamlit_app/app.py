"""
Our Committee — AI Demo Frontend (Streamlit)
A beautiful, bilingual (Urdu/English) AI chat interface 
for the Committee savings & loan management system.
"""
import streamlit as st
import requests
import json
from datetime import datetime

# ─────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────
import os
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")

# ─────────────────────────────────────────────────────────────────
# Page Config
# ─────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="ہماری کمیٹی AI | Our Committee AI",
    page_icon="🏦",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ─────────────────────────────────────────────────────────────────
# Custom CSS — Premium Dark Theme
# ─────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

/* ── Root ── */
html, body, [class*="css"] {
    font-family: 'Inter', sans-serif;
}

/* ── Background ── */
.stApp {
    background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%);
    min-height: 100vh;
}

/* ── Sidebar ── */
section[data-testid="stSidebar"] {
    background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
    border-right: 1px solid rgba(255,255,255,0.08);
}

/* ── Chat bubbles ── */
.user-bubble {
    background: linear-gradient(135deg, #4F46E5, #7C3AED);
    color: white;
    border-radius: 18px 18px 4px 18px;
    padding: 12px 18px;
    margin: 8px 0;
    max-width: 75%;
    margin-left: auto;
    box-shadow: 0 4px 15px rgba(79, 70, 229, 0.3);
    font-size: 14px;
    line-height: 1.6;
}
.ai-bubble {
    background: linear-gradient(135deg, #0d9488, #10b981);
    color: white;
    border-radius: 18px 18px 18px 4px;
    padding: 12px 18px;
    margin: 8px 0;
    max-width: 80%;
    box-shadow: 0 4px 15px rgba(13, 148, 136, 0.3);
    font-size: 14px;
    line-height: 1.6;
}
.ai-bubble-header {
    font-size: 10px;
    opacity: 0.7;
    margin-bottom: 6px;
    font-weight: 600;
    letter-spacing: 0.5px;
}

/* ── Metric cards ── */
.metric-card {
    background: linear-gradient(135deg, #1e293b, #0f172a);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    padding: 20px;
    margin: 8px 0;
    color: white;
}

/* ── Quick chips ── */
.chip-container {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin: 12px 0;
}
.chip {
    background: rgba(79, 70, 229, 0.2);
    border: 1px solid rgba(79, 70, 229, 0.5);
    color: #a78bfa;
    border-radius: 20px;
    padding: 6px 14px;
    font-size: 12px;
    cursor: pointer;
    font-weight: 500;
}

/* ── Titles ── */
h1, h2, h3 { color: white !important; }
p, span, label { color: #cbd5e1; }

/* ── Input ── */
.stTextInput input, .stTextArea textarea {
    background: #1e293b !important;
    border: 1px solid rgba(255,255,255,0.15) !important;
    color: white !important;
    border-radius: 12px !important;
}

/* ── Buttons ── */
.stButton button {
    background: linear-gradient(135deg, #4F46E5, #7C3AED) !important;
    color: white !important;
    border: none !important;
    border-radius: 12px !important;
    font-weight: 600 !important;
    letter-spacing: 0.3px;
}

/* ── Divider ── */
hr { border-color: rgba(255,255,255,0.08) !important; }

/* ── Badge ── */
.badge {
    background: linear-gradient(135deg, #d97706, #f59e0b);
    color: #1c1917;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.5px;
}

/* ── Risk badges ── */
.risk-low { color: #10b981; font-weight: 700; }
.risk-medium { color: #f59e0b; font-weight: 700; }
.risk-high { color: #ef4444; font-weight: 700; }
</style>
""", unsafe_allow_html=True)


# ─────────────────────────────────────────────────────────────────
# Mock App Context (mirrors the Flutter mock data)
# ─────────────────────────────────────────────────────────────────

MOCK_CONTEXT = {
    "current_user": {
        "name": "Fatima Khan",
        "email": "fatima@gmail.com",
        "role": "member",
        "is_subscribed": False,
        "balance": 100000.0,
        "subscription_plan": "none",
    },
    "committees": [
        {
            "id": "c1",
            "name": "Roshan Savings 2026",
            "description": "Monthly rotating savings pool for local small vendors.",
            "total_amount": 100000,
            "monthly_contribution": 10000,
            "members_limit": 10,
            "joined_members": ["Ali Ahmed", "Fatima Khan", "Zainab Bibi", "Hamza Shah", "Sana Ali"],
            "installments_paid": 4,
            "total_installments": 10,
            "draw_winners": ["Zainab Bibi", "Hamza Shah"],
            "status": "active",
            "frequency": "monthly",
        },
        {
            "id": "c2",
            "name": "Gold Circle Bisi",
            "description": "Short term premium drawing cycle.",
            "total_amount": 40000,
            "monthly_contribution": 5000,
            "members_limit": 8,
            "joined_members": ["Ali Ahmed", "Sana Ali", "Usman Ghafoor", "Zainab Bibi"],
            "installments_paid": 2,
            "total_installments": 8,
            "draw_winners": ["Usman Ghafoor"],
            "status": "active",
            "frequency": "weekly",
        },
    ],
    "loans": [
        {
            "id": "l1",
            "applicant_name": "Zainab Bibi",
            "applicant_email": "zainab@gmail.com",
            "amount": 15000,
            "reason": "To purchase sewing materials for boutique work.",
            "monthly_repayment": 1030,
            "duration_months": 15,
            "status": "pending",
            "date_requested": datetime.now().isoformat(),
            "installments_paid": 0,
            "total_repayable": 15450,
        },
    ],
    "receipts": [
        {
            "id": "rec1",
            "user_email": "fatima@gmail.com",
            "user_name": "Fatima Khan",
            "type": "Committee Installment",
            "amount": 10000.0,
            "reference_name": "Roshan Savings 2026",
            "gateway": "JAZZCASH",
            "timestamp": datetime.now().isoformat(),
        },
    ],
    "notifications": [
        {
            "id": "n1",
            "title": "Lucky Draw Result!",
            "body": "Zainab Bibi has won the June cycle draw for Roshan Savings 2026!",
            "timestamp": datetime.now().isoformat(),
            "type": "draw",
        },
    ],
    "language": "en",
}

MANAGER_CONTEXT = {
    **MOCK_CONTEXT,
    "current_user": {
        "name": "Ali Ahmed",
        "email": "ali@gmail.com",
        "role": "manager",
        "is_subscribed": True,
        "balance": 100000.0,
        "subscription_plan": "monthly",
    },
}


# ─────────────────────────────────────────────────────────────────
# API Helpers
# ─────────────────────────────────────────────────────────────────

def call_chat(message: str, history: list, context: dict, agent_type: str) -> dict:
    try:
        payload = {
            "message": message,
            "history": history,
            "context": context,
            "agent_type": agent_type,
        }
        resp = requests.post(f"{BACKEND_URL}/chat", json=payload, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.ConnectionError:
        return {
            "reply": (
                "⚠️ Backend not connected. Start the FastAPI server:\n"
                "```bash\ncd backend && uvicorn main:app --reload\n```\n\n"
                "Or with Docker:\n```bash\ndocker-compose up\n```"
            ),
            "intent": "error",
            "actions_taken": [],
            "sources": [],
            "language": context.get("language", "en"),
        }
    except Exception as e:
        return {"reply": f"Error: {str(e)}", "intent": "error", "actions_taken": [], "sources": [], "language": "en"}


def call_generate_notification(event_type: str, data: dict, language: str, user_name: str) -> dict:
    try:
        resp = requests.post(f"{BACKEND_URL}/notifications/generate", json={
            "event_type": event_type, "data": data, "language": language, "user_name": user_name
        }, timeout=15)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        return {"title": "Error", "body": str(e), "type": "payment", "language": language}


def call_loan_analyze(loan: dict, language: str) -> dict:
    try:
        resp = requests.post(f"{BACKEND_URL}/loan/analyze", json={
            "loan": loan, "applicant_history": [], "committee_membership": [], "language": language
        }, timeout=15)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        return {"risk_level": "medium", "recommendation": "review", "reasoning": str(e), "confidence_score": 0.5, "language": language}


def check_backend_health() -> bool:
    try:
        resp = requests.get(f"{BACKEND_URL}/health", timeout=5)
        return resp.status_code == 200
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────────
# Session State Initialization
# ─────────────────────────────────────────────────────────────────

if "chat_history" not in st.session_state:
    st.session_state.chat_history = []
if "language" not in st.session_state:
    st.session_state.language = "en"
if "role" not in st.session_state:
    st.session_state.role = "member"
if "active_tab" not in st.session_state:
    st.session_state.active_tab = "chat"
if "message_meta" not in st.session_state:
    # Track metadata per AI message: sources, actions_taken, intent
    st.session_state.message_meta = []
if "total_messages" not in st.session_state:
    st.session_state.total_messages = 0
if "last_latency" not in st.session_state:
    st.session_state.last_latency = None


# ─────────────────────────────────────────────────────────────────
# Sidebar
# ─────────────────────────────────────────────────────────────────

with st.sidebar:
    st.markdown("""
    <div style="text-align:center; padding: 20px 0;">
        <div style="font-size: 48px;">🏦</div>
        <h2 style="color: white; margin: 8px 0 4px 0;">ہماری کمیٹی</h2>
        <p style="color: #94a3b8; font-size: 13px;">Our Committee AI</p>
        <div class="badge">AI POWERED</div>
    </div>
    """, unsafe_allow_html=True)

    st.divider()

    # Backend status
    is_backend_up = check_backend_health()
    status_color = "#10b981" if is_backend_up else "#ef4444"
    status_text = "Backend Online ✅" if is_backend_up else "Backend Offline ❌"
    st.markdown(
        f'<div style="background:rgba(255,255,255,0.05); border-radius:10px; padding:10px 14px; '
        f'border-left: 3px solid {status_color}; font-size:12px; color:{status_color}; font-weight:600;">'
        f'{status_text}</div>',
        unsafe_allow_html=True
    )
    st.caption(f"URL: `{BACKEND_URL}`")

    st.divider()

    # Role selector
    st.markdown("**👤 Login As**")
    role = st.selectbox(
        "Select Role",
        ["member", "manager"],
        label_visibility="collapsed",
        index=0 if st.session_state.role == "member" else 1,
    )
    st.session_state.role = role

    # Language toggle
    st.markdown("**🌐 Language / زبان**")
    lang_options = {"English 🇬🇧": "en", "اردو 🇵🇰": "ur"}
    lang_label = st.selectbox(
        "Language",
        list(lang_options.keys()),
        label_visibility="collapsed",
        index=0 if st.session_state.language == "en" else 1,
    )
    st.session_state.language = lang_options[lang_label]

    st.divider()

    # Navigation
    st.markdown("**📱 Navigation**")
    nav_items = {
        "💬 AI Chat Assistant": "chat",
        "📊 Committee Insights": "insights",
        "🔔 Notification Lab": "notifications",
        "⚠️ Loan Risk Analyzer": "loan_risk",
        "🔍 Semantic Search": "search",
    }
    for label, tab_id in nav_items.items():
        btn_style = (
            "background: linear-gradient(135deg, #4F46E5, #7C3AED); border-radius: 10px; padding: 8px 14px;"
            if st.session_state.active_tab == tab_id
            else "background: rgba(255,255,255,0.04); border-radius: 10px; padding: 8px 14px;"
        )
        if st.button(label, key=f"nav_{tab_id}", use_container_width=True):
            st.session_state.active_tab = tab_id

    st.divider()
    st.caption("Built with 🤖 Gemini + LangChain + PGVector")

    # ── Usage counter ────────────────────────────────────────────
    if st.session_state.total_messages > 0:
        st.markdown(
            f'<div style="background:rgba(79,70,229,0.1); border-radius:8px; padding:8px 12px; '
            f'font-size:11px; color:#a78bfa; text-align:center;">'
            f'💬 {st.session_state.total_messages} messages sent this session'
            f'</div>',
            unsafe_allow_html=True,
        )
        if st.session_state.last_latency:
            st.caption(f"⏱️ Last response: {st.session_state.last_latency}ms")

    st.markdown("""
    <div style="background:rgba(217,119,6,0.1); border:1px solid rgba(217,119,6,0.2); border-left:3px solid #d97706; padding:8px 12px; border-radius:8px; font-size:11px; color:#cbd5e1; line-height:1.4;">
        ⚠️ <strong>AI Disclosure:</strong> Insights, loan analysis, and drafts are generated by AI. Please review and verify all financial figures independently.
    </div>
    """, unsafe_allow_html=True)


# ─────────────────────────────────────────────────────────────────
# Main Content
# ─────────────────────────────────────────────────────────────────

context = MANAGER_CONTEXT.copy() if st.session_state.role == "manager" else MOCK_CONTEXT.copy()
context["language"] = st.session_state.language

# ── Page Header ─────────────────────────────────────────────────
col1, col2, col3 = st.columns([1, 3, 1])
with col2:
    user_name = context["current_user"]["name"]
    lang = st.session_state.language
    greeting = f"آپ کا استقبال ہے، {user_name}! 🌙" if lang == "ur" else f"Welcome back, {user_name}! 👋"
    role_badge = "👔 Manager" if st.session_state.role == "manager" else "👤 Member"
    st.markdown(f"""
    <div style="text-align:center; padding: 30px 0 20px 0;">
        <h1 style="font-size: 28px; font-weight: 700; background: linear-gradient(135deg, #4F46E5, #10b981);
                   -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
            {greeting}
        </h1>
        <span style="background: rgba(79,70,229,0.2); border: 1px solid rgba(79,70,229,0.5);
                     color: #a78bfa; border-radius: 20px; padding: 4px 14px; font-size: 12px; font-weight: 600;">
            {role_badge}
        </span>
    </div>
    """, unsafe_allow_html=True)

st.divider()

# ─────────────────────────────────────────────────────────────────
# TAB: AI Chat
# ─────────────────────────────────────────────────────────────────
if st.session_state.active_tab == "chat":
    col_chat, col_stats = st.columns([3, 1])

    with col_chat:
        title_en = "💬 AI Chat Assistant"
        title_ur = "💬 AI چیٹ اسسٹنٹ"
        st.markdown(f"### {title_ur if lang == 'ur' else title_en}")

        # Quick action chips
        st.markdown("**Quick Questions:**")
        chip_cols = st.columns(4)
        chips = {
            "en": ["💳 My Payments", "🏦 My Committees", "💰 Loan Status", "📊 Balance"],
            "ur": ["💳 میری ادائیگیاں", "🏦 میری کمیٹیاں", "💰 قرض کی حیثیت", "📊 بیلنس"],
        }
        chip_messages = {
            "en": ["Show my last 3 payments", "List my committees", "What is my loan status?", "What is my wallet balance?"],
            "ur": ["میری آخری 3 ادائیگیاں دکھائیں", "میری کمیٹیاں کون سی ہیں؟", "میرے قرض کی صورتحال کیا ہے؟", "میرا بیلنس کتنا ہے؟"],
        }
        for i, (chip, msg) in enumerate(zip(chips[lang], chip_messages[lang])):
            with chip_cols[i]:
                if st.button(chip, key=f"chip_{i}", use_container_width=True):
                    # Add as user message and get response
                    st.session_state.chat_history.append({"role": "user", "content": msg})
                    with st.spinner("AI is thinking... 🤔"):
                        result = call_chat(msg, st.session_state.chat_history[:-1], context, st.session_state.role)
                    st.session_state.chat_history.append({"role": "assistant", "content": result["reply"]})
                    st.session_state.message_meta.append({
                        "sources": result.get("sources", []),
                        "intent": result.get("intent"),
                        "actions_taken": result.get("actions_taken", []),
                    })
                    st.session_state.total_messages += 1
                    st.rerun()

        # Chat history display
        st.markdown("---")
        chat_container = st.container()
        with chat_container:
            if not st.session_state.chat_history:
                # ── Welcome flow for new users ───────────────────────────────
                empty_msg = (
                    "السلام علیکم! میں آپ کا AI اسسٹنٹ ہوں۔ نیچے دیے گئے سوالات میں سے کوئی چنیں:"
                    if lang == "ur"
                    else "Hello! I'm your AI assistant for Our Committee. Try one of these to get started:"
                )
                st.markdown(f"""
                <div class="ai-bubble">
                    <div class="ai-bubble-header">🤖 AI ASSISTANT</div>
                    {empty_msg}
                </div>
                """, unsafe_allow_html=True)

                # Suggested prompts for new users
                welcome_prompts = {
                    "en": [
                        "📊 What is my wallet balance?",
                        "🏦 List all my committees",
                        "💳 Show my recent payments",
                        "💰 Am I eligible for a loan?",
                        "🎯 Who won the lucky draw?",
                    ],
                    "ur": [
                        "📊 میرا بیلنس کتنا ہے؟",
                        "🏦 میری کمیٹیاں کون سی ہیں؟",
                        "💳 میری آخری ادائیگیاں دکھائیں",
                        "💰 کیا میں قرض کا اہل ہوں؟",
                        "🎯 لکی ڈرا کا نتیجہ کیا ہے؟",
                    ],
                }
                wp_msgs_en = [
                    "What is my wallet balance?",
                    "List all my committees",
                    "Show my recent payments",
                    "Am I eligible for a loan?",
                    "Who won the lucky draw?",
                ]
                st.markdown("**💡 Suggested questions:**")
                for idx, prompt_label in enumerate(welcome_prompts.get(lang, welcome_prompts["en"])):
                    if st.button(prompt_label, key=f"welcome_{idx}", use_container_width=False):
                        msg = wp_msgs_en[idx]
                        st.session_state.chat_history.append({"role": "user", "content": msg})
                        with st.spinner("Thinking... 🤔"):
                            result = call_chat(msg, [], context, st.session_state.role)
                        st.session_state.chat_history.append({"role": "assistant", "content": result["reply"]})
                        st.session_state.message_meta.append({
                            "sources": result.get("sources", []),
                            "intent": result.get("intent"),
                            "actions_taken": result.get("actions_taken", []),
                        })
                        st.session_state.total_messages += 1
                        st.rerun()
            else:
                ai_msg_idx = 0  # Track which AI message we're on for metadata
                for msg_idx, msg in enumerate(st.session_state.chat_history):
                    if msg["role"] == "user":
                        st.markdown(f'<div class="user-bubble">👤 {msg["content"]}</div>', unsafe_allow_html=True)
                    else:
                        # AI message with RAG source citations
                        st.markdown(f"""
                        <div class="ai-bubble">
                            <div class="ai-bubble-header">🤖 AI ASSISTANT</div>
                            {msg["content"].replace(chr(10), "<br>")}
                        </div>
                        """, unsafe_allow_html=True)

                        # Show RAG source citations and debug info
                        if ai_msg_idx < len(st.session_state.message_meta):
                            meta = st.session_state.message_meta[ai_msg_idx]
                            sources = meta.get("sources", [])
                            actions = meta.get("actions_taken", [])
                            intent = meta.get("intent", "")

                            if sources:
                                source_labels = " · ".join([f"`{s}`" for s in sources[:3]])
                                st.markdown(
                                    f'<div style="font-size:10px; color:#4F46E5; margin:2px 0 8px 4px;">'
                                    f'📎 Sources: {source_labels}</div>',
                                    unsafe_allow_html=True,
                                )

                            if actions or intent:
                                with st.expander("🔍 AI reasoning trace", expanded=False):
                                    if intent:
                                        st.caption(f"**Intent detected**: `{intent}`")
                                    if actions:
                                        for action in actions:
                                            st.caption(f"• {action}")
                                    # Copy response button
                                    st.code(msg["content"], language=None)

                        ai_msg_idx += 1

        # Input area
        st.markdown("---")
        placeholder = "اپنا سوال یہاں لکھیں..." if lang == "ur" else "Type your message here..."
        user_input = st.text_input("Message", placeholder=placeholder, label_visibility="collapsed", key="chat_input")
        send_col, clear_col = st.columns([4, 1])
        with send_col:
            if st.button("Send ✉️" if lang == "en" else "بھیجیں ✉️", use_container_width=True) and user_input.strip():
                import time as _time
                t0 = _time.perf_counter()
                st.session_state.chat_history.append({"role": "user", "content": user_input.strip()})
                with st.spinner("Thinking..." if lang == "en" else "سوچ رہا ہوں..."):
                    result = call_chat(user_input.strip(), st.session_state.chat_history[:-1], context, st.session_state.role)
                latency_ms = round((_time.perf_counter() - t0) * 1000)
                st.session_state.chat_history.append({"role": "assistant", "content": result["reply"]})
                st.session_state.message_meta.append({
                    "sources": result.get("sources", []),
                    "intent": result.get("intent"),
                    "actions_taken": result.get("actions_taken", []),
                })
                st.session_state.total_messages += 1
                st.session_state.last_latency = latency_ms
                st.rerun()
        with clear_col:
            if st.button("Clear 🗑️", use_container_width=True):
                st.session_state.chat_history = []
                st.session_state.message_meta = []
                st.session_state.total_messages = 0
                st.rerun()

    with col_stats:
        st.markdown("### 📈 Quick Stats")
        committees = context.get("committees", [])
        loans = context.get("loans", [])
        receipts = context.get("receipts", [])

        stats = [
            ("🏦", "Committees", len(committees)),
            ("💳", "Receipts", len(receipts)),
            ("💰", "Loans", len(loans)),
            ("⏳", "Pending", len([l for l in loans if l.get("status") == "pending"])),
        ]
        for icon, label, value in stats:
            st.markdown(f"""
            <div class="metric-card" style="text-align:center; padding:16px;">
                <div style="font-size:28px;">{icon}</div>
                <div style="font-size:22px; font-weight:700; color:#10b981;">{value}</div>
                <div style="font-size:11px; color:#94a3b8;">{label}</div>
            </div>
            """, unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────
# TAB: Committee Insights
# ─────────────────────────────────────────────────────────────────
elif st.session_state.active_tab == "insights":
    st.markdown("### 📊 Committee Insights")
    committees = context.get("committees", [])

    for comm in committees:
        progress = comm["installments_paid"] / max(comm["total_installments"], 1)
        with st.expander(f"🏦 {comm['name']} — {comm['status'].upper()}", expanded=True):
            col1, col2, col3 = st.columns(3)
            col1.metric("Total Pool", f"PKR {comm['total_amount']:,.0f}")
            col2.metric("Contribution", f"PKR {comm['monthly_contribution']:,.0f}/{comm['frequency']}")
            col3.metric("Members", f"{len(comm['joined_members'])}/{comm['members_limit']}")
            st.progress(progress, text=f"Progress: {comm['installments_paid']}/{comm['total_installments']} cycles")
            st.caption(f"**Members:** {', '.join(comm['joined_members'])}")
            st.caption(f"**Draw Winners:** {', '.join(comm['draw_winners']) or 'None yet'}")

            # AI insight button
            if st.button(f"🤖 Get AI Insight", key=f"insight_{comm['id']}"):
                msg = f"Give me a brief insight about the committee named {comm['name']}. Status: {comm['status']}, progress: {comm['installments_paid']}/{comm['total_installments']} cycles."
                with st.spinner("Analyzing..."):
                    result = call_chat(msg, [], context, st.session_state.role)
                st.info(result["reply"])

# ─────────────────────────────────────────────────────────────────
# TAB: Notification Lab
# ─────────────────────────────────────────────────────────────────
elif st.session_state.active_tab == "notifications":
    st.markdown("### 🔔 AI Notification Generator")
    st.caption("Generate AI-written notifications for any committee event")

    col1, col2 = st.columns(2)
    with col1:
        event_type = st.selectbox("Event Type", [
            "payment_due", "loan_approved", "loan_rejected", "draw_winner",
            "installment_paid", "penalty_warning", "welcome", "subscription"
        ])
        notif_lang = st.selectbox("Language", ["en", "ur"])
        user_name_notif = st.text_input("Member Name", value=context["current_user"]["name"])
    with col2:
        amount = st.number_input("Amount (PKR)", value=10000, step=1000)
        committee_name = st.text_input("Committee Name", value="Roshan Savings 2026")
        due_date = st.text_input("Due Date", value="5th July 2026")

    if st.button("✨ Generate Notification", use_container_width=True):
        with st.spinner("Generating AI notification..."):
            result = call_generate_notification(
                event_type=event_type,
                data={"amount": amount, "committee": committee_name, "due_date": due_date,
                      "winner": user_name_notif, "gateway": "JazzCash"},
                language=notif_lang,
                user_name=user_name_notif,
            )
        st.success("✅ Notification Generated!")
        st.markdown(f"""
        <div style="background: linear-gradient(135deg, #1e293b, #0f172a); border-radius: 16px;
                    padding: 20px; border: 1px solid rgba(255,255,255,0.1); margin-top: 16px;">
            <div style="font-size: 11px; color: #94a3b8; margin-bottom: 8px; font-weight: 600;">
                {result.get('type', 'NOTIFICATION').upper()} · {notif_lang.upper()}
            </div>
            <div style="font-size: 16px; font-weight: 700; color: white; margin-bottom: 8px;">
                {result.get('title', '')}
            </div>
            <div style="font-size: 13px; color: #cbd5e1; line-height: 1.6;">
                {result.get('body', '')}
            </div>
        </div>
        """, unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────
# TAB: Loan Risk Analyzer
# ─────────────────────────────────────────────────────────────────
elif st.session_state.active_tab == "loan_risk":
    st.markdown("### ⚠️ AI Loan Risk Analyzer")
    st.caption("Manager tool: AI-powered loan application assessment")

    loans = context.get("loans", [])
    if loans:
        for loan in loans:
            with st.expander(f"📋 {loan['applicant_name']} — PKR {loan['amount']:,.0f} ({loan['status'].upper()})", expanded=True):
                col1, col2 = st.columns(2)
                col1.markdown(f"**Reason:** {loan['reason']}")
                col1.markdown(f"**Duration:** {loan['duration_months']} months")
                col2.markdown(f"**Monthly Repayment:** PKR {loan['monthly_repayment']:,.0f}")
                col2.markdown(f"**Total Repayable:** PKR {loan['total_repayable']:,.0f}")

                risk_lang = st.selectbox("Analysis Language", ["en", "ur"], key=f"risk_lang_{loan['id']}")
                if st.button(f"🤖 Analyze Risk", key=f"risk_{loan['id']}"):
                    with st.spinner("Running AI risk assessment..."):
                        result = call_loan_analyze(loan, risk_lang)

                    risk_class = f"risk-{result.get('risk_level', 'medium')}"
                    rec_emoji = {"approve": "✅", "reject": "❌", "review": "🔍"}.get(result.get("recommendation", "review"), "🔍")
                    st.markdown(f"""
                    <div style="background: linear-gradient(135deg, #1e293b, #0f172a); border-radius: 16px;
                                padding: 20px; border: 1px solid rgba(255,255,255,0.1); margin-top: 12px;">
                        <div style="display:flex; justify-content:space-between; margin-bottom:12px;">
                            <div>
                                <span style="font-size:11px; color:#94a3b8;">RISK LEVEL</span><br>
                                <span class="{risk_class}" style="font-size:20px;">{result.get('risk_level','?').upper()}</span>
                            </div>
                            <div>
                                <span style="font-size:11px; color:#94a3b8;">RECOMMENDATION</span><br>
                                <span style="font-size:20px; color:white;">{rec_emoji} {result.get('recommendation','?').upper()}</span>
                            </div>
                            <div>
                                <span style="font-size:11px; color:#94a3b8;">CONFIDENCE</span><br>
                                <span style="font-size:20px; color:#4F46E5;">{int(result.get('confidence_score', 0.5)*100)}%</span>
                            </div>
                        </div>
                        <div style="font-size:13px; color:#cbd5e1; line-height:1.6; padding-top:12px;
                                    border-top:1px solid rgba(255,255,255,0.08);">
                            {result.get('reasoning','')}
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
    else:
        st.info("No loans to analyze.")

# ─────────────────────────────────────────────────────────────────
# TAB: Semantic Search
# ─────────────────────────────────────────────────────────────────
elif st.session_state.active_tab == "search":
    st.markdown("### 🔍 Semantic Search")
    st.caption("Natural language search across committees, receipts, loans, and notifications")

    example_queries = [
        "show my last 3 payments",
        "find pending committees",
        "which loans are approved?",
        "who won the lucky draw?",
        "آخری ادائیگیاں دکھائیں",
    ]
    st.markdown("**Example queries:**")
    eq_cols = st.columns(len(example_queries))
    for i, q in enumerate(example_queries):
        if eq_cols[i].button(q, key=f"eq_{i}"):
            st.session_state["search_query"] = q

    search_query = st.text_input(
        "Search query",
        value=st.session_state.get("search_query", ""),
        placeholder="e.g. show my last 3 payments",
    )
    top_k = st.slider("Max results", 1, 10, 5)

    if st.button("🔍 Search", use_container_width=True) and search_query.strip():
        try:
            resp = requests.post(f"{BACKEND_URL}/search", json={
                "query": search_query.strip(),
                "context": context,
                "top_k": top_k,
            }, timeout=15)
            if resp.status_code == 200:
                data = resp.json()
                results = data.get("results", [])
                st.markdown(f"**Found {len(results)} result(s) for:** *{search_query}*")
                for i, r in enumerate(results):
                    relevance_pct = int(r.get("relevance_score", 0) * 100)
                    st.markdown(f"""
                    <div class="metric-card" style="margin-bottom:10px;">
                        <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
                            <span style="font-size:11px; color:#4F46E5; font-weight:600;">
                                #{i+1} · {r.get('source','unknown')}
                            </span>
                            <span style="font-size:11px; color:#10b981; font-weight:600;">
                                {relevance_pct}% match
                            </span>
                        </div>
                        <div style="font-size:13px; color:#e2e8f0; line-height:1.6;">
                            {r.get('content','')}
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
            else:
                st.error(f"Search error: {resp.status_code}")
        except Exception as e:
            st.error(f"Search failed: {e}")

# ─────────────────────────────────────────────────────────────────
# Footer
# ─────────────────────────────────────────────────────────────────
st.divider()
st.markdown("""
<div style="text-align:center; padding: 16px; color: #475569; font-size: 12px;">
    🏦 <strong style="color:#94a3b8;">Our Committee AI</strong> — 
    Powered by <strong style="color:#4F46E5;">Google Gemini</strong> + 
    <strong style="color:#10b981;">LangChain</strong> + 
    <strong style="color:#d97706;">PGVector</strong><br>
    ⚠️ <span style="color:#94a3b8;">AI-generated responses. Please verify financial details.</span><br>
    Made for Pakistan's Kameti/Bisi savings community 🇵🇰
</div>
""", unsafe_allow_html=True)
