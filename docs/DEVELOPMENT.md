# Mathy — Technical Documentation

## Overview

Mathy is a macOS menu bar app for converting screen-captured math equations to LaTeX. It consists of two components:

- **Mathy.app** — a Swift/SwiftUI menu bar app that handles screen capture, hotkeys, clipboard, and UI
- **mathy-server** — a Python/FastAPI HTTP server wrapping [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR) for OCR inference

They communicate over `localhost:8765`. The app manages the server's full lifecycle — launching, health-checking, auto-restarting, and terminating it.

---

## How a Capture Works

When the user presses **Cmd+Shift+M**, the following pipeline executes:

```
KeyboardShortcuts.onKeyUp
  → AppState.startCapture()
    → ScreenCaptureManager.captureRegion()          # AppleScript → screencapture -i -s
      → saves PNG to ~/Library/Application Support/Mathy/images/
    → OCRService.predict(imageURL)                   # POST multipart/form-data to /predict
      → server runs pix2tex model on image
      → returns {"latex": "\\frac{1}{2}"}
    → ClipboardManager.copy(latex)                   # NSPasteboard.general
    → HistoryStore.add(record)                       # Prepend to history.json (max 100)
    → PreviewPopupView                               # Floating NSPanel with image + KaTeX render
```

The entire flow is `async` and runs on `@MainActor`, with blocking operations (process launches, network requests) dispatched to background threads.

---

## App Lifecycle

**Entry point:** `MathyApp.swift` — a SwiftUI `App` with two scenes:
- `MenuBarExtra("Mathy", image: "MenuBarIcon")` — the menu bar dropdown
- `Settings { SettingsView }` — system settings window

**AppState** (`@MainActor ObservableObject`) is the central coordinator. On init it:
1. Registers the capture hotkey via KeyboardShortcuts
2. Subscribes to server status changes via Combine
3. Checks if a managed Python venv already exists
   - If ready → starts the server
   - If not → shows the onboarding window

---

## Onboarding & Python Environment

On first launch (or after "Reinstall OCR Engine"), `PythonEnvironmentManager` runs an automated setup:

| Stage | What happens |
|---|---|
| **checkingPython** | Searches for Python 3 binary: Homebrew → system paths → `which python3` |
| **creatingVenv** | Runs `python3 -m venv ~/Library/Application Support/Mathy/venv/` |
| **installingDeps** | Upgrades pip, then `pip install -r requirements.txt` (bundled). Fallback: installs `pix2tex fastapi uvicorn[standard] python-multipart Pillow` directly. **10-minute timeout.** |
| **verifying** | Runs `python3 -c "import pix2tex; print('OK')"` in the new venv |
| **ready** | Setup complete — server can start |

The onboarding UI (`OnboardingView` in `SetupView.swift`) shows a 3-step progress indicator and a collapsible log viewer with real-time output from pip.

**Process execution** uses `withCheckedContinuation` + `DispatchQueue.global()` to avoid blocking the main thread. All process helpers drain stdout/stderr via `readabilityHandler` (prevents deadlock when child output exceeds the 64KB pipe buffer). Streaming output collection is protected by `NSLock`.

---

## Server Management

`ServerManager` (`@MainActor`) manages the Python server process:

**Startup:**
1. Check if a server is already running on port 8765 (GET `/health`)
2. If not, find Python binary (resolution order below) and the server script (bundled or project copy)
3. Launch `python3 mathy_server.py 8765` as a child `Process`
4. Begin health polling every 1 second until `model_loaded == true`

**Python resolution order:**
1. Managed venv: `~/Library/Application Support/Mathy/venv/bin/python3`
2. UserDefaults `pythonPath` (user override)
3. Project `.venv/bin/python3` (developer workflow)
4. `/opt/homebrew/bin/python3`
5. `/usr/local/bin/python3`, `/usr/bin/python3`
6. `which python3` (runs off main thread)

**Auto-restart on crash:**
- Exponential backoff: 2s, 4s, 6s delays between attempts
- Max 3 restart attempts before status becomes `.error`
- Implemented via the `Process.terminationHandler` callback

**Health check response:**
```json
{"status": "ok", "model_loaded": true}
```

**Shutdown:** On app quit, `AppState.deinit` calls `serverManager.stop()` which terminates the child process and invalidates the polling timer.

---

## Screen Capture

`ScreenCaptureManager` uses AppleScript to invoke macOS's built-in `screencapture` tool:

```applescript
do shell script "/usr/sbin/screencapture -i -s '/path/to/output.png'"
```

**Why AppleScript instead of ScreenCaptureKit or CGWindowListCreateImage?**

macOS ties TCC (Transparency, Consent, and Control) permissions to the binary path. During development, Xcode rebuilds change the binary path, which invalidates Screen Recording permissions. By running `screencapture` via AppleScript's `do shell script`, the capture runs as an independent process with its own TCC context. This avoids the need to re-grant permissions after every rebuild.

The captured image is saved to a temp file, then moved to `~/Library/Application Support/Mathy/images/capture_{timestamp}.png` for persistence.

---

## OCR Service

`OCRService` sends captured images to the local server:

- **Endpoint:** `POST http://127.0.0.1:8765/predict`
- **Content-Type:** `multipart/form-data` with a `file` field containing the PNG
- **Timeout:** 30 seconds
- **Response:** `{"latex": "..."}` on success; `{"detail": "..."}` on error
- **Error codes:** 400 (invalid image), 503 (model not loaded), 500 (prediction failed)

Uses `URLSession.shared.data(for:)` with async/await.

---

## Python Server (mathy_server.py)

A FastAPI app served by uvicorn on `127.0.0.1:8765`.

**Model loading** happens at startup in a `lifespan` context manager:
- Imports and instantiates `pix2tex.cli.LatexOCR()`
- Takes ~10–15s on first run (downloads model weights ~200MB)
- Sets a global `model_loaded` flag; subsequent startups reuse cached weights

**Endpoints:**

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Returns `{"status": "ok", "model_loaded": bool}` |
| POST | `/predict` | Accepts image file, returns `{"latex": "..."}` |

**Prediction flow:** read uploaded bytes → open as PIL Image → convert to RGB → call `model(img)` → return LaTeX string.

---

## UI Components

### MenuBarView
The main dropdown (280px wide) has two modes:
- **Setup needed:** status message + "Open Setup..." button
- **Normal:** server status indicator, "Capture Equation" button, scrollable history (last 10), settings/quit footer

### PreviewPopupView
A floating `NSPanel` (400×380) shown after each capture:
- Captured image (max 150px height)
- Rendered LaTeX via KaTeX in a `WKWebView`
- Raw LaTeX string with copy button

KaTeX rendering uses a bundled `latex_preview.html` template with CDN fallback (`cdn.jsdelivr.net/npm/katex@0.16.9`). Supports dark mode.

### SettingsView
Two-tab settings window (420×280):
- **General:** hotkey recorder (KeyboardShortcuts.Recorder), launch-at-login toggle, auto-copy toggle
- **Server:** status indicator, restart button, "Reinstall OCR Engine" with confirmation alert

### OnboardingView
Setup wizard (520×440 NSWindow) with 3-step progress, collapsible install log, and retry/continue buttons.

---

## History & Persistence

`HistoryStore` (`@MainActor`) persists conversion records to `~/Library/Application Support/Mathy/history.json`:

```swift
struct ConversionRecord: Identifiable, Codable {
    let id: UUID
    let latex: String
    let timestamp: Date
    let imagePath: String
}
```

- Capped at 100 records (oldest pruned on overflow)
- New records prepended (most recent first)
- Atomic writes to prevent corruption
- Clearing history also deletes associated image files from disk

---

## Threading & Concurrency

| Component | Isolation | Notes |
|---|---|---|
| AppState | `@MainActor` | All state mutations on main thread |
| ServerManager | `@MainActor` | Process launches dispatched to background queue |
| PythonEnvironmentManager | `@MainActor` | Process execution via `withCheckedContinuation` + `DispatchQueue.global()` |
| HistoryStore | `@MainActor` | File I/O is synchronous (small JSON, acceptable) |
| OCRService | None | `URLSession` handles threading internally |
| Hotkey callbacks | Any → `@MainActor` | Wrapped in `Task { @MainActor in }` |

Retain cycles are prevented with `[weak self]` in closures and NotificationCenter observers for window cleanup.

---

## Build & Dependencies

### Swift (SPM)

```bash
cd Mathy && swift build
```

| Dependency | Version | Purpose |
|---|---|---|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 1.10.0 | Global hotkey registration. Pinned — 2.x requires full Xcode for `#Preview` macros. |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | 1.1.0 | Launch-at-login toggle via SMAppService |

Deployment target: **macOS 13+** (Ventura).

Xcode project: `open Mathy/Mathy.xcodeproj` (generate with xcodegen if needed).

### Python

| Dependency | Purpose |
|---|---|
| pix2tex | LaTeX OCR model |
| fastapi | HTTP framework |
| uvicorn[standard] | ASGI server |
| python-multipart | Form-data parsing |
| Pillow | Image processing |

### DMG Packaging

```bash
./scripts/build_dmg.sh 1.0.0
# Output: build/Mathy.dmg
```

---

## Project Structure

```
mathy/
├── Mathy/                      # Swift macOS app
│   ├── Package.swift           # SPM config
│   └── Mathy/
│       ├── MathyApp.swift      # @main entry point (MenuBarExtra)
│       ├── App/                # AppState, HotkeyManager, PythonEnvironmentManager
│       ├── Capture/            # ScreenCaptureManager (AppleScript → screencapture)
│       ├── OCR/                # OCRService (HTTP client), ServerManager (process lifecycle)
│       ├── Views/              # MenuBar, Onboarding, Preview, Settings
│       ├── Models/             # ConversionRecord, HistoryStore
│       ├── Utilities/          # ClipboardManager, Constants
│       └── Resources/          # KaTeX bundle, latex_preview.html, mathy_server.py, requirements.txt
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

---

## Known Issues

- **Screen Recording permission:** macOS ties TCC permissions to binary path. During Xcode development, you may need to remove and re-grant Screen Recording permission after clean builds. Fully quit and relaunch the app after granting.
- **Bundle identifier:** SPM executables lack a bundle identifier; "Cannot index window tabs" warning in Xcode console is cosmetic.
- **Gatekeeper:** The app is unsigned. Users must right-click → Open on first launch.
