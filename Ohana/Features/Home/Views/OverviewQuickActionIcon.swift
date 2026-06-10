//
//  OverviewQuickActionIcon.swift
//  Ohana
//
//  Render-only quick action glyphs and completion overlays.
//

import SwiftUI

struct OhanaQuickActionIcon: View {
    let actionType: String
    let fallbackSystemName: String
    var size: CGFloat = 32
    var color: Color = .ohanaFunctionalIcon
    var isCompleted: Bool = false
    var showsCompletionBadge: Bool = false
    var animationTrigger: Int = 0
    var animatesStateChanges: Bool = true

    private var glyphKind: OhanaQuickActionGlyphKind? {
        OhanaQuickActionGlyphKind.resolve(actionType: actionType, fallbackSystemName: fallbackSystemName)
    }

    var body: some View {
        iconBody
            .ohanaPhasePop(trigger: animationKey, enabled: animatesStateChanges)
            .animation(GoMotion.stateChange, value: isCompleted)
            .animation(GoMotion.stateChange, value: showsCompletionBadge)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var iconBody: some View {
        ZStack(alignment: .bottomTrailing) {
            glyphLayer

            if showsCompletionBadge, isCompleted {
                completionBadge
                    .offset(x: size * 0.08, y: size * 0.08)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var glyphLayer: some View {
        if let glyphKind {
            ZStack {
                OhanaQuickActionGlyph(kind: glyphKind, color: color)
                OhanaQuickActionGlyphStateOverlay(
                    kind: glyphKind,
                    color: color,
                    isCompleted: isCompleted
                )
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size * 0.62, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }

    private var animationKey: String {
        "\(isCompleted)-\(showsCompletionBadge)-\(animationTrigger)"
    }

    private var completionBadge: some View {
        let badgeSize = max(12, size * 0.36)
        return ZStack {
            Circle()
                .fill(Color.goPrimary)
            Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                .font(.system(size: badgeSize * 0.52, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
        }
        .frame(width: badgeSize, height: badgeSize)
        .overlay {
            Circle()
                .strokeBorder(Color.ohanaCardSurface.opacity(0.85), lineWidth: max(1, size * 0.035))
        }
    }
}

private struct OhanaQuickActionGlyph: View {
    let kind: OhanaQuickActionGlyphKind
    let color: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            var iconContext = context
            iconContext.translateBy(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2
            )
            iconContext.scaleBy(x: side / 32, y: side / 32)
            draw(kind, in: &iconContext)
        }
    }

    private func draw(_ kind: OhanaQuickActionGlyphKind, in context: inout GraphicsContext) {
        switch kind {
        case .feed:
            fill(ellipse(x: 6.6, y: 9.8, width: 18.8, height: 8.8), in: &context, opacity: 0.2)
            fill(bowlPath(x: 5.5, y: 14.7, width: 21, height: 11.3), in: &context)

        case .dryFood:
            fill(bowlPath(x: 6.2, y: 18.5, width: 19.6, height: 7.4), in: &context)
            for point in [
                CGPoint(x: 11, y: 16),
                CGPoint(x: 15.1, y: 14.4),
                CGPoint(x: 19.2, y: 15.9),
                CGPoint(x: 13, y: 19),
                CGPoint(x: 17.2, y: 19.1),
                CGPoint(x: 21.1, y: 18.3)
            ] {
                fill(hexFoodPiece(center: point, radius: 1.75), in: &context, opacity: 0.82)
            }

        case .wetFood:
            fill(ellipse(x: 8.4, y: 7.1, width: 15.2, height: 5.6), in: &context)
            fill(roundedRect(x: 8.4, y: 9.8, width: 15.2, height: 15.4, radius: 4), in: &context)
            fill(ellipse(x: 8.4, y: 21.8, width: 15.2, height: 5), in: &context, opacity: 0.36)
            fill(capsule(x: 11.3, y: 13.2, width: 9.4, height: 5.4), in: &context, opacity: 0.22)
            fill(circle(cx: 16, cy: 16, r: 2.35), in: &context, opacity: 0.42)

        case .foodInventory:
            fill(foodBagPath(), in: &context)
            fill(capsule(x: 11, y: 8.8, width: 10, height: 2.7), in: &context, opacity: 0.2)
            fill(capsule(x: 10, y: 15.1, width: 12, height: 2.3), in: &context, opacity: 0.56)
            fill(capsule(x: 10, y: 19, width: 9.2, height: 2.3), in: &context, opacity: 0.38)
            fill(capsule(x: 10, y: 22.9, width: 6.4, height: 2.3), in: &context, opacity: 0.24)

        case .calendar:
            fill(roundedRect(x: 5.5, y: 6.5, width: 21, height: 20, radius: 5.5), in: &context)
            fill(capsule(x: 9, y: 10, width: 14, height: 3), in: &context, opacity: 0.42)
            fill(circle(cx: 11.3, cy: 17.3, r: 1.55), in: &context, opacity: 0.42)
            fill(circle(cx: 16, cy: 17.3, r: 1.55), in: &context, opacity: 0.24)
            fill(circle(cx: 20.7, cy: 17.3, r: 1.55), in: &context, opacity: 0.24)
            fill(capsule(x: 14.1, y: 20.2, width: 7.9, height: 3.2), in: &context, opacity: 0.42)

        case .walk:
            var leash = Path()
            leash.move(to: CGPoint(x: 6.6, y: 8.8))
            leash.addCurve(to: CGPoint(x: 15.5, y: 14.7), control1: CGPoint(x: 9.3, y: 8.4), control2: CGPoint(x: 11.6, y: 12.4))
            stroke(leash, in: &context, width: 2.1, opacity: 0.52)
            fill(circle(cx: 6.6, cy: 8.8, r: 1.9), in: &context, opacity: 0.34)
            fill(roundedRect(x: 11.3, y: 15, width: 11.4, height: 6.7, radius: 3.2), in: &context)
            fill(circle(cx: 23.5, cy: 14.9, r: 4.1), in: &context)
            fill(triangle(points: [
                CGPoint(x: 21.7, y: 11.9),
                CGPoint(x: 23.2, y: 7.9),
                CGPoint(x: 25.3, y: 12.6)
            ]), in: &context, opacity: 0.64)
            fill(circle(cx: 25.1, cy: 14.7, r: 0.9), in: &context, opacity: 0.36)
            stroke(capsule(x: 8.1, y: 14.2, width: 5.2, height: 2.3), in: &context, width: 2.1, opacity: 0.76)
            fill(capsule(x: 13.1, y: 20.2, width: 2.2, height: 5.2), in: &context)
            fill(capsule(x: 19.4, y: 20.2, width: 2.2, height: 5.2), in: &context)

        case .water:
            fill(dropPath(), in: &context)
            fill(bowlPath(x: 7.2, y: 20.2, width: 17.6, height: 5.8), in: &context, opacity: 0.38)
            fill(ellipse(x: 7.2, y: 17.3, width: 17.6, height: 6), in: &context, opacity: 0.18)

        case .waterChange:
            fill(dropPath().applying(CGAffineTransform(translationX: -3.2, y: 1.4).scaledBy(x: 0.86, y: 0.86)), in: &context)
            stroke(arcArrowPath(clockwise: true), in: &context, width: 2.55, opacity: 0.84)
            stroke(arcArrowPath(clockwise: false), in: &context, width: 2.55, opacity: 0.84)

        case .potty:
            fill(bowlPath(x: 7, y: 17.2, width: 18, height: 8.8), in: &context)
            fill(roundedRect(x: 7.8, y: 7.4, width: 16.4, height: 10.8, radius: 4), in: &context, opacity: 0.24)
            drawLabel("WC", at: CGPoint(x: 16, y: 13.2), size: 7.5, opacity: 0.62, in: &context)

        case .litter:
            fill(bowlPath(x: 6.5, y: 17.2, width: 19, height: 8.8), in: &context)
            fill(ellipse(x: 6.5, y: 12.7, width: 19, height: 7.8), in: &context, opacity: 0.18)

        case .groom:
            fill(roundedRect(x: 6.5, y: 8.5, width: 19, height: 6, radius: 3), in: &context)
            fill(capsule(x: 22.6, y: 10.2, width: 4.2, height: 11.2), in: &context, opacity: 0.42)
            for x in [8.5, 11.4, 14.3, 17.2, 20.1] {
                fill(capsule(x: x, y: 13.2, width: 1.55, height: 10.7), in: &context, opacity: 0.68)
            }

        case .health:
            fill(roundedRect(x: 7, y: 6, width: 18, height: 21, radius: 5.2), in: &context)
            fill(capsule(x: 11, y: 9.7, width: 10, height: 2.8), in: &context, opacity: 0.18)
            fill(heartPath(), in: &context, opacity: 0.54)

        case .medicine:
            let outer = rotated(capsule(x: 5.4, y: 12, width: 21.2, height: 8), degrees: -35, center: CGPoint(x: 16, y: 16))
            let inner = rotated(capsule(x: 16, y: 12.4, width: 10.1, height: 7.2), degrees: -35, center: CGPoint(x: 16, y: 16))
            fill(outer, in: &context)
            fill(inner, in: &context, opacity: 0.42)
            fill(rotated(circle(cx: 11.8, cy: 16, r: 2.1), degrees: -35, center: CGPoint(x: 16, y: 16)), in: &context, opacity: 0.18)

        case .weight:
            fill(roundedRect(x: 5.5, y: 8, width: 21, height: 18.5, radius: 6), in: &context)
            fill(capsule(x: 10, y: 11, width: 12, height: 3), in: &context, opacity: 0.18)
            var needle = Path()
            needle.move(to: CGPoint(x: 16, y: 17.3))
            needle.addLine(to: CGPoint(x: 20, y: 13.5))
            stroke(needle, in: &context, width: 2.4, opacity: 0.48)
            fill(circle(cx: 16, cy: 17.3, r: 2.45), in: &context, opacity: 0.48)

        case .expense:
            fill(roundedRect(x: 6, y: 9, width: 20, height: 15.8, radius: 5), in: &context)
            fill(capsule(x: 8.6, y: 12, width: 14.8, height: 3), in: &context, opacity: 0.4)
            drawLabel(AppCurrency.symbol, at: CGPoint(x: 16, y: 20.2), size: AppCurrency.symbol.count > 1 ? 6.8 : 8.8, opacity: 0.58, in: &context)

        case .play:
            fill(roundedRect(x: 5.8, y: 12.4, width: 20.4, height: 11.8, radius: 5.8), in: &context)
            fill(circle(cx: 10.8, cy: 22.1, r: 3.1), in: &context)
            fill(circle(cx: 21.2, cy: 22.1, r: 3.1), in: &context)
            fill(capsule(x: 9.2, y: 16.6, width: 6.1, height: 1.8), in: &context, opacity: 0.46)
            fill(capsule(x: 11.3, y: 14.45, width: 1.8, height: 6.1), in: &context, opacity: 0.46)
            fill(circle(cx: 20.3, cy: 15.8, r: 1.45), in: &context, opacity: 0.52)
            fill(circle(cx: 23.2, cy: 17.9, r: 1.2), in: &context, opacity: 0.34)

        case .rest:
            fill(tentPath(), in: &context)
            fill(triangle(points: [
                CGPoint(x: 15.9, y: 14.1),
                CGPoint(x: 20.6, y: 25.8),
                CGPoint(x: 11.2, y: 25.8)
            ]), in: &context, opacity: 0.2)
            drawLabel("Z", at: CGPoint(x: 21.1, y: 8.4), size: 7.4, opacity: 0.62, in: &context)
            drawLabel("z", at: CGPoint(x: 25, y: 12.4), size: 5.9, opacity: 0.38, in: &context)

        case .photo:
            fill(roundedRect(x: 6, y: 8, width: 20, height: 16, radius: 5), in: &context)
            fill(circle(cx: 20.8, cy: 12.6, r: 2.1), in: &context, opacity: 0.48)
            var mountain = Path()
            mountain.move(to: CGPoint(x: 9.4, y: 22.2))
            mountain.addLine(to: CGPoint(x: 14, y: 16.8))
            mountain.addLine(to: CGPoint(x: 17.4, y: 20.6))
            mountain.addLine(to: CGPoint(x: 19.5, y: 18.3))
            mountain.addLine(to: CGPoint(x: 23, y: 22.2))
            mountain.closeSubpath()
            fill(mountain, in: &context, opacity: 0.32)

        case .cleanup:
            fill(rotated(capsule(x: 8.4, y: 17.4, width: 15.8, height: 6.2), degrees: -18, center: CGPoint(x: 16.3, y: 20.5)), in: &context)
            fill(rotated(capsule(x: 13.5, y: 7, width: 4, height: 13.5), degrees: -18, center: CGPoint(x: 15.5, y: 13.8)), in: &context)
            fill(circle(cx: 22.7, cy: 8.5, r: 2.2), in: &context, opacity: 0.42)
            fill(circle(cx: 25.4, cy: 13, r: 1.35), in: &context, opacity: 0.22)
            fill(circle(cx: 8.2, cy: 24.5, r: 1.5), in: &context, opacity: 0.22)

        case .training:
            fill(circle(cx: 16, cy: 16, r: 10.4), in: &context)
            fill(circle(cx: 16, cy: 16, r: 6.2), in: &context, opacity: 0.22)
            fill(circle(cx: 16, cy: 16, r: 2.7), in: &context, opacity: 0.54)
            fill(rotated(capsule(x: 22.2, y: 5.5, width: 5.4, height: 3.2), degrees: 35, center: CGPoint(x: 24.9, y: 7.1)), in: &context, opacity: 0.54)

        case .plantFertilize:
            fill(bowlPath(x: 9.1, y: 18, width: 13.8, height: 8), in: &context)
            fill(leafPath(start: CGPoint(x: 15.5, y: 17.8), left: true), in: &context)
            fill(leafPath(start: CGPoint(x: 16.7, y: 17.2), left: false), in: &context)
            fill(circle(cx: 23.8, cy: 20.5, r: 2), in: &context, opacity: 0.44)
            fill(circle(cx: 25.8, cy: 15.6, r: 1.4), in: &context, opacity: 0.22)

        case .document:
            fill(documentPath(), in: &context)
            fill(foldPath(), in: &context, opacity: 0.24)
            fill(capsule(x: 12, y: 15.1, width: 8, height: 2.4), in: &context, opacity: 0.42)
            fill(capsule(x: 12, y: 19.6, width: 6.2, height: 2.4), in: &context, opacity: 0.24)

        case .settings:
            fill(gearPath(), in: &context)
            fill(circle(cx: 16, cy: 16, r: 4.1), in: &context, opacity: 0.18)
        }
    }

    private func fill(_ path: Path, in context: inout GraphicsContext, opacity: Double = 1) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    private func stroke(_ path: Path, in context: inout GraphicsContext, width: CGFloat, opacity: Double = 1) {
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
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

    private func rotated(_ path: Path, degrees: CGFloat, center: CGPoint) -> Path {
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: degrees * .pi / 180)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }

    private func triangle(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func hexFoodPiece(center: CGPoint, radius: CGFloat) -> Path {
        var points: [CGPoint] = []
        for index in 0 ..< 6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            points.append(CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            ))
        }
        return triangleFan(points: points)
    }

    private func triangleFan(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func drawLabel(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        context.draw(
            Text(text)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(color.opacity(opacity)),
            at: point,
            anchor: .center
        )
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

    private func foodBagPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 6.2))
        path.addLine(to: CGPoint(x: 22, y: 6.2))
        path.addLine(to: CGPoint(x: 25, y: 26.2))
        path.addLine(to: CGPoint(x: 7, y: 26.2))
        path.closeSubpath()
        return path
    }

    private func tentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 6.4))
        path.addLine(to: CGPoint(x: 27, y: 26.2))
        path.addLine(to: CGPoint(x: 5, y: 26.2))
        path.closeSubpath()
        return path
    }

    private func gearPath() -> Path {
        var path = Path()
        let center = CGPoint(x: 16, y: 16)
        for index in 0 ..< 16 {
            let angle = CGFloat(index) * .pi / 8
            let radius: CGFloat = index.isMultiple(of: 2) ? 11.2 : 8.7
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func dropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.8))
        path.addCurve(to: CGPoint(x: 23.1, y: 17.9), control1: CGPoint(x: 20.8, y: 10.5), control2: CGPoint(x: 23.1, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 25), control1: CGPoint(x: 23.1, y: 22), control2: CGPoint(x: 20, y: 25))
        path.addCurve(to: CGPoint(x: 8.9, y: 17.9), control1: CGPoint(x: 12, y: 25), control2: CGPoint(x: 8.9, y: 22))
        path.addCurve(to: CGPoint(x: 16, y: 4.8), control1: CGPoint(x: 8.9, y: 14.3), control2: CGPoint(x: 11.2, y: 10.5))
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

    private func arcArrowPath(clockwise: Bool) -> Path {
        var path = Path()
        if clockwise {
            path.addArc(center: CGPoint(x: 19, y: 12), radius: 6, startAngle: .degrees(-45), endAngle: .degrees(74), clockwise: false)
            path.move(to: CGPoint(x: 22.3, y: 17.1))
            path.addLine(to: CGPoint(x: 26.4, y: 16.6))
            path.move(to: CGPoint(x: 22.3, y: 17.1))
            path.addLine(to: CGPoint(x: 25.6, y: 13.1))
        } else {
            path.addArc(center: CGPoint(x: 13, y: 12), radius: 6, startAngle: .degrees(135), endAngle: .degrees(255), clockwise: false)
            path.move(to: CGPoint(x: 9.6, y: 6.9))
            path.addLine(to: CGPoint(x: 5.6, y: 7.4))
            path.move(to: CGPoint(x: 9.6, y: 6.9))
            path.addLine(to: CGPoint(x: 6.4, y: 10.9))
        }
        return path
    }

    private func leafPath(start: CGPoint, left: Bool) -> Path {
        var path = Path()
        path.move(to: start)
        if left {
            path.addCurve(to: CGPoint(x: 7.2, y: 11.3), control1: CGPoint(x: 14.3, y: 13.4), control2: CGPoint(x: 11.2, y: 11.2))
            path.addCurve(to: start, control1: CGPoint(x: 8.2, y: 15.4), control2: CGPoint(x: 11.2, y: 17.6))
        } else {
            path.addCurve(to: CGPoint(x: 24.5, y: 9.2), control1: CGPoint(x: 17.5, y: 12.4), control2: CGPoint(x: 20.3, y: 9.7))
            path.addCurve(to: start, control1: CGPoint(x: 24.1, y: 13.9), control2: CGPoint(x: 21.2, y: 16.8))
        }
        path.closeSubpath()
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

    private func foldPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 19.1, y: 5.6))
        path.addLine(to: CGPoint(x: 23.6, y: 10.6))
        path.addLine(to: CGPoint(x: 19.1, y: 10.6))
        path.closeSubpath()
        return path
    }
}

private struct OhanaQuickActionGlyphStateOverlay: View {
    let kind: OhanaQuickActionGlyphKind
    let color: Color
    let isCompleted: Bool

    private struct Dot: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let delay: Double
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content(in: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        switch kind {
        case .feed:
            ForEach(feedDots) { dot in
                dotView(dot, in: size, activeOpacity: 0.94, inactiveOpacity: 0.18)
            }
        case .litter:
            ForEach(litterDots) { dot in
                dotView(dot, in: size, activeOpacity: 0.72, inactiveOpacity: 0.32)
            }
        case .water, .waterChange:
            dotView(
                Dot(id: 0, x: 21.6, y: 8.3, radius: 1.55, delay: 0),
                in: size,
                activeOpacity: 0.72,
                inactiveOpacity: 0.18
            )
        case .play:
            dotView(
                Dot(id: 0, x: 20.3, y: 15.8, radius: 1.45, delay: 0),
                in: size,
                activeOpacity: 0.7,
                inactiveOpacity: 0.34
            )
            dotView(
                Dot(id: 1, x: 23.2, y: 17.9, radius: 1.2, delay: 0.035),
                in: size,
                activeOpacity: 0.58,
                inactiveOpacity: 0.24
            )
        default:
            EmptyView()
        }
    }

    private func dotView(
        _ dot: Dot,
        in size: CGSize,
        activeOpacity: Double,
        inactiveOpacity: Double
    ) -> some View {
        let side = min(size.width, size.height)
        return Circle()
            .fill(color.opacity(isCompleted ? activeOpacity : inactiveOpacity))
            .frame(width: dot.radius * 2 * side / 32, height: dot.radius * 2 * side / 32)
            .position(x: dot.x * side / 32, y: dot.y * side / 32)
            .scaleEffect(isCompleted ? 1 : 0.72)
            .animation(GoMotion.feedback.delay(dot.delay), value: isCompleted)
    }

    private var feedDots: [Dot] {
        [
            Dot(id: 0, x: 12.2, y: 12.1, radius: 2.2, delay: 0),
            Dot(id: 1, x: 16.4, y: 11.1, radius: 2.55, delay: 0.035),
            Dot(id: 2, x: 20.4, y: 12.6, radius: 2.1, delay: 0.07)
        ]
    }

    private var litterDots: [Dot] {
        [
            Dot(id: 0, x: 10.2, y: 15.3, radius: 1.05, delay: 0),
            Dot(id: 1, x: 13.3, y: 14.1, radius: 0.86, delay: 0.02),
            Dot(id: 2, x: 16.4, y: 15.5, radius: 1.18, delay: 0.04),
            Dot(id: 3, x: 19.6, y: 14.2, radius: 0.94, delay: 0.06),
            Dot(id: 4, x: 22.1, y: 16.1, radius: 0.78, delay: 0.08)
        ]
    }
}
