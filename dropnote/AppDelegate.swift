//
//  AppDelegate.swift
//  dropnote
//
//  Created by bastian-js on 10.03.25.
//

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
            button.image?.isTemplate = false
            button.action = #selector(togglePopover(_:))
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        applyStartupSetting() // ⬅️ Autostart prüfen & setzen
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
    
    func applyStartupSetting() {
        let shouldStartOnBoot = SettingsManager.shared.settings.startOnBoot
        print("🌀 Startup setting =", shouldStartOnBoot)
        setLaunchAtLogin(enabled: shouldStartOnBoot)
    }

    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ App registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                print("⛔️ App unregistered from launch at login")
            }
        } catch {
            print("❌ Autostart error:", error.localizedDescription)
        }
    }
}
