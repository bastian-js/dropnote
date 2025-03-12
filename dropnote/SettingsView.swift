//
//  SettingsView.swift
//  dropnote
//
//  Created by bastian-js on 11.03.25.
//

import SwiftUI

struct SettingsView: View {
    @State private var showInDock = SettingsManager.shared.settings.showInDock

    var body: some View {
        TabView {
            VStack {
                Toggle("Show DropNote in dock", isOn: $showInDock)
                    .padding()
                    .onAppear {
                        showInDock = SettingsManager.shared.settings.showInDock
                    }
                    .onChange(of: showInDock) { newValue in
                        updateDockVisibility(show: newValue)
                        SettingsManager.shared.settings.showInDock = newValue
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
            NSApplication.shared.setActivationPolicy(.regular) // 🔥 Dock öffnen wenn Settings offen
        }
    }
    
    func updateDockVisibility(show: Bool) {
        let policy: NSApplication.ActivationPolicy = show ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)
    }
}
