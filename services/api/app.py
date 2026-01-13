from fastapi import FastAPI, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os
import random
import time

app = FastAPI()

REQS = Counter("http_requests_total", "Total HTTP requests", ["path", "method", "status"])
LAT = Histogram("http_request_duration_seconds", "Request latency", ["path"])

ERROR_RATE = float(os.getenv("ERROR_RATE", "0.0"))   # 0.0..1.0
LATENCY_MS = int(os.getenv("LATENCY_MS", "0"))       # add fixed latency
JITTER_MS = int(os.getenv("JITTER_MS", "0"))         # add random jitter up to this

def maybe_sleep(path: str):
    base = LATENCY_MS / 1000.0
    jitter = random.random() * (JITTER_MS / 1000.0) if JITTER_MS > 0 else 0
    if base + jitter > 0:
        time.sleep(base + jitter)

@app.get("/healthz")
def healthz():
    REQS.labels("/healthz", "GET", "200").inc()
    return {"ok": True}

@app.get("/")
def root():
    start = time.time()
    try:
        maybe_sleep("/")
        REQS.labels("/", "GET", "200").inc()
        return {"service": "api", "status": "ok"}
    finally:
        LAT.labels("/").observe(time.time() - start)

@app.get("/error")
def error():
    start = time.time()
    try:
        maybe_sleep("/error")
        if random.random() < ERROR_RATE:
            REQS.labels("/error", "GET", "500").inc()
            return Response(content="injected error", status_code=500)
        REQS.labels("/error", "GET", "200").inc()
        return {"ok": True, "error_rate": ERROR_RATE}
    finally:
        LAT.labels("/error").observe(time.time() - start)

@app.get("/latency")
def latency(ms: int = 250):
    start = time.time()
    try:
        time.sleep(ms / 1000.0)
        REQS.labels("/latency", "GET", "200").inc()
        return {"slept_ms": ms}
    finally:
        LAT.labels("/latency").observe(time.time() - start)

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

