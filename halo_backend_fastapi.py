"""
HALO Backend (FastAPI)
Single-file prototype: halo_backend_fastapi.py
"""

from fastapi import FastAPI, HTTPException, Request, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware # ADD THIS LINE
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import firebase_admin
from firebase_admin import credentials, firestore, auth, messaging
import os
import uvicorn
import asyncio
from transformers import AutoTokenizer, AutoModelForSequenceClassification, pipeline
import datetime
import uuid

# -------------------- CONFIG --------------------
FIREBASE_SERVICE_ACCOUNT = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "./serviceAccountKey.json")
NLP_MODEL_NAME = os.getenv("NLP_MODEL_NAME", "distilbert-base-uncased-finetuned-sst-2-english")

# -------------------- FIREBASE INIT --------------------
if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# -------------------- NLP MODEL LOAD --------------------
# We use a text classification pipeline (DistilBERT / RoBERTa) to detect toxicity / suspicious text.
nlp_tokenizer = AutoTokenizer.from_pretrained(NLP_MODEL_NAME)
nlp_model = AutoModelForSequenceClassification.from_pretrained(NLP_MODEL_NAME)
text_pipe = pipeline("text-classification", model=nlp_model, tokenizer=nlp_tokenizer)

# -------------------- FASTAPI APP --------------------
app = FastAPI(title="HALO Backend (Prototype)")

# ADD THIS BLOCK TO FIX CORS ISSUES
origins = ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------- Pydantic Schemas --------------------
class RegisterChild(BaseModel):
    uid: str
    name: str
    dob: Optional[str]
    address: Optional[str]
    blood_group: Optional[str]
    parent_uid: str
    parent_contacts: List[str]

class AppUsageItem(BaseModel):
    package_name: str
    duration_seconds: int
    timestamp: Optional[str]

class JournalEntry(BaseModel):
    uid: str
    date: Optional[str]
    good: List[str]
    bad: List[str]

class Reminder(BaseModel):
    uid: str
    type: str
    interval_minutes: Optional[int]
    at_time: Optional[str]

class MessageEvent(BaseModel):
    child_uid: str
    from_number: str
    message_text: str
    app: Optional[str]
    timestamp: Optional[str]

class LocationUpdate(BaseModel):
    uid: str
    lat: float
    lng: float
    ts: Optional[str]

class SOSRequest(BaseModel):
    uid: str
    lat: Optional[float]
    lng: Optional[float]
    note: Optional[str]

class ReportText(BaseModel):
    child_uid: str
    text_content: str

class UpdateAlert(BaseModel):
    acknowledged: bool
    
# -------------------- Utility functions --------------------

def verify_firebase_token(id_token: str) -> Dict[str, Any]:
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid auth token: {e}")

def send_push_to_token(token: str, title: str, body: str, data: dict = None):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
        data=data or {}
    )
    try:
        resp = messaging.send(message)
        return resp
    except Exception as e:
        print("FCM error:", e)
        return None

def detect_phishing(text: str) -> bool:
    suspicious_keywords = ["click here", "login", "verify", "password", "bank", "account", "urgent", "verify your", "update your", "confirm your"]
    shortened_domains = ["bit.ly", "tinyurl", "t.co", "goo.gl"]
    lower = text.lower()
    if any(k in lower for k in suspicious_keywords):
        return True
    for d in shortened_domains:
        if d in lower:
            return True
    if "http" in lower and "@" in lower:
        return True
    return False

def analyze_text(text: str) -> Dict[str, Any]:
    try:
        results = text_pipe(text[:512])
        return {"pipe": results}
    except Exception as e:
        print("NLP error", e)
        return {"error": str(e)}

# -------------------- Auth / Onboarding --------------------
@app.post("/child/register")
async def register_child(payload: RegisterChild):
    doc_ref = db.collection("children").document(payload.uid)
    doc_ref.set({
        "name": payload.name,
        "dob": payload.dob,
        "address": payload.address,
        "blood_group": payload.blood_group,
        "parent_uid": payload.parent_uid,
        "parent_contacts": payload.parent_contacts,
        "created_at": firestore.SERVER_TIMESTAMP,
    })
    return {"ok": True, "uid": payload.uid}

@app.post("/parent/register")
async def register_parent(request: Request):
    body = await request.json()
    uid = body.get("uid")
    if not uid:
        raise HTTPException(status_code=400, detail="uid required")
    db.collection("parents").document(uid).set({"meta": body, "created_at": firestore.SERVER_TIMESTAMP})
    return {"ok": True}

# -------------------- Child endpoints --------------------
@app.post("/child/app_usage")
async def push_app_usage(item: AppUsageItem):
    ts = item.timestamp or datetime.datetime.utcnow().isoformat()
    doc = {
        "package": item.package_name,
        "duration_seconds": item.duration_seconds,
        "timestamp": ts,
    }
    db.collection("app_usage").add(doc)
    return {"ok": True}

@app.post("/child/journal")
async def save_journal(entry: JournalEntry):
    date = entry.date or datetime.date.today().isoformat()
    doc = {"good": entry.good, "bad": entry.bad, "date": date, "uid": entry.uid, "created_at": firestore.SERVER_TIMESTAMP}
    db.collection("journals").add(doc)
    return {"ok": True}

@app.post("/child/reminder")
async def set_reminder(rem: Reminder):
    doc = rem.dict()
    doc["created_at"] = firestore.SERVER_TIMESTAMP
    db.collection("reminders").add(doc)
    return {"ok": True, "message": "Reminder saved. Use Cloud Function or server scheduler to trigger."}

@app.post("/child/report_message")
async def handle_message(event: MessageEvent, background_tasks: BackgroundTasks):
    ts = event.timestamp or datetime.datetime.utcnow().isoformat()
    doc = {
        "child_uid": event.child_uid,
        "from": event.from_number,
        "text": event.message_text,
        "app": event.app,
        "timestamp": ts,
    }
    db.collection("messages").add(doc)
    suspicious = detect_phishing(event.message_text)
    analysis = analyze_text(event.message_text)

    alert_doc = {
        "child_uid": event.child_uid,
        "type": "message",
        "from": event.from_number,
        "text": event.message_text,
        "suspicious": suspicious,
        "analysis": analysis,
        "created_at": firestore.SERVER_TIMESTAMP,
        "acknowledged": False,
    }
    alert_ref = db.collection("alerts").add(alert_doc)
    child_snapshot = db.collection("children").document(event.child_uid).get()
    if child_snapshot.exists:
        child_data = child_snapshot.to_dict()
        parent_uid = child_data.get("parent_uid")
        if parent_uid:
            parent_doc = db.collection("parents").document(parent_uid).get()
            if parent_doc.exists:
                parent_data = parent_doc.to_dict().get("meta", {})
                fcm_token = parent_data.get("fcm_token")
                if fcm_token:
                    background_tasks.add_task(send_push_to_token, fcm_token, "New message alert", f"From {event.from_number}: {event.message_text}", {"child_uid": event.child_uid})
    return {"ok": True, "suspicious": suspicious}
    
@app.post("/child/report_text")
async def report_text(payload: ReportText, background_tasks: BackgroundTasks):
    suspicious = detect_phishing(payload.text_content)
    analysis = analyze_text(payload.text_content)
    
    alert_doc = {
        "child_uid": payload.child_uid,
        "type": "reported_text",
        "text": payload.text_content,
        "suspicious": suspicious,
        "analysis": analysis,
        "created_at": firestore.SERVER_TIMESTAMP,
        "acknowledged": False,
    }
    alert_ref = db.collection("alerts").add(alert_doc)
    
    child_snapshot = db.collection("children").document(payload.child_uid).get()
    if child_snapshot.exists:
        child_data = child_snapshot.to_dict()
        parent_uid = child_data.get("parent_uid")
        if parent_uid:
            parent_doc = db.collection("parents").document(parent_uid).get()
            if parent_doc.exists:
                parent_data = parent_doc.to_dict().get("meta", {})
                fcm_token = parent_data.get("fcm_token")
                if fcm_token:
                    background_tasks.add_task(send_push_to_token, fcm_token, "Child Reported Text", f"Your child reported: {payload.text_content}", {"child_uid": payload.child_uid})

    return {"ok": True, "suspicious": suspicious}

@app.post("/child/sos")
async def child_sos(req: SOSRequest):
    sos_id = str(uuid.uuid4())
    doc = {"uid": req.uid, "lat": req.lat, "lng": req.lng, "note": req.note, "ts": firestore.SERVER_TIMESTAMP, "sos_id": sos_id}
    db.collection("sos_requests").add(doc)

    child_snapshot = db.collection("children").document(req.uid).get()
    if child_snapshot.exists:
        child_data = child_snapshot.to_dict()
        parent_uid = child_data.get("parent_uid")
        if parent_uid:
            parent_doc = db.collection("parents").document(parent_uid).get()
            if parent_doc.exists:
                parent_meta = parent_doc.to_dict().get("meta", {})
                fcm_token = parent_meta.get("fcm_token")
                if fcm_token:
                    send_push_to_token(fcm_token, "SOS Alert", f"Child {child_data.get('name')} sent SOS. Location: {req.lat},{req.lng}")
    return {"ok": True, "sos_id": sos_id}

# -------------------- Parent endpoints --------------------
@app.get("/parent/find_child/{child_uid}")
async def find_child_location(child_uid: str):
    docs = db.collection("locations").where("uid", "==", child_uid).order_by("ts", direction=firestore.Query.DESCENDING).limit(1).stream()
    latest = None
    for d in docs:
        latest = d.to_dict()
    if not latest:
        raise HTTPException(status_code=404, detail="No location found for child")
    return {"ok": True, "location": latest}

@app.get("/parent/alerts/{parent_uid}")
async def parent_alerts(parent_uid: str):
    children = db.collection("children").where("parent_uid", "==", parent_uid).stream()
    child_uids = [c.id for c in children]

    # FIX: Add this check to prevent 500 Internal Server Error
    if not child_uids:
        return {"ok": True, "alerts": []}
        
    alerts_query = db.collection("alerts").where("child_uid", "in", child_uids).order_by("created_at", direction=firestore.Query.DESCENDING).limit(50).stream()
    
    out = [{"id": a.id, **a.to_dict()} for a in alerts_query]
    
    return {"ok": True, "alerts": out}

@app.put("/parent/alert/{alert_id}")
async def acknowledge_alert(alert_id: str, payload: UpdateAlert):
    doc_ref = db.collection("alerts").document(alert_id)
    doc_snapshot = doc_ref.get()
    
    if not doc_snapshot.exists:
        raise HTTPException(status_code=404, detail="Alert not found")
        
    try:
        doc_ref.update({"acknowledged": payload.acknowledged})
        return {"ok": True, "message": f"Alert {alert_id} acknowledged status updated."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update alert: {e}")

# -------------------- Location update endpoint (used by child device) --------------------
@app.post("/child/location")
async def update_location(loc: LocationUpdate):
    ts = loc.ts or datetime.datetime.utcnow().isoformat()
    doc = {"uid": loc.uid, "lat": loc.lat, "lng": loc.lng, "ts": ts}
    db.collection("locations").add(doc)
    return {"ok": True}

# -------------------- App usage summary for child (returns data + emoji) --------------------
@app.get("/child/usage_summary/{uid}")
async def usage_summary(uid: str):
    one_day_ago = datetime.datetime.utcnow() - datetime.timedelta(days=1)
    docs = db.collection("app_usage").where("timestamp", ">=", one_day_ago.isoformat()).stream()
    usage = {}
    for d in docs:
        data = d.to_dict()
        package = data.get("package")
        dur = int(data.get("duration_seconds", 0))
        usage[package] = usage.get(package, 0) + dur
    total = sum(usage.values())
    summary = []
    for pkg, sec in usage.items():
        pct = sec / total if total > 0 else 0
        bars = int(pct * 20)
        emoji = "😃" if pct < 0.25 else ("😐" if pct < 0.5 else "😟")
        summary.append({"package": pkg, "seconds": sec, "bar": "█" * bars, "emoji": emoji})
    return {"ok": True, "total_seconds": total, "summary": summary}

# -------------------- Flashcards (simple interactive content) --------------------
@app.get("/child/flashcards")
async def flashcards():
    cards = [
        {"q": "Is it safe to click links from strangers?", "a": "No"},
        {"q": "Should you share your password?", "a": "No"},
        {"q": "If someone asks for your location, what should you do?", "a": "Ask a parent"},
    ]
    return {"ok": True, "cards": cards}

# -------------------- Simple moderation for images (placeholder) --------------------
@app.post("/moderate/image")
async def moderate_image():
    raise HTTPException(status_code=501, detail="Image moderation not implemented in prototype. Use a cloud moderation API or on-device model.")

# -------------------- Health check --------------------
@app.get("/health")
async def health():
    return {"ok": True, "time": datetime.datetime.utcnow().isoformat()}

# -------------------- If run directly --------------------
if __name__ == "__main__":
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    FIREBASE_SERVICE_ACCOUNT_PATH = os.path.join(BASE_DIR, "serviceAccountKey.json")
    FIREBASE_SERVICE_ACCOUNT = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", FIREBASE_SERVICE_ACCOUNT_PATH)
    NLP_MODEL_NAME = os.getenv("NLP_MODEL_NAME", "distilbert-base-uncased-finetuned-sst-2-english")

    if not firebase_admin._apps:
        try:
            cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
            firebase_admin.initialize_app(cred)
            print("Firebase app initialized successfully.")
        except Exception as e:
            print(f"Error initializing Firebase: {e}")
            print(f"Attempted to load credentials from: {FIREBASE_SERVICE_ACCOUNT}")

    db = firestore.client()

    uvicorn.run("halo_backend_fastapi:app", host="0.0.0.0", port=8000, reload=True)