//
//  dropnoteApp.swift
//  dropnote
//
//  Created by bastian-js on 10.03.25.
//

import SwiftUI

@main
struct dropnoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
