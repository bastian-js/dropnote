import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showInDock = SettingsService.shared.settings.showInDock
    @State private var startOnBoot = SettingsService.shared.settings.startOnBoot
    @State private var showWordCounter = SettingsService.shared.settings.showWordCounter
    @State private var searchHotKey = SettingsService.shared.settings.searchHotKey
    @State private var themeMode = SettingsService.shared.settings.themeMode
    @State private var showSearchRecentNotes = SettingsService.shared.settings.showSearchRecentNotes
    @State private var showTodoTab = SettingsService.shared.settings.showTodoTab
    @State private var fullWindowHotKey = SettingsService.shared.settings.fullWindowHotKey
    @State private var searchHotKeyError: String? = nil
    @State private var fullWindowHotKeyError: String? = nil
    @State private var isRecordingHotKey = false
    @State private var isRecordingFullWindowHotKey = false
    @State private var hotKeyMonitor: Any?
    @State private var fullWindowHotKeyMonitor: Any?
    @State private var selectedSection: String? = "General"

    private var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return colorScheme
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveColorScheme == .dark
                    ? [Color.black.opacity(0.18), Color.gray.opacity(0.08)]
                    : [Color.white, Color.gray.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Settings")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .padding(.bottom, 2)

                    sectionButton(title: "General", icon: "gearshape", tag: "General")
                    sectionButton(title: "Display", icon: "paintbrush", tag: "Themes")
                    sectionButton(title: "Info", icon: "info.circle", tag: "Info")

                    Spacer()

                    Text("© 2026 DropNote")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .frame(width: 164)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(effectiveColorScheme == .dark
                            ? Color.black.opacity(0.18)
                            : Color.gray.opacity(0.12)
                        )
                )
                .padding(.leading, 8)
                .padding(.vertical, 12)

                Divider()
                    .padding(.vertical, 18)
                    .padding(.horizontal, 10)
                    .opacity(effectiveColorScheme == .dark ? 1 : 0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedSection == "General" {
                            generalSection
                        } else if selectedSection == "Themes" {
                            themesSection
                        } else if selectedSection == "Info" {
                            infoSection
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.vertical, 18)
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            }
            .padding(.trailing, 16)
        }
        .frame(width: 560, height: 380)
        .preferredColorScheme(resolvedThemeColorScheme())
        .onAppear { reloadSettingsFromService() }
        .onDisappear {
            stopRecordingHotKey()
            stopRecordingFullWindowHotKey()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            settingCard(title: "Startup") {
                toggleRow(
                    title: "Launch on start",
                    subtitle: "Open DropNote automatically after login",
                    isOn: $startOnBoot
                ) { updateSetting(startOnBoot: $0) }

                toggleRow(
                    title: "Show in Dock",
                    subtitle: "Keep the app visible in the Dock",
                    isOn: $showInDock
                ) { updateSetting(showInDock: $0) }
            }

            settingCard(title: "Features") {
                toggleRow(
                    title: "Todo tab",
                    subtitle: "Show a todo list as the first tab in the popover",
                    isOn: $showTodoTab
                ) { updateSetting(showTodoTab: $0) }
            }

            settingCard(title: "Shortcuts") {
                shortcutRow(
                    title: "Global search",
                    subtitle: "Open search from anywhere",
                    hotKey: hotKeyDisplayString(searchHotKey),
                    isRecording: isRecordingHotKey,
                    error: searchHotKeyError,
                    onRecord: { isRecordingHotKey ? stopRecordingHotKey() : startRecordingHotKey() }
                )

                Divider().padding(.vertical, 4)

                shortcutRow(
                    title: "Notes window",
                    subtitle: "Open the full notes window",
                    hotKey: hotKeyDisplayString(fullWindowHotKey),
                    isRecording: isRecordingFullWindowHotKey,
                    error: fullWindowHotKeyError,
                    onRecord: { isRecordingFullWindowHotKey ? stopRecordingFullWindowHotKey() : startRecordingFullWindowHotKey() }
                )
            }

            Text("Current version: 2.1")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            settingCard(title: "Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.callout.weight(.semibold))
                    HStack(spacing: 8) {
                        themeModeButton("System", value: "system")
                        themeModeButton("Light", value: "light")
                        themeModeButton("Dark", value: "dark")
                    }
                }
            }

            settingCard(title: "Search") {
                toggleRow(
                    title: "Show recent notes",
                    subtitle: "Display recent notes in global search window",
                    isOn: $showSearchRecentNotes
                ) { updateSetting(showSearchRecentNotes: $0) }
            }

            settingCard(title: "Editor") {
                toggleRow(
                    title: "Word counter",
                    subtitle: "Show word count at the bottom left",
                    isOn: $showWordCounter
                ) { updateSetting(showWordCounter: $0) }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func themeModeButton(_ label: String, value: String) -> some View {
        Button {
            themeMode = value
            updateSetting(themeMode: value)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeMode == value ? Color.accentColor : Color.gray.opacity(0.15))
                )
                .foregroundColor(themeMode == value ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            settingCard(title: "DropNote") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(effectiveColorScheme == .dark ? Color.black.opacity(0.22) : Color.gray.opacity(0.15))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "note.text")
                                    .font(.system(size: 26, weight: .semibold))
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DropNote")
                                .font(.title3.weight(.semibold))
                            Text("Version 2.1")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Text("© 2026 bastian-js")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Quick notes, clean focus, and instant search.")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Label("Fast capture", systemImage: "bolt.fill")
                        Label("Global search", systemImage: "magnifyingglass")
                        Label("Secure notes", systemImage: "lock.fill")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            }
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func sectionButton(title: String, icon: String, tag: String) -> some View {
        let isSelected = selectedSection == tag
        Button { selectedSection = tag } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? (effectiveColorScheme == .dark ? Color.white.opacity(0.18) : Color.gray.opacity(0.15)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(effectiveColorScheme == .dark ? Color.black.opacity(0.15) : Color.gray.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(effectiveColorScheme == .dark ? Color.white.opacity(0.06) : Color.gray.opacity(0.25), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: isOn.wrappedValue) { _, newValue in onChange(newValue) }
        }
    }

    // MARK: - Shortcut Row

    @ViewBuilder
    private func shortcutRow(
        title: String,
        subtitle: String,
        hotKey: String,
        isRecording: Bool,
        error: String?,
        onRecord: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(hotKey)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(effectiveColorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.12)))
                Button(action: onRecord) {
                    Text(isRecording ? "Recording…" : "Record")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isRecording
                                    ? Color.orange.opacity(0.85)
                                    : (effectiveColorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.12)))
                        )
                        .foregroundColor(isRecording ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            if let err = error {
                Text(err)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Settings Methods

    private func reloadSettingsFromService() {
        let s = SettingsService.shared.settings
        showInDock = s.showInDock
        startOnBoot = s.startOnBoot
        showWordCounter = s.showWordCounter
        searchHotKey = s.searchHotKey
        fullWindowHotKey = s.fullWindowHotKey
        themeMode = s.themeMode
        showSearchRecentNotes = s.showSearchRecentNotes
        showTodoTab = s.showTodoTab
    }

    private func updateSetting(
        showInDock: Bool? = nil,
        startOnBoot: Bool? = nil,
        showWordCounter: Bool? = nil,
        searchHotKey: HotKeySettings? = nil,
        fullWindowHotKey: HotKeySettings? = nil,
        themeMode: String? = nil,
        showSearchRecentNotes: Bool? = nil,
        showTodoTab: Bool? = nil
    ) {
        let s = SettingsService.shared.settings
        let updated = AppSettings(
            showInDock: showInDock ?? self.showInDock,
            startOnBoot: startOnBoot ?? self.startOnBoot,
            showWordCounter: showWordCounter ?? self.showWordCounter,
            searchHotKey: searchHotKey ?? self.searchHotKey,
            fullWindowHotKey: fullWindowHotKey ?? self.fullWindowHotKey,
            hasCompletedOnboarding: s.hasCompletedOnboarding,
            themeMode: themeMode ?? self.themeMode,
            showSearchRecentNotes: showSearchRecentNotes ?? self.showSearchRecentNotes,
            showTodoTab: showTodoTab ?? self.showTodoTab,
            sidebarExpanded: s.sidebarExpanded
        )
        SettingsService.shared.updateSetting(updated)
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }

    // MARK: - Hot Key Recording

    private func startRecordingHotKey() {
        searchHotKeyError = nil
        isRecordingHotKey = true
        hotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleRecordedHotKey(event)
            return nil
        }
    }

    private func stopRecordingHotKey() {
        isRecordingHotKey = false
        if let monitor = hotKeyMonitor { NSEvent.removeMonitor(monitor); hotKeyMonitor = nil }
    }

    private func handleRecordedHotKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else {
            searchHotKeyError = "Please include at least one modifier key."
            stopRecordingHotKey(); return
        }
        let modifiers = carbonModifiers(from: flags)
        let keyCode = UInt32(event.keyCode)
        let keyLabel = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(keyCode)"
        let newHotKey = HotKeySettings(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
        if HotKeyManager.shared.updateGlobalSearchHotKey(keyCode: keyCode, modifiers: modifiers) {
            searchHotKey = newHotKey
            updateSetting(searchHotKey: newHotKey)
            searchHotKeyError = nil
        } else {
            searchHotKeyError = "Shortcut already in use. Try another one."
        }
        stopRecordingHotKey()
    }

    private func startRecordingFullWindowHotKey() {
        fullWindowHotKeyError = nil
        isRecordingFullWindowHotKey = true
        fullWindowHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleRecordedFullWindowHotKey(event)
            return nil
        }
    }

    private func stopRecordingFullWindowHotKey() {
        isRecordingFullWindowHotKey = false
        if let monitor = fullWindowHotKeyMonitor { NSEvent.removeMonitor(monitor); fullWindowHotKeyMonitor = nil }
    }

    private func handleRecordedFullWindowHotKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else {
            fullWindowHotKeyError = "Please include at least one modifier key."
            stopRecordingFullWindowHotKey(); return
        }
        let modifiers = carbonModifiers(from: flags)
        let keyCode = UInt32(event.keyCode)
        let keyLabel = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(keyCode)"
        let newHotKey = HotKeySettings(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
        if HotKeyManager.shared.updateFullWindowHotKey(keyCode: keyCode, modifiers: modifiers) {
            fullWindowHotKey = newHotKey
            updateSetting(fullWindowHotKey: newHotKey)
            fullWindowHotKeyError = nil
        } else {
            fullWindowHotKeyError = "Shortcut already in use. Try another one."
        }
        stopRecordingFullWindowHotKey()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option)  { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift)   { modifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    private func hotKeyDisplayString(_ hotKey: HotKeySettings) -> String {
        var parts: [String] = []
        if hotKey.modifiers & UInt32(cmdKey)    != 0 { parts.append("Cmd") }
        if hotKey.modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if hotKey.modifiers & UInt32(shiftKey)  != 0 { parts.append("Shift") }
        if hotKey.modifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        parts.append(hotKey.keyLabel.isEmpty ? "Key \(hotKey.keyCode)" : hotKey.keyLabel)
        return parts.joined(separator: "+")
    }

    private func resolvedThemeColorScheme() -> ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
