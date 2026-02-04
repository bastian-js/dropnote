import Foundation
import AppKit

struct AppSettings: Codable {
    var showInDock: Bool = true
    var startOnBoot: Bool = false
    var showWordCounter: Bool = true
}

class SettingsManager {
    static let shared = SettingsManager()
    private let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/settings.json")

    private init() {
        loadSettings()
        applyDockSetting()
    }

    private(set) var settings = AppSettings() {
        didSet {
            saveSettings()
            applyDockSetting()
        }
    }

    func updateSetting(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    func saveSettings() {
        do {
            let folderURL = settingsPath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsPath, options: .atomic)
        } catch {
        }
    }

    func loadSettings() {
        do {
            if FileManager.default.fileExists(atPath: settingsPath.path) {
                let data = try Data(contentsOf: settingsPath)
                settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } else {
                saveSettings()
            }
        } catch {
        }
    }

    private func applyDockSetting() {
        let policy: NSApplication.ActivationPolicy = settings.showInDock || NSApp.keyWindow?.title == "Settings" ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)
    }
}
