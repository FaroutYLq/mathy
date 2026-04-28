# Mathy

<p align="center">
  <img src="Mathy/Mathy/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Mathy logo">
</p>

[![CI](https://github.com/FaroutYLq/mathy/actions/workflows/ci.yml/badge.svg)](https://github.com/FaroutYLq/mathy/actions/workflows/ci.yml)

A macOS menu bar app that captures math equations from your screen and converts them to LaTeX using [pix2tex/LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR).

## How It Works

1. Press **Cmd+Shift+M** (configurable)
2. Draw a rectangle around a math equation on screen
3. LaTeX is copied to your clipboard instantly

Mathy runs a local Python server that keeps the OCR model loaded in memory, so after the initial ~15s startup, each conversion takes only ~100-300ms.

## Install

1. Download **Mathy.dmg** from [Releases](https://github.com/FaroutYLq/mathy/releases)
2. Open the DMG and drag **Mathy** to **Applications**
3. First launch: right-click Mathy.app > **Open** (required once to bypass Gatekeeper for unsigned apps)

On first launch, Mathy automatically installs the Python OCR engine (pix2tex) and downloads the model (~200MB). A setup window shows progress — no terminal needed.

### Requirements

- **macOS 13+** (Ventura or later)
- **Python 3.8+** (pre-installed on most Macs, or `brew install python3`)

### Build from Source

```bash
cd Mathy
swift build
.build/debug/Mathy
```

Or open in Xcode:

```bash
cd Mathy
open Mathy.xcodeproj
# Build and run (Cmd+R)
```

To build a DMG for distribution:

```bash
./scripts/build_dmg.sh 1.0.0
# Output: build/Mathy.dmg
```

## Usage

Once running, Mathy appears as a **M(y)** icon in the menu bar.

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
│                    │  localhost:8765    │                    │
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
├── .github/workflows/
│   └── ci.yml                  # CI: Swift build + Python server checks
└── scripts/
    ├── setup.sh                # Manual Python env setup (for development)
    ├── build_dmg.sh            # Build DMG for distribution
    └── generate_icons.py       # Generate app icon assets
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
