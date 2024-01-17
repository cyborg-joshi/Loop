//
//  RadialMenuDirectionSelector.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI
import Defaults

struct RadialMenuDirectionSelectorView: View {
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius

    let activeAction: WindowAction
    let radialMenuSize: CGFloat
    let screenFrame: CGRect

    init(_ activeAction: WindowAction, screenFrame: CGRect, size: CGFloat) {
        self.activeAction = activeAction
        self.screenFrame = screenFrame
        self.radialMenuSize = size
    }

    var body: some View {
//        if activeAngle == .maximize {
//            Color.white
//        } else {
//            if radialMenuCornerRadius < 40 {
//                // This is used when the user configures the radial menu to be a square
//                Color.clear
//                    .overlay {
//
//                        HStack(spacing: 0) {
//                            VStack(spacing: 0) {
//                                DirectionSelectorSquareSegment(.topLeftQuarter, activeAngle, radialMenuSize)
//                                DirectionSelectorSquareSegment(.leftHalf, activeAngle, radialMenuSize)
//                                DirectionSelectorSquareSegment(.bottomLeftQuarter, activeAngle, radialMenuSize)
//                            }
//                            VStack(spacing: 0) {
//                                DirectionSelectorSquareSegment(.topHalf, activeAngle, radialMenuSize)
//                                Spacer().frame(width: radialMenuSize/3, height: radialMenuSize/3)
//                                DirectionSelectorSquareSegment(.bottomHalf, activeAngle, radialMenuSize)
//                            }
//                            VStack(spacing: 0) {
//                                DirectionSelectorSquareSegment(.topRightQuarter, activeAngle, radialMenuSize)
//                                DirectionSelectorSquareSegment(.rightHalf, activeAngle, radialMenuSize)
//                                DirectionSelectorSquareSegment(.bottomRightQuarter, activeAngle, radialMenuSize)
//                            }
//                        }
//                    }
//            } else {
                // This is used when the user configures the radial menu to be a circle
            Color.clear
                .overlay {
                    DirectionSelectorCircleSegment(activeAction, screenFrame, radialMenuSize)
                }
//                    .overlay {
//                        DirectionSelectorCircleSegment(.rightHalf, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.bottomRightQuarter, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.bottomHalf, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.bottomLeftQuarter, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.leftHalf, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.topLeftQuarter, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.topHalf, activeAngle, radialMenuSize)
//                        DirectionSelectorCircleSegment(.topRightQuarter, activeAngle, radialMenuSize)
//                    }
//            }
//        }
    }
}

struct DirectionSelectorCircleSegment: View {
    let radialMenuSize: CGFloat
    let screenFrame: CGRect

    var thickness: Angle = .degrees(45)
    var targetAngle: Angle = .zero

    init(_ action: WindowAction, _ screenFrame: CGRect, _ radialMenuSize: CGFloat) {
        self.radialMenuSize = radialMenuSize
        self.screenFrame = screenFrame

//        self.thickness = .degrees(360 * action.areaPercentage(on: screenFrame))
//        self.targetAngle =

        let windowFrame = action.frame(screenFrame)
        self.thickness = .degrees(360 * (windowFrame.size.area / screenFrame.size.area))

        let screenMidpoint = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        let windowMidpoint = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        self.targetAngle = .radians(-screenMidpoint.angle(to: windowMidpoint))

        print(self.thickness.degrees / 360)
    }

    var body: some View {
        Path { path in
            path.move(to:
                        CGPoint(
                            x: radialMenuSize/2,
                            y: radialMenuSize/2
                        )
            )
            path.addArc(
                center: CGPoint(x: radialMenuSize/2,
                                y: radialMenuSize/2),
                radius: radialMenuSize,
                startAngle: targetAngle - (thickness / 2),
                endAngle: targetAngle + (thickness / 2),
                clockwise: false
            )
        }
        .foregroundColor(Color.black)
        .animation(.easeOut, value: [thickness, targetAngle])
    }
}
