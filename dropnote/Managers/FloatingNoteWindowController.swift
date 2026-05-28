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

    func show(note: Note) {
        let view = FloatingNoteView(note: note, onClose: { [weak self] in
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
