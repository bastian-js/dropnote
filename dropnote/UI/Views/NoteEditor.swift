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

    // Unlock reveal animation. `displayLocked` lags behind `isNoteLocked` so the
    // locked screen stays visible while the padlock opens in place, then reveals.
    @State private var displayLocked: Bool? = nil
    @State private var lockOpen = false

    var body: some View {
        VStack(spacing: 0) {
            if noteIndex < notes.count {
                if displayLocked ?? isNoteLocked {
                    lockedView
                } else {
                    unlockedContent
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorSchemeHelper.borderColor(), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
        .onAppear {
            if displayLocked == nil { displayLocked = isNoteLocked }
        }
        .onChange(of: isNoteLocked) { _, nowLocked in
            handleLockChange(nowLocked: nowLocked)
        }
        .onChange(of: noteIndex) { _, _ in
            displayLocked = isNoteLocked
            lockOpen = false
        }
    }

    @ViewBuilder
    private var unlockedContent: some View {
        VStack(spacing: 0) {
            // Toolbar oben zentriert
            HStack {
                Spacer()
                FormattingToolbar(
                    onBoldTap: { applyBoldFormatting() },
                    onItalicTap: { applyItalicFormatting() },
                    onUnderlineTap: { applyUnderlineFormatting() },
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

    // MARK: - Unlock Reveal Animation

    private func handleLockChange(nowLocked: Bool) {
        if nowLocked {
            // Re-locked: show the locked screen again with a closed padlock.
            displayLocked = true
            lockOpen = false
            return
        }
        // Unlocked this session: open the padlock in place on the locked screen,
        // then reveal the note. Keeps the "This note is locked" screen visible
        // instead of cutting to a separate overlay.
        guard displayLocked != false else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { lockOpen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.3)) { displayLocked = false }
        }
    }


    @ViewBuilder
    private var lockedView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Custom padlock icon — opens in place when the note is unlocked.
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
                    .scaleEffect(lockOpen ? 1.05 : 1.0)
                PadlockIcon(isOpen: lockOpen)
            }
            
            // Locked Text
            VStack(spacing: 8) {
                Text("This note is locked")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Unlock with your password or Touch ID.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
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

// MARK: - Custom Padlock

/// A hand-drawn padlock whose shackle swings open when `isOpen` is true.
private struct PadlockIcon: View {
    var isOpen: Bool

    var body: some View {
        ZStack {
            // Shackle (the arch) — lifts up and swings open clockwise (to the right),
            // pivoting on the right leg that stays seated in the body.
            Shackle()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 22, height: 18)
                .offset(y: isOpen ? -16 : -12)
                .rotationEffect(.degrees(isOpen ? 26 : 0), anchor: .bottomTrailing)

            // Body
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 34, height: 26)
                .offset(y: 9)
                .overlay(
                    VStack(spacing: 1.5) {
                        Circle().frame(width: 6, height: 6)
                        RoundedRectangle(cornerRadius: 1).frame(width: 3.5, height: 6)
                    }
                    .foregroundColor(Color.accentColor)
                    .offset(y: 9)
                )
        }
        .frame(width: 44, height: 48)
    }
}

/// An inverted-U shackle path.
private struct Shackle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        let topY = rect.minY + r
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: topY))
        p.addArc(center: CGPoint(x: rect.midX, y: topY), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: topY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
