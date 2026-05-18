//
//  OhanaChartStyle.swift
//  Ohana
//
//  Shared chart rules for V4: calm area trends, quiet axes, and no over-shooting curves.
//

import SwiftUI
import Charts

enum OhanaChartStyle {
    static let trendInterpolation: InterpolationMethod = .monotone
    static let trendLineStyle = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)

    static func areaGradient(for tint: Color, topOpacity: Double = 0.24, bottomOpacity: Double = 0.02) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(topOpacity), tint.opacity(bottomOpacity)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func yDomain(
        values: [Double],
        includeZero: Bool,
        paddingRatio: Double = 0.14,
        minimumSpan: Double = 1
    ) -> ClosedRange<Double> {
        let cleanValues = values.filter(\.isFinite)
        guard let minValue = cleanValues.min(), let maxValue = cleanValues.max() else {
            return 0...1
        }

        var lower = includeZero ? min(0, minValue) : minValue
        var upper = includeZero ? max(1, maxValue) : maxValue
        let span = max(upper - lower, minimumSpan)

        if includeZero {
            upper += span * paddingRatio
            lower = min(0, lower)
        } else {
            lower -= span * paddingRatio
            upper += span * paddingRatio
        }

        if upper <= lower {
            upper = lower + minimumSpan
        }
        return lower...upper
    }

    static func softenedLinePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            appendSoftSegments(to: &path, points: points)
        }
    }

    static func softenedAreaPath(points: [CGPoint], baselineY: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: baselineY))
            path.addLine(to: first)
            appendSoftSegments(to: &path, points: points)
            path.addLine(to: CGPoint(x: last.x, y: baselineY))
            path.closeSubpath()
        }
    }

    private static func appendSoftSegments(to path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else { return }
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            path.addQuadCurve(to: midpoint, control: previous)
            path.addQuadCurve(to: current, control: current)
        }
    }
}
