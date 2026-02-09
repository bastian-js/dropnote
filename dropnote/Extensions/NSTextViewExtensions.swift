import AppKit

extension NSTextView {
    /// Returns the first NSTextView found in the view hierarchy of a window
    static func findInWindow(_ window: NSWindow) -> NSTextView? {
        guard let contentView = window.contentView else {
            return nil
        }
        return findInViewHierarchy(contentView)
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
