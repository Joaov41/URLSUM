import SwiftUI

@main
struct urlsum2App: App {
    var body: some Scene {
        WindowGroup {
            TabContainerView()
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTabRequested, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("Close Panels") {
                    NotificationCenter.default.post(name: .closePanels, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        #endif
    }
}

// Notification names are defined in Tabbing.swift
