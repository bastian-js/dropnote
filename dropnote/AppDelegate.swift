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
        configureMainMenu()
        setupPopover()
        setupNotifications()
        applyStartupSetting()
        checkAndShowOnboarding()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
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

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        // ── App menu ──────────────────────────────────────────────────
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "DropNote"

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(showAbout(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Notes Window", action: #selector(openFullWindow(_:)), keyEquivalent: "1"))
        appMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(hideApp(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitApp(_:)), keyEquivalent: "q"))
        appMenu.items.forEach { $0.target = self }

        // ── Format menu ───────────────────────────────────────────────
        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        let boldItem = NSMenuItem(title: "Bold", action: NSSelectorFromString("bold:"), keyEquivalent: "b")
        boldItem.keyEquivalentModifierMask = .command

        let italicItem = NSMenuItem(title: "Italic", action: NSSelectorFromString("italic:"), keyEquivalent: "i")
        italicItem.keyEquivalentModifierMask = .command

        let underlineItem = NSMenuItem(title: "Underline", action: NSSelectorFromString("underline:"), keyEquivalent: "u")
        underlineItem.keyEquivalentModifierMask = .command

        formatMenu.addItem(boldItem)
        formatMenu.addItem(italicItem)
        formatMenu.addItem(underlineItem)
        formatMenu.addItem(.separator())

        let newNoteItem = NSMenuItem(title: "New Note", action: #selector(newNoteFromMenu(_:)), keyEquivalent: "n")
        newNoteItem.keyEquivalentModifierMask = .command
        newNoteItem.target = self
        formatMenu.addItem(newNoteItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        let hotKey = SettingsService.shared.settings.searchHotKey
        HotKeyManager.shared.registerGlobalSearchHotKey(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)

        let fwHotKey = SettingsService.shared.settings.fullWindowHotKey
        HotKeyManager.shared.registerFullWindowHotKey(keyCode: fwHotKey.keyCode, modifiers: fwHotKey.modifiers)

        DispatchQueue.global(qos: .userInitiated).async {
            NoteSearchService.shared.indexNotes()
        }
    }

    @objc private func handleAppDidResignActive() {
        popover.performClose(nil)
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApplication.shared.orderFrontStandardAboutPanel(sender)
    }

    @objc private func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func openFullWindow(_ sender: Any?) {
        FullWindowController.shared.show()
    }

    @objc private func newNoteFromMenu(_ sender: Any?) {
        // If full window is visible, tell it to create a new note
        NotificationCenter.default.post(name: Notification.Name("NewNoteRequested"), object: nil)
    }

    @objc private func hideApp(_ sender: Any?) {
        NSApplication.shared.hide(sender)
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }

    private func applyStartupSetting() {
        setLaunchAtLogin(enabled: SettingsService.shared.settings.startOnBoot)
    }

    private func checkAndShowOnboarding() {
        if !SettingsService.shared.settings.hasCompletedOnboarding {
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        if #available(macOS 12.0, *) { window.toolbarStyle = .unified }
        window.center()

        let hostingController = NSHostingController(rootView: OnboardingView())
        hostingController.view.wantsLayer = true
        window.contentViewController = hostingController

        let delegate = OnboardingWindowDelegate()
        window.delegate = delegate
        objc_setAssociatedObject(window, "onboardingDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {}
    }
}

// MARK: - Onboarding Window Delegate

class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {}
}
