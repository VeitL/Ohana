//
//  RainbowWalkEffects.swift
//  Ohana
//
//  Shared rainbow walk-route and poop-pin rendering for live maps,
//  walk detail maps, and static map snapshots.
//

import SwiftUI
import MapKit
import UIKit

enum RainbowWalkEffectKeys {
    static let route = "shop_equip_fx_rainbow"
    static let poop = "shop_equip_fx_rainbow_poop"
}

enum RainbowWalkPalette {
    static let colors: [Color] = [
        Color.goRed,
        Color.goOrange,
        Color.goYellow,
        Color.goTeal,
        Color.goBlue,
        Color.goPurple
    ]

    static let uiColors: [UIColor] = [
        UIColor.systemRed,
        UIColor.systemOrange,
        UIColor.systemYellow,
        UIColor.systemTeal,
        UIColor.systemBlue,
        UIColor.systemPurple
    ]
}

struct RainbowRoutePolyline: MapContent {
    let coordinates: [CLLocationCoordinate2D]
    var normalColor: Color = .goPrimary
    var lineWidth: CGFloat = 6
    var isRainbow: Bool
    var isFlowing: Bool
    var flowPhase: CGFloat

    @MapContentBuilder
    var body: some MapContent {
        if isRainbow {
            MapPolyline(coordinates: coordinates)
                .stroke(
                    LinearGradient(
                        colors: RainbowWalkPalette.colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

            if isFlowing {
                MapPolyline(coordinates: coordinates)
                    .stroke(
                        Color.goCardWhite.opacity(0.72), // ui-v4: allow map highlight ink over rainbow route.
                        style: StrokeStyle(
                            lineWidth: max(1.8, lineWidth * 0.28),
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [10, 24],
                            dashPhase: flowPhase
                        )
                    )
            }
        } else {
            MapPolyline(coordinates: coordinates)
                .stroke(normalColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

struct RainbowPoopPin: View {
    var isRainbow: Bool
    var isFlowing: Bool
    var size: CGFloat = 28

    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var rotation: Double = 0

    private var shouldFlow: Bool {
        isRainbow && isFlowing && workloadPolicy.ambientMotionBudget(isVisible: true).allowsMotion
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.arkInk.opacity(isRainbow ? 0.68 : 0.62))

            if isRainbow {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: RainbowWalkPalette.colors, center: .center),
                        lineWidth: 3
                    )
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: Color.goPurple.opacity(0.35), radius: 7, y: 1) // ui-v4: allow map pin glow.

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.goYellow.opacity(0.42), Color.clear],
                            center: .center,
                            startRadius: 1,
                            endRadius: size * 0.48
                        )
                    )
                    .padding(3)
            } else {
                Circle()
                    .strokeBorder(Color.goYellow.opacity(0.75), lineWidth: 1.4)
            }

            Text("💩")
                .font(.system(size: size * 0.54))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.arkInk.opacity(0.28), radius: 5, y: 2) // ui-v4: allow map pin elevation.
        .accessibilityLabel("便便位置")
        .onAppear { updateFlow() }
        .onChange(of: shouldFlow) { _, _ in updateFlow() }
    }

    private func updateFlow() {
        guard shouldFlow else {
            withAnimation(GoMotion.feedback) { rotation = 0 }
            return
        }
        rotation = 0
        withAnimation(.linear(duration: 1.45).repeatForever(autoreverses: false)) { // ui-v4: allow route cosmetic loop; runtime-guardrail: allow gated by AppWorkloadPolicy and only used for visible equipped map pins; smoothness: allow visible map-pin loop behind AppWorkloadPolicy.
            rotation = 360
        }
    }
}

enum MapSnapshotRainbowRenderer {
    static func drawRoute(
        coordinates: [CLLocationCoordinate2D],
        on snapshot: MKMapSnapshotter.Snapshot,
        in context: CGContext,
        isRainbow: Bool,
        lineWidth: CGFloat = 3
    ) {
        guard coordinates.count >= 2 else { return }
        context.saveGState()
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if isRainbow {
            for index in 1..<coordinates.count {
                let start = snapshot.point(for: coordinates[index - 1])
                let end = snapshot.point(for: coordinates[index])
                context.setStrokeColor(RainbowWalkPalette.uiColors[(index - 1) % RainbowWalkPalette.uiColors.count].cgColor)
                context.beginPath()
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
            }
        } else {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.beginPath()
            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                if index == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.strokePath()
        }
        context.restoreGState()
    }

    static func drawPoopMarker(
        at point: CGPoint,
        in context: CGContext,
        isRainbow: Bool
    ) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.28).cgColor) // ui-v4: allow map snapshot pin shadow.
        UIColor.black.withAlphaComponent(0.68).setFill() // ui-v4: allow map snapshot pin ink.
        UIBezierPath(ovalIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)).fill()
        context.restoreGState()

        if isRainbow {
            let center = point
            let radius: CGFloat = 10.5
            let colors = RainbowWalkPalette.uiColors
            for index in colors.indices {
                let start = CGFloat(index) / CGFloat(colors.count) * .pi * 2
                let end = CGFloat(index + 1) / CGFloat(colors.count) * .pi * 2
                let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
                path.lineWidth = 3
                colors[index].setStroke()
                path.stroke()
            }
        } else {
            UIColor.systemBrown.setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
            ring.lineWidth = 2
            ring.stroke()
        }

        let text = "💩" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        text.draw(in: CGRect(x: point.x - 9, y: point.y - 8, width: 18, height: 18), withAttributes: attributes)
    }
}
