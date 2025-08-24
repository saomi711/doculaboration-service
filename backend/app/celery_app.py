import os
from celery import Celery

# -------------------  ENV  -------------------
# These values are injected via docker‑compose env variables
BROKER_URL = os.getenv(
    "CELERY_BROKER_URL", "amqp://guest:guest@rabbitmq:5672//"
)  # RabbitMQ
RESULT_BACKEND = os.getenv(
    "CELERY_RESULT_BACKEND", "redis://redis:6379/0"
)  # Redis

# ----------------------------------------------------
# Celery app (no tasks defined here – only the worker
# module will import this object)
# ----------------------------------------------------
celery = Celery(
    "worker",
    broker=BROKER_URL,
    backend=RESULT_BACKEND,
)
# optional: make Celery use JSON (the default is fine)