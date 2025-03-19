import SwiftUI

struct SettingsView: View {
    @State private var showInDock = SettingsManager.shared.settings.showInDock
    @State private var startOnBoot = SettingsManager.shared.settings.startOnBoot
    
    var body: some View {
        TabView {
            VStack {
                Toggle("Show DropNote in dock", isOn: $showInDock)
                    .padding()
                    .onAppear {
                        showInDock = SettingsManager.shared.settings.showInDock
                        startOnBoot = SettingsManager.shared.settings.startOnBoot
                    }
                    .onChange(of: showInDock) { newValue in
                        SettingsManager.shared.updateSetting(AppSettings(showInDock: newValue, startOnBoot: startOnBoot))
                    }
                
                Toggle("Start app on boot", isOn: $startOnBoot)
                    .padding()
                    .onChange(of: startOnBoot) { newValue in
                        SettingsManager.shared.updateSetting(AppSettings(showInDock: showInDock, startOnBoot: newValue))
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            
            VStack {
                Text("DropNote")
                    .font(.title)
                    .padding(.top)
                Text("2025 © bastian-js")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
            .tabItem {
                Label("Info", systemImage: "info.circle")
            }
        }
        .frame(width: 300, height: 200)
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }
}
