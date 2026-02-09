import Foundation
import AppKit

final class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    private let settingsPath: URL
    @Published private(set) var settings = AppSettings() {
        didSet {
            saveSettings()
            applyDockSetting()
        }
    }
    
    private init() {
        self.settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/settings.json")
        loadSettings()
        applyDockSetting()
    }
    
    // MARK: - Public Methods
    
    func updateSetting(_ newSettings: AppSettings) {
        self.settings = newSettings
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        do {
            let folderURL = settingsPath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsPath, options: .atomic)
        } catch {
            // Silently fail - settings are not critical
        }
    }
    
    private func loadSettings() {
        do {
            if FileManager.default.fileExists(atPath: settingsPath.path) {
                let data = try Data(contentsOf: settingsPath)
                settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } else {
                saveSettings()
            }
        } catch {
            // Silently fail - use defaults
        }
    }
    
    private func applyDockSetting() {
        let policy: NSApplication.ActivationPolicy = settings.showInDock || NSApp.keyWindow?.title == "Settings" ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)
    }
}
