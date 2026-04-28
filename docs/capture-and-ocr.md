# Screen Capture & OCR

## Screen Capture

`ScreenCaptureManager` captures a user-selected screen region using macOS's built-in `screencapture` tool, invoked via AppleScript.

### Why AppleScript?

macOS ties TCC (Transparency, Consent, and Control) permissions — including Screen Recording — to the binary path. This creates a problem during development: every Xcode rebuild produces a new binary at a different path, invalidating the Screen Recording permission grant.

By running `screencapture` via AppleScript's `do shell script`, the capture executes as an independent process with its own TCC context:

```applescript
do shell script "/usr/sbin/screencapture -i -s '/path/to/output.png'"
```

The `-i` flag enables interactive mode (like Cmd+Shift+4) and `-s` restricts to selection mode. The user draws a rectangle, and the screenshot is saved to the specified path.

### Capture Flow

1. Generate a unique temp file path: `{tempDir}/mathy_capture_{UUID}.png`
2. Run the AppleScript via `NSAppleScript` on a background queue (`DispatchQueue.global`)
3. User draws a selection rectangle on screen
4. If the file exists after the script returns (user didn't cancel):
    - Copy to persistent storage: `~/Library/Application Support/Mathy/images/capture_{timestamp}.png`
    - Delete the temp file
    - Return the persistent URL
5. If no file exists (user pressed Escape): return `nil`

The entire operation uses `withCheckedContinuation` to bridge to async/await.

### Image Storage

Captured images are stored persistently at:

```
~/Library/Application Support/Mathy/images/capture_{timestamp}.png
```

These files are referenced by `ConversionRecord.imagePath` and displayed in the preview popup. When history entries are deleted (individually or via "Clear All"), the associated image files are also removed from disk.

---

## OCR Service

`OCRService` is the HTTP client that sends captured images to the local Python server for LaTeX recognition.

### Request Format

```
POST http://127.0.0.1:8765/predict
Content-Type: multipart/form-data; boundary={uuid}
Timeout: 30 seconds

--{boundary}
Content-Disposition: form-data; name="file"; filename="capture.png"
Content-Type: image/png

{binary image data}
--{boundary}--
```

The multipart body is constructed manually (no third-party HTTP library). A UUID is used as the boundary string.

### Response Handling

**Success (200):**
```json
{"latex": "\\frac{a}{b}"}
```

The `latex` field is extracted and returned as a `String`.

**Errors:**

| Code | Meaning | Handling |
|---|---|---|
| 400 | Invalid image | Throws `OCRError.serverError(detail)` |
| 503 | Model not loaded | Throws `OCRError.serverError(detail)` |
| 500 | Prediction failed | Throws `OCRError.serverError(detail)` |
| Network error | Server unreachable | Throws underlying `URLError` |

Error responses are decoded from `{"detail": "..."}` when available, with a fallback to a generic HTTP status code message.

### Error Types

```swift
enum OCRError: Error {
    case invalidResponse    // Non-HTTP response
    case httpError(Int)     // Non-200 status (fallback)
    case serverError(String) // Detailed error from server
}
```

### Integration

`OCRService` is called from `AppState.startCapture()`. Errors are caught and printed to console but not shown to the user (the capture simply appears to fail silently). The service uses `URLSession.shared.data(for:)` with native async/await — no callbacks or Combine.
