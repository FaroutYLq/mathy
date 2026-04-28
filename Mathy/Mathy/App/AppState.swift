import SwiftUI
import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let captureEquation = Self("captureEquation", default: .init(.m, modifiers: [.command, .shift]))
}

@MainActor
final class AppState: ObservableObject {
    @Published var serverStatus: ServerStatus = .stopped
    @Published var isCapturing = false
    @Published var lastResult: ConversionRecord?
    @Published var showPreview = false
    @Published var isProcessing = false

    let serverManager = ServerManager()
    let captureManager = ScreenCaptureManager()
    let ocrService = OCRService()
    let clipboardManager = ClipboardManager()
    let historyStore = HistoryStore()
    let hotkeyManager = HotkeyManager()

    private var cancellables = Set<AnyCancellable>()
    private var previewPanel: PreviewPanel?

    enum ServerStatus: String {
        case stopped = "Stopped"
        case starting = "Starting..."
        case running = "Running"
        case error = "Error"
    }

    init() {
        setupHotkey()
        setupServerMonitoring()
        startServer()
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .captureEquation) { [weak self] in
            Task { @MainActor in
                self?.startCapture()
            }
        }
    }

    private func setupServerMonitoring() {
        serverManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .stopped: self?.serverStatus = .stopped
                case .starting: self?.serverStatus = .starting
                case .running: self?.serverStatus = .running
                case .error: self?.serverStatus = .error
                }
            }
            .store(in: &cancellables)
    }

    func startServer() {
        serverManager.start()
    }

    func stopServer() {
        serverManager.stop()
    }

    func startCapture() {
        guard !isCapturing, !isProcessing else { return }
        isCapturing = true

        Task {
            defer { isCapturing = false }

            guard let imageURL = await captureManager.captureRegion() else {
                return
            }

            isProcessing = true
            defer { isProcessing = false }

            do {
                let latex = try await ocrService.predict(imageURL: imageURL)
                let record = ConversionRecord(
                    latex: latex,
                    imagePath: imageURL.path
                )
                historyStore.add(record)
                lastResult = record
                clipboardManager.copy(latex)
                showPreviewPopup(record: record)
            } catch {
                print("OCR Error: \(error.localizedDescription)")
            }
        }
    }

    func copyToClipboard(_ text: String) {
        clipboardManager.copy(text)
    }

    private func showPreviewPopup(record: ConversionRecord) {
        if previewPanel == nil {
            previewPanel = PreviewPanel()
        }
        previewPanel?.show(record: record, appState: self)
    }

    deinit {
        let mgr = serverManager
        Task { @MainActor in mgr.stop() }
    }
}
