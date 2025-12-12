from fastapi import FastAPI
from pydantic import BaseModel
from typing import List

app = FastAPI(title="CrisisAssist API")

class ChatRequest(BaseModel):
    message: str
    crisis_type: str
    severity: str

class Source(BaseModel):
    title: str
    subtitle: str
    confidence: float

class ChatResponse(BaseModel):
    answer: str
    sources: List[Source]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    # ---- TEMP: rule-based mock to prove end-to-end wiring ----
    # Later we replace this block with RAG retrieval + LLM generation.
    if "supplier" in req.message.lower() or "resin" in req.message.lower():
        answer = (
            "✔ Immediate Actions\n"
            "• Pause affected production line\n"
            "• Notify procurement team\n"
            "• Switch to approved alternate suppliers\n\n"
            "⚠ Risks & Notes\n"
            "• Alternate suppliers may require quality validation\n"
            "• Transport delays possible\n\n"
            "📄 Sources Used\n"
            "SOP-014, Supplier DB – Tier 1 Vendors"
        )
        sources = [
            {"title": "SOP-014", "subtitle": "Emergency Production Change", "confidence": 0.86},
            {"title": "Supplier DB", "subtitle": "Resin Tier-1 Vendors", "confidence": 0.79},
        ]
    else:
        answer = (
            "✔ Suggested Next Step\n"
            f"• Please share the impacted system/line and the current status.\n\n"
            "📄 Sources Used\n"
            "General Crisis Playbook"
        )
        sources = [
            {"title": "Playbook", "subtitle": "General Crisis Response", "confidence": 0.70},
        ]

    return {"answer": answer, "sources": sources}