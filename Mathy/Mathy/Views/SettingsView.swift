import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("autoCopy") private var autoCopy = true

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            serverTab
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
        }
        .frame(width: 420, height: 280)
    }

    private var generalTab: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture Hotkey:", name: .captureEquation)

            LaunchAtLogin.Toggle("Launch at Login")

            Toggle("Auto-copy LaTeX to clipboard", isOn: $autoCopy)
        }
        .padding()
    }

    private var serverTab: some View {
        Form {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text("Status: \(appState.serverStatus.rawValue)")

                Spacer()

                Button("Restart Server") {
                    appState.stopServer()
                    appState.startServer()
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OCR Engine")
                        .font(.headline)
                    Text("Reinstall if you experience issues with recognition.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Reinstall...") {
                    appState.stopServer()
                    appState.envManager.resetEnvironment()
                    appState.needsSetup = true
                    appState.showOnboarding()
                }
            }
        }
        .padding()
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
