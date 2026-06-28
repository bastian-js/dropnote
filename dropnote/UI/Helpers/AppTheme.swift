import SwiftUI
import AppKit
import Combine

/// Central place for the user-selectable accent color. Views read `AppTheme.shared`
/// and apply `.appAccent()` at their root so every `Color.accentColor` / tinted
/// control downstream picks up the custom color.
final class AppTheme: ObservableObject {
    static let shared = AppTheme()

    @Published var accentHex: String

    private var cancellable: AnyCancellable?

    private init() {
        accentHex = SettingsService.shared.settings.accentColorHex
        // Keep in sync if settings change elsewhere.
        cancellable = SettingsService.shared.$settings
            .map(\.accentColorHex)
            .removeDuplicates()
            .sink { [weak self] hex in self?.accentHex = hex }
    }

    /// Resolved accent color, or nil to fall back to the system accent.
    var accentColor: Color? {
        Color(hex: accentHex)
    }

    /// AppKit accent color, falling back to the system accent when unset.
    var accentNSColor: NSColor {
        NSColor(hex: accentHex) ?? .controlAccentColor
    }

    /// Curated palette shown in Settings.
    static let palette: [String] = [
        "#0A84FF", // blue (default-ish)
        "#5E5CE6", // indigo
        "#BF5AF2", // purple
        "#FF2D55", // pink
        "#FF453A", // red
        "#FF9F0A", // orange
        "#FFD60A", // yellow
        "#30D158", // green
        "#64D2FF", // teal
        "#8E8E93"  // graphite
    ]
}

extension Color {
    /// Parses "#RRGGBB" / "RRGGBB" (and "#RRGGBBAA"). Returns nil for empty/invalid.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }

        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Best-effort "#RRGGBB" string for an sRGB color.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        guard let color = Color(hex: hex) else { return nil }
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(srgbRed: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }
}

private struct AppAccentModifier: ViewModifier {
    @ObservedObject private var theme = AppTheme.shared

    func body(content: Content) -> some View {
        if let accent = theme.accentColor {
            content
                .tint(accent)
                .accentColor(accent)
        } else {
            content
        }
    }
}

extension View {
    /// Applies the user's custom accent color (if set) to this subtree.
    func appAccent() -> some View {
        modifier(AppAccentModifier())
    }
}
