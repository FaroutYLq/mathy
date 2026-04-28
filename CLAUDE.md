# Mathy — Claude Code Guidelines

## Project Overview
macOS menu bar app for LaTeX OCR. Two components:
- **Mathy.app** (Swift/SwiftUI) — menu bar UI, hotkeys, screen capture, clipboard
- **mathy-server** (Python/FastAPI) — wraps pix2tex, persistent local HTTP server on port 8765

## Build & Run

### Swift App
```bash
cd Mathy && swift build
# Or open in Xcode: open Mathy/Mathy.xcodeproj (generate with xcodegen if needed)
```
- Deployment target: macOS 13+
- SPM dependencies: KeyboardShortcuts (1.10.0), LaunchAtLogin-Modern (1.1.0)
- KeyboardShortcuts 2.x uses `#Preview` macros that require full Xcode — pinned to 1.10.0 for CLI builds

### Python Server (for development)
```bash
./scripts/setup.sh          # Creates .venv, installs deps
source .venv/bin/activate
python server/mathy_server.py
```
- Test: `curl http://127.0.0.1:8765/health`
- Predict: `curl -X POST -F "file=@image.png" http://127.0.0.1:8765/predict`

> **Note:** End users don't need to run these commands. The app auto-installs Python dependencies on first launch via the onboarding flow.

## Project Structure
```
Mathy/Mathy/
  MathyApp.swift          # @main, MenuBarExtra scene
  App/                    # AppState, HotkeyManager, PythonEnvironmentManager
  Capture/                # ScreenCaptureManager (AppleScript -> screencapture)
  OCR/                    # OCRService (HTTP client), ServerManager (process lifecycle)
  Views/                  # MenuBarView, OnboardingView, PreviewPopupView, SettingsView, etc.
  Models/                 # ConversionRecord, HistoryStore (JSON persistence)
  Utilities/              # ClipboardManager, Constants
  Resources/              # Bundled KaTeX, latex_preview.html, mathy_server.py, requirements.txt
server/                   # FastAPI server + requirements.txt (canonical copy)
scripts/                  # setup.sh, build_dmg.sh, generate_icons.py
.github/workflows/        # CI pipeline (Swift build + Python checks)
```

## Key Patterns
- **Auto-onboarding**: PythonEnvironmentManager creates a managed venv at `~/Library/Application Support/Mathy/venv/`, auto-installs pix2tex on first launch. No terminal required for end users.
- **Onboarding window**: NSWindow managed by AppState; uses NotificationCenter observer on `willCloseNotification` to break retain cycle (AppState -> window -> hostingView -> environmentObject -> AppState).
- **Server auto-detection**: ServerManager checks if server is already running before launching
- **Python resolution order**: Managed venv -> UserDefaults -> project .venv -> Homebrew -> system -> `which`
- **Path resolution**: Uses SOURCE_ROOT env (Xcode) and walks up from bundle URL to find project root
- **Screen capture**: Uses AppleScript `do shell script` to run screencapture as independent process (avoids TCC inheritance)
- **SettingsLink**: Uses `if #available(macOS 14.0, *)` guard with NSApp.sendAction fallback for macOS 13
- **Actor isolation**: AppState and ServerManager are @MainActor; blocking Process calls run off main thread via `withCheckedContinuation` + `DispatchQueue.global()`
- **Process pipe safety**: All Process helpers use `readabilityHandler` to drain pipes (avoids deadlock if child output exceeds 64KB pipe buffer). Streaming variant uses `NSLock` for thread-safe output collection.
- **History**: JSON file at ~/Library/Application Support/Mathy/history.json, capped at 100 entries

## Known Issues
- **Screen Recording permission**: macOS ties TCC permissions to binary path. During Xcode development, may need to remove and re-grant Screen Recording permission after clean builds. Must fully quit and relaunch app after granting.
- **Bundle identifier**: SPM executables lack a bundle identifier; "Cannot index window tabs" warning in Xcode console is cosmetic
- **Info.plist**: Excluded from SPM resources (forbidden by SPM); only used by Xcode project builds
- **Entitlements**: Mathy.entitlements is managed by Xcode; kept as empty dict for non-sandboxed development
- **File naming**: `SetupView.swift` contains `OnboardingView` struct (historical rename)
