from typing import TypedDict, List, Dict, Any
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver
import uvicorn
from fastapi import FastAPI

app = FastAPI()

# 1. State definition
class AgentState(TypedDict):
    invoice_id: str
    customer_id: str
    suggested_credit: float
    status: str

# 2. Checkpointing (Persistence)
# LangGraph requires an explicit saver for persistence.
memory = SqliteSaver.from_conn_string(":memory:")

# 3. Node definition
def fetch_data(state: AgentState):
    return {"status": "data_fetched"}

def analyze(state: AgentState):
    return {"suggested_credit": 250.0}

def finalize(state: AgentState):
    # Issue credit
    return {"status": "completed"}

# 4. Human-in-the-loop logic
def check_policy(state: AgentState):
    if state["suggested_credit"] > 100:
        return "human_approval"
    return "finalize"

# 5. Build Graph
workflow = StateGraph(AgentState)
workflow.add_node("fetch_data", fetch_data)
workflow.add_node("analyze", analyze)
workflow.add_node("finalize", finalize)

workflow.set_entry_point("fetch_data")
workflow.add_edge("fetch_data", "analyze")

# Conditional routing with interrupt
workflow.add_conditional_edges(
    "analyze",
    check_policy,
    {
        "human_approval": END,  # Hitting END here with a thread_id saves to checkpointer
        "finalize": "finalize"
    }
)

workflow.add_edge("finalize", END)
graph = workflow.compile(checkpointer=memory, interrupt_before=["finalize"])

# 6. FastAPI endpoints to manage the lifecycle
@app.post("/dispute")
def start_dispute(invoice_id: str, customer_id: str):
    config = {"configurable": {"thread_id": invoice_id}}
    # Start execution
    for event in graph.stream({"invoice_id": invoice_id, "customer_id": customer_id}, config):
        # LangGraph will automatically pause at the interrupt point
        if "analyze" in event:
            state = graph.get_state(config)
            if state.values["suggested_credit"] > 100:
                return {"status": "PENDING_APPROVAL", "state": state.values}

@app.post("/dispute/approve")
def approve_dispute(invoice_id: str):
    config = {"configurable": {"thread_id": invoice_id}}
    # Resume after approval
    graph.invoke(None, config)
    return {"status": "COMPLETED"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
