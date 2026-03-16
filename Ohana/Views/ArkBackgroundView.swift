//
//  ArkBackgroundView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

// MARK: - 背景风格枚举
enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case goDefault   = "go_default"
    case deepAmbient = "deep_ambient"
    case aurora      = "aurora"
    case midnight    = "midnight"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .goDefault:   return "Go 经典"
        case .deepAmbient: return "深邃光球"
        case .aurora:      return "极光"
        case .midnight:    return "午夜"
        }
    }

    var previewColors: [Color] {
        switch self {
        case .goDefault:   return [Color(hex: "0A0A0C"), .goLime, .goBlue]
        case .deepAmbient: return [Color(hex: "030712"), Color(hex: "1D4ED8"), Color(hex: "6D28D9")]
        case .aurora:      return [Color(hex: "0A0A0C"), Color(hex: "00C9A7"), Color(hex: "845EC2")]
        case .midnight:    return [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "21262D")]
        }
    }
}

// MARK: - ArkBackgroundView（根据用户设置切换背景风格）
struct ArkBackgroundView: View {
    var level: IslandLevel = .seedling
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goDefault.rawValue

    private var style: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goDefault
    }

    var body: some View {
        switch style {
        case .goDefault:   GoDefaultBackground()
        case .deepAmbient: DeepAmbientBackground()
        case .aurora:      AuroraBackground()
        case .midnight:    MidnightBackground()
        }
    }
}

// MARK: - 1. Go 经典（原设计系统三球 Blob）
private struct GoDefaultBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    @State private var blob1Offset: CGSize = .zero
    @State private var blob2Offset: CGSize = .zero
    @State private var blob3Offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color(hex: isDark ? "0A0A0C" : "F0F4FF")
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(isDark ? 0.55 : 0.35))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -80 + blob1Offset.width, y: -160 + blob1Offset.height)

                Circle()
                    .fill(Color.goBlue.opacity(isDark ? 0.45 : 0.25))
                    .frame(width: 300)
                    .blur(radius: 90)
                    .offset(x: 110 + blob2Offset.width, y: 60 + blob2Offset.height)

                Circle()
                    .fill(Color.goPurple.opacity(isDark ? 0.55 : 0.30))
                    .frame(width: 220)
                    .blur(radius: 60)
                    .offset(x: -40 + blob3Offset.width, y: 280 + blob3Offset.height)
            }

            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blob1Offset = CGSize(width: 40, height: -30)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                blob2Offset = CGSize(width: -50, height: 35)
            }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                blob3Offset = CGSize(width: 30, height: -40)
            }
        }
    }
}

// MARK: - 2. 深邃光球（Dynamic Ambient — 用户提供的设计稿）
private struct DeepAmbientBackground: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "030712").ignoresSafeArea()

                // 光球 1 (深蓝)
                Circle()
                    .fill(Color(hex: "1D4ED8"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(0.4)
                    .offset(
                        x: isAnimating ? 150 : -100,
                        y: isAnimating ? -120 : 80
                    )
                    .scaleEffect(isAnimating ? 1.3 : 0.9)

                // 光球 2 (紫色)
                Circle()
                    .fill(Color(hex: "6D28D9"))
                    .frame(width: min(geo.size.width * 0.7, 500))
                    .blur(radius: 100)
                    .opacity(0.35)
                    .offset(
                        x: isAnimating ? -150 : 80,
                        y: isAnimating ? 120 : -100
                    )
                    .scaleEffect(isAnimating ? 1.4 : 0.8)

                // 光球 3 (青蓝)
                Circle()
                    .fill(Color(hex: "0369A1"))
                    .frame(width: min(geo.size.width * 0.9, 700))
                    .blur(radius: 120)
                    .opacity(0.4)
                    .offset(
                        x: isAnimating ? 100 : -120,
                        y: isAnimating ? 150 : -100
                    )
                    .scaleEffect(isAnimating ? 1.2 : 0.9)

                // 光球 4 (靛蓝)
                Circle()
                    .fill(Color(hex: "4338CA"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(0.35)
                    .offset(
                        x: isAnimating ? -120 : 140,
                        y: isAnimating ? -140 : 110
                    )
                    .scaleEffect(isAnimating ? 0.9 : 1.4)

                NoiseTextureView()
                    .opacity(0.02)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 3. 极光
private struct AuroraBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "0A0A0C").ignoresSafeArea()

            ZStack {
                // 绿→青渐变条
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Color(hex: "00C9A7").opacity(0.5), Color(hex: "00B4D8").opacity(0.3)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 500, height: 120)
                    .blur(radius: 60)
                    .offset(y: -200 + phase * 30)
                    .rotationEffect(.degrees(Double(-15 + phase * 5)))

                // 紫色光带
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Color(hex: "845EC2").opacity(0.4), Color(hex: "D65DB1").opacity(0.25)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 450, height: 100)
                    .blur(radius: 50)
                    .offset(y: -140 + phase * 20)
                    .rotationEffect(.degrees(Double(10 - phase * 3)))

                // 青蓝色光条
                Ellipse()
                    .fill(Color(hex: "0096C7").opacity(0.3))
                    .frame(width: 380, height: 80)
                    .blur(radius: 45)
                    .offset(y: -100 + phase * 15)
                    .rotationEffect(.degrees(Double(-8 + phase * 4)))
            }

            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

// MARK: - 4. 午夜（纯深色 + 微光）
private struct MidnightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "0D1117")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 微光
            Circle()
                .fill(Color(hex: "30363D").opacity(0.3))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(y: -200)

            NoiseTextureView()
                .opacity(0.02)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ArkBackgroundView()
}
