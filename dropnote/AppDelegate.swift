import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        applyStartupSetting()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
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
    }
}
