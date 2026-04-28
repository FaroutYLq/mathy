# Onboarding & Python Setup

On first launch (or after selecting "Reinstall OCR Engine" in settings), `PythonEnvironmentManager` runs a fully automated setup that installs the Python OCR engine without requiring the user to open a terminal.

## Setup Stages

| Stage | What happens |
|---|---|
| **checkingPython** | Searches for a Python 3 binary on the system |
| **creatingVenv** | Creates a dedicated venv at `~/Library/Application Support/Mathy/venv/` |
| **installingDeps** | Upgrades pip, then installs pix2tex and server dependencies |
| **verifying** | Imports pix2tex in the new venv to confirm installation |
| **ready** | Setup complete — server can start |
| **failed** | Something went wrong — shows error message and retry option |

## Python Discovery

The onboarding flow first needs to find a working Python 3 installation. It checks these paths in order:

1. `/opt/homebrew/bin/python3` (Homebrew on Apple Silicon)
2. `/usr/local/bin/python3` (Homebrew on Intel, or manual installs)
3. `/usr/bin/python3` (macOS system Python)
4. `which python3` (fallback — runs off main thread to avoid blocking UI)

If no Python is found, the user sees instructions to install Python via Homebrew.

## Venv Creation

```bash
python3 -m venv ~/Library/Application\ Support/Mathy/venv/
```

If a broken venv already exists (e.g., from a failed previous attempt), it is removed first. The venv is a standard Python virtual environment with its own `bin/python3`, `pip`, and `site-packages`.

## Dependency Installation

After venv creation, pip installs the dependencies:

```bash
# Upgrade pip
venv/bin/python3 -m pip install --upgrade pip

# Install from bundled requirements.txt
venv/bin/python3 -m pip install -r requirements.txt
```

The `requirements.txt` is bundled inside Mathy.app. If the bundled file isn't found (e.g., during development), it falls back to installing packages directly:

```
pix2tex fastapi uvicorn[standard] python-multipart Pillow
```

The installation has a **10-minute timeout**. This is generous because pix2tex has many dependencies (PyTorch, etc.) that can take several minutes to download.

## Verification

After installation, the setup runs:

```bash
venv/bin/python3 -c "import pix2tex; print('OK')"
```

This confirms that pix2tex was installed correctly and can be imported. If this fails, the user sees an error with the install log.

## Process Execution Details

All subprocess calls use a careful pattern to avoid common macOS pitfalls:

**Non-blocking execution:**
```
withCheckedContinuation + DispatchQueue.global(qos: .userInitiated)
```
This bridges synchronous `Process` (Foundation) calls to Swift's async/await without blocking the main thread.

**Pipe deadlock prevention:** Child processes can deadlock if their output exceeds the 64KB pipe buffer and nobody is reading. All process helpers use `readabilityHandler` on the pipe's `fileHandleForReading` to drain output asynchronously as it arrives. The collected output is protected by `NSLock` for thread safety.

**Streaming output:** During pip installation, output is streamed in real time to the `@Published installLog` property, which the onboarding UI displays in a scrollable, monospaced text view. Updates are dispatched to `@MainActor` via `Task`.

**Timeout:** A `DispatchSourceTimer` fires after 600 seconds and terminates the process. The result includes a `timedOut` flag so the UI can show an appropriate message.

## Onboarding UI

The onboarding window (`OnboardingView` in `SetupView.swift`) is a 520x440 `NSWindow` managed by `AppState`:

- App icon and welcome title (changes per stage)
- 3-step progress indicator with status icons (pending / in progress / done / failed)
- Collapsible "Show Details" log viewer (monospaced, selectable text)
- Action buttons: "Check Again" (if Python not found), "Retry Setup" (on failure), "Start Using Mathy" (on success)

**Window lifecycle:** The window is stored as `AppState.onboardingWindow`. A `NotificationCenter` observer on `willCloseNotification` sets this reference to `nil`, breaking the retain cycle (AppState -> NSWindow -> NSHostingView -> environmentObject -> AppState).

## Reset

The "Reinstall OCR Engine" button in settings triggers:

1. Confirmation alert
2. `serverManager.stop()` — terminates the running server
3. `envManager.resetEnvironment()` — deletes the entire venv directory
4. `showOnboarding()` — opens the setup window to start fresh
