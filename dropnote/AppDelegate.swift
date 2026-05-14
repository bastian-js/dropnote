import Cocoa
import SwiftUI
import ServiceManagement
import ObjectiveC

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var onboardingWindow: NSWindow?

    private var popoverKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        setupStatusBar()
        configureMainMenu()
        setupPopover()
        setupNotifications()
        setupPopoverKeyMonitor()
        applyStartupSetting()
        checkAndShowOnboarding()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the window key AND make the NSTextView first responder so that
            // keyboard shortcuts (Cmd+V etc.) reach it without requiring a click first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let window = self.popover.contentViewController?.view.window else { return }
                window.makeKey()
                if let tv = NSTextView.findInWindow(window) {
                    window.makeFirstResponder(tv)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        HotKeyManager.shared.unregisterGlobalSearchHotKey()
        if let m = popoverKeyMonitor { NSEvent.removeMonitor(m) }
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
        #if DEBUG
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "⚙︎ Reset Onboarding", action: #selector(devResetOnboarding(_:)), keyEquivalent: ""))
        #endif
        appMenu.items.forEach { $0.target = self }

        // ── Edit menu ─────────────────────────────────────────────────
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

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

    private func setupPopoverKeyMonitor() {
        // Fallback for when makeKey() loses the race or canBecomeKey returns false.
        // IMPORTANT: only intercept when the popover window is the key window (or
        // no window is key). If any other window (e.g. the full notes window) is key
        // we must let events flow normally so that window's text view can handle them.
        popoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.popover.isShown,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let ch = event.charactersIgnoringModifiers,
                  let popoverWindow = self.popover.contentViewController?.view.window else { return event }

            let keyWindow = NSApp.keyWindow
            guard keyWindow == nil || keyWindow == popoverWindow else { return event }

            guard let tv = NSTextView.findInWindow(popoverWindow) else { return event }

            switch ch {
            case "v": tv.paste(nil)
            case "c": tv.copy(nil)
            case "x": tv.cut(nil)
            case "a": tv.selectAll(nil)
            case "z":
                if event.modifierFlags.contains(.shift) { tv.undoManager?.redo() }
                else { tv.undoManager?.undo() }
            default: return event
            }
            return nil
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            SettingsService.shared.reapplyActivationPolicy()
        }
    }

    @objc private func showAbout(_ sender: Any?) {
        AboutWindowController.shared.show()
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

    #if DEBUG
    @objc private func devResetOnboarding(_ sender: Any?) {
        var s = SettingsService.shared.settings
        s.hasCompletedOnboarding = false
        SettingsService.shared.updateSetting(s)
        showOnboardingWindow()
    }
    #endif

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
        guard #available(macOS 13.0, *) else { return }
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
