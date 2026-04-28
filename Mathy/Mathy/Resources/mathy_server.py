#!/usr/bin/env python3
"""Mathy OCR Server — FastAPI wrapper around pix2tex LaTeX OCR."""

import asyncio
import io
import logging
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("mathy-server")

model = None
model_loaded = False

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
INFERENCE_TIMEOUT = 30  # seconds


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model, model_loaded
    logger.info("Loading pix2tex model (this may take 10-15s on first run)...")
    try:
        from pix2tex.cli import LatexOCR
        model = LatexOCR()
        model_loaded = True
        logger.info("Model loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        model_loaded = False
    yield
    logger.info("Shutting down mathy-server.")


app = FastAPI(title="Mathy OCR Server", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": model_loaded}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not model_loaded or model is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    try:
        contents = await file.read()
        if len(contents) > MAX_UPLOAD_BYTES:
            raise HTTPException(
                status_code=413,
                detail=f"File too large (max {MAX_UPLOAD_BYTES // 1024 // 1024} MB)",
            )
        img = Image.open(io.BytesIO(contents)).convert("RGB")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")

    try:
        loop = asyncio.get_event_loop()
        latex = await asyncio.wait_for(
            loop.run_in_executor(None, model, img),
            timeout=INFERENCE_TIMEOUT,
        )
        return {"latex": latex}
    except asyncio.TimeoutError:
        logger.error("Prediction timed out")
        raise HTTPException(status_code=504, detail="Prediction timed out")
    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise HTTPException(status_code=500, detail="Prediction failed")


if __name__ == "__main__":
    import uvicorn

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    if not (1 <= port <= 65535):
        print(f"Error: port {port} out of range (1-65535)", file=sys.stderr)
        sys.exit(1)
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="info")
