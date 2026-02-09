import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var showInDock = SettingsService.shared.settings.showInDock
    @State private var startOnBoot = SettingsService.shared.settings.startOnBoot
    @State private var showWordCounter = SettingsService.shared.settings.showWordCounter
    @State private var selectedSection: String? = "General"
    
    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedSection) {
                Label("General", systemImage: "gearshape").tag("General")
                Label("Themes", systemImage: "paintbrush").tag("Themes")
                Label("Info", systemImage: "info.circle").tag("Info")
            }
            .listStyle(SidebarListStyle())
            .frame(width: 140)
            .padding(.top, 10)
            
            Divider()
            
            VStack(alignment: .leading) {
                if selectedSection == "General" {
                    generalSection
                } else if selectedSection == "Themes" {
                    themesSection
                } else if selectedSection == "Info" {
                    infoSection
                }
            }
            .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 460, height: 320)
        .onAppear {
            reloadSettingsFromService()
        }
        .onDisappear {
            if !SettingsService.shared.settings.showInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }
    
    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2.bold())
            
            HStack {
                Text("Launch on start")
                Spacer()
                Toggle("", isOn: $startOnBoot)
                    .labelsHidden()
                    .onChange(of: startOnBoot) { _, newValue in
                        updateSetting(startOnBoot: newValue)
                    }
            }
            
            HStack {
                Text("Show in Dock")
                Spacer()
                Toggle("", isOn: $showInDock)
                    .labelsHidden()
                    .onChange(of: showInDock) { _, newValue in
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
            
            Spacer()
            
            Text("Current version: 1.2")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 16)
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display")
                .font(.title2.bold())
            
            HStack {
                Text("Show word counter")
                Spacer()
                Toggle("", isOn: $showWordCounter)
                    .labelsHidden()
                    .onChange(of: showWordCounter) { _, newValue in
                        updateSetting(showWordCounter: newValue)
                    }
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var infoSection: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("DropNote")
                .font(.largeTitle)
            Text("2025 © bastian-js")
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Private Methods
    
    private func reloadSettingsFromService() {
        showInDock = SettingsService.shared.settings.showInDock
        startOnBoot = SettingsService.shared.settings.startOnBoot
        showWordCounter = SettingsService.shared.settings.showWordCounter
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    private func updateSetting(showInDock: Bool? = nil, startOnBoot: Bool? = nil, showWordCounter: Bool? = nil) {
        let updated = AppSettings(
            showInDock: showInDock ?? self.showInDock,
            startOnBoot: startOnBoot ?? self.startOnBoot,
            showWordCounter: showWordCounter ?? self.showWordCounter
        )
        SettingsService.shared.updateSetting(updated)
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }
}
