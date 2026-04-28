import SwiftUI
import AppKit

struct PreviewPopupView: View {
    let record: ConversionRecord
    @ObservedObject var appState: AppState
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            // Captured image
            if let nsImage = NSImage(contentsOfFile: record.imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            Divider()

            // Rendered LaTeX
            LaTeXRenderView(latex: record.latex)
                .frame(height: 80)
                .cornerRadius(6)

            Divider()

            // Raw LaTeX
            HStack {
                Text(record.latex)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(3)

                Spacer()

                Button {
                    appState.copyToClipboard(record.latex)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? .green : .primary)
                }
                .buttonStyle(.bordered)
            }

            Text("Copied to clipboard")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400)
    }
}

// NSPanel wrapper for floating preview
class PreviewPanel {
    private var panel: NSPanel?

    func show(record: ConversionRecord, appState: AppState) {
        let contentView = PreviewPopupView(record: record, appState: appState)
        let hostingView = NSHostingView(rootView: contentView)

        if panel == nil {
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
                styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel?.title = "Mathy — Result"
            panel?.isFloatingPanel = true
            panel?.level = .floating
            panel?.hidesOnDeactivate = false
        }

        panel?.contentView = hostingView
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
    }
}
