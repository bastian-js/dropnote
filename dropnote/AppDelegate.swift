import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenubarIcon")
            button.image?.size = NSSize(width: 14, height: 14)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
        }
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        // Register global search hotkey (CMD+OPTION+F)
        HotKeyManager.shared.registerGlobalSearchHotKey()
        
        // Initialize search index
        DispatchQueue.global(qos: .userInitiated).async {
            SearchIndexManager.shared.indexNotes()
        }
        
        applyStartupSetting()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        print("togglePopover called, isShown: \(popover.isShown)")
        if let button = statusItem.button {
            if popover.isShown {
                print("Closing popover")
                popover.performClose(sender)
            } else {
                print("Opening popover")
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                print("Popover should now be visible: \(popover.isShown)")
            }
        } else {
            print("No status item button found!")
        }
    }

    @objc private func handleAppDidResignActive() {
        popover.performClose(nil)
    }
    
    func applyStartupSetting() {
        let shouldStartOnBoot = SettingsManager.shared.settings.startOnBoot
        setLaunchAtLogin(enabled: shouldStartOnBoot)
    }

    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        HotKeyManager.shared.unregisterGlobalSearchHotKey()
    }
}
