import os
import asyncio
import uuid
from langsmith import Client
from langsmith.evaluation import evaluate, LangChainStringEvaluator

from services.llm_service import LLMService
from models.schemas import AppContext, UserContext, ChatMessage

# Initialize LangSmith client
client = Client()

# Mock context for evaluation
mock_context = AppContext(
    current_user=UserContext(
        name="Test User",
        email="test@example.com",
        role="member",
        balance=50000.0,
        is_subscribed=True,
        subscription_plan="premium"
    ),
    committees=[],
    loans=[],
    receipts=[],
    notifications=[],
    language="en"
)

# Initialize LLM Service
llm_service = LLMService()

async def chat_target(inputs: dict) -> dict:
    """The target function to evaluate."""
    message = inputs["message"]
    agent_type = inputs.get("agent_type", "member")
    context = inputs.get("context", mock_context)
    
    reply = await llm_service.chat(
        message=message,
        history=[],
        context=context,
        agent_type=agent_type
    )
    return {"reply": reply}

def wrapper_target(inputs: dict) -> dict:
    """Synchronous wrapper for LangSmith evaluation."""
    return asyncio.run(chat_target(inputs))

def main():
    dataset_name = f"Committee-Chat-Eval-{uuid.uuid4().hex[:8]}"
    dataset = client.create_dataset(
        dataset_name=dataset_name,
        description="Evaluation dataset for Our Committee AI assistant",
    )
    
    # Add examples
    examples = [
        ("What is my current balance?", "50000"),
        ("Can you lend me 50,000 PKR?", "10,000"), # It should deny based on rules
        ("Who won the lucky draw?", "don't have that information"),
    ]
    
    for query, expected in examples:
        client.create_example(
            inputs={"message": query, "agent_type": "member"},
            outputs={"reply": expected},
            dataset_id=dataset.id,
        )
        
    print(f"Created dataset: {dataset_name}")
    print("Running evaluation...")
    
    # Use exact match or QA evaluator
    evaluators = [
        LangChainStringEvaluator("qa"),
        LangChainStringEvaluator("embedding_distance")
    ]
    
    try:
        results = evaluate(
            wrapper_target,
            data=dataset_name,
            evaluators=evaluators,
            experiment_prefix="eval-baseline",
        )
        print("Evaluation complete. Check LangSmith dashboard for details.")
    except Exception as e:
        print(f"Evaluation encountered an issue (check LANGCHAIN_API_KEY): {e}")

if __name__ == "__main__":
    main()
