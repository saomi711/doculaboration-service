import os
import asyncio
import json
import logging
from typing import AsyncGenerator

from celery import Celery
import redis.asyncio as aioredis

# ------------------------------------------------------------------
# 1️⃣  Celery app – must import the same Celery object as the
#     FastAPI side (they share the same broker & backend)
# ------------------------------------------------------------------
celery = Celery(
    "worker",
    broker=os.getenv("CELERY_BROKER_URL", "amqp://guest:guest@rabbitmq:5672//"),
    backend=os.getenv("CELERY_RESULT_BACKEND", "redis://redis:6379/0"),
)
# ------------------------------------------------------------------


@celery.task(name="app.tasks.run_odt")
def run_odt(gsheet_name: str):
    """
    This is executed **in the worker process**.
    It runs the shell script, streams its output to Redis,
    and returns the path to the generated file.
    """
    import redis
    
    # --------------- 1️⃣  Prepare
    # The script writes its output into ./out/ which is a volume
    # mounted on both containers.
    out_dir = os.path.abspath(os.path.join(os.getcwd(), "out"))
    os.makedirs(out_dir, exist_ok=True)

    try:
        # --------------- 2️⃣  Run the script asynchronously
        loop = asyncio.get_event_loop()
        result = loop.run_until_complete(
            _run_script(gsheet_name, out_dir, run_odt.request.id)
        )
        return result  # e.g. {"pdf": "...", "json": "...", "odt": "..."}
    finally:
        # --------------- 3️⃣  Cleanup: Remove processing lock
        try:
            redis_client = redis.from_url("redis://redis:6379/0")
            processing_key = f"processing:{gsheet_name}"
            redis_client.delete(processing_key)
            redis_client.close()
        except Exception as e:
            # Don't fail the task if cleanup fails
            logging.warning(f"Failed to cleanup processing lock for {gsheet_name}: {e}")


# ------------------------------------------------------------------
# Helper – run the shell script and push each stdout line to Redis
# ------------------------------------------------------------------
async def _run_script(gsheet_name: str, out_dir: str, task_id: str) -> dict:
    """
    Returns a dict with the paths of the files that have been
    generated.  Raises an exception on non‑zero return code.
    """
    redis = await aioredis.from_url("redis://redis:6379")
    channel_name = f"task:{task_id}"

    # Create task-specific working directory to avoid conflicts
    task_work_dir = os.path.join("/app", f"work_{task_id}")
    task_out_dir = os.path.join(task_work_dir, "out")
    os.makedirs(task_work_dir, exist_ok=True)
    os.makedirs(task_out_dir, exist_ok=True)
    
    # Copy necessary files to task-specific directory
    import shutil
    shutil.copytree("/app/gsheet-to-json", os.path.join(task_work_dir, "gsheet-to-json"))
    shutil.copytree("/app/json-to-odt", os.path.join(task_work_dir, "json-to-odt"))
    shutil.copytree("/app/json-to-docx", os.path.join(task_work_dir, "json-to-docx"))
    shutil.copy("/app/all-formats-from-gsheet.sh", os.path.join(task_work_dir, "all-formats-from-gsheet.sh"))
    # Make script executable
    os.chmod(os.path.join(task_work_dir, "all-formats-from-gsheet.sh"), 0o755)
    
    # Update config files to use task-specific output directory
    import yaml
    
    # Update gsheet-to-json config
    gsheet_config_path = os.path.join(task_work_dir, "gsheet-to-json", "conf", "config.yml")
    with open(gsheet_config_path, 'r') as f:
        gsheet_config = yaml.safe_load(f)
    gsheet_config['dirs']['output-dir'] = task_out_dir
    with open(gsheet_config_path, 'w') as f:
        yaml.dump(gsheet_config, f)
    
    # Update json-to-odt config
    odt_config_path = os.path.join(task_work_dir, "json-to-odt", "conf", "config.yml")
    with open(odt_config_path, 'r') as f:
        odt_config = yaml.safe_load(f)
    odt_config['dirs']['output-dir'] = task_out_dir
    with open(odt_config_path, 'w') as f:
        yaml.dump(odt_config, f)
    
    # Update json-to-docx config
    docx_config_path = os.path.join(task_work_dir, "json-to-docx", "conf", "config.yml")
    with open(docx_config_path, 'r') as f:
        docx_config = yaml.safe_load(f)
    docx_config['dirs']['output-dir'] = task_out_dir
    with open(docx_config_path, 'w') as f:
        yaml.dump(docx_config, f)

    cmd = f"./all-formats-from-gsheet.sh {gsheet_name}"
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=task_work_dir,  # Use task-specific directory
    )

    # --------------- 3️⃣  Stream stdout line‑by‑line
    async def _publish(line: str):
        await redis.publish(channel_name, line)

    # read stdout line‑by‑line (non‑blocking)
    while True:
        line = await proc.stdout.readline()
        if not line:
            break
        text = line.decode().rstrip()
        # 1) write to the redis channel for SSE
        await _publish(text)
        # 2) also log to worker's console (good for debugging)
        logging.info(f"[{gsheet_name}] {text}")

    # Wait for the process to finish
    await proc.wait()
    # close the PubSub channel (the SSE side will receive EOF)
    await redis.publish(channel_name, "__DONE__")
    await redis.close()

    # --------------- 4️⃣  Check return code
    if proc.returncode != 0:
        # Cleanup task directory on failure
        try:
            shutil.rmtree(task_work_dir)
        except Exception:
            pass
        err_msg = f"Script failed (exit {proc.returncode}) – maybe you forgot to share {gsheet_name} with Spectrum"
        raise RuntimeError(err_msg)

    # --------------- 5️⃣  Copy generated files to shared output directory
    generated_files = {}
    
    try:
        # Copy files from task directory to shared output directory
        task_files = {
            "json": f"{gsheet_name}.json",
            "odt": f"{gsheet_name}.odt",
            "docx": f"{gsheet_name}.docx",
            "pdf": f"{gsheet_name}.odt.pdf"
        }
        
        for file_type, filename in task_files.items():
            src_path = os.path.join(task_out_dir, filename)
            dst_path = os.path.join(out_dir, filename)
            
            if os.path.exists(src_path):
                shutil.copy2(src_path, dst_path)
                generated_files[file_type] = os.path.join("out", filename)
                logging.info(f"[{gsheet_name}] Copied {file_type}: {src_path} -> {dst_path}")
            else:
                logging.warning(f"[{gsheet_name}] Expected file not found: {src_path}")
    
    except Exception as e:
        logging.error(f"[{gsheet_name}] Error copying files: {e}")
        raise RuntimeError(f"Failed to copy generated files: {e}")
    
    finally:
        # --------------- 6️⃣  Cleanup task-specific directory
        try:
            shutil.rmtree(task_work_dir)
            logging.info(f"[{gsheet_name}] Cleaned up task directory: {task_work_dir}")
        except Exception as e:
            logging.warning(f"[{gsheet_name}] Failed to cleanup task directory: {e}")

    return generated_files