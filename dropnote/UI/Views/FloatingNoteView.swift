import SwiftUI

/// A small, always-on-top, editable view of a note that lives outside the popover.
///
/// It is not a copy: it reads and writes the shared `NotesStore`, so edits show up
/// in the popover and the full window as they are typed.
struct FloatingNoteView: View {
    let noteID: UUID
    @ObservedObject private var store = NotesStore.shared

    let onClose: () -> Void

    @State private var windowOpacity: Double = 0.95
    @State private var isHoveringClose = false

    private var note: Note? { store.note(noteID) }
    private var title: String { note?.title ?? "" }

    init(note: Note, onClose: @escaping () -> Void) {
        self.noteID = note.id
        self.onClose = onClose
    }

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
        .appAccent()
    }

    // MARK: - Title Bar

    @ViewBuilder
    private var titleBar: some View {
        HStack(spacing: 7) {
            closeButton

            Text(title.isEmpty ? "Untitled" : title)
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
        if let note {
            RichTextEditor(
                contentID: note.id,
                text: note.text,
                attributedTextRTF: note.attributedTextRTF,
                onChange: { text, rtf in
                    store.updateContent(id: noteID, text: text, rtf: rtf)
                }
            )
            .frame(minWidth: 200, minHeight: 120)
        } else {
            // The note was deleted or self-destructed while floating.
            VStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("This note no longer exists.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button("Close", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .frame(minWidth: 200, minHeight: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
