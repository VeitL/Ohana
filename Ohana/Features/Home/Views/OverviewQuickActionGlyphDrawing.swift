//
//  OverviewQuickActionGlyphDrawing.swift
//  Ohana
//
//  Base and accent drawing dispatch for quick-action glyphs.
//

import SwiftUI

extension OhanaQuickActionGlyphDrawing {
    mutating func drawBase(_ kind: OhanaQuickActionGlyphKind) {
        switch kind {
        case .feed, .calendar, .walk, .water, .potty, .medicine, .groom,
             .health, .sleep, .vet, .weight, .reminder, .plantWater, .play,
             .bath, .task:
            drawCoreBase(kind)
        case .foodStock, .dryFood, .wetFood, .treat, .foodBag, .feeder,
             .waterChange, .filterChange, .litter, .cleanup, .walkMap,
             .distance, .training, .mood:
            drawFoodAndActivityBase(kind)
        case .checkIn, .family, .profile, .privacy, .expense, .insurance,
             .document, .photo, .birthday, .reward, .temperature,
             .plantFertilize, .notificationHealth, .settings, .allFeatures:
            drawHouseholdBase(kind)
        case .freeFlight, .misting, .substrateChange, .workout,
             .plantPruning, .plantPestCheck, .plantRotating,
             .plantRepotting, .plantNewLeaf, .plantIssue:
            drawExtendedBase(kind)
        }
    }

    private mutating func drawCoreBase(_ kind: OhanaQuickActionGlyphKind) {
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
        default:
            return
        }
    }

    private mutating func drawFoodAndActivityBase(_ kind: OhanaQuickActionGlyphKind) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawHouseholdBase(_ kind: OhanaQuickActionGlyphKind) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawExtendedBase(_ kind: OhanaQuickActionGlyphKind) {
        switch kind {
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
        default:
            return
        }
    }

    mutating func drawAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
        case .feed, .calendar, .walk, .water, .potty, .medicine, .groom,
             .health:
            drawCoreAccent(kind, index: index)
        case .sleep, .vet, .weight, .reminder, .plantWater, .play, .bath,
             .task:
            drawCareStateAccent(kind, index: index)
        case .foodStock, .dryFood, .wetFood, .treat, .foodBag, .feeder:
            drawFoodAccent(kind, index: index)
        case .waterChange, .filterChange, .litter, .cleanup, .walkMap,
             .distance, .training, .mood:
            drawMaintenanceAccent(kind, index: index)
        case .checkIn, .family, .profile, .privacy, .expense, .insurance,
             .document, .photo, .birthday, .reward:
            drawHouseholdAccent(kind, index: index)
        case .temperature, .plantFertilize, .notificationHealth, .settings,
             .allFeatures:
            drawStatusAccent(kind, index: index)
        case .freeFlight, .misting, .substrateChange, .workout,
             .plantPruning, .plantPestCheck, .plantRotating,
             .plantRepotting, .plantNewLeaf, .plantIssue:
            drawExtendedAccent(kind, index: index)
        }
    }

    private mutating func drawCoreAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
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
        default:
            return
        }
    }

    private mutating func drawCareStateAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawFoodAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawMaintenanceAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawHouseholdAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawStatusAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }

    private mutating func drawExtendedAccent(_ kind: OhanaQuickActionGlyphKind, index: Int) {
        switch kind {
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
        default:
            return
        }
    }
}
