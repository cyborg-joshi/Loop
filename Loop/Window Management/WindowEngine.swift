//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI
import Defaults

struct WindowEngine {

    /// Resize a Window
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - direction: WindowDirection
    ///   - screen: Screen the window should be resized on
    static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen,
        supressAnimations: Bool = false
    ) {
        guard action.direction != .noAction else { return }
        let willChangeScreens = ScreenManager.screenContaining(window) != screen
        print("Resizing \(window.nsRunningApplication?.localizedName ?? window.title ?? "<unknown>") to \(action.direction) on \(screen.localizedName)")

        window.activate()

        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        if action.direction == .fullscreen {
            window.toggleFullscreen()
            WindowRecords.record(window, action)
            return
        }
        window.setFullscreen(false)

        if action.direction == .hide {
            window.toggleHidden()
            return
        }

        if action.direction == .minimize {
            window.toggleMinimized()
            return
        }

        let screenFrame = screen.safeScreenFrame
        guard
            let newWindowFrame = WindowEngine.generateWindowFrame(
                window,
                screenFrame,
                action
            )
        else {
            return
        }
        var targetWindowFrame = WindowEngine.applyPadding(newWindowFrame, screenFrame, action)

        print("Target window frame: \(targetWindowFrame)")

        var animate = (!supressAnimations && Defaults[.animateWindowResizes])
        if animate {
            if PermissionsManager.ScreenRecording.getStatus() == false {
                PermissionsManager.ScreenRecording.requestAccess()
                animate = false
                return
            }

            // Calculate the window's minimum window size and change the target accordingly
            window.getMinSize(screen: screen) { minSize in
                let nsScreenFrame = screenFrame.flipY!

                if (targetWindowFrame.minX + minSize.width) > nsScreenFrame.maxX {
                    targetWindowFrame.origin.x = nsScreenFrame.maxX - minSize.width - Defaults[.windowPadding]
                }

                if (targetWindowFrame.minY + minSize.height) > nsScreenFrame.maxY {
                    targetWindowFrame.origin.y = nsScreenFrame.maxY - minSize.height - Defaults[.windowPadding]
                }

                window.setFrame(targetWindowFrame, animate: true) {
                    WindowRecords.record(window, action)
                }
            }
        } else {
            window.setFrame(targetWindowFrame, sizeFirst: willChangeScreens) {
                WindowEngine.handleSizeConstrainedWindow(window: window, screenFrame: screenFrame)

                // Fixes an issue where window isn't resized correctly on multi-monitor setups
                if !window.frame.approximatelyEqual(to: targetWindowFrame) {
                    print("Backup resizing...")
                    window.setFrame(targetWindowFrame)
                }

                WindowRecords.record(window, action)
            }
        }
    }

    static func getTargetWindow() -> Window? {
        var result: Window?

        if Defaults[.resizeWindowUnderCursor],
           let mouseLocation = CGEvent.mouseLocation,
           let window = WindowEngine.windowAtPosition(mouseLocation) {
            result = window
        }

        if result == nil {
           result = WindowEngine.frontmostWindow
        }

        return result
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static var frontmostWindow: Window? {
        guard
            let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
            let window = Window(pid: app.processIdentifier)
        else {
            return nil
        }
        return window
    }

    static func windowAtPosition(_ position: CGPoint) -> Window? {
        if let element = AXUIElement.systemWide.getElementAtPosition(position),
           let windowElement = element.getValue(.window),
           // swiftlint:disable:next force_cast
           let window = Window(element: windowElement as! AXUIElement) {
            return window
        }

        let windowList = WindowEngine.windowList
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    static var windowList: [Window] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        var windowList: [Window] = []
        for window in list {
            if let pid = window[kCGWindowOwnerPID as String] as? Int32,
               let window = Window(pid: pid) {
                windowList.append(window)
            }
        }

        return windowList
    }

    static func generateWindowFrame(
        _ window: Window,
        _ screenFrame: CGRect,
        _ action: WindowAction
    ) -> CGRect? {
        let windowFrame = window.frame
        let direction = action.direction

        var newWindowFrame: CGRect = .zero
        newWindowFrame.origin = screenFrame.origin

        switch direction {
        case .custom:
            guard
                let newFrame = WindowEngine.generateCustomWindowFrame(action, screenFrame)
            else {
                return nil
            }
            newWindowFrame = newFrame
        case .center:
            newWindowFrame = CGRect(
                x: screenFrame.midX - windowFrame.width / 2,
                y: screenFrame.midY - windowFrame.height / 2,
                width: windowFrame.width,
                height: windowFrame.height
            )
        case .macOSCenter:
            let yOffset = getMacOSCenterYOffset(windowFrame.height, screenHeight: screenFrame.height)

            newWindowFrame = CGRect(
                x: screenFrame.midX - windowFrame.width / 2,
                y: screenFrame.midY - windowFrame.height / 2 + yOffset,
                width: windowFrame.width,
                height: windowFrame.height
            )
        case .undo:
            let previousDirection = WindowRecords.getLastAction(for: window, willResize: true)
            if let previousResizeFrame = self.generateWindowFrame(window, screenFrame, previousDirection) {
                newWindowFrame = previousResizeFrame
            } else {
                return nil
            }
        case .initialFrame:
            if let initalFrame = WindowRecords.getInitialFrame(for: window) {
                newWindowFrame = initalFrame
            } else {
                return nil
            }
        default:
            guard let frameMultiplyValues = direction.frameMultiplyValues else { return nil}
            newWindowFrame.origin.x += screenFrame.width * frameMultiplyValues.minX
            newWindowFrame.origin.y += screenFrame.height * frameMultiplyValues.minY
            newWindowFrame.size.width += screenFrame.width * frameMultiplyValues.width
            newWindowFrame.size.height += screenFrame.height * frameMultiplyValues.height
        }

        return newWindowFrame
    }

    private static func generateCustomWindowFrame(_ action: WindowAction, _ screenFrame: CGRect) -> CGRect? {
        guard
            action.direction == .custom,
            let measureSystem = action.measureSystem,
            let anchor = action.anchor,
            let width = action.width,
            let height = action.height
        else {
            return nil
        }
        var newWindowFrame: CGRect = .zero
        newWindowFrame.origin = screenFrame.origin

        switch measureSystem {
        case .percentage:
            newWindowFrame.size.width += screenFrame.width * (width / 100.0)
            newWindowFrame.size.height += screenFrame.height * (height / 100.0)
        case .pixels:
            newWindowFrame.size.width += width
            newWindowFrame.size.height += height
        }

        switch anchor {
        case .topLeft:
            break
        case .top:
            newWindowFrame.origin.x = screenFrame.midX - newWindowFrame.width / 2
        case .topRight:
            newWindowFrame.origin.x = screenFrame.maxX - newWindowFrame.width
        case .right:
            newWindowFrame.origin.x = screenFrame.maxX - newWindowFrame.width
            newWindowFrame.origin.y = screenFrame.midY - newWindowFrame.height / 2
        case .bottomRight:
            newWindowFrame.origin.x = screenFrame.maxX - newWindowFrame.width
            newWindowFrame.origin.y = screenFrame.maxY - newWindowFrame.height
        case .bottom:
            newWindowFrame.origin.x = screenFrame.midX - newWindowFrame.width / 2
            newWindowFrame.origin.y = screenFrame.maxY - newWindowFrame.height
        case .bottomLeft:
            newWindowFrame.origin.y = screenFrame.maxY - newWindowFrame.height
        case .left:
            newWindowFrame.origin.y = screenFrame.midY - newWindowFrame.height / 2
        case .center:
            newWindowFrame.origin.x = screenFrame.midX - newWindowFrame.width / 2
            newWindowFrame.origin.y = screenFrame.midY - newWindowFrame.height / 2
        case .macOSCenter:
            let yOffset = getMacOSCenterYOffset(newWindowFrame.height, screenHeight: screenFrame.height)
            newWindowFrame.origin.x = screenFrame.midX - newWindowFrame.width / 2
            newWindowFrame.origin.y = (screenFrame.midY - newWindowFrame.height / 2) + yOffset
        }

        return newWindowFrame
    }

    static func getMacOSCenterYOffset(_ windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Apply padding on a CGRect, using the provided WindowDirection
    /// - Parameters:
    ///   - windowFrame: The frame the window WILL be resized to
    ///   - direction: The direction the window WILL be resized to
    /// - Returns: CGRect with padding applied
    private static func applyPadding(_ windowFrame: CGRect, _ screenFrame: CGRect, _ action: WindowAction) -> CGRect {
        let padding = Defaults[.windowPadding]
        let halfPadding = Defaults[.windowPadding] / 2

        let paddedScreenFrame = screenFrame.padding(.all, padding)
        var paddedWindowFrame = windowFrame.intersection(paddedScreenFrame)

        if action.direction == .macOSCenter,
           windowFrame.height >= paddedScreenFrame.height {

            paddedWindowFrame.origin.y = paddedScreenFrame.minY
            paddedWindowFrame.size.height = paddedScreenFrame.height
        }

        if action.direction == .center || action.direction == .macOSCenter {
            return paddedWindowFrame
        }

        if paddedWindowFrame.minX != paddedScreenFrame.minX {
            paddedWindowFrame = paddedWindowFrame.padding(.leading, halfPadding)
        }

        if paddedWindowFrame.maxX != paddedScreenFrame.maxX {
            paddedWindowFrame = paddedWindowFrame.padding(.trailing, halfPadding)
        }

        if paddedWindowFrame.minY != paddedScreenFrame.minY {
            paddedWindowFrame = paddedWindowFrame.padding(.top, halfPadding)
        }

        if paddedWindowFrame.maxY != paddedScreenFrame.maxY {
            paddedWindowFrame = paddedWindowFrame.padding(.bottom, halfPadding)
        }

        return paddedWindowFrame
    }

    /// Will move a window back onto the screen. To be run AFTER a window has been resized.
    /// - Parameters:
    ///   - window: Window
    ///   - screenFrame: The screen's frame
    private static func handleSizeConstrainedWindow(window: Window, screenFrame: CGRect) {
        let windowFrame = window.frame
        // If the window is fully shown on the screen
        if (windowFrame.maxX <= screenFrame.maxX) && (windowFrame.maxY <= screenFrame.maxY) {
            return
        }

        // If not, then Loop will auto re-adjust the window size to be fully shown on the screen
        var fixedWindowFrame = windowFrame

        if fixedWindowFrame.maxX > screenFrame.maxX {
            fixedWindowFrame.origin.x = screenFrame.maxX - fixedWindowFrame.width - Defaults[.windowPadding]
        }

        if fixedWindowFrame.maxY > screenFrame.maxY {
            fixedWindowFrame.origin.y = screenFrame.maxY - fixedWindowFrame.height - Defaults[.windowPadding]
        }

        window.setPosition(fixedWindowFrame.origin)
    }
}
