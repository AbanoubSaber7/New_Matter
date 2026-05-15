"""
NLTK-style FAQ chatbot server for YouMatter (WebSocket + HTTP).

Run (from this folder):
  pip install -r requirements.txt
  python -m nltk.downloader punkt_tab punkt
  uvicorn main:app --host 0.0.0.0 --port 8765
"""

from __future__ import annotations

import asyncio
import json
import os
import random
import re
import unicodedata
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    import nltk
    from nltk import word_tokenize
    from nltk.stem import PorterStemmer
except ImportError as e:  # pragma: no cover
    raise SystemExit("Install requirements: pip install -r requirements.txt") from e

ROOT = Path(__file__).resolve().parent
INTENTS_PATH = ROOT / "intents.json"

with INTENTS_PATH.open(encoding="utf-8") as f:
    _DATA = json.load(f)

INTENTS = _DATA["intents"]
FALLBACK = _DATA.get(
    "fallback_responses",
    ["I'm here to listen. Could you say a bit more?"],
)

stemmer = PorterStemmer()


def _normalize(s: str) -> str:
    s = unicodedata.normalize("NFKC", s)
    return s.lower().strip()


def tokenize(text: str) -> list[str]:
    text = _normalize(text)
    # English-ish tokens via NLTK; Arabic often splits on whitespace/punctuation
    tokens: list[str] = []
    for piece in re.split(r"[^\w\u0600-\u06FF]+", text):
        if not piece:
            continue
        if all(ord(c) < 128 for c in piece):
            try:
                tokens.extend(word_tokenize(piece))
            except LookupError:
                tokens.append(piece)
        else:
            tokens.append(piece)
    out: list[str] = []
    for w in tokens:
        w = w.strip()
        if not w:
            continue
        if all(ord(c) < 128 for c in w):
            out.append(stemmer.stem(w))
        else:
            out.append(w)
    return out


def bag(text: str) -> set[str]:
    return set(tokenize(text))


def best_response(user_text: str) -> str:
    u = bag(user_text)
    if not u:
        return random.choice(FALLBACK)

    best_score = 0.0
    best_intent: dict | None = None

    for intent in INTENTS:
        for pattern in intent.get("patterns", []):
            p = bag(pattern)
            if not p:
                continue
            inter = len(u & p)
            score = inter / max(len(p), 1)
            if score > best_score:
                best_score = score
                best_intent = intent

    if best_intent and best_score >= 0.25:
        responses = best_intent.get("responses") or FALLBACK
        return random.choice(responses)
    return random.choice(FALLBACK)


app = FastAPI(title="YouMatter NLTK Chatbot")


@app.on_event("startup")
def _ensure_nltk_data() -> None:
    for resource in ("punkt", "punkt_tab"):
        try:
            nltk.data.find(f"tokenizers/{resource}")
        except LookupError:
            nltk.download(resource, quiet=True)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatBody(BaseModel):
    text: str


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/chat")
def chat_http(body: ChatBody) -> dict[str, str]:
    reply = best_response(body.text)
    return {"reply": reply}


@app.websocket("/ws")
async def chat_ws(ws: WebSocket) -> None:
    await ws.accept()
    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send_text(
                    json.dumps(
                        {
                            "type": "error",
                            "id": None,
                            "text": "Invalid JSON",
                        },
                        ensure_ascii=False,
                    )
                )
                continue

            if msg.get("type") == "ping":
                await ws.send_text(json.dumps({"type": "pong"}, ensure_ascii=False))
                continue

            if msg.get("type") == "reset":
                await ws.send_text(
                    json.dumps({"type": "reset_ok"}, ensure_ascii=False)
                )
                continue

            if msg.get("type") != "chat":
                continue

            cid = msg.get("id")
            text = (msg.get("text") or "").strip()
            if not isinstance(cid, str) or not cid:
                await ws.send_text(
                    json.dumps(
                        {
                            "type": "error",
                            "id": cid,
                            "text": "Missing id",
                        },
                        ensure_ascii=False,
                    )
                )
                continue

            try:
                reply = await asyncio.to_thread(best_response, text)
                await ws.send_text(
                    json.dumps(
                        {"type": "reply", "id": cid, "text": reply},
                        ensure_ascii=False,
                    )
                )
            except Exception as e:  # pragma: no cover
                await ws.send_text(
                    json.dumps(
                        {
                            "type": "error",
                            "id": cid,
                            "text": str(e),
                        },
                        ensure_ascii=False,
                    )
                )
    except WebSocketDisconnect:
        return


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    port = int(os.environ.get("PORT", "8765"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
