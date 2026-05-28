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
    var showTranscriptionTab: Bool = true
    var sidebarExpanded: Bool = true
    var userTags: [String] = ["Work", "Personal", "Urgent"]
    var popoverWidth: Double = 320
    var popoverHeight: Double = 480
    var popoverSizeLocked: Bool = false
    var showEditorToolbar: Bool = true

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
        showTranscriptionTab   = try c.decodeIfPresent(Bool.self,           forKey: .showTranscriptionTab)   ?? true
        sidebarExpanded        = try c.decodeIfPresent(Bool.self,           forKey: .sidebarExpanded)        ?? true
        userTags               = try c.decodeIfPresent([String].self,       forKey: .userTags)               ?? ["Work", "Personal", "Urgent"]
        popoverWidth           = try c.decodeIfPresent(Double.self,         forKey: .popoverWidth)           ?? 320
        popoverHeight          = try c.decodeIfPresent(Double.self,         forKey: .popoverHeight)          ?? 480
        popoverSizeLocked      = try c.decodeIfPresent(Bool.self,           forKey: .popoverSizeLocked)      ?? false
        showEditorToolbar      = try c.decodeIfPresent(Bool.self,           forKey: .showEditorToolbar)      ?? true
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
        showTranscriptionTab: Bool = true,
        sidebarExpanded: Bool = true,
        userTags: [String] = ["Work", "Personal", "Urgent"],
        popoverWidth: Double = 320,
        popoverHeight: Double = 480,
        popoverSizeLocked: Bool = false,
        showEditorToolbar: Bool = true
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
        self.showTranscriptionTab = showTranscriptionTab
        self.sidebarExpanded = sidebarExpanded
        self.userTags = userTags
        self.popoverWidth = popoverWidth
        self.popoverHeight = popoverHeight
        self.popoverSizeLocked = popoverSizeLocked
        self.showEditorToolbar = showEditorToolbar
    }
}
