import SwiftUI
import AppKit

/// Edits one note, identified by id.
///
/// It reads the note out of `NotesStore` on every render instead of holding an
/// index into a notes array, so adding, deleting, pinning or reordering notes can
/// never leave it pointing at the wrong note (or past the end of the array).
struct NoteEditor: View {
    let noteID: UUID
    @ObservedObject var store: NotesStore = .shared
    @Binding var unlockedNoteIDs: Set<UUID>
    let showWordCounter: Bool

    var onUnlock: (UUID) -> Void
    var onToggleLock: (UUID) -> Void

    // Unlock reveal animation. `displayLocked` lags behind `isNoteLocked` so the
    // locked screen stays visible while the padlock opens in place, then reveals.
    @State private var displayLocked: Bool? = nil
    @State private var lockOpen = false

    private var note: Note? { store.note(noteID) }

    var body: some View {
        VStack(spacing: 0) {
            if let note {
                if displayLocked ?? isNoteLocked {
                    lockedView
                } else {
                    unlockedContent(note: note)
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
        .onChange(of: noteID) { _, _ in
            displayLocked = isNoteLocked
            lockOpen = false
        }
    }

    @ViewBuilder
    private func unlockedContent(note: Note) -> some View {
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

            // Text Editor — keyed by note id, so switching tabs always swaps the
            // document and edits always land on the note that is on screen.
            RichTextEditor(
                contentID: note.id,
                text: note.text,
                attributedTextRTF: note.attributedTextRTF,
                onChange: { text, rtf in
                    store.updateContent(id: noteID, text: text, rtf: rtf)
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Words Counter unten links
            if showWordCounter {
                HStack {
                    Text("Words: \(WordCount.count(in: note))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
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
        // A short popover — many notes add a scrollbar under the tabs — can't fit
        // the full layout. Step down to smaller ones instead of overflowing and
        // getting clipped at the top and bottom.
        ViewThatFits(in: .vertical) {
            regularLockedLayout
            compactLockedLayout
            minimalLockedLayout
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var regularLockedLayout: some View {
        VStack(spacing: 20) {
            Spacer()

            padlockBadge(size: 84)

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

            unlockButton(verticalPadding: 12)
                .padding(.horizontal, 20)

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private var compactLockedLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            padlockBadge(size: 46)
            Text("This note is locked")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 8)
            Spacer(minLength: 8)
            unlockButton(verticalPadding: 8)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var minimalLockedLayout: some View {
        HStack(spacing: 10) {
            padlockBadge(size: 30)
            Text("Locked")
                .font(.system(size: 13, weight: .semibold))
            unlockButton(verticalPadding: 6)
        }
        .padding(.horizontal, 12)
    }

    /// Custom padlock icon — opens in place when the note is unlocked. Drawn at
    /// 84pt and scaled, so every layout shares the same animation.
    @ViewBuilder
    private func padlockBadge(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: 84, height: 84)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
                .scaleEffect(lockOpen ? 1.05 : 1.0)
            PadlockIcon(isOpen: lockOpen)
        }
        .scaleEffect(size / 84)
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func unlockButton(verticalPadding: CGFloat) -> some View {
        Button {
            onUnlock(noteID)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Unlock Note")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut(.defaultAction)
    }

    // MARK: - Computed Properties

    private var isNoteLocked: Bool {
        guard let note else { return false }
        return note.isHidden(unlockedIDs: unlockedNoteIDs)
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
        guard store.contains(noteID), let textView = NSTextView.focused else { return }

        let selectedRanges = textView.selectedRanges
        action(textView)
        updateNoteFromTextView(textView)

        DispatchQueue.main.async {
            textView.selectedRanges = selectedRanges
            textView.window?.makeFirstResponder(textView)
        }
    }

    private func updateNoteFromTextView(_ textView: NSTextView) {
        let attributed = textView.attributedString()
        let rtf = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        store.updateContent(id: noteID, text: textView.string, rtf: rtf)
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
