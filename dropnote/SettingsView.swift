import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var showInDock = SettingsManager.shared.settings.showInDock
    @State private var startOnBoot = SettingsManager.shared.settings.startOnBoot
    @State private var showWordCounter = SettingsManager.shared.settings.showWordCounter
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("General")
                            .font(.title2.bold())

                        HStack {
                            Text("Launch on start")
                            Spacer()
                            Toggle("", isOn: $startOnBoot)
                                .labelsHidden()
                                .onChange(of: startOnBoot) { _, newValue in
                                    updateSettings(startOnBoot: newValue)
                                }
                        }

                        HStack {
                            Text("Show in Dock")
                            Spacer()
                            Toggle("", isOn: $showInDock)
                                .labelsHidden()
                                .onChange(of: showInDock) { _, newValue in
                                    updateSettings(showInDock: newValue)
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
                } else if selectedSection == "Themes" {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Themes")
                            .font(.title2.bold())

                        HStack {
                            Text("Show word counter")
                            Spacer()
                            Toggle("", isOn: $showWordCounter)
                                .labelsHidden()
                                .onChange(of: showWordCounter) { _, newValue in
                                    updateSettings(showWordCounter: newValue)
                                }
                        }

                        Spacer()
                    }
                    .padding(24)
                } else if selectedSection == "Info" {
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
            }
            .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 460, height: 320)
        .onAppear {
            showInDock = SettingsManager.shared.settings.showInDock
            startOnBoot = SettingsManager.shared.settings.startOnBoot
            showWordCounter = SettingsManager.shared.settings.showWordCounter
            NSApplication.shared.setActivationPolicy(.regular)
        }
        .onDisappear {
            if !SettingsManager.shared.settings.showInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    func updateSettings(showInDock: Bool? = nil, startOnBoot: Bool? = nil, showWordCounter: Bool? = nil) {
        let updated = AppSettings(
            showInDock: showInDock ?? self.showInDock,
            startOnBoot: startOnBoot ?? self.startOnBoot,
            showWordCounter: showWordCounter ?? self.showWordCounter
        )
        SettingsManager.shared.updateSetting(updated)
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }
}
