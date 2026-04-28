import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.needsSetup {
                setupSection
            } else {
                normalSection
            }

            Divider()

            // Footer actions
            if !appState.needsSetup {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings...")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                } else {
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings...")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }

            Button {
                appState.stopServer()
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit Mathy")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }

    // MARK: - Setup needed

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.orange)
                Text(setupStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if isSetupInProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Button {
                appState.showOnboarding()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle")
                    Text("Open Setup...")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var setupStatusText: String {
        switch appState.envManager.stage {
        case .idle: return "Setup required"
        case .checkingPython: return "Checking Python..."
        case .creatingVenv: return "Creating environment..."
        case .installingDeps: return "Installing OCR engine..."
        case .verifying: return "Verifying..."
        case .ready: return "Ready — finishing up..."
        case .failed: return "Setup failed"
        }
    }

    private var isSetupInProgress: Bool {
        switch appState.envManager.stage {
        case .checkingPython, .creatingVenv, .installingDeps, .verifying: return true
        default: return false
        }
    }

    // MARK: - Normal operation

    private var normalSection: some View {
        Group {
            // Status header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text("Server: \(appState.serverStatus.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Capture button
            Button {
                appState.startCapture()
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Capture Equation")
                    Spacer()
                    Text("Cmd+Shift+M")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .disabled(appState.serverStatus != .running || appState.isCapturing || appState.isProcessing)

            if appState.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            if let error = appState.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            // History
            if !appState.historyStore.records.isEmpty {
                Text("Recent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.historyStore.records.prefix(10)) { record in
                            HistoryRowView(record: record)
                                .environmentObject(appState)
                        }
                    }
                }
                .frame(maxHeight: 200)

                Divider()
            }
        }
    }

    private var statusColor: Color {
        switch appState.serverStatus {
        case .running: return .green
        case .starting: return .yellow
        case .stopped: return .gray
        case .error: return .red
        }
    }
}
