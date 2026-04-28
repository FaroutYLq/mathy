import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("pythonPath") private var pythonPath = ""
    @AppStorage("serverPort") private var serverPort = 8765
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
            TextField("Python Path (leave empty for auto-detect):", text: $pythonPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Server Port:")
                TextField("", value: $serverPort, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }

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
