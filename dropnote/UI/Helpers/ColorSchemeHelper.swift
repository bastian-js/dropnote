import SwiftUI

struct ColorSchemeHelper {
    /// Border color that adapts to light/dark mode
    static func borderColor() -> Color {
        Color(nsColor: .separatorColor).opacity(0.75)
    }
    
    /// Input field background that adapts to light/dark mode
    static func inputBackground() -> Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// Search field background with stronger light-mode contrast
    static func searchFieldBackground() -> Color {
        Color(nsColor: .textBackgroundColor)
    }

    /// Search field border with visible light-mode edge
    static func searchFieldBorder() -> Color {
        Color(nsColor: .separatorColor).opacity(0.9)
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
