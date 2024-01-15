//
//  RadialMenuView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Combine
import Defaults

struct RadialMenuView: View {

    let radialMenuSize: CGFloat = 100

    // This will determine whether Loop needs to show a warning (if it's nil)
    let frontmostWindow: Window?

    @State var currentAction: WindowDirection = .noAction

    @State var previewMode = false
    @State var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Variables that store the radial menu's shape
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.useGradient) var useGradient
    @Default(.animationConfiguration) var animationConfiguration

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                ZStack {
                    ZStack {
                        // NSVisualEffect on background
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                        // This rectangle with a gradient is masked with the current direction radial menu view
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            Color.getLoopAccent(tone: .normal),
                                            Color.getLoopAccent(tone: useGradient ? .darker : .normal)
                                        ]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .mask {
                                RadialMenuDirectionSelectorView(
                                    activeAngle: currentAction,
                                    size: self.radialMenuSize
                                )
                            }
                    }
                    // Mask the whole ZStack with the shape the user defines
                    .mask {
                        if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                            Circle()
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        } else {
                            RoundedRectangle(cornerRadius: radialMenuCornerRadius, style: .continuous)
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        }
                    }

                    Group {
                        if frontmostWindow == nil && previewMode == false {
                            Image("custom.macwindow.trianglebadge.exclamationmark")
                        } else if let image = self.currentAction.radialMenuImage {
                            image
                        }
                    }
                    .foregroundStyle(Color.getLoopAccent(tone: .normal))
                    .font(Font.system(size: 20, weight: .bold))
                }
                .frame(width: radialMenuSize, height: radialMenuSize)

                Spacer()
            }
            Spacer()
        }
        .shadow(radius: 10)

        // Animate window
        .scaleEffect(currentAction == .maximize ? 0.85 : 1)
        .animation(animationConfiguration.radialMenuAnimation, value: currentAction)
        .onAppear {
            if previewMode {
                currentAction = currentAction.nextPreviewDirection
            }
        }
        .onReceive(timer) { _ in
            if previewMode {
                currentAction = currentAction.nextPreviewDirection
            }
        }
        .onReceive(.updateUIDirection) { obj in
            if !self.previewMode, let action = obj.userInfo?["action"] as? WindowAction {
                self.currentAction = action.direction.base

                print("New radial menu window action recieved: \(action.direction)")
            }
        }
    }
}
