import SwiftUI

/// A small, always-on-top, editable copy of a note that lives outside the popover.
/// Edits are persisted straight to disk and broadcast so the popover / full window
/// stay in sync.
struct FloatingNoteView: View {
    let noteID: UUID
    @State private var title: String
    @State private var text: String
    @State private var rtf: Data?

    let onClose: () -> Void

    @State private var windowOpacity: Double = 0.95
    @State private var isHoveringClose = false
    @State private var saveWork: DispatchWorkItem?

    init(note: Note, onClose: @escaping () -> Void) {
        self.noteID = note.id
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.text)
        _rtf = State(initialValue: note.attributedTextRTF)
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
        RichTextEditor(
            text: $text,
            attributedTextRTF: rtf,
            onTextChange: scheduleSave,
            onAttributedChange: { newRTF in
                rtf = newRTF
                scheduleSave()
            }
        )
        .frame(minWidth: 200, minHeight: 120)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshotText = text
        let snapshotRTF = rtf
        let work = DispatchWorkItem {
            persist(text: snapshotText, rtf: snapshotRTF)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func persist(text: String, rtf: Data?) {
        DispatchQueue.global(qos: .utility).async {
            guard var notes = NotesFileService.shared.loadNotes(),
                  let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
            notes[idx].text = text
            notes[idx].attributedTextRTF = rtf
            notes[idx].updateModifiedDate()
            notes[idx].captureVersionIfNeeded()
            NotesFileService.shared.saveNotes(notes)
            DispatchQueue.main.async {
                NoteSearchService.shared.indexNotes(with: notes)
                NotificationCenter.default.post(name: ExpiryManager.notesReloadRequested, object: nil)
            }
        }
    }
}
