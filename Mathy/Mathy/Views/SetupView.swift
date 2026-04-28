import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var pythonFound = false
    @State private var pix2texInstalled = false
    @State private var serverWorking = false
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Mathy Setup")
                .font(.title)

            Text("Let's make sure everything is configured correctly.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                checkRow(title: "Python 3 found", checked: pythonFound)
                checkRow(title: "pix2tex installed", checked: pix2texInstalled)
                checkRow(title: "Server responding", checked: serverWorking)
            }
            .padding()
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Run Checks") {
                    runChecks()
                }
                .disabled(isChecking)

                if isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if pythonFound && !pix2texInstalled {
                Text("Install pix2tex by running:\npip install pix2tex")
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(4)
            }
        }
        .padding(30)
        .frame(width: 400)
        .onAppear { runChecks() }
    }

    private func checkRow(title: String, checked: Bool) -> some View {
        HStack {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(checked ? .green : .secondary)
            Text(title)
        }
    }

    private func runChecks() {
        isChecking = true
        errorMessage = nil

        Task {
            // Check Python
            let pythonCheck = Process()
            pythonCheck.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            pythonCheck.arguments = ["python3"]
            let pipe = Pipe()
            pythonCheck.standardOutput = pipe
            try? pythonCheck.run()
            pythonCheck.waitUntilExit()
            pythonFound = pythonCheck.terminationStatus == 0

            // Check pix2tex
            if pythonFound {
                let pipCheck = Process()
                pipCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                pipCheck.arguments = ["python3", "-c", "import pix2tex"]
                try? pipCheck.run()
                pipCheck.waitUntilExit()
                pix2texInstalled = pipCheck.terminationStatus == 0
            }

            // Check server
            if let url = URL(string: "\(Constants.serverBaseURL)/health") {
                do {
                    let (_, response) = try await URLSession.shared.data(from: url)
                    serverWorking = (response as? HTTPURLResponse)?.statusCode == 200
                } catch {
                    serverWorking = false
                }
            }

            isChecking = false
        }
    }
}
