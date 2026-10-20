import AppKit
import SwiftUI

final class FloatingNoteWindowController: NSWindowController {
    static let shared = FloatingNoteWindowController()

    private init() {
        let win = FloatingNSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isMovableByWindowBackground = true
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        super.init(window: win)
    }

    required init?(coder: NSCoder) { nil }

    /// A locked note is only shown after the user authenticated — the floating
    /// window has no locked screen of its own to fall back on.
    func show(note: Note) {
        guard note.isLocked else {
            present(note: note, unlocked: false)
            return
        }
        Task { @MainActor in
            guard await AuthenticationService.shared.unlock(noteID: note.id, reason: "Float \"\(note.title)\"") else { return }
            self.present(note: note, unlocked: true)
        }
    }

    private func present(note: Note, unlocked: Bool) {
        let view = FloatingNoteView(note: note, isUnlocked: unlocked, onClose: { [weak self] in
            self?.window?.orderOut(nil)
        })
        window?.contentView = NSHostingView(rootView: view)

        // Position top-right of main screen on first show
        if let screen = NSScreen.main, window?.isVisible == false {
            let sf = screen.visibleFrame
            let frame = NSRect(x: sf.maxX - 320, y: sf.maxY - 260, width: 300, height: 240)
            window?.setFrame(frame, display: false)
        }

        window?.orderFrontRegardless()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func hide() { window?.orderOut(nil) }
}

private final class FloatingNSWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
