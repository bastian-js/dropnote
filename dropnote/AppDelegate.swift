import Cocoa
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        setupStatusBar()
        setupPopover()
        setupNotifications()
        applyStartupSetting()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        HotKeyManager.shared.unregisterGlobalSearchHotKey()
    }
    
    // MARK: - Private Methods
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenubarIcon")
            button.image?.size = NSSize(width: 14, height: 14)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        let hotKey = SettingsService.shared.settings.searchHotKey
        HotKeyManager.shared.registerGlobalSearchHotKey(
            keyCode: hotKey.keyCode,
            modifiers: hotKey.modifiers
        )
        
        // Initialize search index
        DispatchQueue.global(qos: .userInitiated).async {
            NoteSearchService.shared.indexNotes()
        }
    }
    
    @objc private func handleAppDidResignActive() {
        popover.performClose(nil)
    }
    
    private func applyStartupSetting() {
        let shouldStartOnBoot = SettingsService.shared.settings.startOnBoot
        setLaunchAtLogin(enabled: shouldStartOnBoot)
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail - login launch is not critical
        }
    }
}
