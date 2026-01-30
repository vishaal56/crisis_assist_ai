from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import os, uuid
import numpy as np

from pypdf import PdfReader
from sentence_transformers import SentenceTransformer
import faiss

app = FastAPI(title="CrisisAssist RAG API")

# (CORS not strictly needed for same machine, but safe for web dev)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DATA_DIR = "data"
os.makedirs(DATA_DIR, exist_ok=True)

model = SentenceTransformer("all-MiniLM-L6-v2")

# In-memory store (good for prototype/demo)
DOC_STORE: List[Dict[str, Any]] = []  # each: {id, doc_name, chunk, meta}
INDEX = None
EMB_DIM = 384  # all-MiniLM-L6-v2 dim


def chunk_text(text: str, chunk_size: int = 700, overlap: int = 120) -> List[str]:
    text = " ".join(text.split())
    chunks = []
    i = 0
    while i < len(text):
        chunks.append(text[i:i + chunk_size])
        i += chunk_size - overlap
    return [c for c in chunks if len(c) > 50]


def embed_texts(texts: List[str]) -> np.ndarray:
    emb = model.encode(texts, normalize_embeddings=True)
    return np.array(emb, dtype=np.float32)


def rebuild_faiss():
    global INDEX
    if len(DOC_STORE) == 0:
        INDEX = faiss.IndexFlatIP(EMB_DIM)
        return

    vectors = embed_texts([d["chunk"] for d in DOC_STORE])
    INDEX = faiss.IndexFlatIP(EMB_DIM)
    INDEX.add(vectors)


def pdf_to_text(pdf_path: str) -> str:
    reader = PdfReader(pdf_path)
    pages = []
    for p in reader.pages:
        t = p.extract_text() or ""
        pages.append(t)
    return "\n".join(pages)


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
    return {"status": "ok", "docs": len(DOC_STORE)}

from fastapi import Form

@app.post("/upload")
async def upload(
        file: UploadFile = File(...),
        doc_type: str = Form(...)
):
    # Save file
    file_id = str(uuid.uuid4())
    out_path = os.path.join(DATA_DIR, f"{file_id}_{file.filename}")
    with open(out_path, "wb") as f:
        f.write(await file.read())

    # Extract text + chunk
    text = pdf_to_text(out_path)
    chunks = chunk_text(text)

    # Store chunks with metadata
    for idx, ch in enumerate(chunks):
        DOC_STORE.append({
            "id": f"{file_id}_{idx}",
            "doc_name": file.filename,
            "chunk": ch,
            "meta": {
                "chunk_index": idx,
                "doc_type": doc_type
            }
        })


    rebuild_faiss()

    return {"uploaded": file.filename, "chunks_added": len(chunks), "total_chunks": len(DOC_STORE)}


def retrieve(query: str, top_k: int = 4):
    if INDEX is None or INDEX.ntotal == 0:
        return []

    qv = embed_texts([query])
    scores, ids = INDEX.search(qv, top_k)

    results = []
    for score, idx in zip(scores[0], ids[0]):
        if idx == -1:
            continue
        d = DOC_STORE[int(idx)]
        results.append((float(score), d))
    return results


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    # Retrieve relevant knowledge
    results = retrieve(
        query=f"[{req.crisis_type} | {req.severity}] {req.message}",
        top_k=4
    )

    if not results:
        return {
            "answer": (
                "I don't have enough verified internal knowledge uploaded yet.\n\n"
                "✔ Next step\n"
                "• Upload SOP PDFs or supplier docs using the Upload Knowledge button.\n\n"
                "📄 Sources Used\nNone"
            ),
            "sources": []
        }

    # Build a grounded response (prototype rules)
    # Later you can replace this with an LLM call using retrieved chunks.
    top_chunks = [r[1]["chunk"] for r in results[:2]]
    answer = (
            "✔ Immediate Actions (from internal knowledge)\n"
            "• Follow the relevant SOP steps for this crisis\n"
            "• Notify owner teams mentioned in the document\n"
            "• Apply the documented workaround / alternative supplier procedure\n\n"
            "⚠ Risks & Notes\n"
            "• If steps are unclear, escalate to the responsible role listed in SOP\n\n"
            "📄 Sources Used\n"
            + ", ".join(list({r[1]['doc_name'] for r in results}))
            + "\n\n"
              "— Retrieved Snippet (for transparency) —\n"
            + top_chunks[0][:350]
            + "..."
    )

    sources = []
    for score, d in results:
        sources.append({
            "title": d["doc_name"],
            "subtitle": f"Chunk {d['meta']['chunk_index']} (retrieved)",
            "confidence": round(score, 2)
        })

    return {"answer": answer, "sources": sources}