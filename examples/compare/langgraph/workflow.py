from typing import TypedDict, List, Dict, Any, Union
from langgraph.graph import StateGraph, END

# 1. Define the Graph State
class AgentState(TypedDict):
    invoice_id: str
    customer_id: str
    invoice_data: Dict[str, Any]
    usage_logs: List[Dict[str, Any]]
    analysis: Dict[str, Any]
    status: str
    suggested_credit: float

# 2. Define the Nodes
def fetch_data(state: AgentState) -> Dict[str, Any]:
    # Call APIs
    return {
        "invoice_data": {"total": 1250.0},
        "usage_logs": [{"event": "API_CALL", "count": 1000}]
    }

def analyze_discrepancy(state: AgentState) -> Dict[str, Any]:
    # LLM reasoning over the invoice_data and usage_logs
    return {
        "analysis": "Over-counted usage detected.",
        "suggested_credit": 250.0
    }

def finalize(state: AgentState) -> Dict[str, Any]:
    # Issue credit via billing API
    return {"status": "completed"}

# 3. Define the Routing (the "Policy")
def check_policy(state: AgentState) -> str:
    if state["suggested_credit"] > 100:
        return "human_approval"
    return "finalize"

# 4. Build the Graph
workflow = StateGraph(AgentState)

workflow.add_node("fetch_data", fetch_data)
workflow.add_node("analyze", analyze_discrepancy)
workflow.add_node("finalize", finalize)

workflow.set_entry_point("fetch_data")
workflow.add_edge("fetch_data", "analyze")

# Conditional routing
workflow.add_conditional_edges(
    "analyze",
    check_policy,
    {
        "human_approval": END,  # Hitting END here means the host app must resume
        "finalize": "finalize"
    }
)

workflow.add_edge("finalize", END)

# Note: LangGraph's "checkpointer" allows persisting this state to a DB,
# but the host app must manually manage the "interrupts" and "resumptions"
# which requires significant integration code.

app = workflow.compile()
