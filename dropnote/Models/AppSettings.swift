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

    static let defaultFullWindow = HotKeySettings(
        keyCode: 45, // N key
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "N"
    )
}

struct AppSettings: Codable {
    var showInDock: Bool = true
    var startOnBoot: Bool = false
    var showWordCounter: Bool = true
    var searchHotKey: HotKeySettings = .default
    var fullWindowHotKey: HotKeySettings = .defaultFullWindow
    var hasCompletedOnboarding: Bool = false
    var themeMode: String = "system"
    var showSearchRecentNotes: Bool = true
    var showTodoTab: Bool = true
    var sidebarExpanded: Bool = true

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showInDock             = try c.decodeIfPresent(Bool.self,           forKey: .showInDock)             ?? true
        startOnBoot            = try c.decodeIfPresent(Bool.self,           forKey: .startOnBoot)            ?? false
        showWordCounter        = try c.decodeIfPresent(Bool.self,           forKey: .showWordCounter)        ?? true
        searchHotKey           = try c.decodeIfPresent(HotKeySettings.self, forKey: .searchHotKey)           ?? .default
        fullWindowHotKey       = try c.decodeIfPresent(HotKeySettings.self, forKey: .fullWindowHotKey)       ?? .defaultFullWindow
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self,           forKey: .hasCompletedOnboarding) ?? false
        themeMode              = try c.decodeIfPresent(String.self,         forKey: .themeMode)              ?? "system"
        showSearchRecentNotes  = try c.decodeIfPresent(Bool.self,           forKey: .showSearchRecentNotes)  ?? true
        showTodoTab            = try c.decodeIfPresent(Bool.self,           forKey: .showTodoTab)            ?? true
        sidebarExpanded        = try c.decodeIfPresent(Bool.self,           forKey: .sidebarExpanded)        ?? true
    }

    init(
        showInDock: Bool = true,
        startOnBoot: Bool = false,
        showWordCounter: Bool = true,
        searchHotKey: HotKeySettings = .default,
        fullWindowHotKey: HotKeySettings = .defaultFullWindow,
        hasCompletedOnboarding: Bool = false,
        themeMode: String = "system",
        showSearchRecentNotes: Bool = true,
        showTodoTab: Bool = true,
        sidebarExpanded: Bool = true
    ) {
        self.showInDock = showInDock
        self.startOnBoot = startOnBoot
        self.showWordCounter = showWordCounter
        self.searchHotKey = searchHotKey
        self.fullWindowHotKey = fullWindowHotKey
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.themeMode = themeMode
        self.showSearchRecentNotes = showSearchRecentNotes
        self.showTodoTab = showTodoTab
        self.sidebarExpanded = sidebarExpanded
    }
}
