import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var envManager: PythonEnvironmentManager
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            stepsSection
            Spacer()
            actionSection
        }
        .frame(width: 520, height: 440)
        .onAppear {
            if envManager.stage == .idle {
                Task { await envManager.runSetup() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image("MenuBarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .foregroundColor(.accentColor)

            Text(headerTitle)
                .font(.title2.bold())

            Text(headerSubtitle)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
    }

    private var headerTitle: String {
        switch envManager.stage {
        case .ready: return "You're all set!"
        case .failed: return "Setup Issue"
        default: return "Setting up Mathy"
        }
    }

    private var headerSubtitle: String {
        switch envManager.stage {
        case .idle, .checkingPython:
            return "Checking your system..."
        case .creatingVenv:
            return "Creating the OCR environment..."
        case .installingDeps:
            return "Installing the LaTeX recognition engine.\nThis takes a few minutes on first run."
        case .verifying:
            return "Almost there..."
        case .ready:
            return "Press \u{2318}\u{21E7}M to capture any equation."
        case .failed:
            return "Something went wrong during setup."
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow("Python 3", status: pythonStepStatus)
            stepRow("OCR engine", status: depsStepStatus)
            stepRow("Ready", status: readyStepStatus)

            if showLog || isFailed {
                logView
            }
        }
        .padding(24)
    }

    private func stepRow(_ title: String, status: StepStatus) -> some View {
        HStack(spacing: 10) {
            Group {
                switch status {
                case .pending:
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                case .inProgress:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .frame(width: 16)

            Text(title)
                .font(.body)
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(envManager.installLog)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("logBottom")
            }
            .frame(maxHeight: 140)
            .padding(8)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
            .onReceive(envManager.$installLog) { _ in
                proxy.scrollTo("logBottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Action buttons

    private var actionSection: some View {
        HStack {
            if !isFailed && envManager.stage != .ready {
                Button(showLog ? "Hide Details" : "Show Details") {
                    showLog.toggle()
                }
                .buttonStyle(.link)
            }

            Spacer()

            if case .failed(let message) = envManager.stage {
                if message.contains("Python 3 not found") {
                    Button("Check Again") {
                        Task { await envManager.runSetup() }
                    }
                } else {
                    Button("Retry Setup") {
                        envManager.resetEnvironment()
                        Task { await envManager.runSetup() }
                    }
                }
            }

            if envManager.stage == .ready {
                Button("Start Using Mathy") {
                    appState.completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(20)
    }

    // MARK: - Step status logic

    private enum StepStatus {
        case pending, inProgress, done, failed
    }

    private var isFailed: Bool {
        if case .failed = envManager.stage { return true }
        return false
    }

    private var pythonStepStatus: StepStatus {
        switch envManager.stage {
        case .idle: return .pending
        case .checkingPython: return .inProgress
        case .failed(let msg) where msg.contains("Python"): return .failed
        case .creatingVenv, .installingDeps, .verifying, .ready: return .done
        case .failed: return .done
        }
    }

    private var depsStepStatus: StepStatus {
        switch envManager.stage {
        case .idle, .checkingPython: return .pending
        case .creatingVenv, .installingDeps: return .inProgress
        case .verifying, .ready: return .done
        case .failed(let msg) where msg.contains("Python"): return .pending
        case .failed: return .failed
        }
    }

    private var readyStepStatus: StepStatus {
        switch envManager.stage {
        case .ready: return .done
        case .verifying: return .inProgress
        case .failed(let msg) where msg.contains("Python"): return .pending
        case .failed(let msg) where msg.contains("Verification"): return .failed
        default: return .pending
        }
    }
}
