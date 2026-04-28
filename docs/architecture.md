# Architecture

## System Overview

```
+--------------------+                    +--------------------+
|     Mathy.app      |       HTTP         |    mathy-server    |
|   (Swift/SwiftUI)  | <---------------> |  (Python/FastAPI)  |
|                    |  localhost:8765    |                    |
|  - Menu bar UI     |                    |  - pix2tex model   |
|  - Screen capture  |  POST /predict     |  - Loaded once     |
|  - Hotkey          |  ---------------> |  - Fast inference  |
|  - KaTeX preview   |                    |                    |
|  - History         |  {"latex": "..."}  |                    |
|                    |  <--------------- |                    |
+--------------------+                    +--------------------+
```

The Swift app manages the Python server's full lifecycle — launching it on startup, polling its health endpoint, auto-restarting on crash, and terminating it on quit. All communication happens over HTTP on `localhost:8765`.

## Capture Pipeline

When the user presses **Cmd+Shift+M**, the following pipeline executes:

```
KeyboardShortcuts.onKeyUp
  -> AppState.startCapture()
    -> ScreenCaptureManager.captureRegion()          # AppleScript -> screencapture -i -s
      -> saves PNG to ~/Library/Application Support/Mathy/images/
    -> OCRService.predict(imageURL)                   # POST multipart/form-data to /predict
      -> server runs pix2tex model on image
      -> returns {"latex": "\\frac{1}{2}"}
    -> ClipboardManager.copy(latex)                   # NSPasteboard.general
    -> HistoryStore.add(record)                       # Prepend to history.json (max 100)
    -> PreviewPopupView                               # Floating NSPanel with image + KaTeX render
```

The entire flow is `async` and runs on `@MainActor`, with blocking operations (process launches, network requests) dispatched to background threads. Guards prevent concurrent captures (`isCapturing`) and overlapping OCR requests (`isProcessing`).

## App Lifecycle

**Entry point:** `MathyApp.swift` — a SwiftUI `App` struct with two scenes:

- `MenuBarExtra("Mathy", image: "MenuBarIcon")` — the menu bar dropdown (`.window` style)
- `Settings { SettingsView }` — the system settings window

**AppState** (`@MainActor ObservableObject`) is the central coordinator that owns all managers. On init:

1. Registers the capture hotkey via KeyboardShortcuts
2. Subscribes to server status changes via Combine
3. Calls `checkSetupAndStart()` which checks if the managed Python venv exists:
    - If ready: starts the server immediately
    - If not: shows the onboarding window

**Managers owned by AppState:**

| Manager | Responsibility |
|---|---|
| `ServerManager` | Python server process lifecycle |
| `ScreenCaptureManager` | AppleScript-based screen region capture |
| `OCRService` | HTTP client to `/predict` endpoint |
| `ClipboardManager` | NSPasteboard wrapper |
| `HistoryStore` | JSON persistence of conversion records |
| `HotkeyManager` | Placeholder for future hotkey expansion |
| `PythonEnvironmentManager` | Venv creation and pix2tex installation |

## Threading & Concurrency

All state-holding classes use `@MainActor` isolation to ensure UI consistency:

| Component | Isolation | Notes |
|---|---|---|
| AppState | `@MainActor` | All state mutations on main thread |
| ServerManager | `@MainActor` | Process launches dispatched to `DispatchQueue.global()` |
| PythonEnvironmentManager | `@MainActor` | Process execution via `withCheckedContinuation` |
| HistoryStore | `@MainActor` | File I/O is synchronous (small JSON, acceptable) |
| OCRService | None | `URLSession` handles threading internally |
| Hotkey callbacks | Any -> `@MainActor` | Wrapped in `Task { @MainActor in }` |

**Key concurrency patterns:**

- **Process execution:** `withCheckedContinuation` + `DispatchQueue.global(qos: .userInitiated)` bridges synchronous `Process` calls to async/await
- **Pipe safety:** All process helpers use `readabilityHandler` to drain stdout/stderr asynchronously, preventing deadlock when child output exceeds the 64KB pipe buffer. Output collection is protected by `NSLock`.
- **Retain cycle prevention:** `[weak self]` in closures, NotificationCenter observers for window cleanup

## Data Flow

```
~/Library/Application Support/Mathy/
  +-- venv/                          # Managed Python environment
  |   +-- bin/python3                # Used to launch server
  +-- images/                        # Captured screenshots
  |   +-- capture_{timestamp}.png    # Persistent copies
  +-- history.json                   # Conversion records (max 100)
```

All persistent data lives under `~/Library/Application Support/Mathy/`. The `Constants.appSupportDirectory` property creates this directory on first access.
