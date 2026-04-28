# Mathy

A macOS menu bar app that captures math equations from your screen and converts them to LaTeX using [pix2tex/LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR).

## How It Works

1. Press **Cmd+Shift+M** (configurable)
2. Draw a rectangle around a math equation on screen
3. LaTeX is copied to your clipboard instantly

Mathy runs a local Python server that keeps the OCR model loaded in memory, so after the initial ~15s startup, each conversion takes only ~100-300ms.

## Getting Started

### Requirements

- **macOS 13+** (Ventura or later)
- **Python 3.8+** (pre-installed on most Macs, or `brew install python3`)

### Install & Run

```bash
cd Mathy
swift build
.build/debug/Mathy
```

That's it. On first launch, Mathy automatically:
1. Creates a Python environment
2. Installs the OCR engine (pix2tex) and dependencies
3. Downloads the model (~200MB on first run)
4. Starts the server

A setup window shows progress. Once complete, click **Start Using Mathy** and you're ready to go.

### Or build with Xcode

```bash
cd Mathy
open Mathy.xcodeproj
```

Then build and run (Cmd+R).

## Usage

Once running, Mathy appears as an **f(x)** icon in the menu bar.

- **Cmd+Shift+M** — Capture a screen region and convert to LaTeX
- Click the menu bar icon to see server status, recent history, and settings
- Converted LaTeX is automatically copied to your clipboard
- A preview popup shows the captured image alongside rendered LaTeX

### Settings

- Custom capture hotkey
- Auto-copy to clipboard toggle
- Launch at login
- Reinstall OCR engine (if you experience issues)

## Architecture

```
┌────────────────────┐                    ┌────────────────────┐
│     Mathy.app      │       HTTP         │    mathy-server    │
│   (Swift/SwiftUI)  │ <──────────────>   │  (Python/FastAPI)  │
│                    │  localhost:8765     │                    │
│  - Menu bar UI     │                    │  - pix2tex model   │
│  - Screen capture  │  POST /predict     │  - Loaded once     │
│  - Hotkey          │  ──────────────>   │  - Fast inference  │
│  - KaTeX preview   │                    │                    │
│  - History         │  {"latex": "..."}  │                    │
│                    │  <──────────────   │                    │
└────────────────────┘                    └────────────────────┘
```

The app manages the server automatically:
- Creates and maintains a Python venv at `~/Library/Application Support/Mathy/venv/`
- Launches the server on startup, polls `/health` until the model is loaded
- Auto-restarts on crash (up to 3 attempts with exponential backoff)
- Terminates the server on app quit

## Project Structure

```
mathy/
├── Mathy/                      # Swift macOS app
│   ├── Package.swift           # SPM config
│   └── Mathy/
│       ├── MathyApp.swift      # @main entry point (MenuBarExtra)
│       ├── App/                # AppState, HotkeyManager, PythonEnvironmentManager
│       ├── Capture/            # Screen region capture
│       ├── OCR/                # HTTP client + server process manager
│       ├── Views/              # MenuBar, Onboarding, Preview, Settings
│       ├── Models/             # ConversionRecord, HistoryStore
│       ├── Utilities/          # Clipboard, Constants
│       └── Resources/          # KaTeX bundle, HTML template, server script, requirements.txt
├── server/
│   ├── mathy_server.py         # FastAPI server wrapping pix2tex
│   └── requirements.txt
└── scripts/
    └── setup.sh                # Manual Python env setup (for development)
```

## Development

For development, you can also set up the Python server manually:

```bash
./scripts/setup.sh          # Creates .venv, installs deps
source .venv/bin/activate
python server/mathy_server.py
```

Test endpoints:
```bash
curl http://127.0.0.1:8765/health
curl -X POST -F "file=@test.png" http://127.0.0.1:8765/predict
```

## License

See [LICENSE](LICENSE).
