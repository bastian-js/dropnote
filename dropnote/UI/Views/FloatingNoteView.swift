import SwiftUI

struct FloatingNoteView: View {
    let note: Note
    let onClose: () -> Void
    @State private var windowOpacity: Double = 0.92
    @State private var isHoveringClose = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.25)
            noteContent
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 6)
        .opacity(windowOpacity)
    }

    // MARK: - Title Bar

    @ViewBuilder
    private var titleBar: some View {
        HStack(spacing: 7) {
            closeButton

            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            opacitySlider
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(isHoveringClose ? Color.red.opacity(0.85) : Color.primary.opacity(0.12))
                    .frame(width: 13, height: 13)

                if isHoveringClose {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isHoveringClose)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringClose = $0 }
        .help("Close")
    }

    @ViewBuilder
    private var opacitySlider: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.5))

            Slider(value: $windowOpacity, in: 0.2...1.0)
                .frame(width: 52)
                .controlSize(.mini)
                .tint(Color.secondary.opacity(0.6))
        }
        .help("Adjust transparency")
    }

    // MARK: - Note Content

    @ViewBuilder
    private var noteContent: some View {
        ScrollView {
            Text(note.text.isEmpty ? "Empty note" : note.text)
                .font(.system(size: 12))
                .foregroundColor(note.text.isEmpty ? .secondary.opacity(0.5) : .primary.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .textSelection(.enabled)
        }
    }
}
