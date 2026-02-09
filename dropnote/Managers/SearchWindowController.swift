import SwiftUI
import AppKit

// Custom window that can become key window
class SearchNSWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

final class SearchWindowController: NSWindowController {
    static let shared = SearchWindowController()
    
    private init() {
        let window = SearchNSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: SearchWindowView())
        
        super.init(window: window)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        guard let window = window, let screen = NSScreen.main else {
            return
        }
        
        centerWindow(window, on: screen)
        resetSearchState()
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        // Force focus on search field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(window.contentView)
        }
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Private Methods
    
    private func centerWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2 + 100
        
        window.setFrame(
            NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height),
            display: true
        )
    }
    
    private func resetSearchState() {
        NotificationCenter.default.post(name: Notification.Name("ResetSearchWindow"), object: nil)
    }
}
