import Cocoa
import SwiftUI

final class FullWindowController: NSObject, NSWindowDelegate {
    static let shared = FullWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        win.title = "DropNote"
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 760, height: 520)
        win.delegate = self
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden

        let hostingController = NSHostingController(rootView: FullWindowView())
        win.contentViewController = hostingController
        // Force the desired initial size — NSHostingController would otherwise
        // shrink the window to the SwiftUI view's ideal size on first layout.
        win.setContentSize(NSSize(width: 1120, height: 760))
        win.center()

        self.window = win
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Release the window so AppKit, the NSHostingController, and all SwiftUI
        // state (including NSTextView + glyph layout) can be deallocated.
        // show() will create a fresh window next time.
        window = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            SettingsService.shared.reapplyActivationPolicy()
        }
        return true
    }
}
