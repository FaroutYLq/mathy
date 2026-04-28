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
    @Published var needsSetup = false

    let serverManager = ServerManager()
    let captureManager = ScreenCaptureManager()
    let ocrService = OCRService()
    let clipboardManager = ClipboardManager()
    let historyStore = HistoryStore()
    let hotkeyManager = HotkeyManager()
    let envManager = PythonEnvironmentManager()

    private var cancellables = Set<AnyCancellable>()
    private var previewPanel: PreviewPanel?
    private var onboardingWindow: NSWindow?
    private var windowCloseObserver: Any?

    enum ServerStatus: String {
        case stopped = "Stopped"
        case starting = "Starting..."
        case running = "Running"
        case error = "Error"
    }

    init() {
        setupHotkey()
        setupServerMonitoring()
        checkSetupAndStart()
    }

    private func checkSetupAndStart() {
        Task {
            let ready = await envManager.checkExistingSetup()
            if ready {
                needsSetup = false
                startServer()
            } else {
                needsSetup = true
                showOnboarding()
            }
        }
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

    // MARK: - Onboarding

    func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(envManager: envManager)
                .environmentObject(self)
            let hostingView = NSHostingView(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.title = "Mathy"
            window.center()
            window.isReleasedWhenClosed = false
            onboardingWindow = window

            // Break retain cycle (self → window → hostingView → environmentObject → self)
            // by releasing the window reference when the user closes it via the X button.
            windowCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.onboardingWindow = nil
                    if let obs = self?.windowCloseObserver {
                        NotificationCenter.default.removeObserver(obs)
                        self?.windowCloseObserver = nil
                    }
                }
            }
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func completeOnboarding() {
        needsSetup = false
        onboardingWindow?.close()
        // Observer handles cleanup, but nil out explicitly for immediate release
        onboardingWindow = nil
        if let obs = windowCloseObserver {
            NotificationCenter.default.removeObserver(obs)
            windowCloseObserver = nil
        }
        startServer()
    }

    // MARK: - Preview

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
