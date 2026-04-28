# UI Components

Mathy's UI is built with SwiftUI, presented as a `MenuBarExtra` with `.window` style. Additional windows (preview popup, onboarding) are managed as `NSWindow`/`NSPanel` instances.

## MenuBarView

The main menu bar dropdown (280px fixed width) has two modes:

**Setup needed** (`AppState.needsSetup == true`):

- Status message with icon
- "Open Setup..." button to launch onboarding
- Progress indicator if setup is already in progress

**Normal operation:**

- **Server status** — colored circle indicator (green = running, yellow = starting, red = error/stopped) with text label
- **"Capture Equation" button** — disabled when server isn't running or a capture is in progress
- **Processing indicator** — shown during OCR inference
- **Recent history** — scrollable list of the last 10 conversions (max 200px height). Each row shows the LaTeX string and a relative timestamp. Click a row to copy its LaTeX to clipboard.
- **Footer** — Settings button and Quit button

The Settings button uses `if #available(macOS 14.0, *)` to choose between `SettingsLink` (macOS 14+) and `NSApp.sendAction` fallback (macOS 13).

## PreviewPopupView

A floating panel shown after each successful capture. Displayed as an `NSPanel` with these traits:

- **Style:** titled, closable, non-activating, utility window
- **Behavior:** floating, does not hide on deactivate
- **Size:** 400x380, centered on screen

**Layout (top to bottom):**

1. **Captured image** — loaded from the saved PNG, max 150px height, with a subtle border
2. **Rendered LaTeX** — KaTeX rendering in a `WKWebView` (80px height)
3. **Raw LaTeX** — selectable monospaced text with a "Copy" button

### KaTeX Rendering

`LaTeXRenderView` (an `NSViewRepresentable` wrapping `WKWebView`) renders LaTeX using KaTeX:

1. **Primary:** Loads the bundled `latex_preview.html` template from app resources
2. **Fallback:** Generates HTML inline using KaTeX from CDN (`cdn.jsdelivr.net/npm/katex@0.16.9`)

The LaTeX string is escaped (backslashes, quotes) and substituted into a `{{LATEX}}` placeholder in the HTML template. The rendering uses `displayMode: true` with 20px font size and supports dark mode via `prefers-color-scheme: dark`.

## SettingsView

A two-tab settings window (420x280):

### General Tab

- **Capture hotkey** — `KeyboardShortcuts.Recorder` widget for remapping the global shortcut. The shortcut is persisted in UserDefaults by the KeyboardShortcuts framework.
- **Launch at login** — toggle backed by `LaunchAtLogin.isEnabled` (uses SMAppService)
- **Auto-copy to clipboard** — toggle stored in UserDefaults

### Server Tab

- **Server status** — colored indicator matching the menu bar
- **Restart server** — stops and relaunches the Python server
- **Reinstall OCR engine** — confirmation alert, then: stop server -> delete venv -> show onboarding

## OnboardingView

The first-run setup wizard. See [Onboarding & Python Setup](onboarding.md) for full details on the UI and setup flow.

## History

`HistoryStore` (`@MainActor`) manages conversion records persisted to JSON:

```swift
struct ConversionRecord: Identifiable, Codable {
    let id: UUID
    let latex: String
    let timestamp: Date
    let imagePath: String
}
```

**Storage:** `~/Library/Application Support/Mathy/history.json`

**Behavior:**

- New records are prepended (most recent first)
- Capped at 100 records — oldest entries are pruned on overflow
- Writes are atomic to prevent corruption on crash
- Deleting a record also deletes its associated image file from disk
- "Clear All" removes all records and all images

The menu bar shows the 10 most recent entries. Each entry is clickable to copy its LaTeX.
