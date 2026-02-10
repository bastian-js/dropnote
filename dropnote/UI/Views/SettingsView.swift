import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @State private var showInDock = SettingsService.shared.settings.showInDock
    @State private var startOnBoot = SettingsService.shared.settings.startOnBoot
    @State private var showWordCounter = SettingsService.shared.settings.showWordCounter
    @State private var searchHotKey = SettingsService.shared.settings.searchHotKey
    @State private var searchHotKeyError: String? = nil
    @State private var isRecordingHotKey = false
    @State private var hotKeyMonitor: Any?
    @State private var selectedSection: String? = "General"
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.18), Color.gray.opacity(0.08)],
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
                    
                    Text("DropNote")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .frame(width: 164)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.18))
                )
                .padding(.leading, 8)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.vertical, 18)
                    .padding(.horizontal, 10)
                
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
        .onAppear {
            reloadSettingsFromService()
        }
        .onDisappear {
            stopRecordingHotKey()
            if !SettingsService.shared.settings.showInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }
    
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
                ) { newValue in
                    updateSetting(startOnBoot: newValue)
                }
                
                toggleRow(
                    title: "Show in Dock",
                    subtitle: "Keep the app visible in the Dock",
                    isOn: $showInDock
                ) { newValue in
                    updateSetting(showInDock: newValue)
                    if !newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if NSApp.keyWindow?.title != "Settings" {
                                NSApplication.shared.setActivationPolicy(.accessory)
                            }
                        }
                    }
                }
            }
            
            settingCard(title: "Search shortcut") {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Global search")
                            .font(.callout.weight(.semibold))
                        Text("Press to open search from anywhere")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(hotKeyDisplayString(searchHotKey))
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.2))
                        )
                    Button(action: {
                        if isRecordingHotKey {
                            stopRecordingHotKey()
                        } else {
                            startRecordingHotKey()
                        }
                    }) {
                        Text(isRecordingHotKey ? "Recording..." : "Record")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
                if let searchHotKeyError {
                    Text(searchHotKeyError)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
            
            Text("Current version: 2.0")
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
            
            settingCard(title: "Editor") {
                toggleRow(
                    title: "Word counter",
                    subtitle: "Show word count at the bottom left",
                    isOn: $showWordCounter
                ) { newValue in
                    updateSetting(showWordCounter: newValue)
                }
            }
            
            Spacer()
        }
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
                            .fill(Color.black.opacity(0.22))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "note.text")
                                    .font(.system(size: 26, weight: .semibold))
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DropNote")
                                .font(.title3.weight(.semibold))
                            Text("Version 1.2")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Text("2025 (c) bastian-js")
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
    
    @ViewBuilder
    private func sectionButton(title: String, icon: String, tag: String) -> some View {
        let isSelected = selectedSection == tag
        Button {
            selectedSection = tag
        } label: {
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
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.clear)
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
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func reloadSettingsFromService() {
        showInDock = SettingsService.shared.settings.showInDock
        startOnBoot = SettingsService.shared.settings.startOnBoot
        showWordCounter = SettingsService.shared.settings.showWordCounter
        searchHotKey = SettingsService.shared.settings.searchHotKey
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    private func updateSetting(
        showInDock: Bool? = nil,
        startOnBoot: Bool? = nil,
        showWordCounter: Bool? = nil,
        searchHotKey: HotKeySettings? = nil
    ) {
        let updated = AppSettings(
            showInDock: showInDock ?? self.showInDock,
            startOnBoot: startOnBoot ?? self.startOnBoot,
            showWordCounter: showWordCounter ?? self.showWordCounter,
            searchHotKey: searchHotKey ?? self.searchHotKey
        )
        SettingsService.shared.updateSetting(updated)
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }
    
    private func startRecordingHotKey() {
        searchHotKeyError = nil
        isRecordingHotKey = true
        hotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleRecordedHotKey(event)
            return nil
        }
    }
    
    private func stopRecordingHotKey() {
        isRecordingHotKey = false
        if let hotKeyMonitor {
            NSEvent.removeMonitor(hotKeyMonitor)
            self.hotKeyMonitor = nil
        }
    }
    
    private func handleRecordedHotKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else {
            searchHotKeyError = "Please include at least one modifier key."
            stopRecordingHotKey()
            return
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
    
    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        return modifiers
    }
    
    private func hotKeyDisplayString(_ hotKey: HotKeySettings) -> String {
        var parts: [String] = []
        if hotKey.modifiers & UInt32(cmdKey) != 0 {
            parts.append("Cmd")
        }
        if hotKey.modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if hotKey.modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        if hotKey.modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        parts.append(hotKey.keyLabel.isEmpty ? "Key \(hotKey.keyCode)" : hotKey.keyLabel)
        return parts.joined(separator: "+")
    }
}
