//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()
    @State var isMenubarItemPresented: Bool = false

    var body: some Scene {
        MenuBarExtra("Loop", image: "empty") {
            #if DEBUG
            MenuBarHeaderText("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
            #endif

            Menu("Resize…") {
                MenuBarHeaderText("General")
                ForEach(WindowDirection.general) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Halves")
                ForEach(WindowDirection.halves) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Quarters")
                ForEach(WindowDirection.quarters) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Horizontal Thirds")
                ForEach(WindowDirection.horizontalThirds) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Vertical Thirds")
                ForEach(WindowDirection.verticalThirds) { MenuBarResizeButton($0) }
            }

            Button("Settings") {
                NSApp.setActivationPolicy(.regular)
                appDelegate.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("About \(Bundle.main.appName)") {
                NSApp.setActivationPolicy(.regular)
                aboutViewController.open()
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: $isMenubarItemPresented) { statusItem in
            statusItem.length = 22

            guard let button = statusItem.button else { return }

            let view = NSHostingView(rootView: MenuBarIconView())
            view.frame.size = NSSize(width: 22, height: 22)
            button.addSubview(view)
        }
    }
}
