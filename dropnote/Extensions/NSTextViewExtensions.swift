import AppKit

extension NSTextView {
    /// Returns the first NSTextView found in the view hierarchy of a window
    static func findInWindow(_ window: NSWindow) -> NSTextView? {
        guard let contentView = window.contentView else {
            return nil
        }
        return findInViewHierarchy(contentView)
    }
    
    /// The text view that currently has keyboard focus, falling back to the first
    /// one in the key window. Formatting commands must act on *this* view —
    /// several windows (popover, full window, floating note) can host an editor at
    /// the same time.
    static var focused: NSTextView? {
        guard let window = NSApplication.shared.keyWindow else { return nil }
        if let responder = window.firstResponder as? NSTextView { return responder }
        return findInWindow(window)
    }

    /// Recursively searches for NSTextView in view hierarchy
    private static func findInViewHierarchy(_ view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        
        for subview in view.subviews {
            if let found = findInViewHierarchy(subview) {
                return found
            }
        }
        
        return nil
    }
}
