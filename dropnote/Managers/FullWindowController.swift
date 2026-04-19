import Cocoa
import SwiftUI

final class FullWindowController: NSObject, NSWindowDelegate {
    static let shared = FullWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        win.title = "DropNote"
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 760, height: 520)
        win.delegate = self

        win.center()

        let hostingController = NSHostingController(rootView: FullWindowView())
        win.contentViewController = hostingController

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the window to close; just hide it so state is preserved
        sender.orderOut(nil)
        return false
    }
}
