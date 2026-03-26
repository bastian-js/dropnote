import Foundation
import Carbon

struct HotKeySettings: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String
    
    static let `default` = HotKeySettings(
        keyCode: 3,
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "F"
    )
}

struct AppSettings: Codable {
    var showInDock: Bool = true
    var startOnBoot: Bool = false
    var showWordCounter: Bool = true
    var searchHotKey: HotKeySettings = .default
    var hasCompletedOnboarding: Bool = false
    var themeMode: String = "system" // "system", "light", "dark"
    var showSearchRecentNotes: Bool = true // true = show input + recent notes, false = show only input
}
