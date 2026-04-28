import SwiftUI

struct HistoryRowView: View {
    let record: ConversionRecord
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

    var body: some View {
        Button {
            appState.copyToClipboard(record.latex)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.latex)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(record.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isHovering {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
