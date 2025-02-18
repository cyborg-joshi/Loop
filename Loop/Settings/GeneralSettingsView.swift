//
//  GeneralSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults
import ServiceManagement

struct GeneralSettingsView: View {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor
    @Default(.currentIcon) var currentIcon
    @Default(.notificationWhenIconUnlocked) var notificationWhenIconUnlocked
    @Default(.timesLooped) var timesLooped
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.windowPadding) var windowPadding
    @Default(.windowSnapping) var windowSnapping
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        if launchAtLogin {
                            try? SMAppService().register()
                        } else {
                            try? SMAppService().unregister()
                        }
                    }

                VStack(alignment: .leading) {
                    Toggle("Hide menubar icon", isOn: $hideMenuBarIcon)

                    if hideMenuBarIcon {
                        Text("Re-open Loop again to see this window.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                Toggle(isOn: $windowSnapping) {
                    HStack {
                        Text("Window Snapping")
                        BetaIndicator("BETA")
                    }
                }

                Toggle(isOn: $animateWindowResizes) {
                    HStack {
                        Text("Animate windows being resized")
                        BetaIndicator("BETA")
                    }
                }
                .onChange(of: animateWindowResizes) { _ in
                    if animateWindowResizes == true {
                        PermissionsManager.ScreenRecording.requestAccess()
                    }
                }

                Slider(value: $windowPadding,
                       in: 0...20,
                       step: 2,
                       minimumValueLabel: Text("0px"),
                       maximumValueLabel: Text("20px")) {
                    Text("Window Padding")
                }

                Toggle(
                    "Restore window frame on drag",
                    isOn: $restoreWindowFrameOnDrag
                )

                Toggle(isOn: $resizeWindowUnderCursor) {
                    VStack(alignment: .leading) {
                        Text("Resize window under cursor")
                        Text(resizeWindowUnderCursor ?
                             "Resizes window under cursor, and uses the frontmost window as backup." :
                             "Resizes frontmost window."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Animation Speed", selection: $animationConfiguration) {
                    ForEach(AnimationConfiguration.allCases) { configuration in
                        Text(configuration.name)
                    }
                }
            }

            Section("Loop's icon") {
                VStack(alignment: .leading) {
                    Picker("Selected icon:", selection: $currentIcon) {
                        ForEach(IconManager.returnUnlockedIcons(), id: \.self) { icon in
                            HStack {
                                Image(nsImage: NSImage(named: icon.iconName)!)
                                Text(icon.getName())
                            }
                            .tag(icon.iconName)
                        }
                    }
                    Text("Loop more to unlock more icons! (You've looped \(timesLooped) times!)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .onChange(of: self.currentIcon) { _ in
                    IconManager.refreshCurrentAppIcon()
                }

                Toggle(
                    "Notify when new icons are unlocked",
                    isOn: Binding(
                        get: {
                            self.notificationWhenIconUnlocked
                        },
                        set: {
                            if $0 {
                                AppDelegate.sendNotification(
                                    "Loop",
                                    "You will now be notified when you unlock a new icon."
                                )

                                self.notificationWhenIconUnlocked = AppDelegate.areNotificationsEnabled()
                            } else {
                                self.notificationWhenIconUnlocked = $0
                            }
                        }
                    )
                )
                .onAppear {
                    if self.notificationWhenIconUnlocked {
                        self.notificationWhenIconUnlocked = AppDelegate.areNotificationsEnabled()
                    }
                }
            }

            Section("Accent Color") {
                Toggle("Use System Accent Color", isOn: $useSystemAccentColor)

                if !useSystemAccentColor {
                    ColorPicker("Custom Accent Color", selection: $customAccentColor, supportsOpacity: false)
                }

                Toggle("Use Gradient", isOn: $useGradient)

                if !useSystemAccentColor && useGradient {
                    ColorPicker("Custom Gradient color", selection: $gradientColor, supportsOpacity: false)
                        .foregroundColor(
                            useGradient ? (useSystemAccentColor ? .secondary : nil) : .secondary
                        )
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
