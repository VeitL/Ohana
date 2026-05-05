//
//  WeightLineChart.swift
//  Ohana
//
//  Small reusable weight sparkline.
//

import SwiftUI

struct WeightLineChart: View {
    let logs: [PetWeightLog]

    private var weights: [Double] { logs.map { $0.weight } }
    private var minW: Double { (weights.min() ?? 0) - 0.2 }
    private var maxW: Double { (weights.max() ?? 1) + 0.2 }
    private var range: Double { max(maxW - minW, 0.1) }

    private func xPos(_ i: Int, w: CGFloat) -> CGFloat {
        logs.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(logs.count - 1) * w
    }

    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minW) / range) * h
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                if logs.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: h))
                        p.addLine(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i - 1, w: w), y: yPos(weights[i - 1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(
                                to: curr,
                                control1: CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y),
                                control2: CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                            )
                        }
                        p.addLine(to: CGPoint(x: xPos(logs.count - 1, w: w), y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.goTeal.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))

                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i - 1, w: w), y: yPos(weights[i - 1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(
                                to: curr,
                                control1: CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y),
                                control2: CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                            )
                        }
                    }
                    .stroke(Color.goTeal, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}
