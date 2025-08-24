import os
import uuid
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse, FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from celery.result import AsyncResult

from .celery_app import celery

# ------------------ FastAPI ------------------
app = FastAPI()

# Health check endpoint
@app.get("/")
async def root():
    return {"message": "Doculaboration API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "doculaboration-api"}

origins = [
    "http://localhost.tiangolo.com",
    "https://localhost.tiangolo.com",
    "http://localhost",
    "http://localhost:8080",
    "http://localhost:3000",  # React development server
    "http://127.0.0.1:3000",
    "*"  # Allow all origins for development
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=False,  # Set to False when using allow_origins=["*"]
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# ------------------------------------------------------------
# 1️⃣  Create a Celery task (the heavy shell script)
# ------------------------------------------------------------
@app.post("/process/{gsheet_name}")
async def create_task(gsheet_name: str):
    """
    Fire‑and‑forget: create a Celery job, return a task ID.
    Check for existing running tasks to prevent duplicates.
    """
    import redis
    
    # Check if there's already a running task for this gsheet
    redis_client = redis.from_url("redis://redis:6379/0")
    
    # Look for existing running tasks
    existing_task_key = f"processing:{gsheet_name}"
    existing_task_id = redis_client.get(existing_task_key)
    
    if existing_task_id:
        # Check if the existing task is still running
        existing_result = AsyncResult(existing_task_id.decode(), app=celery)
        if existing_result.state in ['PENDING', 'STARTED']:
            return JSONResponse({
                "task_id": existing_task_id.decode(),
                "message": "Task already running for this document"
            })
    
    # Create new task
    job = celery.send_task("app.tasks.run_odt", args=[gsheet_name])
    
    # Mark this document as being processed
    redis_client.setex(existing_task_key, 3600, job.id)  # Expire in 1 hour
    
    return JSONResponse({"task_id": job.id})


# ------------------------------------------------------------
# 2️⃣  Poll job status (used by frontend, CLI or UI)
# ------------------------------------------------------------
@app.get("/status/{task_id}")
def get_status(task_id: str):
    """
    Returns JSON:
    {
        "status": "PENDING|STARTED|SUCCESS|FAILURE",
        "result": ... (optional)
    }
    """
    result = AsyncResult(task_id, app=celery)
    payload = {"status": result.state}
    if result.state == "SUCCESS":
        # result.result is whatever the task returns (file_path)
        payload["result"] = result.result
    elif result.state == "FAILURE":
        payload["error"] = str(result.result)  # exception string
    return JSONResponse(payload)


# ------------------------------------------------------------
# 3️⃣  Stream stdout from the worker (SSE)
# ------------------------------------------------------------
@app.get("/stream/{task_id}")
async def stream_output(task_id: str):
    """
    Connect with EventSource (Server‑Sent Events).  
    The worker publishes each line on a Redis PubSub channel
    named `task:<task_id>`.  Here we subscribe and push
    the lines as SSE.
    """
    async def event_generator():
        import aioredis

        redis = await aioredis.from_url("redis://redis:6379")
        channel = f"task:{task_id}"
        
        # Create pubsub and subscribe to channel
        pubsub = redis.pubsub()
        await pubsub.subscribe(channel)
        
        try:
            async for message in pubsub.listen():
                if message['type'] == 'message':
                    line = message['data'].decode()
                    if line == "__DONE__":
                        break
                    # SSE format
                    yield f"data: {line}\n\n"
                elif message['type'] == 'subscribe':
                    # Initial subscription confirmation, ignore
                    continue
        finally:
            await pubsub.unsubscribe(channel)
            await pubsub.close()
            await redis.close()

    # Content-Type tells the browser this is an EventSource
    return StreamingResponse(event_generator(),
                              media_type="text/event-stream")


# ------------------------------------------------------------
# 4️⃣  Serve the generated artefacts
# ------------------------------------------------------------
def _file_path(gsheet_name: str, ext: str) -> str:
    return os.path.join("out", f"{gsheet_name}{ext}")

@app.get("/pdf/{gsheet_name}/download")
def download_pdf(gsheet_name: str):
    path = _file_path(gsheet_name, ".odt.pdf")
    return FileResponse(path,
                          media_type="application/pdf",
                          filename=f"{gsheet_name}.pdf")

@app.get("/json/{gsheet_name}/download")
def download_json(gsheet_name: str):
    path = _file_path(gsheet_name, ".json")
    return FileResponse(path,
                          media_type="application/json",
                          filename=f"{gsheet_name}.json")

@app.get("/odt/{gsheet_name}/download")
def download_odt(gsheet_name: str):
    path = _file_path(gsheet_name, ".odt")
    return FileResponse(path,
                          media_type="application/vnd.oasis.opendocument.text",
                          filename=f"{gsheet_name}.odt")

@app.get("/docx/{gsheet_name}/download")
def download_docx(gsheet_name: str):
    path = _file_path(gsheet_name, ".docx")
    return FileResponse(path,
                          media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                          filename=f"{gsheet_name}.docx")