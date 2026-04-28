# Mathy

**A macOS menu bar app that captures math equations from your screen and converts them to LaTeX.**

Mathy uses [pix2tex/LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR) to recognize math equations in screen captures and convert them to LaTeX code. It runs entirely on your machine — no cloud services, no API keys.

## How It Works

1. Press **Cmd+Shift+M** (configurable)
2. Draw a rectangle around a math equation on screen
3. LaTeX is copied to your clipboard instantly

Under the hood, Mathy is two components working together:

- **Mathy.app** (Swift/SwiftUI) — a menu bar app that handles screen capture, hotkeys, clipboard, and preview UI
- **mathy-server** (Python/FastAPI) — a local HTTP server wrapping pix2tex for OCR inference

The app keeps the Python server running in the background with the OCR model loaded in memory. After the initial ~15s model load, each conversion takes only ~100-300ms.

## Quick Links

- [Getting Started](getting-started.md) — install, requirements, and usage
- [Architecture](architecture.md) — how the capture pipeline, app lifecycle, and concurrency work
- [Components](onboarding.md) — detailed docs for each subsystem
- [Development](development.md) — build from source, project structure, and dependencies
