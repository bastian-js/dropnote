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
                .stroke(ColorSchemeHelper.borderColor(), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var lockedView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Lock Icon with background
            VStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 80)
            .background(
                Circle()
                    .fill(Color.accentColor.opacity(0.8))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            
            // Locked Text
            VStack(spacing: 8) {
                Text("This note is locked")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Enter your password or use biometrics to unlock and view this note.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Unlock Button
            Button {
                onUnlock(noteIndex)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Unlock Note")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
    
    // MARK: - Computed Properties
    
    private var isNoteLocked: Bool {
        notes[noteIndex].isLocked && !unlockedNoteIDs.contains(notes[noteIndex].id)
    }
    
    // MARK: - Private Methods
    
    private func applyBoldFormatting() {
        applyFormatting { textView in
            TextFormattingHelper.toggleFontTrait(.bold, in: textView)
        }
    }
    
    private func applyItalicFormatting() {
        applyFormatting { textView in
            TextFormattingHelper.toggleFontTrait(.italic, in: textView)
        }
    }
    
    private func applyUnderlineFormatting() {
        applyFormatting { textView in
            TextFormattingHelper.toggleUnderline(in: textView)
        }
    }

    private func applyFormatting(_ action: (NSTextView) -> Void) {
        guard let textView = NSTextView.findInWindow(NSApplication.shared.keyWindow ?? NSWindow()) else {
            return
        }

        let selectedRanges = textView.selectedRanges
        action(textView)
        updateNoteFromTextView(textView)

        DispatchQueue.main.async {
            textView.selectedRanges = selectedRanges
            textView.window?.makeFirstResponder(textView)
        }
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
