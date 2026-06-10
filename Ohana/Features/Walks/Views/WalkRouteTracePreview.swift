//
//  WalkRouteTracePreview.swift
//  Ohana
//
//  Lightweight static route preview for surfaces that should not mount MapKit.
//

import CoreLocation
import SwiftUI

struct WalkRouteTracePreview: View {
    let coordinates: [CLLocationCoordinate2D]
    let title: String

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "133B32"),
                                Color(hex: "0A1822")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Color.goPrimary,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
                }

                if let start = points.first {
                    routeMarker(at: start, fill: .goPrimary, size: 16)
                }
                if points.count >= 2, let end = points.last {
                    routeMarker(at: end, fill: .goRed, size: 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.caption2(.bold))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(OhanaFont.caption2(.bold))
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.arkInk.opacity(0.45), in: Capsule()) // ui-v4: allow route label scrim
                .padding(8)
            }
        }
    }

    private func routeMarker(at point: CGPoint, fill: Color, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().fill(Color.ohanaPrimaryText).frame(width: max(5, size * 0.38)))
            .position(point)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !coordinates.isEmpty else { return [] }
        let inset: CGFloat = 18
        let width = max(1, size.width - inset * 2)
        let height = max(1, size.height - inset * 2)
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? minLat
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? minLon
        let latSpan = max(0.000001, maxLat - minLat)
        let lonSpan = max(0.000001, maxLon - minLon)

        return coordinates.map { coordinate in
            let x = inset + CGFloat((coordinate.longitude - minLon) / lonSpan) * width
            let y = inset + CGFloat(1 - (coordinate.latitude - minLat) / latSpan) * height
            return CGPoint(x: x, y: y)
        }
    }
}
