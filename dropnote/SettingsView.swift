//
//  SettingsView.swift
//  dropnote
//
//  Created by bastian-js on 11.03.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("showInDock") private var showInDock: Bool = true
    
    var body: some View {
        TabView {
            VStack {
                Toggle("Symbol im Dock anzeigen", isOn: $showInDock)
                    .padding()
                    .onChange(of: showInDock) { newValue in
                        updateDockVisibility(show: newValue)
                    }
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gear")
            }
            
            VStack {
                Text("DropNote")
                    .font(.title)
                    .padding(.top)
                Text("© 2025 Bastian-JS")
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
