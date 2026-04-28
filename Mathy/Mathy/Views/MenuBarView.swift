import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            // Footer actions
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

    private var statusColor: Color {
        switch appState.serverStatus {
        case .running: return .green
        case .starting: return .yellow
        case .stopped: return .gray
        case .error: return .red
        }
    }
}
