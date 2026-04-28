# Development

## Build from Source

### Swift App

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

### Python Server (standalone)

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

!!! note
    End users don't need these commands. The app handles Python setup and server management automatically.

### DMG Packaging

```bash
./scripts/build_dmg.sh 1.0.0
# Output: build/Mathy.dmg
```

## Dependencies

### Swift (SPM)

| Dependency | Version | Purpose |
|---|---|---|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 1.10.0 | Global hotkey registration |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | 1.1.0 | Launch-at-login via SMAppService |

KeyboardShortcuts is pinned to 1.10.0 because 2.x uses `#Preview` macros that require a full Xcode project (not compatible with `swift build` on CLI).

Deployment target: **macOS 13+** (Ventura).

### Python

| Dependency | Purpose |
|---|---|
| pix2tex | LaTeX OCR model (includes PyTorch) |
| fastapi | Async HTTP framework |
| uvicorn[standard] | ASGI server |
| python-multipart | multipart/form-data parsing |
| Pillow | Image loading and conversion |

## Project Structure

```
mathy/
+-- Mathy/                      # Swift macOS app
|   +-- Package.swift           # SPM config
|   +-- Mathy/
|       +-- MathyApp.swift      # @main entry point (MenuBarExtra)
|       +-- App/                # AppState, HotkeyManager, PythonEnvironmentManager
|       +-- Capture/            # ScreenCaptureManager (AppleScript -> screencapture)
|       +-- OCR/                # OCRService (HTTP client), ServerManager (process lifecycle)
|       +-- Views/              # MenuBar, Onboarding, Preview, Settings
|       +-- Models/             # ConversionRecord, HistoryStore
|       +-- Utilities/          # ClipboardManager, Constants
|       +-- Resources/          # KaTeX bundle, latex_preview.html, mathy_server.py, requirements.txt
+-- server/
|   +-- mathy_server.py         # FastAPI server wrapping pix2tex
|   +-- requirements.txt
+-- docs/                       # This documentation (MkDocs)
+-- .github/workflows/
|   +-- ci.yml                  # CI: Swift build + Python server checks
+-- scripts/
    +-- setup.sh                # Manual Python env setup (for development)
    +-- build_dmg.sh            # Build DMG for distribution
    +-- generate_icons.py       # Generate app icon assets
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and PR:

1. **Swift build** — `cd Mathy && swift build` on macOS runner
2. **Python checks** — validates server script syntax and imports

## Known Issues

**Screen Recording permission:** macOS ties TCC permissions to the binary path. During Xcode development, you may need to remove and re-grant Screen Recording permission in System Settings after clean builds. You must fully quit and relaunch the app after granting.

**Bundle identifier:** SPM executables don't have a bundle identifier. The "Cannot index window tabs" warning in Xcode console is cosmetic and harmless.

**Gatekeeper:** The app is currently unsigned. Users must right-click > Open on first launch to bypass Gatekeeper. A proper Developer ID signing setup would eliminate this.

**Info.plist:** Excluded from SPM resources (forbidden by SPM); only used by Xcode project builds.

**File naming:** `SetupView.swift` contains the `OnboardingView` struct (historical rename, not worth the churn to fix).
