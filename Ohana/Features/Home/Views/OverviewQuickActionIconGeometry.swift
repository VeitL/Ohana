//
//  OverviewQuickActionIconGeometry.swift
//  Ohana
//
//  32pt vector geometry for the approved 44-icon duotone quick-action set and
//  the live app's semantically distinct production extensions.
//

import SwiftUI

struct OhanaQuickActionGlyphArtwork: View {
    let kind: OhanaQuickActionGlyphKind
    let primaryColor: Color
    let accentColor: Color
    let restingAccentOpacity: Double
    let animationTrigger: Int
    let animatesStateChanges: Bool

    var body: some View {
        GeometryReader { proxy in
            let motionScale = min(proxy.size.width, proxy.size.height) / 32
            ZStack {
                OhanaQuickActionBaseLayer(kind: kind, color: primaryColor)

                ForEach(0 ..< kind.accentElementCount, id: \.self) { index in
                    OhanaQuickActionAccentLayer(
                        kind: kind,
                        index: index,
                        primaryColor: primaryColor,
                        accentColor: accentColor
                    )
                    .modifier(OhanaQuickActionAccentMotionModifier(
                        kind: kind.motionKind(for: index),
                        elementIndex: index,
                        anchor: kind.motionAnchor(for: index),
                        restingOpacity: restingAccentOpacity,
                        trigger: animationTrigger,
                        enabled: animatesStateChanges,
                        motionScale: motionScale
                    ))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension OhanaQuickActionGlyphKind {
    var accentElementCount: Int {
        switch self {
        case .feed: 3
        case .calendar: 5
        case .walk: 3
        case .water: 1
        case .potty: 1
        case .medicine: 1
        case .groom: 5
        case .health: 1
        case .sleep: 2
        case .vet: 1
        case .weight: 1
        case .reminder: 1
        case .plantWater: 1
        case .play: 3
        case .bath: 2
        case .task: 2
        case .foodStock: 3
        case .dryFood: 6
        case .wetFood: 2
        case .treat: 3
        case .foodBag: 3
        case .feeder: 2
        case .waterChange: 1
        case .filterChange: 4
        case .litter: 3
        case .cleanup: 3
        case .walkMap: 1
        case .distance: 2
        case .training: 2
        case .mood: 2
        case .checkIn: 2
        case .family: 2
        case .profile: 2
        case .privacy: 1
        case .expense: 2
        case .insurance: 1
        case .document: 3
        case .photo: 2
        case .birthday: 2
        case .reward: 1
        case .temperature: 2
        case .plantFertilize: 2
        case .notificationHealth: 1
        case .settings: 1
        case .allFeatures: 1
        case .freeFlight: 2
        case .misting: 3
        case .substrateChange: 3
        case .workout: 3
        case .plantPruning: 1
        case .plantPestCheck: 1
        case .plantRotating: 1
        case .plantRepotting: 1
        case .plantNewLeaf: 1
        case .plantIssue: 1
        }
    }

    func motionKind(for elementIndex: Int) -> OhanaQuickActionAccentMotionKind {
        switch self {
        case .water:
            .waterDrop
        case .waterChange:
            .waterChange
        case .filterChange:
            elementIndex == 3 ? .waterChange : .confirm
        case .litter:
            elementIndex == 2 ? .litterScoop : .drop
        case .temperature:
            elementIndex == 0 ? .temperatureMercury : .float
        case .sleep:
            .sleep
        case .feed, .dryFood, .feeder, .plantFertilize, .substrateChange:
            .drop
        case .walk, .walkMap, .distance, .workout:
            .step
        case .plantWater, .bath, .freeFlight, .misting, .plantNewLeaf:
            .float
        case .potty, .groom, .cleanup, .plantPruning:
            .sweep
        case .weight:
            .gauge
        case .play, .treat, .birthday, .reward:
            .bounce
        case .health, .vet, .training, .mood, .notificationHealth,
             .plantPestCheck, .plantIssue:
            .pulse
        case .calendar, .task, .foodStock, .reminder, .checkIn, .privacy,
             .insurance, .document, .photo, .settings, .allFeatures:
            .confirm
        case .medicine, .wetFood, .foodBag, .family, .profile, .expense,
             .plantRepotting:
            .tilt
        case .plantRotating:
            .waterChange
        }
    }

    func motionAnchor(for elementIndex: Int) -> UnitPoint {
        primaryMotionAnchor(for: elementIndex) ??
            secondaryMotionAnchor(for: elementIndex) ??
            extendedMotionAnchor(for: elementIndex) ??
            .center
    }

    private func primaryMotionAnchor(for elementIndex: Int) -> UnitPoint? {
        let anchor: UnitPoint? = switch self {
        case .feed:
            [motionPoint(12.2, 12.1), motionPoint(16.4, 11.1), motionPoint(20.4, 12.6)][elementIndex]
        case .calendar:
            [motionPoint(16, 11.5), motionPoint(11.3, 17.3), motionPoint(16, 17.3), motionPoint(20.7, 17.3), motionPoint(18, 21.8)][elementIndex]
        case .walk:
            [motionPoint(11, 11.8), motionPoint(6.6, 8.8), motionPoint(25.1, 14.7)][elementIndex]
        case .water:
            motionPoint(16, 15.2)
        case .potty:
            motionPoint(16, 13.2)
        case .sleep:
            elementIndex == 0 ? motionPoint(21.1, 8.4) : motionPoint(25, 12.4)
        case .weight:
            motionPoint(16, 17.3)
        case .reminder:
            motionPoint(23.3, 8.7)
        case .plantWater:
            motionPoint(24.3, 19)
        case .play:
            [motionPoint(12.3, 17.2), motionPoint(21, 16.4), motionPoint(23.9, 19)][elementIndex]
        case .bath:
            elementIndex == 0 ? motionPoint(22.6, 8.3) : motionPoint(18.6, 11.2)
        case .task:
            elementIndex == 0 ? motionPoint(16, 16) : motionPoint(22.7, 22.7)
        case .dryFood:
            dryFoodMotionAnchor(for: elementIndex)
        default:
            nil
        }
        return anchor
    }

    private func secondaryMotionAnchor(for elementIndex: Int) -> UnitPoint? {
        let anchor: UnitPoint? = switch self {
        case .treat:
            [motionPoint(8.8, 20.7), motionPoint(23.2, 11.3), motionPoint(16, 15.25)][elementIndex]
        case .feeder:
            elementIndex == 0 ? motionPoint(16, 10.5) : motionPoint(16, 16)
        case .filterChange:
            elementIndex == 3 ? motionPoint(16, 16) : motionPoint(16, 12 + CGFloat(elementIndex) * 3.9)
        case .litter:
            [motionPoint(10.3, 16.8), motionPoint(13.4, 15.8), motionPoint(20.2, 12)][elementIndex]
        case .cleanup:
            [motionPoint(22.7, 8.5), motionPoint(25.4, 13), motionPoint(8.2, 24.5)][elementIndex]
        case .distance:
            elementIndex == 0 ? motionPoint(7.8, 22.4) : motionPoint(24.2, 6.8)
        case .mood:
            elementIndex == 0 ? motionPoint(20.2, 12.2) : motionPoint(16, 18.8)
        case .family:
            elementIndex == 0 ? motionPoint(20.1, 11.9) : motionPoint(21, 21.5)
        case .profile:
            elementIndex == 0 ? motionPoint(16, 13) : motionPoint(16, 20)
        case .birthday:
            elementIndex == 0 ? motionPoint(16, 14.6) : motionPoint(16, 7)
        case .temperature:
            elementIndex == 0 ? motionPoint(11.3, 24.5) : motionPoint(22.5, 15)
        case .plantFertilize:
            elementIndex == 0 ? motionPoint(23.8, 20.5) : motionPoint(25.8, 15.6)
        case .allFeatures:
            motionPoint(21.5, 21.5)
        default:
            nil
        }
        return anchor
    }

    private func extendedMotionAnchor(for elementIndex: Int) -> UnitPoint? {
        let anchor: UnitPoint? = switch self {
        case .freeFlight:
            elementIndex == 0 ? motionPoint(16.5, 14.2) : motionPoint(7.3, 20.2)
        case .misting:
            [motionPoint(11, 23), motionPoint(16, 25), motionPoint(21, 23)][elementIndex]
        case .substrateChange:
            motionPoint(16, 14 + CGFloat(elementIndex) * 3.6)
        case .workout:
            [motionPoint(16, 16), motionPoint(7.1, 8.6), motionPoint(24.9, 8.6)][elementIndex]
        case .plantPruning:
            motionPoint(21.2, 12.8)
        case .plantPestCheck:
            motionPoint(18.8, 15.3)
        case .plantRotating:
            motionPoint(16, 15.8)
        case .plantRepotting:
            motionPoint(17.6, 15.2)
        case .plantNewLeaf:
            motionPoint(21.4, 11.2)
        case .plantIssue:
            motionPoint(17.8, 15.8)
        default:
            nil
        }
        return anchor
    }

    private func motionPoint(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        UnitPoint(x: x / 32, y: y / 32)
    }

    private func dryFoodMotionAnchor(for elementIndex: Int) -> UnitPoint {
        let points = [(11.0, 15.8), (15.1, 14.2), (19.2, 15.7), (13.0, 18.8), (17.2, 18.9), (21.1, 18.1)]
        return motionPoint(points[elementIndex].0, points[elementIndex].1)
    }
}

private struct OhanaQuickActionBaseLayer: View {
    let kind: OhanaQuickActionGlyphKind
    let color: Color

    var body: some View {
        Canvas { context, size in
            var drawing = OhanaQuickActionGlyphDrawing(
                context: context,
                size: size,
                primaryColor: color,
                accentColor: .clear
            )
            drawing.drawBase(kind)
        }
    }
}

private struct OhanaQuickActionAccentLayer: View {
    let kind: OhanaQuickActionGlyphKind
    let index: Int
    let primaryColor: Color
    let accentColor: Color

    var body: some View {
        Canvas { context, size in
            var drawing = OhanaQuickActionGlyphDrawing(
                context: context,
                size: size,
                primaryColor: primaryColor,
                accentColor: accentColor
            )
            drawing.drawAccent(kind, index: index)
        }
    }
}

struct OhanaQuickActionGlyphDrawing {
    private var context: GraphicsContext
    let primaryColor: Color
    let accentColor: Color

    init(context: GraphicsContext, size: CGSize, primaryColor: Color, accentColor: Color) {
        let side = min(size.width, size.height)
        var scaledContext = context
        scaledContext.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        scaledContext.scaleBy(x: side / 32, y: side / 32)
        self.context = scaledContext
        self.primaryColor = primaryColor
        self.accentColor = accentColor
    }
}

extension OhanaQuickActionGlyphDrawing {
    mutating func fill(_ path: Path, _ color: Color, opacity: Double = 1) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    mutating func stroke(_ path: Path, _ color: Color, width: CGFloat, opacity: Double = 1) {
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    mutating func drawLabel(_ text: String, at point: CGPoint, size: CGFloat, color: Color) {
        context.draw(
            Text(text)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(color),
            at: point,
            anchor: .center
        )
    }

    func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        ellipse(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    }

    func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: x, y: y, width: width, height: height))
        return path
    }

    func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: width, height: height),
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )
        return path
    }

    func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        roundedRect(x: x, y: y, width: width, height: height, radius: min(width, height) / 2)
    }

    func triangle(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    func rotated(_ path: Path, degrees: CGFloat, center: CGPoint) -> Path {
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: degrees * .pi / 180)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }

    func bowlPath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        let bottom = y + height
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        path.addLine(to: CGPoint(x: x + width - width * 0.08, y: bottom - height * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: x + width * 0.72, y: bottom),
            control: CGPoint(x: x + width * 0.92, y: bottom)
        )
        path.addLine(to: CGPoint(x: x + width * 0.28, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: x + width * 0.08, y: bottom - height * 0.28),
            control: CGPoint(x: x + width * 0.08, y: bottom)
        )
        path.closeSubpath()
        return path
    }

    func tentPath() -> Path {
        triangle([CGPoint(x: 16, y: 6.4), CGPoint(x: 27, y: 26.2), CGPoint(x: 5, y: 26.2)])
    }

    func shieldPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.8))
        path.addLine(to: CGPoint(x: 24.4, y: 8))
        path.addLine(to: CGPoint(x: 24.4, y: 14.8))
        path.addCurve(
            to: CGPoint(x: 16, y: 27.2),
            control1: CGPoint(x: 24.4, y: 20.3),
            control2: CGPoint(x: 21.3, y: 24.6)
        )
        path.addCurve(
            to: CGPoint(x: 7.6, y: 14.8),
            control1: CGPoint(x: 10.7, y: 24.6),
            control2: CGPoint(x: 7.6, y: 20.3)
        )
        path.addLine(to: CGPoint(x: 7.6, y: 8))
        path.closeSubpath()
        return path
    }

    func bellPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 20.7))
        path.addLine(to: CGPoint(x: 10, y: 14.8))
        path.addArc(
            center: CGPoint(x: 16, y: 14.8),
            radius: 6,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 22, y: 20.7))
        path.addLine(to: CGPoint(x: 24, y: 23.2))
        path.addLine(to: CGPoint(x: 8, y: 23.2))
        path.closeSubpath()
        return path
    }

    func bellClapperPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 13.1, y: 24.2))
        path.addLine(to: CGPoint(x: 18.9, y: 24.2))
        path.addQuadCurve(to: CGPoint(x: 13.1, y: 24.2), control: CGPoint(x: 16, y: 29.2))
        path.closeSubpath()
        return path
    }

    func plantPotPath(x: CGFloat, y: CGFloat, width: CGFloat) -> Path {
        bowlPath(x: x, y: y, width: width, height: 26 - y)
    }

    func plantLeftLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.1, y: 17.8))
        path.addCurve(
            to: CGPoint(x: 7.7, y: 10),
            control1: CGPoint(x: 14.9, y: 13.3),
            control2: CGPoint(x: 12, y: 10.4)
        )
        path.addCurve(
            to: CGPoint(x: 15.1, y: 17.8),
            control1: CGPoint(x: 8.1, y: 14.3),
            control2: CGPoint(x: 11, y: 17.1)
        )
        path.closeSubpath()
        return path
    }

    func plantRightLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16.8, y: 16.8))
        path.addCurve(
            to: CGPoint(x: 24.3, y: 8),
            control1: CGPoint(x: 17.1, y: 12.1),
            control2: CGPoint(x: 20, y: 8.9)
        )
        path.addCurve(
            to: CGPoint(x: 16.8, y: 16.8),
            control1: CGPoint(x: 24.2, y: 12.6),
            control2: CGPoint(x: 21.3, y: 15.8)
        )
        path.closeSubpath()
        return path
    }

    func fertilizeLeftLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.5, y: 17.8))
        path.addCurve(
            to: CGPoint(x: 7.2, y: 11.3),
            control1: CGPoint(x: 14.3, y: 13.4),
            control2: CGPoint(x: 11.2, y: 11.2)
        )
        path.addCurve(
            to: CGPoint(x: 15.5, y: 17.8),
            control1: CGPoint(x: 8.2, y: 15.4),
            control2: CGPoint(x: 11.2, y: 17.6)
        )
        path.closeSubpath()
        return path
    }

    func fertilizeRightLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16.7, y: 17.2))
        path.addCurve(
            to: CGPoint(x: 24.5, y: 9.2),
            control1: CGPoint(x: 17.5, y: 12.4),
            control2: CGPoint(x: 20.3, y: 9.7)
        )
        path.addCurve(
            to: CGPoint(x: 16.7, y: 17.2),
            control1: CGPoint(x: 24.1, y: 13.9),
            control2: CGPoint(x: 21.2, y: 16.8)
        )
        path.closeSubpath()
        return path
    }

    func gameControllerPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.1, y: 11.9))
        path.addLine(to: CGPoint(x: 21.9, y: 11.9))
        path.addCurve(to: CGPoint(x: 26.9, y: 16.9), control1: CGPoint(x: 24.7, y: 11.9), control2: CGPoint(x: 26.9, y: 14.1))
        path.addLine(to: CGPoint(x: 26.9, y: 20.4))
        path.addCurve(to: CGPoint(x: 20.6, y: 22.5), control1: CGPoint(x: 26.9, y: 23.8), control2: CGPoint(x: 22.7, y: 25.2))
        path.addLine(to: CGPoint(x: 19.4, y: 20.9))
        path.addLine(to: CGPoint(x: 12.6, y: 20.9))
        path.addLine(to: CGPoint(x: 11.4, y: 22.5))
        path.addCurve(to: CGPoint(x: 5.1, y: 20.4), control1: CGPoint(x: 9.3, y: 25.2), control2: CGPoint(x: 5.1, y: 23.8))
        path.addLine(to: CGPoint(x: 5.1, y: 16.9))
        path.addCurve(to: CGPoint(x: 10.1, y: 11.9), control1: CGPoint(x: 5.1, y: 14.1), control2: CGPoint(x: 7.3, y: 11.9))
        path.closeSubpath()
        return path
    }

    func bathWavePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 16.5))
        path.addCurve(to: CGPoint(x: 14.7, y: 16.5), control1: CGPoint(x: 10.8, y: 14.3), control2: CGPoint(x: 12.9, y: 14.3))
        path.addCurve(to: CGPoint(x: 20.4, y: 16.5), control1: CGPoint(x: 16.5, y: 18.7), control2: CGPoint(x: 18.6, y: 18.7))
        return path
    }

    func foodBagPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 6.2))
        path.addLine(to: CGPoint(x: 22, y: 6.2))
        path.addLine(to: CGPoint(x: 25, y: 26.2))
        path.addLine(to: CGPoint(x: 7, y: 26.2))
        path.closeSubpath()
        return path
    }

    func waterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.8))
        path.addCurve(to: CGPoint(x: 23.1, y: 17.9), control1: CGPoint(x: 20.8, y: 10.5), control2: CGPoint(x: 23.1, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 25), control1: CGPoint(x: 23.1, y: 22), control2: CGPoint(x: 20, y: 25))
        path.addCurve(to: CGPoint(x: 8.9, y: 17.9), control1: CGPoint(x: 12, y: 25), control2: CGPoint(x: 8.9, y: 22))
        path.addCurve(to: CGPoint(x: 16, y: 4.8), control1: CGPoint(x: 8.9, y: 14.3), control2: CGPoint(x: 11.2, y: 10.5))
        path.closeSubpath()
        return path
    }

    func smallWaterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.2, y: 5.1))
        path.addCurve(to: CGPoint(x: 17.3, y: 16.1), control1: CGPoint(x: 15.3, y: 9.9), control2: CGPoint(x: 17.3, y: 13.2))
        path.addArc(center: CGPoint(x: 11.2, y: 16.1), radius: 6.1, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 11.2, y: 5.1), control1: CGPoint(x: 5.1, y: 13.2), control2: CGPoint(x: 7.1, y: 9.9))
        path.closeSubpath()
        return path
    }

    func plantWaterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 24.3, y: 14.2))
        path.addCurve(to: CGPoint(x: 27.1, y: 19.4), control1: CGPoint(x: 26.2, y: 16.5), control2: CGPoint(x: 27.1, y: 18))
        path.addArc(center: CGPoint(x: 24.3, y: 19.4), radius: 2.8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 24.3, y: 14.2), control1: CGPoint(x: 21.5, y: 18), control2: CGPoint(x: 22.4, y: 16.5))
        path.closeSubpath()
        return path
    }

    func heartPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 23.1))
        path.addCurve(to: CGPoint(x: 10.6, y: 16.3), control1: CGPoint(x: 13.9, y: 21.8), control2: CGPoint(x: 10.6, y: 19.4))
        path.addCurve(to: CGPoint(x: 13.7, y: 12.9), control1: CGPoint(x: 10.6, y: 14.3), control2: CGPoint(x: 11.9, y: 12.9))
        path.addCurve(to: CGPoint(x: 16, y: 14.2), control1: CGPoint(x: 14.8, y: 12.9), control2: CGPoint(x: 15.6, y: 13.4))
        path.addCurve(to: CGPoint(x: 18.3, y: 12.9), control1: CGPoint(x: 16.4, y: 13.4), control2: CGPoint(x: 17.2, y: 12.9))
        path.addCurve(to: CGPoint(x: 21.4, y: 16.3), control1: CGPoint(x: 20.1, y: 12.9), control2: CGPoint(x: 21.4, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 23.1), control1: CGPoint(x: 21.4, y: 19.4), control2: CGPoint(x: 18.1, y: 21.8))
        path.closeSubpath()
        return path
    }

    func weightNeedlePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 17.3))
        path.addLine(to: CGPoint(x: 20, y: 13.5))
        return path
    }

    func taskCheckPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.5, y: 16.4))
        path.addLine(to: CGPoint(x: 14.5, y: 19.5))
        path.addLine(to: CGPoint(x: 20.9, y: 12.5))
        return path
    }

    func hexFoodPiece(center: CGPoint, radius: CGFloat) -> Path {
        let points = (0 ..< 6).map { index in
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        return triangle(points)
    }

    func waterChangeUpperArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 19.4, y: 10.2))
        path.addArc(center: CGPoint(x: 19.4, y: 17.4), radius: 7.2, startAngle: .degrees(-90), endAngle: .degrees(-30), clockwise: false)
        return path
    }

    func waterChangeUpperArrowHead() -> Path {
        triangle([CGPoint(x: 23.3, y: 11.7), CGPoint(x: 27, y: 14.7), CGPoint(x: 22.5, y: 16.2)])
    }

    func waterChangeLowerArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 25.4, y: 19.2))
        path.addCurve(to: CGPoint(x: 19.6, y: 23.7), control1: CGPoint(x: 24.3, y: 21.8), control2: CGPoint(x: 22.4, y: 23.4))
        return path
    }

    func waterChangeLowerArrowHead() -> Path {
        triangle([CGPoint(x: 21.6, y: 21.1), CGPoint(x: 18.9, y: 24.9), CGPoint(x: 17.1, y: 20.5)])
    }

    func filterLeftArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6.8, y: 11.2))
        path.addCurve(to: CGPoint(x: 6.9, y: 21), control1: CGPoint(x: 5.4, y: 14.4), control2: CGPoint(x: 5.5, y: 17.8))
        return path
    }

    func filterLeftArrowHead() -> Path {
        triangle([CGPoint(x: 4.4, y: 18.8), CGPoint(x: 7.1, y: 22.4), CGPoint(x: 8.6, y: 18.3)])
    }

    func filterRightArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 25.2, y: 20.8))
        path.addCurve(to: CGPoint(x: 25.1, y: 11), control1: CGPoint(x: 26.6, y: 17.6), control2: CGPoint(x: 26.5, y: 14.2))
        return path
    }

    func filterRightArrowHead() -> Path {
        triangle([CGPoint(x: 27.6, y: 13.2), CGPoint(x: 24.9, y: 9.6), CGPoint(x: 23.4, y: 13.7)])
    }

    func mapPinPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 5.2))
        path.addArc(center: CGPoint(x: 16, y: 11.4), radius: 6.2, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        path.addCurve(to: CGPoint(x: 16, y: 21.8), control1: CGPoint(x: 22.2, y: 16.1), control2: CGPoint(x: 16, y: 21.8))
        path.addCurve(to: CGPoint(x: 16, y: 5.2), control1: CGPoint(x: 16, y: 21.8), control2: CGPoint(x: 9.8, y: 16.1))
        path.closeSubpath()
        return path
    }

    func walkMapTrailPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.5, y: 24.8))
        path.addCurve(to: CGPoint(x: 17.8, y: 24.8), control1: CGPoint(x: 10.8, y: 22.6), control2: CGPoint(x: 14.2, y: 22.5))
        path.addCurve(to: CGPoint(x: 24.6, y: 24.7), control1: CGPoint(x: 20.1, y: 26.3), control2: CGPoint(x: 22.5, y: 26.3))
        return path
    }

    func distancePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.8, y: 22.4))
        path.addCurve(to: CGPoint(x: 23.8, y: 10), control1: CGPoint(x: 11.6, y: 15), control2: CGPoint(x: 20.4, y: 18.6))
        return path
    }

    func smilePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.2, y: 17.8))
        path.addCurve(to: CGPoint(x: 20.8, y: 17.8), control1: CGPoint(x: 13.6, y: 20.4), control2: CGPoint(x: 18.4, y: 20.4))
        return path
    }

    func checkInPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.8, y: 16.2))
        path.addLine(to: CGPoint(x: 14.4, y: 19.8))
        path.addLine(to: CGPoint(x: 21.4, y: 11.8))
        return path
    }

    func familyPrimaryBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 5.8, y: 24.6))
        path.addCurve(to: CGPoint(x: 19.8, y: 24.6), control1: CGPoint(x: 6.4, y: 19.6), control2: CGPoint(x: 9.2, y: 16.6))
        path.addCurve(to: CGPoint(x: 5.8, y: 24.6), control1: CGPoint(x: 19.2, y: 19.6), control2: CGPoint(x: 16.4, y: 16.6))
        path.closeSubpath()
        return path
    }

    func familySecondaryBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.4, y: 24.6))
        path.addCurve(to: CGPoint(x: 26.5, y: 24.6), control1: CGPoint(x: 15.9, y: 20.6), control2: CGPoint(x: 18.2, y: 18.2))
        path.addCurve(to: CGPoint(x: 15.4, y: 24.6), control1: CGPoint(x: 26, y: 20.6), control2: CGPoint(x: 23.8, y: 18.2))
        path.closeSubpath()
        return path
    }

    func profileBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.8, y: 22.5))
        path.addCurve(to: CGPoint(x: 21.2, y: 22.5), control1: CGPoint(x: 11.4, y: 18.9), control2: CGPoint(x: 13.4, y: 17))
        path.addCurve(to: CGPoint(x: 10.8, y: 22.5), control1: CGPoint(x: 20.6, y: 18.9), control2: CGPoint(x: 18.6, y: 17))
        path.closeSubpath()
        return path
    }

    func lockShacklePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.5, y: 14))
        path.addLine(to: CGPoint(x: 11.5, y: 11.8))
        path.addArc(center: CGPoint(x: 16, y: 11.8), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: 20.5, y: 14))
        return path
    }

    func insuranceCheckPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.9, y: 15.9))
        path.addLine(to: CGPoint(x: 14.7, y: 18.8))
        path.addLine(to: CGPoint(x: 20.2, y: 12.6))
        return path
    }

    func documentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 5.5))
        path.addLine(to: CGPoint(x: 19.4, y: 5.5))
        path.addLine(to: CGPoint(x: 23.5, y: 9.7))
        path.addLine(to: CGPoint(x: 23.5, y: 26.5))
        path.addLine(to: CGPoint(x: 9, y: 26.5))
        path.closeSubpath()
        return path
    }

    func documentFoldPath() -> Path {
        triangle([CGPoint(x: 19.1, y: 5.6), CGPoint(x: 23.6, y: 10.6), CGPoint(x: 19.1, y: 10.6)])
    }

    func photoMountainPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9.4, y: 22.2))
        path.addLine(to: CGPoint(x: 14, y: 16.8))
        path.addLine(to: CGPoint(x: 17.4, y: 20.6))
        path.addLine(to: CGPoint(x: 19.5, y: 18.3))
        path.addLine(to: CGPoint(x: 23, y: 22.2))
        path.closeSubpath()
        return path
    }

    func birthdayFlamePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.3))
        path.addCurve(to: CGPoint(x: 18.2, y: 8.1), control1: CGPoint(x: 17.5, y: 6.1), control2: CGPoint(x: 18.2, y: 7.1))
        path.addArc(center: CGPoint(x: 16, y: 8.1), radius: 2.2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 16, y: 4.3), control1: CGPoint(x: 13.8, y: 7.1), control2: CGPoint(x: 14.5, y: 6.1))
        path.closeSubpath()
        return path
    }

    func rewardRibbonPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.4, y: 18))
        path.addLine(to: CGPoint(x: 14.6, y: 26.5))
        path.addLine(to: CGPoint(x: 16.8, y: 23.5))
        path.addLine(to: CGPoint(x: 20, y: 24.9))
        path.addLine(to: CGPoint(x: 16.8, y: 16.6))
        path.closeSubpath()
        return path
    }

    func temperatureDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 22.5, y: 6.4))
        path.addCurve(to: CGPoint(x: 27.2, y: 15.1), control1: CGPoint(x: 25.7, y: 10.2), control2: CGPoint(x: 27.2, y: 12.7))
        path.addArc(center: CGPoint(x: 22.5, y: 15.1), radius: 4.7, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 22.5, y: 6.4), control1: CGPoint(x: 17.8, y: 12.7), control2: CGPoint(x: 19.3, y: 10.2))
        path.closeSubpath()
        return path
    }

    func temperatureHighlightPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 21.1, y: 13.4))
        path.addCurve(to: CGPoint(x: 23.5, y: 10.2), control1: CGPoint(x: 21.8, y: 12.2), control2: CGPoint(x: 22.6, y: 11.2))
        return path
    }

    func notificationBellPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 20.4))
        path.addLine(to: CGPoint(x: 10, y: 14.8))
        path.addArc(center: CGPoint(x: 16, y: 14.8), radius: 6, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: 22, y: 20.4))
        path.addLine(to: CGPoint(x: 24.1, y: 23))
        path.addLine(to: CGPoint(x: 7.9, y: 23))
        path.closeSubpath()
        return path
    }

    func notificationBellClapperPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 13.2, y: 24))
        path.addLine(to: CGPoint(x: 18.8, y: 24))
        path.addQuadCurve(to: CGPoint(x: 13.2, y: 24), control: CGPoint(x: 16, y: 28.8))
        path.closeSubpath()
        return path
    }

    func notificationHeartPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 22.4, y: 12.9))
        path.addCurve(to: CGPoint(x: 19.2, y: 8.8), control1: CGPoint(x: 21.2, y: 12.2), control2: CGPoint(x: 19.2, y: 10.7))
        path.addCurve(to: CGPoint(x: 21.1, y: 6.7), control1: CGPoint(x: 19.2, y: 7.6), control2: CGPoint(x: 20, y: 6.7))
        path.addCurve(to: CGPoint(x: 22.4, y: 7.5), control1: CGPoint(x: 21.7, y: 6.7), control2: CGPoint(x: 22.2, y: 7))
        path.addCurve(to: CGPoint(x: 23.7, y: 6.7), control1: CGPoint(x: 22.6, y: 7), control2: CGPoint(x: 23.1, y: 6.7))
        path.addCurve(to: CGPoint(x: 25.6, y: 8.8), control1: CGPoint(x: 24.8, y: 6.7), control2: CGPoint(x: 25.6, y: 7.6))
        path.addCurve(to: CGPoint(x: 22.4, y: 12.9), control1: CGPoint(x: 25.6, y: 10.7), control2: CGPoint(x: 23.6, y: 12.2))
        path.closeSubpath()
        return path
    }

    func birdBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 5.2, y: 17.4))
        path.addCurve(
            to: CGPoint(x: 14.6, y: 12.5),
            control1: CGPoint(x: 8.1, y: 16.9),
            control2: CGPoint(x: 10.9, y: 14.4)
        )
        path.addCurve(
            to: CGPoint(x: 26.8, y: 7.1),
            control1: CGPoint(x: 19.1, y: 10.3),
            control2: CGPoint(x: 23.3, y: 8.1)
        )
        path.addCurve(
            to: CGPoint(x: 20.2, y: 18.8),
            control1: CGPoint(x: 26.1, y: 12.6),
            control2: CGPoint(x: 24.3, y: 16.6)
        )
        path.addCurve(
            to: CGPoint(x: 11.9, y: 22.4),
            control1: CGPoint(x: 17.2, y: 20.4),
            control2: CGPoint(x: 14.4, y: 21.8)
        )
        path.closeSubpath()
        return path
    }

    func birdWingPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.4, y: 17.3))
        path.addCurve(
            to: CGPoint(x: 23.7, y: 10.2),
            control1: CGPoint(x: 15.8, y: 16.6),
            control2: CGPoint(x: 20.3, y: 13.5)
        )
        path.addCurve(
            to: CGPoint(x: 17.5, y: 18.6),
            control1: CGPoint(x: 22.3, y: 14.9),
            control2: CGPoint(x: 20, y: 17.4)
        )
        path.closeSubpath()
        return path
    }

    func birdFlightPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 4.8, y: 20.3))
        path.addCurve(
            to: CGPoint(x: 10, y: 20.3),
            control1: CGPoint(x: 6.5, y: 18.6),
            control2: CGPoint(x: 8.3, y: 18.6)
        )
        return path
    }

    func cloudPath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 5.5, y: 12, width: 10, height: 10))
        path.addEllipse(in: CGRect(x: 10.2, y: 7, width: 12.5, height: 14))
        path.addEllipse(in: CGRect(x: 18, y: 11.5, width: 8.5, height: 9.5))
        path.addRoundedRect(
            in: CGRect(x: 7.5, y: 15, width: 17, height: 7),
            cornerSize: CGSize(width: 3.5, height: 3.5),
            style: .continuous
        )
        return path
    }

    func mistDropPath(center: CGPoint) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - 3))
        path.addCurve(
            to: CGPoint(x: center.x + 2, y: center.y + 0.7),
            control1: CGPoint(x: center.x + 1.4, y: center.y - 1.3),
            control2: CGPoint(x: center.x + 2, y: center.y - 0.1)
        )
        path.addArc(
            center: CGPoint(x: center.x, y: center.y + 0.7),
            radius: 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - 3),
            control1: CGPoint(x: center.x - 2, y: center.y - 0.1),
            control2: CGPoint(x: center.x - 1.4, y: center.y - 1.3)
        )
        path.closeSubpath()
        return path
    }

    func workoutBarPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7, y: 16))
        path.addLine(to: CGPoint(x: 25, y: 16))
        return path
    }

    func workoutMotionPath(left: Bool) -> Path {
        let direction: CGFloat = left ? 1 : -1
        let originX: CGFloat = left ? 4.6 : 27.4
        var path = Path()
        path.move(to: CGPoint(x: originX, y: 10.3))
        path.addLine(to: CGPoint(x: originX + direction * 3.4, y: 7))
        return path
    }

    func pruningLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.8, y: 19.5))
        path.addCurve(
            to: CGPoint(x: 17.9, y: 7.2),
            control1: CGPoint(x: 11.3, y: 13.4),
            control2: CGPoint(x: 14.6, y: 8.4)
        )
        path.addCurve(
            to: CGPoint(x: 11.8, y: 19.5),
            control1: CGPoint(x: 20.3, y: 12),
            control2: CGPoint(x: 17, y: 17.2)
        )
        path.closeSubpath()
        return path
    }

    func pruningScissorPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 20, y: 16.1))
        path.addLine(to: CGPoint(x: 26.4, y: 6.9))
        path.move(to: CGPoint(x: 22, y: 16.8))
        path.addLine(to: CGPoint(x: 15.7, y: 9.4))
        return path
    }

    func genericLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6.5, y: 23.7))
        path.addCurve(
            to: CGPoint(x: 25.1, y: 6.4),
            control1: CGPoint(x: 8.2, y: 13.4),
            control2: CGPoint(x: 16.2, y: 6.3)
        )
        path.addCurve(
            to: CGPoint(x: 6.5, y: 23.7),
            control1: CGPoint(x: 24.4, y: 16.1),
            control2: CGPoint(x: 16.5, y: 23.8)
        )
        path.closeSubpath()
        return path
    }

    func pestMagnifierPath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 13.3, y: 9.8, width: 11, height: 11))
        path.move(to: CGPoint(x: 22.5, y: 19))
        path.addLine(to: CGPoint(x: 27, y: 23.5))
        return path
    }

    func pestBugPath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 15.2, y: 11.5, width: 7.2, height: 8.2))
        path.move(to: CGPoint(x: 18.8, y: 11.5))
        path.addLine(to: CGPoint(x: 18.8, y: 19.7))
        return path
    }

    func plantRotateArrowPath() -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: 16, y: 16),
            radius: 11.2,
            startAngle: .degrees(205),
            endAngle: .degrees(335),
            clockwise: false
        )
        return path
    }

    func plantRotateArrowHead() -> Path {
        triangle([
            CGPoint(x: 25.8, y: 9.7),
            CGPoint(x: 27.9, y: 15),
            CGPoint(x: 22.4, y: 13.8)
        ])
    }

    func repotLeafPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.2, y: 18.9))
        path.addCurve(
            to: CGPoint(x: 15.3, y: 8.4),
            control1: CGPoint(x: 9.8, y: 13.8),
            control2: CGPoint(x: 12.2, y: 9.4)
        )
        path.addCurve(
            to: CGPoint(x: 10.2, y: 18.9),
            control1: CGPoint(x: 17.5, y: 12.8),
            control2: CGPoint(x: 15, y: 17.1)
        )
        path.closeSubpath()
        return path
    }

    func repotArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.8, y: 13.8))
        path.addCurve(
            to: CGPoint(x: 22.5, y: 12.7),
            control1: CGPoint(x: 15.2, y: 10.5),
            control2: CGPoint(x: 19.4, y: 10.2)
        )
        return path
    }

    func repotArrowHead() -> Path {
        triangle([
            CGPoint(x: 20.5, y: 9.8),
            CGPoint(x: 25.2, y: 12.8),
            CGPoint(x: 20.2, y: 15.2)
        ])
    }

    func newLeafStemPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.5, y: 20.2))
        path.addCurve(
            to: CGPoint(x: 18.8, y: 9.6),
            control1: CGPoint(x: 15.4, y: 15.2),
            control2: CGPoint(x: 17.2, y: 11.5)
        )
        return path
    }

    func newLeafAccentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 17.2, y: 13.4))
        path.addCurve(
            to: CGPoint(x: 25.4, y: 7.1),
            control1: CGPoint(x: 19.2, y: 9.5),
            control2: CGPoint(x: 22.3, y: 7.3)
        )
        path.addCurve(
            to: CGPoint(x: 17.2, y: 13.4),
            control1: CGPoint(x: 24.7, y: 11.7),
            control2: CGPoint(x: 21.5, y: 14)
        )
        path.closeSubpath()
        return path
    }

    func gearPath() -> Path {
        var path = Path()
        let center = CGPoint(x: 16, y: 16)
        for index in 0 ..< 16 {
            let angle = CGFloat(index) * .pi / 8
            let radius: CGFloat = index.isMultiple(of: 2) ? 11.2 : 8.7
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
