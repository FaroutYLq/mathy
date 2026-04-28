# Server Management

The Python server is managed entirely by the Swift app. Users never need to interact with it directly.

## ServerManager

`ServerManager` (`@MainActor`) manages the Python server process lifecycle. It tracks four states:

| Status | Meaning |
|---|---|
| `stopped` | Server is not running |
| `starting` | Server process launched, waiting for model to load |
| `running` | Model loaded, ready to accept predictions |
| `error` | Server crashed too many times |

## Startup Sequence

1. **Check for existing server:** GET `http://127.0.0.1:8765/health` — if it responds with `model_loaded: true`, skip launching (server may be running from a previous session or manual start)
2. **Find Python binary** (resolution order):
    1. Managed venv: `~/Library/Application Support/Mathy/venv/bin/python3`
    2. UserDefaults `pythonPath` key (user override from settings)
    3. Project `.venv/bin/python3` (developer workflow)
    4. `/opt/homebrew/bin/python3` (Homebrew on Apple Silicon)
    5. `/usr/local/bin/python3` (Homebrew on Intel)
    6. `/usr/bin/python3` (macOS system)
    7. `which python3` (runs off main thread)
3. **Find server script:** Bundled copy in `Bundle.main`, or `server/mathy_server.py` in the project root
4. **Launch process:** `python3 mathy_server.py 8765`
5. **Start health polling:** Timer fires every 1 second, GET `/health`, waiting for `model_loaded == true`

## Health Polling

Once the server process is launched, `ServerManager` polls the health endpoint every second:

```json
GET /health
Response: {"status": "ok", "model_loaded": true}
```

The `model_loaded` field starts as `false` while pix2tex loads its model weights (~10-15s on first run). Once it becomes `true`, `ServerManager` sets status to `.running` and cancels the polling timer.

## Auto-Restart

If the server process terminates unexpectedly, the `Process.terminationHandler` triggers auto-restart with exponential backoff:

| Attempt | Delay |
|---|---|
| 1st | 2 seconds |
| 2nd | 4 seconds |
| 3rd | 6 seconds |
| 4th+ | Gives up, sets status to `.error` |

The restart counter resets when the server successfully reaches `.running` status.

## Shutdown

On app quit, `AppState.deinit` calls `serverManager.stop()`:

1. Invalidates the health polling timer
2. Calls `process.terminate()` on the child process
3. Sets status to `.stopped`

## Process I/O

- **stdout** is redirected to `/dev/null` (not needed by the app)
- **stderr** is captured via a `Pipe` with `readabilityHandler` and logged to console as `[mathy-server]` prefixed lines
- The `readabilityHandler` pattern prevents pipe buffer deadlocks

## Project Root Resolution

To find the server script and project `.venv` during development, `ServerManager` resolves the project root by:

1. Checking the `SOURCE_ROOT` environment variable (set by Xcode)
2. Walking up from `Bundle.main.bundleURL` up to 8 parent directories, looking for `server/mathy_server.py`

---

# Python Server (mathy_server.py)

The server is a FastAPI application served by uvicorn, bound to `127.0.0.1:8765` (localhost only — not exposed to the network).

## Model Loading

Model loading happens at startup in a FastAPI `lifespan` context manager:

```python
@asynccontextmanager
async def lifespan(app):
    model = LatexOCR()          # Loads pix2tex model
    model_loaded = True
    yield
```

- Imports `pix2tex.cli.LatexOCR` and instantiates it
- First run downloads model weights (~200MB) to the pix2tex cache
- Subsequent launches reuse cached weights (~10-15s load time)
- If loading fails, `model_loaded` stays `False` and `/predict` returns 503

## API Endpoints

### `GET /health`

Returns server status. Used by `ServerManager` for health polling.

```json
{"status": "ok", "model_loaded": true}
```

### `POST /predict`

Accepts an image file and returns recognized LaTeX.

**Request:** multipart/form-data with a `file` field containing the image (PNG, JPEG, etc.)

**Response (200):**
```json
{"latex": "\\frac{1}{2}"}
```

**Error responses:**

| Code | Condition | Body |
|---|---|---|
| 400 | Image couldn't be decoded | `{"detail": "Invalid image: ..."}` |
| 503 | Model not loaded yet | `{"detail": "Model not loaded yet"}` |
| 500 | Prediction failed | `{"detail": "Prediction failed: ..."}` |

**Prediction flow:**

1. Read uploaded file bytes
2. Open with PIL (`Image.open`), convert to RGB
3. Call `model(img)` — pix2tex inference
4. Return LaTeX string

## Running Manually

For development, the server can be started independently:

```bash
# Using the project venv
source .venv/bin/activate
python server/mathy_server.py

# Or with a custom port
python server/mathy_server.py 9000
```

Test endpoints:

```bash
curl http://127.0.0.1:8765/health
curl -X POST -F "file=@equation.png" http://127.0.0.1:8765/predict
```
