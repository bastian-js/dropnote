import SwiftUI

struct ColorSchemeHelper {
    @Environment(\.colorScheme) var colorScheme
    
    /// Border color that adapts to light/dark mode
    static func borderColor() -> Color {
        Color.gray.opacity(0.3)
    }
    
    /// Input field background that adapts to light/dark mode
    static func inputBackground() -> Color {
        Color(nsColor: NSColor(calibratedWhite: 0, alpha: 0.05))
    }
    
    /// Tab background when selected
    static func selectedTabBackground() -> Color {
        Color.accentColor.opacity(0.2)
    }
    
    /// Subtle divider color
    static func dividerColor() -> Color {
        Color.gray.opacity(0.25)
    }
    
    /// Toolbar separators
    static func toolbarSeparator() -> Color {
        Color.gray.opacity(0.35)
    }
}
