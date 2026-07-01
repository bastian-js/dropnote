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
    @State private var showTodoTabTitle = SettingsService.shared.settings.showTodoTabTitle
    @State private var showTranscriptionTab = SettingsService.shared.settings.showTranscriptionTab
    @State private var showTranscriptionTabTitle = SettingsService.shared.settings.showTranscriptionTabTitle
    @State private var fullWindowHotKey = SettingsService.shared.settings.fullWindowHotKey
    @State private var searchHotKeyError: String? = nil
    @State private var fullWindowHotKeyError: String? = nil
    @State private var isRecordingHotKey = false
    @State private var isRecordingFullWindowHotKey = false
    @State private var hotKeyMonitor: Any?
    @State private var fullWindowHotKeyMonitor: Any?
    @State private var popoverSizeLocked = SettingsService.shared.settings.popoverSizeLocked
    @State private var showEditorToolbar = SettingsService.shared.settings.showEditorToolbar
    @State private var accentColorHex = SettingsService.shared.settings.accentColorHex
    @State private var showTodoBadge = SettingsService.shared.settings.showTodoBadge
    @State private var showColorPopover = false
    @State private var noteRelockMode = SettingsService.shared.settings.noteRelockMode
    @State private var noteRelockMinutes = SettingsService.shared.settings.noteRelockMinutes
    @State private var userTags: [String] = SettingsService.shared.settings.userTags
    @State private var newTagInput: String = ""
    @State private var selectedSection: String? = "General"
    @State private var dangerAlert: DangerAlert? = nil

    enum DangerAlert: Identifiable {
        case deleteNotes, resetSettings, deleteEverything
        var id: Int { hashValue }
    }

    private var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return colorScheme
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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

                    sectionButton(title: "Danger Zone", icon: "exclamationmark.triangle.fill", tag: "Danger", destructive: true)

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
                        } else if selectedSection == "Danger" {
                            dangerSection
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.vertical, 18)
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            }
            .padding(.trailing, 16)
        }
        .frame(minWidth: 680, idealWidth: 720, maxWidth: .infinity,
               minHeight: 500, idealHeight: 540, maxHeight: .infinity)
        .appAccent()
        .preferredColorScheme(resolvedThemeColorScheme())
        .onAppear { reloadSettingsFromService() }
        .alert(item: $dangerAlert) { alert in
            switch alert {
            case .deleteNotes:
                return Alert(
                    title: Text("Delete all notes?"),
                    message: Text("All notes will be permanently deleted. This cannot be undone."),
                    primaryButton: .destructive(Text("Delete All")) { performDeleteNotes() },
                    secondaryButton: .cancel()
                )
            case .resetSettings:
                return Alert(
                    title: Text("Reset all settings?"),
                    message: Text("All settings will be restored to their defaults."),
                    primaryButton: .destructive(Text("Reset")) { performResetSettings() },
                    secondaryButton: .cancel()
                )
            case .deleteEverything:
                return Alert(
                    title: Text("Delete everything?"),
                    message: Text("All notes, todos, and settings will be wiped. DropNote will be in a clean state. This cannot be undone."),
                    primaryButton: .destructive(Text("Wipe Everything")) { performDeleteEverything() },
                    secondaryButton: .cancel()
                )
            }
        }
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
                    subtitle: "Off: menu bar only — hidden from the Dock and ⌘-Tab",
                    isOn: $showInDock
                ) { newValue in
                    updateSetting(showInDock: newValue)
                    // Switching to accessory reorders the app's windows and drops this
                    // one behind others — pull it back to the front so it stays put.
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        SettingsWindowController.shared.window?.makeKeyAndOrderFront(nil)
                    }
                }
            }

            settingCard(title: "Todo Tab") {
                toggleRow(
                    title: "Show todo tab",
                    subtitle: "Show a todo list as the first tab in the popover",
                    isOn: $showTodoTab
                ) { updateSetting(showTodoTab: $0) }

                Divider().padding(.vertical, 4)

                toggleRow(
                    title: "Show tab title",
                    subtitle: "Show the “Todos” label next to the icon (off = icon only)",
                    isOn: $showTodoTabTitle
                ) { updateSetting(showTodoTabTitle: $0) }

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.callout.weight(.semibold))
                    tagsEditor
                }
            }

            settingCard(title: "Transcription") {
                toggleRow(
                    title: "Show transcription tab",
                    subtitle: "Show a mic tab to transcribe speech into text",
                    isOn: $showTranscriptionTab
                ) { updateSetting(showTranscriptionTab: $0) }

                Divider().padding(.vertical, 4)

                toggleRow(
                    title: "Show tab title",
                    subtitle: "Show the “Transcribe” label next to the icon (off = icon only)",
                    isOn: $showTranscriptionTabTitle
                ) { updateSetting(showTranscriptionTabTitle: $0) }
            }

            settingCard(title: "Menu Bar") {
                toggleRow(
                    title: "Todo badge",
                    subtitle: "Show a dot in your accent color on the menu bar icon when todos are open",
                    isOn: $showTodoBadge
                ) { updateSetting(showTodoBadge: $0) }
            }

            settingCard(title: "Note Lock") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Re-lock an unlocked note…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)

                    lockModeRow("When switching notes", "onSwitch")
                    lockModeRow("After a set time", "timer")
                    lockModeRow("When the popover closes", "onPopoverClose")
                    lockModeRow("Only when the app restarts", "onAppRestart")

                    if noteRelockMode == "timer" {
                        Divider().padding(.vertical, 6)
                        HStack {
                            Text("Re-lock after")
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Stepper("\(noteRelockMinutes) min", value: $noteRelockMinutes, in: 1...120)
                                .onChange(of: noteRelockMinutes) { _, v in updateSetting(noteRelockMinutes: v) }
                                .fixedSize()
                        }
                    }
                }
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

            Text("Current version: \(appVersion)")
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

                    Divider().padding(.vertical, 2)

                    accentColorPicker
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

                Divider().padding(.vertical, 4)

                toggleRow(
                    title: "Action toolbar",
                    subtitle: "Show the note action bar at the bottom of the popover",
                    isOn: $showEditorToolbar
                ) { updateSetting(showEditorToolbar: $0) }
            }

            settingCard(title: "Popover") {
                toggleRow(
                    title: "Lock size",
                    subtitle: "Prevent the popover from being resized by dragging",
                    isOn: $popoverSizeLocked
                ) { updateSetting(popoverSizeLocked: $0) }

                Divider().padding(.vertical, 4)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset size")
                            .font(.callout.weight(.semibold))
                        Text("Restore to default 320 × 480")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        let defaultSize = CGSize(width: 320, height: 480)
                        var s = SettingsService.shared.settings
                        s.popoverWidth = 320
                        s.popoverHeight = 480
                        SettingsService.shared.updateSetting(s)
                        AppDelegate.shared?.popover?.contentSize = defaultSize
                        NotificationCenter.default.post(name: Notification.Name("PopoverSizeReset"), object: defaultSize)
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(effectiveColorScheme == .dark ? 0.18 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Danger Zone")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundColor(.red)

            settingCard(title: "Data") {
                dangerRow(
                    title: "Delete all notes",
                    subtitle: "Permanently removes every note. Cannot be undone.",
                    icon: "note.text",
                    action: { dangerAlert = .deleteNotes }
                )

                Divider().padding(.vertical, 4)

                dangerRow(
                    title: "Delete all todos",
                    subtitle: "Clears the entire todo list permanently.",
                    icon: "checkmark.circle",
                    action: { performDeleteTodos() }
                )
            }

            settingCard(title: "Settings") {
                dangerRow(
                    title: "Reset all settings",
                    subtitle: "Restores every setting to its factory default.",
                    icon: "gearshape",
                    action: { dangerAlert = .resetSettings }
                )
            }

            settingCard(title: "Nuclear") {
                dangerRow(
                    title: "Wipe everything",
                    subtitle: "Deletes all notes, todos, and settings. Clean slate.",
                    icon: "trash",
                    prominent: true,
                    action: { dangerAlert = .deleteEverything }
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func dangerRow(
        title: String,
        subtitle: String,
        icon: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: action) {
                Label(prominent ? "Wipe" : "Delete", systemImage: prominent ? "trash.fill" : "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(effectiveColorScheme == .dark ? 0.18 : 0.1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Danger Actions

    private func performDeleteNotes() {
        NotesFileService.shared.saveNotes([])
        NoteSearchService.shared.indexNotes(with: [])
        NotificationCenter.default.post(name: Notification.Name("NotesWiped"), object: nil)
    }

    private func performDeleteTodos() {
        TodoFileService.shared.todos = []
        TodoFileService.shared.save()
    }

    private func performResetSettings() {
        let fresh = AppSettings()
        SettingsService.shared.updateSetting(fresh)
        reloadSettingsFromService()
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }

    private func performDeleteEverything() {
        performDeleteNotes()
        performDeleteTodos()
        performResetSettings()
        // Clean slate → take the user back through onboarding.
        NotificationCenter.default.post(name: Notification.Name("ShowOnboardingRequested"), object: nil)
    }

    @ViewBuilder
    private var accentColorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Accent color")
                    .font(.callout.weight(.semibold))
                Spacer()
                if !accentColorHex.isEmpty {
                    Button("Reset") { setAccent("") }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                // System default swatch
                accentSwatch(hex: "", isSystem: true)

                ForEach(AppTheme.palette, id: \.self) { hex in
                    accentSwatch(hex: hex, isSystem: false)
                }

                Spacer(minLength: 0)

                Button {
                    showColorPopover.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                center: .center
                            ))
                            .frame(width: 20, height: 20)
                        Image(systemName: "eyedropper")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 1)
                        Circle()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            .frame(width: 24, height: 24)
                    }
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Custom color")
                .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                    CustomAccentPicker(current: accentColorHex) { hex in
                        setAccent(hex)
                    }
                    .appAccent()
                }
            }
        }
    }

    @ViewBuilder
    private func accentSwatch(hex: String, isSystem: Bool) -> some View {
        let isSelected = accentColorHex.caseInsensitiveCompare(hex) == .orderedSame
        Button {
            setAccent(hex)
        } label: {
            ZStack {
                Circle()
                    .fill(isSystem ? Color.accentColor : (Color(hex: hex) ?? .gray))
                    .frame(width: 20, height: 20)
                if isSystem {
                    Image(systemName: "a.circle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                Circle()
                    .stroke(Color.primary.opacity(isSelected ? 0.9 : 0.12), lineWidth: isSelected ? 2 : 1)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(isSystem ? "System" : hex)
    }

    private func setAccent(_ hex: String) {
        accentColorHex = hex
        updateSetting(accentColorHex: hex)
    }

    @ViewBuilder
    private func lockModeRow(_ title: String, _ value: String) -> some View {
        let isSelected = noteRelockMode == value
        Button {
            noteRelockMode = value
            updateSetting(noteRelockMode: value)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

            // Hero card
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 14, x: 0, y: 8)
                    Image(systemName: "note.text")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text("DropNote")
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("Version \(appVersion)")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("Quick notes, clean focus, and instant search.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(effectiveColorScheme == .dark ? Color.black.opacity(0.15) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(effectiveColorScheme == .dark ? Color.white.opacity(0.06) : Color.gray.opacity(0.22), lineWidth: 1)
                    )
            )

            // Links
            settingCard(title: "Links") {
                VStack(spacing: 2) {
                    infoLinkRow(
                        title: "Website",
                        subtitle: "dropnote.dev",
                        icon: "globe",
                        url: "https://dropnote.dev"
                    )
                    Divider().padding(.vertical, 2)
                    infoLinkRow(
                        title: "GitHub",
                        subtitle: "bastian-js/dropnote",
                        icon: "chevron.left.forwardslash.chevron.right",
                        url: "https://github.com/bastian-js/dropnote"
                    )
                    Divider().padding(.vertical, 2)
                    infoLinkRow(
                        title: "Report an issue",
                        subtitle: "Found a bug? Let me know",
                        icon: "ladybug",
                        url: "https://github.com/bastian-js/dropnote/issues/new/choose"
                    )
                }
            }

            // Developer
            settingCard(title: "Developer") {
                infoLinkRow(
                    title: "Made by bastian-js",
                    subtitle: "bbastian.dev",
                    icon: "person.crop.circle",
                    url: "https://bbastian.dev"
                )
            }

            Text("© 2026 bastian-js · All rights reserved")
                .font(.footnote)
                .foregroundColor(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func infoLinkRow(title: String, subtitle: String, icon: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) { NSWorkspace.shared.open(link) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func sectionButton(title: String, icon: String, tag: String, destructive: Bool = false) -> some View {
        let isSelected = selectedSection == tag
        Button { selectedSection = tag } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(destructive ? .red : .primary)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(destructive ? .red : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? (destructive
                            ? Color.red.opacity(effectiveColorScheme == .dark ? 0.22 : 0.12)
                            : (effectiveColorScheme == .dark ? Color.white.opacity(0.18) : Color.gray.opacity(0.15)))
                        : Color.clear)
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
    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if userTags.isEmpty {
                Text("No tags yet. Add one below.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(userTags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Button {
                            userTags.removeAll { $0 == tag }
                            updateSetting(userTags: userTags)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
            }

            HStack(spacing: 8) {
                TextField("New tag…", text: $newTagInput)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(effectiveColorScheme == .dark
                                ? Color.white.opacity(0.06)
                                : Color.gray.opacity(0.1))
                    )
                    .onSubmit { addTag() }

                let isTagEmpty = newTagInput.trimmingCharacters(in: .whitespaces).isEmpty
                Button { addTag() } label: {
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isTagEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isTagEmpty)
            }
        }
    }

    private func addTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !userTags.contains(trimmed) else { return }
        userTags.append(trimmed)
        updateSetting(userTags: userTags)
        newTagInput = ""
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
        showTodoTabTitle = s.showTodoTabTitle
        showTranscriptionTab = s.showTranscriptionTab
        showTranscriptionTabTitle = s.showTranscriptionTabTitle
        popoverSizeLocked = s.popoverSizeLocked
        showEditorToolbar = s.showEditorToolbar
        userTags = s.userTags
        accentColorHex = s.accentColorHex
        showTodoBadge = s.showTodoBadge
        noteRelockMode = s.noteRelockMode
        noteRelockMinutes = s.noteRelockMinutes
    }

    private func updateSetting(
        showInDock: Bool? = nil,
        startOnBoot: Bool? = nil,
        showWordCounter: Bool? = nil,
        searchHotKey: HotKeySettings? = nil,
        fullWindowHotKey: HotKeySettings? = nil,
        themeMode: String? = nil,
        showSearchRecentNotes: Bool? = nil,
        showTodoTab: Bool? = nil,
        showTodoTabTitle: Bool? = nil,
        showTranscriptionTab: Bool? = nil,
        showTranscriptionTabTitle: Bool? = nil,
        popoverSizeLocked: Bool? = nil,
        showEditorToolbar: Bool? = nil,
        userTags: [String]? = nil,
        accentColorHex: String? = nil,
        showTodoBadge: Bool? = nil,
        noteRelockMode: String? = nil,
        noteRelockMinutes: Int? = nil
    ) {
        var s = SettingsService.shared.settings
        if let v = showInDock            { s.showInDock = v }
        if let v = startOnBoot           { s.startOnBoot = v }
        if let v = showWordCounter       { s.showWordCounter = v }
        if let v = searchHotKey          { s.searchHotKey = v }
        if let v = fullWindowHotKey      { s.fullWindowHotKey = v }
        if let v = themeMode             { s.themeMode = v }
        if let v = showSearchRecentNotes { s.showSearchRecentNotes = v }
        if let v = showTodoTab           { s.showTodoTab = v }
        if let v = showTodoTabTitle      { s.showTodoTabTitle = v }
        if let v = showTranscriptionTab  { s.showTranscriptionTab = v }
        if let v = showTranscriptionTabTitle { s.showTranscriptionTabTitle = v }
        if let v = popoverSizeLocked     { s.popoverSizeLocked = v }
        if let v = showEditorToolbar     { s.showEditorToolbar = v }
        if let v = userTags              { s.userTags = v }
        if let v = accentColorHex        { s.accentColorHex = v }
        if let v = showTodoBadge         { s.showTodoBadge = v }
        if let v = noteRelockMode        { s.noteRelockMode = v }
        if let v = noteRelockMinutes     { s.noteRelockMinutes = v }
        SettingsService.shared.updateSetting(s)
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

// MARK: - Custom Accent Picker

/// A fully custom color picker (no AppKit `NSColorPanel`) that matches the app's
/// look: a generated spectrum grid, a grayscale row, and a hex field.
private struct CustomAccentPicker: View {
    let current: String
    let onSelect: (String) -> Void

    @State private var hexInput: String

    init(current: String, onSelect: @escaping (String) -> Void) {
        self.current = current
        self.onSelect = onSelect
        _hexInput = State(initialValue: current.hasPrefix("#") ? String(current.dropFirst()) : current)
    }

    private let hues: [Double] = (0..<12).map { Double($0) / 12.0 }
    private let brightnessLevels: [Double] = [1.0, 0.82, 0.6]
    private let saturation: Double = 0.85

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom color")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 5) {
                ForEach(brightnessLevels.indices, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(hues.indices, id: \.self) { col in
                            swatch(Color(hue: hues[col], saturation: saturation, brightness: brightnessLevels[row]))
                        }
                    }
                }
                HStack(spacing: 5) {
                    ForEach(0..<12, id: \.self) { i in
                        swatch(Color(hue: 0, saturation: 0, brightness: Double(i) / 11.0))
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("#")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("RRGGBB", text: $hexInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                    .onSubmit { applyHex() }

                Button { applyHex() } label: {
                    Text("Apply")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isValidHex ? Color.accentColor : Color.gray.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValidHex)
            }
        }
        .padding(14)
        .frame(width: 256)
    }

    private var isValidHex: Bool {
        Color(hex: hexInput) != nil
    }

    @ViewBuilder
    private func swatch(_ color: Color) -> some View {
        let hex = color.hexString
        let isSelected = hex.caseInsensitiveCompare(current) == .orderedSame
        Button {
            hexInput = String(hex.dropFirst())
            onSelect(hex)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(isSelected ? 0.9 : 0.12), lineWidth: isSelected ? 2 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyHex() {
        guard let color = Color(hex: hexInput) else { return }
        onSelect(color.hexString)
    }
}
