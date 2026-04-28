# Mathy

A macOS menu bar app that captures math equations from your screen and converts them to LaTeX using [pix2tex/LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR).

## How It Works

1. Press **Cmd+Shift+M** (configurable)
2. Draw a rectangle around a math equation on screen
3. LaTeX is copied to your clipboard instantly

Mathy runs a local Python server that keeps the OCR model loaded in memory, so after the initial ~15s startup, each conversion takes only ~100-300ms.

## Architecture

```
┌──────────────────┐       HTTP        ┌──────────────────┐
│   Mathy.app      │ ◄──────────────►  │  mathy-server    │
│   (Swift/SwiftUI)│   localhost:8765   │  (Python/FastAPI) │
│                  │                    │                  │
│  - Menu bar UI   │  POST /predict    │  - pix2tex model │
│  - Screen capture│  ──────────────►  │  - Loaded once   │
│  - Hotkey        │                    │  - Fast inference│
│  - KaTeX preview │  {"latex": "..."}  │                  │
│  - History       │  ◄────────────── │                  │
└──────────────────┘                    └──────────────────┘
```

## Project Structure

```
mathy/
├── Mathy/                      # Swift macOS app
│   ├── Package.swift           # SPM config
│   ├── project.yml             # XcodeGen spec
│   └── Mathy/
│       ├── MathyApp.swift      # @main entry point (MenuBarExtra)
│       ├── App/                # AppState, HotkeyManager
│       ├── Capture/            # Screen region capture
│       ├── OCR/                # HTTP client + server process manager
│       ├── Views/              # MenuBar, Preview, Settings, Setup
│       ├── Models/             # ConversionRecord, HistoryStore
│       ├── Utilities/          # Clipboard, Constants
│       └── Resources/          # KaTeX bundle, HTML template
├── server/
│   ├── mathy_server.py         # FastAPI server wrapping pix2tex
│   └── requirements.txt
└── scripts/
    └── setup.sh                # Python environment setup
```

## Requirements

- **macOS 13+** (Ventura or later)
- **Python 3.8+**
- **Xcode 15+** (for building the app, or use `swift build` with Command Line Tools)

## Setup

### 1. Python Server

```bash
# Create venv and install dependencies (pix2tex, fastapi, uvicorn, etc.)
./scripts/setup.sh
```

Or manually:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r server/requirements.txt
```

### 2. Test the Server

```bash
source .venv/bin/activate
python server/mathy_server.py
```

The first run downloads the pix2tex model (~200MB). Once you see `Model loaded successfully`, test it:

```bash
# Health check
curl http://127.0.0.1:8765/health

# OCR prediction (replace test.png with any math equation image)
curl -X POST -F "file=@test.png" http://127.0.0.1:8765/predict
```

### 3. Build the App

**Option A: Swift Package Manager (command line)**

```bash
cd Mathy
swift build
.build/debug/Mathy
```

**Option B: Xcode (recommended)**

```bash
brew install xcodegen
cd Mathy
xcodegen generate
open Mathy.xcodeproj
```

Then build and run from Xcode (Cmd+R).

## Usage

Once running, Mathy appears as an **f(x)** icon in the menu bar.

- **Cmd+Shift+M** — Capture a screen region and convert to LaTeX
- Click the menu bar icon to see server status, recent history, and settings
- Converted LaTeX is automatically copied to your clipboard
- A preview popup shows the captured image alongside rendered LaTeX

### Settings

- Custom hotkey
- Python interpreter path
- Server port
- Auto-copy to clipboard toggle
- Launch at login

## Server API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server status and model load state |
| `/predict` | POST | Multipart image upload, returns `{"latex": "..."}` |

## How the App Manages the Server

The app automatically launches and monitors the Python server:

- Detects Python from common paths (`/opt/homebrew/bin/python3`, `/usr/local/bin/python3`, project `.venv`, or user-configured path)
- Polls `/health` until the model is loaded
- Auto-restarts on crash (up to 3 attempts with exponential backoff)
- Terminates the server on app quit

## License

See [LICENSE](LICENSE).
