import Cocoa
import SwiftUI
import ServiceManagement
import ObjectiveC

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var onboardingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        setupStatusBar()
        setupPopover()
        setupNotifications()
        applyStartupSetting()
        checkAndShowOnboarding()
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
    
    private func checkAndShowOnboarding() {
        let hasCompletedOnboarding = SettingsService.shared.settings.hasCompletedOnboarding
        
        if !hasCompletedOnboarding {
            showOnboardingWindow()
        }
    }
    
    private func showOnboardingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "DropNote Onboarding"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        
        // Modern window styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        
        if #available(macOS 12.0, *) {
            window.toolbarStyle = .unified
        }
        
        window.center()
        
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)
        hostingController.view.wantsLayer = true
        window.contentViewController = hostingController
        
        // Set up window delegate to handle close without completion
        let delegate = OnboardingWindowDelegate()
        window.delegate = delegate
        objc_setAssociatedObject(window, "onboardingDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
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

// MARK: - Onboarding Window Delegate
class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Reset onboarding if window is closed without completing
        guard let window = notification.object as? NSWindow else { return }
        
        // Only reset if onboarding wasn't completed (handled in OnboardingView)
        // The OnboardingView will determine whether to reset or complete based on how it was closed
    }
}
