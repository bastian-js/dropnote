import SwiftUI
import AppKit

struct NoteEditor: View {
    let noteIndex: Int
    @Binding var notes: [Note]
    @Binding var unlockedNoteIDs: Set<UUID>
    @Binding var showWordCounter: Bool
    
    var onSave: () -> Void
    var onUnlock: (Int) -> Void
    var onToggleLock: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if isNoteLocked {
                lockedView
            } else {
                // Toolbar oben zentriert
                HStack {
                    Spacer()
                    FormattingToolbar(
                        onBoldTap: {
                            applyBoldFormatting()
                        },
                        onItalicTap: {
                            applyItalicFormatting()
                        },
                        onUnderlineTap: {
                            applyUnderlineFormatting()
                        },
                        onUpdateFormats: { _, _, _ in }
                    )
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                // Text Editor
                RichTextEditor(
                    text: $notes[noteIndex].text,
                    attributedTextRTF: notes[noteIndex].attributedTextRTF,
                    onTextChange: onSave,
                    onAttributedChange: { rtfData in
                        notes[noteIndex].attributedTextRTF = rtfData
                        onSave()
                    }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Words Counter unten links
                if showWordCounter {
                    HStack {
                        Text("Words: \(notes[noteIndex].text.split { $0.isWhitespace || $0.isNewline }.count)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var lockedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text("Locked")
                .font(.headline)
            Text("Unlock to view and edit this note.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Unlock") {
                onUnlock(noteIndex)
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
    
    // MARK: - Computed Properties
    
    private var isNoteLocked: Bool {
        notes[noteIndex].isLocked && !unlockedNoteIDs.contains(notes[noteIndex].id)
    }
    
    // MARK: - Private Methods
    
    private func applyBoldFormatting() {
        guard let textView = NSTextView.findInWindow(NSApplication.shared.keyWindow ?? NSWindow()) else {
            return
        }
        TextFormattingHelper.toggleFontTrait(.bold, in: textView)
        updateNoteFromTextView(textView)
    }
    
    private func applyItalicFormatting() {
        guard let textView = NSTextView.findInWindow(NSApplication.shared.keyWindow ?? NSWindow()) else {
            return
        }
        TextFormattingHelper.toggleFontTrait(.italic, in: textView)
        updateNoteFromTextView(textView)
    }
    
    private func applyUnderlineFormatting() {
        guard let textView = NSTextView.findInWindow(NSApplication.shared.keyWindow ?? NSWindow()) else {
            return
        }
        TextFormattingHelper.toggleUnderline(in: textView)
        updateNoteFromTextView(textView)
    }
    
    private func updateNoteFromTextView(_ textView: NSTextView) {
        notes[noteIndex].text = textView.string
        if let rtfData = try? textView.attributedString().data(
            from: NSRange(location: 0, length: textView.attributedString().length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            notes[noteIndex].attributedTextRTF = rtfData
        }
        onSave()
    }
}
