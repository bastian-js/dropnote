import SwiftUI
import AppKit

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    private var hasPresentedOnce = false

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        window.contentView = NSHostingView(rootView: SettingsView())

        NSApp.activate(ignoringOtherApps: true)
        if !hasPresentedOnce {
            window.center()
            hasPresentedOnce = true
        }

        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        window.makeKey()
        window.orderFrontRegardless()
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Delay so the window is fully gone before we recheck visible windows.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            SettingsService.shared.reapplyActivationPolicy()
        }
    }
}