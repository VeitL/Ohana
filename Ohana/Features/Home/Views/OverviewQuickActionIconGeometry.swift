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
        func point(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
            UnitPoint(x: x / 32, y: y / 32)
        }

        switch self {
        case .feed:
            return [point(12.2, 12.1), point(16.4, 11.1), point(20.4, 12.6)][elementIndex]
        case .calendar:
            return [point(16, 11.5), point(11.3, 17.3), point(16, 17.3), point(20.7, 17.3), point(18, 21.8)][elementIndex]
        case .walk:
            return [point(11, 11.8), point(6.6, 8.8), point(25.1, 14.7)][elementIndex]
        case .water:
            return point(16, 15.2)
        case .potty:
            return point(16, 13.2)
        case .sleep:
            return elementIndex == 0 ? point(21.1, 8.4) : point(25, 12.4)
        case .weight:
            return point(16, 17.3)
        case .reminder:
            return point(23.3, 8.7)
        case .plantWater:
            return point(24.3, 19)
        case .play:
            return [point(12.3, 17.2), point(21, 16.4), point(23.9, 19)][elementIndex]
        case .bath:
            return elementIndex == 0 ? point(22.6, 8.3) : point(18.6, 11.2)
        case .task:
            return elementIndex == 0 ? point(16, 16) : point(22.7, 22.7)
        case .dryFood:
            let points = [(11.0, 15.8), (15.1, 14.2), (19.2, 15.7), (13.0, 18.8), (17.2, 18.9), (21.1, 18.1)]
            return point(points[elementIndex].0, points[elementIndex].1)
        case .treat:
            return [point(8.8, 20.7), point(23.2, 11.3), point(16, 15.25)][elementIndex]
        case .feeder:
            return elementIndex == 0 ? point(16, 10.5) : point(16, 16)
        case .filterChange:
            return elementIndex == 3 ? point(16, 16) : point(16, 12 + CGFloat(elementIndex) * 3.9)
        case .litter:
            return [point(10.3, 16.8), point(13.4, 15.8), point(20.2, 12)][elementIndex]
        case .cleanup:
            return [point(22.7, 8.5), point(25.4, 13), point(8.2, 24.5)][elementIndex]
        case .distance:
            return elementIndex == 0 ? point(7.8, 22.4) : point(24.2, 6.8)
        case .mood:
            return elementIndex == 0 ? point(20.2, 12.2) : point(16, 18.8)
        case .family:
            return elementIndex == 0 ? point(20.1, 11.9) : point(21, 21.5)
        case .profile:
            return elementIndex == 0 ? point(16, 13) : point(16, 20)
        case .birthday:
            return elementIndex == 0 ? point(16, 14.6) : point(16, 7)
        case .temperature:
            return elementIndex == 0 ? point(11.3, 24.5) : point(22.5, 15)
        case .plantFertilize:
            return elementIndex == 0 ? point(23.8, 20.5) : point(25.8, 15.6)
        case .allFeatures:
            return point(21.5, 21.5)
        case .freeFlight:
            return elementIndex == 0 ? point(16.5, 14.2) : point(7.3, 20.2)
        case .misting:
            return [point(11, 23), point(16, 25), point(21, 23)][elementIndex]
        case .substrateChange:
            return point(16, 14 + CGFloat(elementIndex) * 3.6)
        case .workout:
            return [point(16, 16), point(7.1, 8.6), point(24.9, 8.6)][elementIndex]
        case .plantPruning:
            return point(21.2, 12.8)
        case .plantPestCheck:
            return point(18.8, 15.3)
        case .plantRotating:
            return point(16, 15.8)
        case .plantRepotting:
            return point(17.6, 15.2)
        case .plantNewLeaf:
            return point(21.4, 11.2)
        case .plantIssue:
            return point(17.8, 15.8)
        default:
            return .center
        }
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

private struct OhanaQuickActionGlyphDrawing {
    private var context: GraphicsContext
    private let primaryColor: Color
    private let accentColor: Color

    init(context: GraphicsContext, size: CGSize, primaryColor: Color, accentColor: Color) {
        let side = min(size.width, size.height)
        var scaledContext = context
        scaledContext.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        scaledContext.scaleBy(x: side / 32, y: side / 32)
        self.context = scaledContext
        self.primaryColor = primaryColor
        self.accentColor = accentColor
    }

    mutating func drawBase(_ kind: OhanaQuickActionGlyphKind) {
        switch kind {
        case .feed:
            fill(ellipse(x: 6.6, y: 9.8, width: 18.8, height: 8.8), primaryColor, opacity: 0.22)
            fill(bowlPath(x: 5.5, y: 14.7, width: 21, height: 11.3), primaryColor)
        case .calendar:
            fill(roundedRect(x: 5.5, y: 6.5, width: 21, height: 20, radius: 5.5), primaryColor)
        case .walk:
            fill(roundedRect(x: 11.3, y: 15, width: 11.4, height: 6.7, radius: 3.2), primaryColor)
            fill(circle(cx: 23.5, cy: 14.9, r: 4.1), primaryColor)
            fill(triangle([
                CGPoint(x: 21.7, y: 11.9), CGPoint(x: 23.2, y: 7.9), CGPoint(x: 25.3, y: 12.6)
            ]), primaryColor, opacity: 0.64)
            var tail = Path()
            tail.move(to: CGPoint(x: 13.3, y: 15.3))
            tail.addLine(to: CGPoint(x: 8.1, y: 14.2))
            stroke(tail, primaryColor, width: 2.1)
            fill(capsule(x: 13.1, y: 20.2, width: 2.2, height: 5.2), primaryColor)
            fill(capsule(x: 19.4, y: 20.2, width: 2.2, height: 5.2), primaryColor)
        case .water:
            fill(bowlPath(x: 7.2, y: 20.2, width: 17.6, height: 5.8), primaryColor)
            fill(ellipse(x: 7.2, y: 17.3, width: 17.6, height: 6), primaryColor, opacity: 0.22)
        case .potty:
            fill(bowlPath(x: 7, y: 17.2, width: 18, height: 8.8), primaryColor)
            fill(roundedRect(x: 7.8, y: 7.4, width: 16.4, height: 10.8, radius: 4), primaryColor, opacity: 0.22)
        case .medicine:
            fill(rotated(capsule(x: 5.4, y: 12, width: 21.2, height: 8), degrees: -35, center: CGPoint(x: 16, y: 16)), primaryColor)
            fill(rotated(circle(cx: 11.8, cy: 16, r: 2.1), degrees: -35, center: CGPoint(x: 16, y: 16)), primaryColor, opacity: 0.22)
        case .groom:
            fill(roundedRect(x: 6.5, y: 8.5, width: 19, height: 6, radius: 3), primaryColor)
            fill(capsule(x: 22.6, y: 10.2, width: 4.2, height: 11.2), primaryColor, opacity: 0.42)
        case .health:
            fill(roundedRect(x: 7, y: 6, width: 18, height: 21, radius: 5.2), primaryColor)
            fill(capsule(x: 11, y: 9.7, width: 10, height: 2.8), primaryColor, opacity: 0.22)
        case .sleep:
            fill(tentPath(), primaryColor)
        case .vet:
            fill(shieldPath(), primaryColor)
        case .weight:
            fill(roundedRect(x: 5.5, y: 8, width: 21, height: 18.5, radius: 6), primaryColor)
            fill(capsule(x: 10, y: 11, width: 12, height: 3), primaryColor, opacity: 0.22)
        case .reminder:
            fill(bellPath(), primaryColor)
            fill(bellClapperPath(), primaryColor)
        case .plantWater:
            fill(plantPotPath(x: 9.2, y: 17.4, width: 13.6), primaryColor)
            fill(plantLeftLeafPath(), primaryColor)
            fill(plantRightLeafPath(), primaryColor)
        case .play:
            fill(gameControllerPath(), primaryColor)
        case .bath:
            fill(bowlPath(x: 6.5, y: 17.2, width: 19, height: 8.8), primaryColor)
            stroke(bathWavePath(), primaryColor, width: 4.2)
        case .task:
            fill(roundedRect(x: 6.5, y: 6.5, width: 19, height: 19, radius: 6), primaryColor)
        case .foodStock, .foodBag:
            fill(foodBagPath(), primaryColor)
            fill(capsule(x: 11, y: 8.8, width: 10, height: 2.7), primaryColor, opacity: 0.22)
        case .dryFood:
            fill(bowlPath(x: 6.2, y: 18.5, width: 19.6, height: 7.5), primaryColor)
        case .wetFood:
            fill(ellipse(x: 8.4, y: 7.1, width: 15.2, height: 5.6), primaryColor)
            fill(roundedRect(x: 8.4, y: 9.8, width: 15.2, height: 15.4, radius: 4), primaryColor)
        case .treat:
            fill(rotated(capsule(x: 8.2, y: 11, width: 15.6, height: 10), degrees: -24, center: CGPoint(x: 16, y: 16)), primaryColor)
        case .feeder:
            fill(roundedRect(x: 10.5, y: 5, width: 11, height: 15.2, radius: 4.4), primaryColor)
            fill(bowlPath(x: 7.4, y: 19, width: 17.2, height: 7), primaryColor)
        case .waterChange:
            fill(smallWaterDropPath(), primaryColor)
        case .filterChange:
            fill(roundedRect(x: 10, y: 6.2, width: 12, height: 19.6, radius: 4), primaryColor)
            fill(capsule(x: 8.5, y: 6.2, width: 15, height: 3.2), primaryColor, opacity: 0.22)
            fill(capsule(x: 8.5, y: 22.6, width: 15, height: 3.2), primaryColor, opacity: 0.22)
        case .litter:
            fill(bowlPath(x: 5.8, y: 18.2, width: 20.4, height: 8), primaryColor)
            fill(ellipse(x: 5.8, y: 14.2, width: 20.4, height: 7), primaryColor, opacity: 0.22)
        case .cleanup:
            fill(rotated(capsule(x: 8.4, y: 17.4, width: 15.8, height: 6.2), degrees: -18, center: CGPoint(x: 16.3, y: 20.5)), primaryColor)
            fill(rotated(capsule(x: 13.5, y: 7, width: 4, height: 13.5), degrees: -18, center: CGPoint(x: 15.5, y: 13.8)), primaryColor)
        case .walkMap:
            fill(mapPinPath(), primaryColor)
            stroke(walkMapTrailPath(), primaryColor, width: 4.2)
        case .distance:
            stroke(distancePath(), primaryColor, width: 4.2)
            fill(circle(cx: 23.8, cy: 10, r: 3), primaryColor)
        case .training:
            fill(circle(cx: 16, cy: 16, r: 10.4), primaryColor)
            fill(rotated(capsule(x: 22.2, y: 5.5, width: 5.4, height: 3.2), degrees: 35, center: CGPoint(x: 24.9, y: 7.1)), primaryColor)
        case .mood:
            fill(circle(cx: 16, cy: 16, r: 10.2), primaryColor)
        case .checkIn:
            fill(roundedRect(x: 6.5, y: 6.5, width: 19, height: 19, radius: 9.5), primaryColor)
        case .family:
            fill(circle(cx: 12.3, cy: 10.6, r: 4.2), primaryColor)
            fill(familyPrimaryBodyPath(), primaryColor)
        case .profile:
            fill(roundedRect(x: 6.5, y: 5.8, width: 19, height: 21, radius: 5.5), primaryColor)
        case .privacy:
            fill(roundedRect(x: 7.8, y: 14, width: 16.4, height: 12, radius: 4.2), primaryColor)
            stroke(lockShacklePath(), primaryColor, width: 4.2)
        case .expense:
            fill(roundedRect(x: 6, y: 9, width: 20, height: 15.8, radius: 5), primaryColor)
        case .insurance:
            fill(shieldPath(), primaryColor)
        case .document:
            fill(documentPath(), primaryColor)
        case .photo:
            fill(roundedRect(x: 6, y: 8, width: 20, height: 16, radius: 5), primaryColor)
        case .birthday:
            fill(roundedRect(x: 7, y: 15.2, width: 18, height: 10.3, radius: 4), primaryColor)
            fill(roundedRect(x: 14.6, y: 6.6, width: 2.8, height: 6.8, radius: 1.4), primaryColor)
        case .reward:
            fill(circle(cx: 16, cy: 12.6, r: 7.5), primaryColor)
            fill(rewardRibbonPath(), primaryColor)
        case .temperature:
            fill(roundedRect(x: 8.2, y: 5.2, width: 6.2, height: 15.8, radius: 3.1), primaryColor)
            fill(circle(cx: 11.3, cy: 22, r: 5.2), primaryColor)
            stroke(temperatureHighlightPath(), primaryColor, width: 2.1)
        case .plantFertilize:
            fill(plantPotPath(x: 9.1, y: 18, width: 13.8), primaryColor)
            fill(fertilizeLeftLeafPath(), primaryColor)
            fill(fertilizeRightLeafPath(), primaryColor)
        case .notificationHealth:
            fill(notificationBellPath(), primaryColor)
            fill(notificationBellClapperPath(), primaryColor)
        case .settings:
            fill(gearPath(), primaryColor)
        case .allFeatures:
            for y in [7.0, 18.0] {
                for x in [7.0, 18.0] {
                    fill(roundedRect(x: x, y: y, width: 7, height: 7, radius: 2.2), primaryColor)
                }
            }
        case .freeFlight:
            fill(birdBodyPath(), primaryColor)
        case .misting:
            fill(cloudPath(), primaryColor)
        case .substrateChange:
            fill(bowlPath(x: 6.2, y: 12.5, width: 19.6, height: 13.5), primaryColor)
            fill(ellipse(x: 6.2, y: 9.5, width: 19.6, height: 7), primaryColor, opacity: 0.22)
        case .workout:
            stroke(workoutBarPath(), primaryColor, width: 3.6)
            fill(roundedRect(x: 4.8, y: 10.8, width: 4.2, height: 10.4, radius: 2.1), primaryColor)
            fill(roundedRect(x: 23, y: 10.8, width: 4.2, height: 10.4, radius: 2.1), primaryColor)
            fill(roundedRect(x: 8.3, y: 12.3, width: 3.2, height: 7.4, radius: 1.6), primaryColor, opacity: 0.64)
            fill(roundedRect(x: 20.5, y: 12.3, width: 3.2, height: 7.4, radius: 1.6), primaryColor, opacity: 0.64)
        case .plantPruning:
            fill(plantPotPath(x: 6.8, y: 19, width: 12.5), primaryColor)
            fill(pruningLeafPath(), primaryColor)
        case .plantPestCheck:
            fill(genericLeafPath(), primaryColor)
            stroke(pestMagnifierPath(), primaryColor, width: 3.2)
        case .plantRotating:
            fill(plantPotPath(x: 10.2, y: 18.7, width: 11.6), primaryColor)
            fill(fertilizeLeftLeafPath(), primaryColor)
            fill(fertilizeRightLeafPath(), primaryColor)
        case .plantRepotting:
            fill(plantPotPath(x: 4.9, y: 18.8, width: 10.6), primaryColor)
            fill(plantPotPath(x: 18.1, y: 17.3, width: 9), primaryColor, opacity: 0.64)
            fill(repotLeafPath(), primaryColor)
        case .plantNewLeaf:
            fill(plantPotPath(x: 8.8, y: 19.4, width: 12.6), primaryColor)
            stroke(newLeafStemPath(), primaryColor, width: 3)
            fill(plantLeftLeafPath(), primaryColor)
        case .plantIssue:
            fill(genericLeafPath(), primaryColor)
        }
    }

    mutating func drawAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
        case .feed:
            let dots = [(12.2, 12.1, 2.2), (16.4, 11.1, 2.55), (20.4, 12.6, 2.1)]
            fill(circle(cx: dots[index].0, cy: dots[index].1, r: dots[index].2), accentColor)
        case .calendar:
            switch index {
            case 0: fill(capsule(x: 9, y: 10, width: 14, height: 3), accentColor)
            case 1: fill(circle(cx: 11.3, cy: 17.3, r: 1.55), accentColor)
            case 2: fill(circle(cx: 16, cy: 17.3, r: 1.55), accentColor)
            case 3: fill(circle(cx: 20.7, cy: 17.3, r: 1.55), accentColor)
            default: fill(capsule(x: 14.1, y: 20.2, width: 7.9, height: 3.2), accentColor)
            }
        case .walk:
            switch index {
            case 0:
                var leash = Path()
                leash.move(to: CGPoint(x: 6.6, y: 8.8))
                leash.addCurve(to: CGPoint(x: 15.5, y: 14.7), control1: CGPoint(x: 9.3, y: 8.4), control2: CGPoint(x: 11.6, y: 12.4))
                stroke(leash, accentColor, width: 2.1)
            case 1: fill(circle(cx: 6.6, cy: 8.8, r: 1.9), accentColor)
            default: fill(circle(cx: 25.1, cy: 14.7, r: 0.9), accentColor)
            }
        case .water:
            fill(waterDropPath(), accentColor)
        case .potty:
            drawLabel("WC", at: CGPoint(x: 16, y: 13.2), size: 7.5, color: accentColor)
        case .medicine:
            fill(rotated(capsule(x: 16, y: 12.4, width: 10.1, height: 7.2), degrees: -35, center: CGPoint(x: 16, y: 16)), accentColor)
        case .groom:
            let xValues: [CGFloat] = [8.5, 11.4, 14.3, 17.2, 20.1]
            fill(capsule(x: xValues[index], y: 13.2, width: 1.55, height: 10.7), accentColor)
        case .health:
            fill(heartPath(), accentColor)
        case .sleep:
            if index == 0 {
                drawLabel("Z", at: CGPoint(x: 21.1, y: 8.4), size: 7.4, color: accentColor)
            } else {
                drawLabel("z", at: CGPoint(x: 25, y: 12.4), size: 5.9, color: accentColor)
            }
        case .vet:
            fill(roundedRect(x: 14.2, y: 10.6, width: 3.6, height: 11, radius: 1.8), accentColor)
            fill(roundedRect(x: 10.5, y: 14.3, width: 11, height: 3.6, radius: 1.8), accentColor)
        case .weight:
            stroke(weightNeedlePath(), accentColor, width: 3)
            fill(circle(cx: 16, cy: 17.3, r: 2.45), accentColor)
        case .reminder:
            fill(circle(cx: 23.3, cy: 8.7, r: 3.2), accentColor)
        case .plantWater:
            fill(plantWaterDropPath(), accentColor)
        case .play:
            switch index {
            case 0:
                fill(capsule(x: 9.3, y: 16.1, width: 6.2, height: 2.1), accentColor)
                fill(capsule(x: 11.3, y: 14.1, width: 2.1, height: 6.2), accentColor)
            case 1: fill(circle(cx: 21, cy: 16.4, r: 1.55), accentColor)
            default: fill(circle(cx: 23.9, cy: 19, r: 1.55), accentColor)
            }
        case .bath:
            if index == 0 {
                fill(circle(cx: 22.6, cy: 8.3, r: 2.3), accentColor)
            } else {
                fill(circle(cx: 18.6, cy: 11.2, r: 1.6), accentColor)
            }
        case .task:
            if index == 0 {
                stroke(taskCheckPath(), accentColor, width: 3)
            } else {
                fill(circle(cx: 22.7, cy: 22.7, r: 2.2), accentColor)
            }
        case .foodStock, .foodBag:
            let bars = [(10.0, 15.1, 12.0), (10.0, 19.0, 9.2), (10.0, 22.9, 6.4)]
            fill(capsule(x: bars[index].0, y: bars[index].1, width: bars[index].2, height: 2.3), accentColor)
        case .dryFood:
            let points = [
                CGPoint(x: 11, y: 15.8), CGPoint(x: 15.1, y: 14.2), CGPoint(x: 19.2, y: 15.7),
                CGPoint(x: 13, y: 18.8), CGPoint(x: 17.2, y: 18.9), CGPoint(x: 21.1, y: 18.1)
            ]
            fill(hexFoodPiece(center: points[index], radius: 1.75), accentColor)
        case .wetFood:
            if index == 0 {
                fill(ellipse(x: 8.4, y: 21.8, width: 15.2, height: 5), accentColor)
                fill(capsule(x: 11.3, y: 13.2, width: 9.4, height: 5.4), accentColor)
            } else {
                fill(circle(cx: 16, cy: 16, r: 2.35), accentColor)
            }
        case .treat:
            switch index {
            case 0: fill(circle(cx: 8.8, cy: 20.7, r: 3), accentColor)
            case 1: fill(circle(cx: 23.2, cy: 11.3, r: 2.5), accentColor)
            default:
                fill(rotated(capsule(x: 13.4, y: 13.9, width: 5.2, height: 2.7), degrees: -24, center: CGPoint(x: 16, y: 15.25)), accentColor)
            }
        case .feeder:
            if index == 0 {
                fill(capsule(x: 13, y: 9, width: 6, height: 3), accentColor)
            } else {
                fill(circle(cx: 16, cy: 16, r: 2.6), accentColor)
            }
        case .waterChange:
            stroke(waterChangeUpperArrowPath(), accentColor, width: 3)
            fill(waterChangeUpperArrowHead(), accentColor)
            stroke(waterChangeLowerArrowPath(), accentColor, width: 3)
            fill(waterChangeLowerArrowHead(), accentColor)
        case .filterChange:
            if index < 3 {
                fill(capsule(x: 13, y: 11 + CGFloat(index) * 3.9, width: 6, height: 2.2), accentColor)
            } else {
                stroke(filterLeftArrowPath(), accentColor, width: 3)
                fill(filterLeftArrowHead(), accentColor)
                stroke(filterRightArrowPath(), accentColor, width: 3)
                fill(filterRightArrowHead(), accentColor)
            }
        case .litter:
            switch index {
            case 0: fill(circle(cx: 10.3, cy: 16.8, r: 0.9), accentColor)
            case 1: fill(circle(cx: 13.4, cy: 15.8, r: 0.75), accentColor)
            default:
                fill(roundedRect(x: 18.5, y: 4.6, width: 3.6, height: 10.4, radius: 1.8), accentColor)
                fill(roundedRect(x: 15.2, y: 12, width: 10, height: 7.2, radius: 2.5), accentColor)
                for point in [CGPoint(x: 18.1, y: 15), CGPoint(x: 21, y: 15), CGPoint(x: 19.5, y: 17.2), CGPoint(x: 22.4, y: 17.2)] {
                    fill(circle(cx: point.x, cy: point.y, r: 0.68), primaryColor)
                }
            }
        case .cleanup:
            let dots = [(22.7, 8.5, 2.2), (25.4, 13.0, 1.35), (8.2, 24.5, 1.5)]
            fill(circle(cx: dots[index].0, cy: dots[index].1, r: dots[index].2), accentColor)
        case .walkMap:
            fill(circle(cx: 16, cy: 11.5, r: 2.4), accentColor)
        case .distance:
            if index == 0 {
                fill(circle(cx: 7.8, cy: 22.4, r: 3), accentColor)
            } else {
                fill(capsule(x: 21.4, y: 5.2, width: 5.6, height: 3.2), accentColor)
            }
        case .training:
            if index == 0 {
                fill(circle(cx: 16, cy: 16, r: 6.2), accentColor)
            } else {
                fill(circle(cx: 16, cy: 16, r: 2.7), accentColor)
            }
        case .mood:
            if index == 0 {
                fill(circle(cx: 20.2, cy: 12.2, r: 2.1), accentColor)
            } else {
                stroke(smilePath(), accentColor, width: 3)
            }
        case .checkIn:
            if index == 0 {
                stroke(checkInPath(), accentColor, width: 3)
            } else {
                fill(circle(cx: 23.1, cy: 22.6, r: 2.2), accentColor)
            }
        case .family:
            if index == 0 {
                fill(circle(cx: 20.1, cy: 11.9, r: 3.4), accentColor)
            } else {
                fill(familySecondaryBodyPath(), accentColor)
            }
        case .profile:
            if index == 0 {
                fill(circle(cx: 16, cy: 13, r: 3.4), accentColor)
            } else {
                fill(profileBodyPath(), accentColor)
            }
        case .privacy:
            fill(circle(cx: 16, cy: 20.1, r: 2.3), accentColor)
        case .expense:
            if index == 0 {
                fill(capsule(x: 8.6, y: 12, width: 14.8, height: 3), accentColor)
            } else {
                drawLabel(AppCurrency.symbol, at: CGPoint(x: 16, y: 20.2), size: AppCurrency.symbol.count > 1 ? 6.8 : 9, color: accentColor)
            }
        case .insurance:
            stroke(insuranceCheckPath(), accentColor, width: 3)
        case .document:
            switch index {
            case 0: fill(documentFoldPath(), accentColor)
            case 1: fill(capsule(x: 12, y: 15.1, width: 8, height: 2.4), accentColor)
            default: fill(capsule(x: 12, y: 19.6, width: 6.2, height: 2.4), accentColor)
            }
        case .photo:
            if index == 0 {
                fill(circle(cx: 20.8, cy: 12.6, r: 2.1), accentColor)
            } else {
                fill(photoMountainPath(), accentColor)
            }
        case .birthday:
            if index == 0 {
                fill(capsule(x: 9, y: 12.2, width: 14, height: 4.8), accentColor)
            } else {
                fill(birthdayFlamePath(), accentColor)
            }
        case .reward:
            fill(circle(cx: 16, cy: 12.6, r: 3.2), accentColor)
        case .temperature:
            if index == 0 {
                fill(capsule(x: 10.2, y: 9.2, width: 2.2, height: 12), accentColor)
                fill(circle(cx: 11.3, cy: 22, r: 2.45), accentColor)
            } else {
                fill(temperatureDropPath(), accentColor)
            }
        case .plantFertilize:
            if index == 0 {
                fill(circle(cx: 23.8, cy: 20.5, r: 2), accentColor)
            } else {
                fill(circle(cx: 25.8, cy: 15.6, r: 1.4), accentColor)
            }
        case .notificationHealth:
            fill(notificationHeartPath(), accentColor)
        case .settings:
            fill(circle(cx: 16, cy: 16, r: 4.1), accentColor)
        case .allFeatures:
            fill(roundedRect(x: 18, y: 18, width: 7, height: 7, radius: 2.2), accentColor)
        case .freeFlight:
            if index == 0 {
                fill(birdWingPath(), accentColor)
            } else {
                stroke(birdFlightPath(), accentColor, width: 2.4)
            }
        case .misting:
            let drops = [(11.0, 23.0), (16.0, 25.0), (21.0, 23.0)]
            fill(mistDropPath(center: CGPoint(x: drops[index].0, y: drops[index].1)), accentColor)
        case .substrateChange:
            let widths: [CGFloat] = [12, 9, 6]
            fill(capsule(x: 10, y: 13 + CGFloat(index) * 3.6, width: widths[index], height: 2.1), accentColor)
        case .workout:
            switch index {
            case 0: fill(capsule(x: 13, y: 14.6, width: 6, height: 2.8), accentColor)
            case 1: stroke(workoutMotionPath(left: true), accentColor, width: 2.2)
            default: stroke(workoutMotionPath(left: false), accentColor, width: 2.2)
            }
        case .plantPruning:
            stroke(pruningScissorPath(), accentColor, width: 2.5)
            fill(circle(cx: 19.1, cy: 17.3, r: 2.1), accentColor)
            fill(circle(cx: 23.3, cy: 18.5, r: 2.1), accentColor)
        case .plantPestCheck:
            fill(pestBugPath(), accentColor)
            fill(circle(cx: 17.8, cy: 14.7, r: 0.75), primaryColor)
            fill(circle(cx: 20, cy: 15.8, r: 0.75), primaryColor)
        case .plantRotating:
            stroke(plantRotateArrowPath(), accentColor, width: 2.8)
            fill(plantRotateArrowHead(), accentColor)
        case .plantRepotting:
            stroke(repotArrowPath(), accentColor, width: 2.8)
            fill(repotArrowHead(), accentColor)
        case .plantNewLeaf:
            fill(newLeafAccentPath(), accentColor)
        case .plantIssue:
            fill(capsule(x: 16.4, y: 10, width: 2.8, height: 8.9), accentColor)
            fill(circle(cx: 17.8, cy: 22, r: 1.7), accentColor)
        }
    }

    private mutating func fill(_ path: Path, _ color: Color, opacity: Double = 1) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    private mutating func stroke(_ path: Path, _ color: Color, width: CGFloat, opacity: Double = 1) {
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private mutating func drawLabel(_ text: String, at point: CGPoint, size: CGFloat, color: Color) {
        context.draw(
            Text(text)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(color),
            at: point,
            anchor: .center
        )
    }

    private func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        ellipse(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    }

    private func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: x, y: y, width: width, height: height))
        return path
    }

    private func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: width, height: height),
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )
        return path
    }

    private func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        roundedRect(x: x, y: y, width: width, height: height, radius: min(width, height) / 2)
    }

    private func triangle(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func rotated(_ path: Path, degrees: CGFloat, center: CGPoint) -> Path {
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: degrees * .pi / 180)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }

    private func bowlPath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
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

    private func tentPath() -> Path {
        triangle([CGPoint(x: 16, y: 6.4), CGPoint(x: 27, y: 26.2), CGPoint(x: 5, y: 26.2)])
    }

    private func shieldPath() -> Path {
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

    private func bellPath() -> Path {
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

    private func bellClapperPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 13.1, y: 24.2))
        path.addLine(to: CGPoint(x: 18.9, y: 24.2))
        path.addQuadCurve(to: CGPoint(x: 13.1, y: 24.2), control: CGPoint(x: 16, y: 29.2))
        path.closeSubpath()
        return path
    }

    private func plantPotPath(x: CGFloat, y: CGFloat, width: CGFloat) -> Path {
        bowlPath(x: x, y: y, width: width, height: 26 - y)
    }

    private func plantLeftLeafPath() -> Path {
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

    private func plantRightLeafPath() -> Path {
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

    private func fertilizeLeftLeafPath() -> Path {
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

    private func fertilizeRightLeafPath() -> Path {
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

    private func gameControllerPath() -> Path {
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

    private func bathWavePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 16.5))
        path.addCurve(to: CGPoint(x: 14.7, y: 16.5), control1: CGPoint(x: 10.8, y: 14.3), control2: CGPoint(x: 12.9, y: 14.3))
        path.addCurve(to: CGPoint(x: 20.4, y: 16.5), control1: CGPoint(x: 16.5, y: 18.7), control2: CGPoint(x: 18.6, y: 18.7))
        return path
    }

    private func foodBagPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 6.2))
        path.addLine(to: CGPoint(x: 22, y: 6.2))
        path.addLine(to: CGPoint(x: 25, y: 26.2))
        path.addLine(to: CGPoint(x: 7, y: 26.2))
        path.closeSubpath()
        return path
    }

    private func waterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.8))
        path.addCurve(to: CGPoint(x: 23.1, y: 17.9), control1: CGPoint(x: 20.8, y: 10.5), control2: CGPoint(x: 23.1, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 25), control1: CGPoint(x: 23.1, y: 22), control2: CGPoint(x: 20, y: 25))
        path.addCurve(to: CGPoint(x: 8.9, y: 17.9), control1: CGPoint(x: 12, y: 25), control2: CGPoint(x: 8.9, y: 22))
        path.addCurve(to: CGPoint(x: 16, y: 4.8), control1: CGPoint(x: 8.9, y: 14.3), control2: CGPoint(x: 11.2, y: 10.5))
        path.closeSubpath()
        return path
    }

    private func smallWaterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.2, y: 5.1))
        path.addCurve(to: CGPoint(x: 17.3, y: 16.1), control1: CGPoint(x: 15.3, y: 9.9), control2: CGPoint(x: 17.3, y: 13.2))
        path.addArc(center: CGPoint(x: 11.2, y: 16.1), radius: 6.1, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 11.2, y: 5.1), control1: CGPoint(x: 5.1, y: 13.2), control2: CGPoint(x: 7.1, y: 9.9))
        path.closeSubpath()
        return path
    }

    private func plantWaterDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 24.3, y: 14.2))
        path.addCurve(to: CGPoint(x: 27.1, y: 19.4), control1: CGPoint(x: 26.2, y: 16.5), control2: CGPoint(x: 27.1, y: 18))
        path.addArc(center: CGPoint(x: 24.3, y: 19.4), radius: 2.8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 24.3, y: 14.2), control1: CGPoint(x: 21.5, y: 18), control2: CGPoint(x: 22.4, y: 16.5))
        path.closeSubpath()
        return path
    }

    private func heartPath() -> Path {
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

    private func weightNeedlePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 17.3))
        path.addLine(to: CGPoint(x: 20, y: 13.5))
        return path
    }

    private func taskCheckPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.5, y: 16.4))
        path.addLine(to: CGPoint(x: 14.5, y: 19.5))
        path.addLine(to: CGPoint(x: 20.9, y: 12.5))
        return path
    }

    private func hexFoodPiece(center: CGPoint, radius: CGFloat) -> Path {
        let points = (0 ..< 6).map { index in
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        return triangle(points)
    }

    private func waterChangeUpperArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 19.4, y: 10.2))
        path.addArc(center: CGPoint(x: 19.4, y: 17.4), radius: 7.2, startAngle: .degrees(-90), endAngle: .degrees(-30), clockwise: false)
        return path
    }

    private func waterChangeUpperArrowHead() -> Path {
        triangle([CGPoint(x: 23.3, y: 11.7), CGPoint(x: 27, y: 14.7), CGPoint(x: 22.5, y: 16.2)])
    }

    private func waterChangeLowerArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 25.4, y: 19.2))
        path.addCurve(to: CGPoint(x: 19.6, y: 23.7), control1: CGPoint(x: 24.3, y: 21.8), control2: CGPoint(x: 22.4, y: 23.4))
        return path
    }

    private func waterChangeLowerArrowHead() -> Path {
        triangle([CGPoint(x: 21.6, y: 21.1), CGPoint(x: 18.9, y: 24.9), CGPoint(x: 17.1, y: 20.5)])
    }

    private func filterLeftArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6.8, y: 11.2))
        path.addCurve(to: CGPoint(x: 6.9, y: 21), control1: CGPoint(x: 5.4, y: 14.4), control2: CGPoint(x: 5.5, y: 17.8))
        return path
    }

    private func filterLeftArrowHead() -> Path {
        triangle([CGPoint(x: 4.4, y: 18.8), CGPoint(x: 7.1, y: 22.4), CGPoint(x: 8.6, y: 18.3)])
    }

    private func filterRightArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 25.2, y: 20.8))
        path.addCurve(to: CGPoint(x: 25.1, y: 11), control1: CGPoint(x: 26.6, y: 17.6), control2: CGPoint(x: 26.5, y: 14.2))
        return path
    }

    private func filterRightArrowHead() -> Path {
        triangle([CGPoint(x: 27.6, y: 13.2), CGPoint(x: 24.9, y: 9.6), CGPoint(x: 23.4, y: 13.7)])
    }

    private func mapPinPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 5.2))
        path.addArc(center: CGPoint(x: 16, y: 11.4), radius: 6.2, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        path.addCurve(to: CGPoint(x: 16, y: 21.8), control1: CGPoint(x: 22.2, y: 16.1), control2: CGPoint(x: 16, y: 21.8))
        path.addCurve(to: CGPoint(x: 16, y: 5.2), control1: CGPoint(x: 16, y: 21.8), control2: CGPoint(x: 9.8, y: 16.1))
        path.closeSubpath()
        return path
    }

    private func walkMapTrailPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.5, y: 24.8))
        path.addCurve(to: CGPoint(x: 17.8, y: 24.8), control1: CGPoint(x: 10.8, y: 22.6), control2: CGPoint(x: 14.2, y: 22.5))
        path.addCurve(to: CGPoint(x: 24.6, y: 24.7), control1: CGPoint(x: 20.1, y: 26.3), control2: CGPoint(x: 22.5, y: 26.3))
        return path
    }

    private func distancePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.8, y: 22.4))
        path.addCurve(to: CGPoint(x: 23.8, y: 10), control1: CGPoint(x: 11.6, y: 15), control2: CGPoint(x: 20.4, y: 18.6))
        return path
    }

    private func smilePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.2, y: 17.8))
        path.addCurve(to: CGPoint(x: 20.8, y: 17.8), control1: CGPoint(x: 13.6, y: 20.4), control2: CGPoint(x: 18.4, y: 20.4))
        return path
    }

    private func checkInPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.8, y: 16.2))
        path.addLine(to: CGPoint(x: 14.4, y: 19.8))
        path.addLine(to: CGPoint(x: 21.4, y: 11.8))
        return path
    }

    private func familyPrimaryBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 5.8, y: 24.6))
        path.addCurve(to: CGPoint(x: 19.8, y: 24.6), control1: CGPoint(x: 6.4, y: 19.6), control2: CGPoint(x: 9.2, y: 16.6))
        path.addCurve(to: CGPoint(x: 5.8, y: 24.6), control1: CGPoint(x: 19.2, y: 19.6), control2: CGPoint(x: 16.4, y: 16.6))
        path.closeSubpath()
        return path
    }

    private func familySecondaryBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.4, y: 24.6))
        path.addCurve(to: CGPoint(x: 26.5, y: 24.6), control1: CGPoint(x: 15.9, y: 20.6), control2: CGPoint(x: 18.2, y: 18.2))
        path.addCurve(to: CGPoint(x: 15.4, y: 24.6), control1: CGPoint(x: 26, y: 20.6), control2: CGPoint(x: 23.8, y: 18.2))
        path.closeSubpath()
        return path
    }

    private func profileBodyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.8, y: 22.5))
        path.addCurve(to: CGPoint(x: 21.2, y: 22.5), control1: CGPoint(x: 11.4, y: 18.9), control2: CGPoint(x: 13.4, y: 17))
        path.addCurve(to: CGPoint(x: 10.8, y: 22.5), control1: CGPoint(x: 20.6, y: 18.9), control2: CGPoint(x: 18.6, y: 17))
        path.closeSubpath()
        return path
    }

    private func lockShacklePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.5, y: 14))
        path.addLine(to: CGPoint(x: 11.5, y: 11.8))
        path.addArc(center: CGPoint(x: 16, y: 11.8), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: 20.5, y: 14))
        return path
    }

    private func insuranceCheckPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.9, y: 15.9))
        path.addLine(to: CGPoint(x: 14.7, y: 18.8))
        path.addLine(to: CGPoint(x: 20.2, y: 12.6))
        return path
    }

    private func documentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 5.5))
        path.addLine(to: CGPoint(x: 19.4, y: 5.5))
        path.addLine(to: CGPoint(x: 23.5, y: 9.7))
        path.addLine(to: CGPoint(x: 23.5, y: 26.5))
        path.addLine(to: CGPoint(x: 9, y: 26.5))
        path.closeSubpath()
        return path
    }

    private func documentFoldPath() -> Path {
        triangle([CGPoint(x: 19.1, y: 5.6), CGPoint(x: 23.6, y: 10.6), CGPoint(x: 19.1, y: 10.6)])
    }

    private func photoMountainPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9.4, y: 22.2))
        path.addLine(to: CGPoint(x: 14, y: 16.8))
        path.addLine(to: CGPoint(x: 17.4, y: 20.6))
        path.addLine(to: CGPoint(x: 19.5, y: 18.3))
        path.addLine(to: CGPoint(x: 23, y: 22.2))
        path.closeSubpath()
        return path
    }

    private func birthdayFlamePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.3))
        path.addCurve(to: CGPoint(x: 18.2, y: 8.1), control1: CGPoint(x: 17.5, y: 6.1), control2: CGPoint(x: 18.2, y: 7.1))
        path.addArc(center: CGPoint(x: 16, y: 8.1), radius: 2.2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 16, y: 4.3), control1: CGPoint(x: 13.8, y: 7.1), control2: CGPoint(x: 14.5, y: 6.1))
        path.closeSubpath()
        return path
    }

    private func rewardRibbonPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.4, y: 18))
        path.addLine(to: CGPoint(x: 14.6, y: 26.5))
        path.addLine(to: CGPoint(x: 16.8, y: 23.5))
        path.addLine(to: CGPoint(x: 20, y: 24.9))
        path.addLine(to: CGPoint(x: 16.8, y: 16.6))
        path.closeSubpath()
        return path
    }

    private func temperatureDropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 22.5, y: 6.4))
        path.addCurve(to: CGPoint(x: 27.2, y: 15.1), control1: CGPoint(x: 25.7, y: 10.2), control2: CGPoint(x: 27.2, y: 12.7))
        path.addArc(center: CGPoint(x: 22.5, y: 15.1), radius: 4.7, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: 22.5, y: 6.4), control1: CGPoint(x: 17.8, y: 12.7), control2: CGPoint(x: 19.3, y: 10.2))
        path.closeSubpath()
        return path
    }

    private func temperatureHighlightPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 21.1, y: 13.4))
        path.addCurve(to: CGPoint(x: 23.5, y: 10.2), control1: CGPoint(x: 21.8, y: 12.2), control2: CGPoint(x: 22.6, y: 11.2))
        return path
    }

    private func notificationBellPath() -> Path {
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

    private func notificationBellClapperPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 13.2, y: 24))
        path.addLine(to: CGPoint(x: 18.8, y: 24))
        path.addQuadCurve(to: CGPoint(x: 13.2, y: 24), control: CGPoint(x: 16, y: 28.8))
        path.closeSubpath()
        return path
    }

    private func notificationHeartPath() -> Path {
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

    private func birdBodyPath() -> Path {
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

    private func birdWingPath() -> Path {
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

    private func birdFlightPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 4.8, y: 20.3))
        path.addCurve(
            to: CGPoint(x: 10, y: 20.3),
            control1: CGPoint(x: 6.5, y: 18.6),
            control2: CGPoint(x: 8.3, y: 18.6)
        )
        return path
    }

    private func cloudPath() -> Path {
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

    private func mistDropPath(center: CGPoint) -> Path {
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

    private func workoutBarPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7, y: 16))
        path.addLine(to: CGPoint(x: 25, y: 16))
        return path
    }

    private func workoutMotionPath(left: Bool) -> Path {
        let direction: CGFloat = left ? 1 : -1
        let originX: CGFloat = left ? 4.6 : 27.4
        var path = Path()
        path.move(to: CGPoint(x: originX, y: 10.3))
        path.addLine(to: CGPoint(x: originX + direction * 3.4, y: 7))
        return path
    }

    private func pruningLeafPath() -> Path {
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

    private func pruningScissorPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 20, y: 16.1))
        path.addLine(to: CGPoint(x: 26.4, y: 6.9))
        path.move(to: CGPoint(x: 22, y: 16.8))
        path.addLine(to: CGPoint(x: 15.7, y: 9.4))
        return path
    }

    private func genericLeafPath() -> Path {
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

    private func pestMagnifierPath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 13.3, y: 9.8, width: 11, height: 11))
        path.move(to: CGPoint(x: 22.5, y: 19))
        path.addLine(to: CGPoint(x: 27, y: 23.5))
        return path
    }

    private func pestBugPath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 15.2, y: 11.5, width: 7.2, height: 8.2))
        path.move(to: CGPoint(x: 18.8, y: 11.5))
        path.addLine(to: CGPoint(x: 18.8, y: 19.7))
        return path
    }

    private func plantRotateArrowPath() -> Path {
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

    private func plantRotateArrowHead() -> Path {
        triangle([
            CGPoint(x: 25.8, y: 9.7),
            CGPoint(x: 27.9, y: 15),
            CGPoint(x: 22.4, y: 13.8)
        ])
    }

    private func repotLeafPath() -> Path {
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

    private func repotArrowPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 11.8, y: 13.8))
        path.addCurve(
            to: CGPoint(x: 22.5, y: 12.7),
            control1: CGPoint(x: 15.2, y: 10.5),
            control2: CGPoint(x: 19.4, y: 10.2)
        )
        return path
    }

    private func repotArrowHead() -> Path {
        triangle([
            CGPoint(x: 20.5, y: 9.8),
            CGPoint(x: 25.2, y: 12.8),
            CGPoint(x: 20.2, y: 15.2)
        ])
    }

    private func newLeafStemPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 15.5, y: 20.2))
        path.addCurve(
            to: CGPoint(x: 18.8, y: 9.6),
            control1: CGPoint(x: 15.4, y: 15.2),
            control2: CGPoint(x: 17.2, y: 11.5)
        )
        return path
    }

    private func newLeafAccentPath() -> Path {
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

    private func gearPath() -> Path {
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
