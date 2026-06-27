//
//  ArkBackgroundView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

// MARK: - ArkBackgroundView（根据用户设置切换背景风格）
struct ArkBackgroundView: View {
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage("appCustomBackgroundVersion") private var customBackgroundVersion = 0
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var style: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goDefault
    }

    private var shouldReduceWork: Bool {
        workloadPolicy.ambientMotionBudget(isVisible: true) == .static
    }

    var body: some View {
        switch style {
        case .goDefault: shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(GoDefaultBackground())
        case .goIsland: GoIslandBackground()
        case .cleanBlueGray: CleanBlueGrayBackground()
        case .deepAmbient: shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(DeepAmbientBackground())
        case .aurora, .midnight, .sunsetGlow, .sakuraMist:
            StaticGradientBackground(colors: style.gradientColors(for: colorScheme))
        case .forestGlade: shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(ForestGladeBackground())
        case .paperCream: PaperCreamBackground()
        case .neonGrid:
            StaticGradientBackground(colors: style.gradientColors(for: colorScheme))
        case .coastalFresh, .lavenderDawn, .mintFrost, .peachCloud, .graphitePulse:
            StaticGradientBackground(colors: style.gradientColors(for: colorScheme))
        case .customPhoto: CustomPhotoBackground(version: customBackgroundVersion)
        }
    }
}

private struct StaticGradientBackground: View {
    let colors: [Color]

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay {
                NoiseTextureView()
                    .opacity(0.014)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
            }
    }
}

/// Single app-wide screen backdrop. Use this for full-screen views and sheets so
/// Settings > Background Style applies consistently across the app.
struct OhanaAppBackground: View {
    var body: some View {
        ArkBackgroundView() // ui-v4: allow app-wide background wrapper
            .ignoresSafeArea()
    }
}

/// Static app backdrop for presentation handoffs and high-frequency route opens.
/// It preserves the selected background palette without decoding custom photos or
/// starting ambient animation loops on the user's tap frame.
struct OhanaStaticAppBackground: View {
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goIsland.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var style: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goIsland
    }

    var body: some View {
        StaticGradientBackground(colors: style.gradientColors(for: colorScheme))
            .ignoresSafeArea()
    }
}

// MARK: - 1. Go 默认（三球 Blob）
private struct GoDefaultBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    @State private var blob1Offset: CGSize = .zero
    @State private var blob2Offset: CGSize = .zero
    @State private var blob3Offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color(hex: isDark ? "0A0A0C" : "F5F7FA")
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(isDark ? 0.55 : 0.35))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -80 + blob1Offset.width, y: -160 + blob1Offset.height)

                Circle()
                    .fill(Color(hex: isDark ? "64748B" : "CBD5E1").opacity(isDark ? 0.28 : 0.22))
                    .frame(width: 300)
                    .blur(radius: 90)
                    .offset(x: 110 + blob2Offset.width, y: 60 + blob2Offset.height)

                Circle()
                    .fill(Color.goPurple.opacity(isDark ? 0.38 : 0.18))
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
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { // ui-v4: allow workload-gated ambient background drift; smoothness: allow ambient background loop behind visible shell, reduced by policy gates.
                blob1Offset = CGSize(width: 40, height: -30)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { // ui-v4: allow workload-gated ambient background drift; smoothness: allow ambient background loop behind visible shell, reduced by policy gates.
                blob2Offset = CGSize(width: -50, height: 35)
            }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { // ui-v4: allow workload-gated ambient background drift; smoothness: allow ambient background loop behind visible shell, reduced by policy gates.
                blob3Offset = CGSize(width: 30, height: -40)
            }
        }
    }
}

// MARK: - 1b. GO 岛屿（GO UI 首页壁纸 — 仅渐变 + 轻噪点，避免全 App 重复跑天气粒子 Timer）
private struct GoIslandBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var gradientColors: [Color] {
        AppBackgroundStyle.goIsland.gradientColors(for: colorScheme)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.022 : 0.010)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct CleanBlueGrayBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "111318"), Color(hex: "1A1E25"), Color(hex: "090B10")]
                    : [Color(hex: "F1F4F8"), Color(hex: "E5EAF0"), Color(hex: "D7DFE8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "64748B").opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 280)
                .blur(radius: 90)
                .offset(x: 110, y: -180)

            Circle()
                .fill(Color(hex: "64748B").opacity(colorScheme == .dark ? 0.18 : 0.13))
                .frame(width: 260)
                .blur(radius: 80)
                .offset(x: -120, y: 220)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.018 : 0.012)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct CustomPhotoBackground: View {
    let version: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = CustomAppBackgroundStore.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 22)
                        .overlay(readabilityOverlay)
                } else {
                    GoIslandBackground()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .id(version)
    }

    private var readabilityOverlay: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "020617").opacity(0.76), Color(hex: "111827").opacity(0.70), Color.arkInk.opacity(0.78)]
                    : [Color(hex: "F1F5F9").opacity(0.70), Color(hex: "E2E8F0").opacity(0.64), Color(hex: "CBD5E1").opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            (colorScheme == .dark ? Color.arkInk : Color.goCardWhite)
                .opacity(colorScheme == .dark ? 0.10 : 0.12)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.02 : 0.015)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 2. 深邃光球（Dynamic Ambient — 用户提供的设计稿）
private struct DeepAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [Color(hex: "030712"), Color(hex: "0F172A"), Color(hex: "111827")]
                        : [Color(hex: "EEF1F7"), Color(hex: "E3E7F0"), Color(hex: "D4DAE6")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: isDark ? "334155" : "CBD5E1"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.30 : 0.24)
                    .offset(
                        x: isAnimating ? 150 : -100,
                        y: isAnimating ? -120 : 80
                    )
                    .scaleEffect(isAnimating ? 1.3 : 0.9)

                Circle()
                    .fill(Color(hex: isDark ? "6D28D9" : "C4B5FD"))
                    .frame(width: min(geo.size.width * 0.7, 500))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.28 : 0.20)
                    .offset(
                        x: isAnimating ? -150 : 80,
                        y: isAnimating ? 120 : -100
                    )
                    .scaleEffect(isAnimating ? 1.4 : 0.8)

                Circle()
                    .fill(Color(hex: isDark ? "0E7490" : "BAE6FD"))
                    .frame(width: min(geo.size.width * 0.9, 700))
                    .blur(radius: 120)
                    .opacity(isDark ? 0.24 : 0.14)
                    .offset(
                        x: isAnimating ? 100 : -120,
                        y: isAnimating ? 150 : -100
                    )
                    .scaleEffect(isAnimating ? 1.2 : 0.9)

                Circle()
                    .fill(Color(hex: isDark ? "3730A3" : "C7D2FE"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.24 : 0.16)
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
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) { // ui-v4: allow workload-gated aurora background drift; smoothness: allow ambient background loop behind visible shell, reduced by policy gates.
                isAnimating = true
            }
        }
    }
}

// MARK: - 7. 森谷
private struct ForestGladeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var sway = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "052E1F") : Color(hex: "E8F5EF"))
                .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "059669").opacity(colorScheme == .dark ? 0.4 : 0.28))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: sway ? -70 : -100, y: -120)

            Circle()
                .fill(Color(hex: "34D399").opacity(colorScheme == .dark ? 0.28 : 0.22))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: sway ? 100 : 70, y: 180)

            Circle()
                .fill(Color(hex: "065F46").opacity(colorScheme == .dark ? 0.35 : 0.12))
                .frame(width: 340)
                .blur(radius: 90)
                .offset(y: sway ? 20 : -10)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.02 : 0.012)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { sway = true } // ui-v4: allow workload-gated ambient background sway; smoothness: allow ambient background loop behind visible shell, reduced by policy gates.
        }
    }
}

// MARK: - 8. 暖纸（浅色偏暖 / 深色暖灰）
private struct PaperCreamBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: "1C1917"), Color(hex: "292524"), Color(hex: "1C1917")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "78716C").opacity(0.2))
                    .frame(width: 280)
                    .blur(radius: 75)
                    .offset(x: -60, y: -140)
            } else {
                LinearGradient(
                    colors: [Color(hex: "FAF7F2"), Color(hex: "F0E8DC"), Color(hex: "E8DDD0")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "D6C4B0").opacity(0.35))
                    .frame(width: 320)
                    .blur(radius: 90)
                    .offset(x: 80, y: -100)

                Circle()
                    .fill(Color(hex: "C9B8A4").opacity(0.2))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -100, y: 200)
            }

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.025 : 0.035)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - GO 岛屿向导底（与 GO Focus 渐变 + 浮动色球一致）
/// 添加宠物 / 家庭成员等全屏向导使用，避免误用 `ArkBackgroundView` 的 `go_default` 浅色底。
struct GoIslandWizardBackdrop: View {
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blobPulse = false

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppBackgroundStyle.goIsland.gradientColors(for: .dark),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.goLime)
                        .frame(width: 260, height: 260)
                        .blur(radius: 80)
                        .opacity(shouldReduceWork ? 0.12 : 0.22)
                        .offset(x: blobPulse ? -50 : -70, y: blobPulse ? -70 : -90)

                    Circle()
                        .fill(Color(hex: "64748B"))
                        .frame(width: 300, height: 300)
                        .blur(radius: 90)
                        .opacity(shouldReduceWork ? 0.14 : 0.26)
                        .offset(x: blobPulse ? geo.size.width - 80 : geo.size.width - 100,
                                y: blobPulse ? 180 : 220)

                    Circle()
                        .fill(Color(hex: "A855F7"))
                        .frame(width: 240, height: 240)
                        .blur(radius: 90)
                        .opacity(shouldReduceWork ? 0.14 : 0.30)
                        .offset(x: blobPulse ? -40 : -60,
                                y: blobPulse ? geo.size.height * 0.55 : geo.size.height * 0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            NoiseTextureView()
                .opacity(0.022)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !shouldReduceWork else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { // ui-v4: allow workload-gated onboarding background pulse; smoothness: allow onboarding-only background loop gated by reduced-work policy.
                blobPulse = true
            }
        }
    }
}

#Preview {
    ArkBackgroundView() // ui-v4: allow background component preview
}
