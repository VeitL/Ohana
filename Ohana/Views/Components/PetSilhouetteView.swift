//
//  PetSilhouetteView.swift
//  Ohana
//
//  添加宠物时的互动剪影组件 — 用 SwiftUI 几何绘制猫/狗，支持毛色/瞳色实时预览 + 动画 + 点击交互
//

import SwiftUI

// MARK: - Public Entry
/// species: "猫" / "狗"（其他物种 fallback 为通用圆形剪影）
/// patternName: 图案毛色名（"奶牛色"/"三花"/"玳瑁"/"重点色"/"银渐层"/"蓝白双色"/"虎斑"），nil 时纯色
/// onTapCoat: 点击身体时触发（显示毛色选择器）
/// onTapEye: 点击眼睛时触发（显示瞳色选择器）
struct PetSilhouetteView: View {
    let species: String
    var coatColor: Color = Color(hex: "E8C49A")
    var eyeColor: Color = Color(hex: "6B3A2A")
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    /// 关闭偶发眨眼（用于小尺寸预览卡等，完全静态）
    var isAnimationEnabled: Bool = true

    var body: some View {
        switch species {
        case "猫": CatSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                   onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        case "狗": DogSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                   onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        case "兔子", "兔": RabbitSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                             onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        case "仓鼠": HamsterSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                        onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        case "鸟": BirdSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                   onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        default:   GenericSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                      onTapCoat: onTapCoat, onTapEye: onTapEye, isAnimationEnabled: isAnimationEnabled)
        }
    }
}

// MARK: - 轻量偶发眨眼（无 repeatForever、无递归 DispatchQueue）
private struct SilhouetteIdleBlinkModifier: ViewModifier {
    var isEnabled: Bool
    @Binding var blinkScale: CGFloat
    @State private var blinkLoop: Task<Void, Never>? = nil

    func body(content: Content) -> some View {
        content
            .onAppear { restartBlinkIfNeeded() }
            .onDisappear {
                blinkLoop?.cancel()
                blinkLoop = nil
            }
            .onChange(of: isEnabled) { _, new in
                blinkLoop?.cancel()
                blinkLoop = nil
                if new { restartBlinkIfNeeded() }
            }
    }

    private func restartBlinkIfNeeded() {
        guard isEnabled else { return }
        blinkLoop?.cancel()
        blinkLoop = Task {
            while !Task.isCancelled {
                let ns = UInt64(Double.random(in: 5.5...9.0) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.linear(duration: 0.04)) { blinkScale = 0.06 }
                }
                try? await Task.sleep(nanoseconds: 65_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.linear(duration: 0.09)) { blinkScale = 1.0 }
                }
            }
        }
    }
}

private extension View {
    func silhouetteIdleBlink(isEnabled: Bool, blinkScale: Binding<CGFloat>) -> some View {
        modifier(SilhouetteIdleBlinkModifier(isEnabled: isEnabled, blinkScale: blinkScale))
    }
}

/// 点击眼睛：短 easeOut，避免 spring + 多次主线程调度
private enum SilhouetteEyeTapFeedback {
    static func play(eyePulse: Binding<CGFloat>) {
        withAnimation(.easeOut(duration: 0.12)) { eyePulse.wrappedValue = 1.07 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.easeOut(duration: 0.14)) { eyePulse.wrappedValue = 1.0 }
        }
    }
}

// MARK: - Cat Silhouette（Kawaii 插画风）
private struct CatSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 地面阴影
            Ellipse()
                .fill(coatColor.opacity(0.18))
                .frame(width: 108, height: 18)
                .blur(radius: 5)
                .offset(y: 94)

            // 身体（蓬松大圆）
            Circle()
                .fill(RadialGradient(
                    colors: [coatColor.mix(with: .white, by: 0.18), coatColor.mix(with: .black, by: 0.06)],
                    center: UnitPoint(x: 0.45, y: 0.3), startRadius: 0, endRadius: 64))
                .frame(width: 128)
                .overlay(patternOverlay.clipShape(Circle()))
                .offset(y: 56)
                .onTapGesture { onTapCoat?() }

            // 尾巴
            CatTailShape()
                .stroke(LinearGradient(colors: [coatColor, coatColor.mix(with: .black, by: 0.1)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 44, height: 44)
                .offset(x: 70, y: 70)
                .onTapGesture { onTapCoat?() }

            // 头部组
            ZStack {
                // 耳朵外层
                CatEarShape()
                    .fill(coatColor.mix(with: .black, by: 0.06))
                    .frame(width: 32, height: 36)
                    .offset(x: -36, y: -44)
                CatEarShape()
                    .fill(coatColor.mix(with: .black, by: 0.06))
                    .frame(width: 32, height: 36)
                    .scaleEffect(x: -1)
                    .offset(x: 36, y: -44)
                // 耳朵内粉
                CatEarShape()
                    .fill(Color(hex: "FFB3C1").opacity(0.85))
                    .frame(width: 15, height: 18)
                    .offset(x: -36, y: -40)
                CatEarShape()
                    .fill(Color(hex: "FFB3C1").opacity(0.85))
                    .frame(width: 15, height: 18)
                    .scaleEffect(x: -1)
                    .offset(x: 36, y: -40)

                // 大圆头（kawaii 风格，径向渐变）
                Circle()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.22), coatColor.mix(with: .black, by: 0.04)],
                        center: UnitPoint(x: 0.38, y: 0.28), startRadius: 0, endRadius: 72))
                    .frame(width: 136)
                    .shadow(color: coatColor.opacity(0.25), radius: 10, y: 5)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 脸颊腮红
                Ellipse()
                    .fill(Color(hex: "FFB3C1").opacity(0.32))
                    .frame(width: 28, height: 18)
                    .offset(x: -38, y: 22)
                Ellipse()
                    .fill(Color(hex: "FFB3C1").opacity(0.32))
                    .frame(width: 28, height: 18)
                    .offset(x: 38, y: 22)

                // 眼睛（kawaii 大眼，略低位置）
                HStack(spacing: 28) {
                    PetEyeView(eyeColor: eyeColor, size: 24)
                    PetEyeView(eyeColor: eyeColor, size: 24)
                }
                .offset(y: 8)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 小鼻子（粉色圆点）
                Circle()
                    .fill(Color(hex: "FF9BAB"))
                    .frame(width: 9)
                    .offset(y: 36)

                // 猫须
                Group {
                    Capsule().fill(.white.opacity(0.55)).frame(width: 24, height: 1.5).rotationEffect(.degrees(-12)).offset(x: -42, y: 32)
                    Capsule().fill(.white.opacity(0.45)).frame(width: 22, height: 1.5).offset(x: -42, y: 38)
                    Capsule().fill(.white.opacity(0.35)).frame(width: 20, height: 1.5).rotationEffect(.degrees(12)).offset(x: -42, y: 44)
                    Capsule().fill(.white.opacity(0.55)).frame(width: 24, height: 1.5).rotationEffect(.degrees(12)).offset(x: 42, y: 32)
                    Capsule().fill(.white.opacity(0.45)).frame(width: 22, height: 1.5).offset(x: 42, y: 38)
                    Capsule().fill(.white.opacity(0.35)).frame(width: 20, height: 1.5).rotationEffect(.degrees(-12)).offset(x: 42, y: 44)
                }
            }
            .offset(y: -20)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }

    @ViewBuilder private var patternOverlay: some View {
        if let p = patternName { BodyPatternDots(patternName: p) } else { Color.clear }
    }
}

// MARK: - Dog Silhouette（Kawaii 插画风）
private struct DogSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    private var earColor: Color { coatColor.mix(with: .black, by: 0.18) }

    var body: some View {
        ZStack {
            // 地面阴影
            Ellipse()
                .fill(coatColor.opacity(0.18))
                .frame(width: 114, height: 18)
                .blur(radius: 5)
                .offset(y: 94)

            // 身体（蓬松大圆）
            Circle()
                .fill(RadialGradient(
                    colors: [coatColor.mix(with: .white, by: 0.15), coatColor.mix(with: .black, by: 0.08)],
                    center: UnitPoint(x: 0.42, y: 0.3), startRadius: 0, endRadius: 66))
                .frame(width: 132)
                .overlay(patternOverlay.clipShape(Circle()))
                .offset(y: 54)
                .onTapGesture { onTapCoat?() }

            // 尾巴
            DogTailShape()
                .stroke(LinearGradient(colors: [earColor, coatColor], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 34, height: 34)
                .offset(x: 68, y: 40)
                .onTapGesture { onTapCoat?() }

            // 头部组
            ZStack {
                // 垂耳（椭圆圆润形）— 在头后面
                Ellipse()
                    .fill(LinearGradient(colors: [earColor.mix(with: .white, by: 0.05), earColor.mix(with: .black, by: 0.12)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 42, height: 62)
                    .offset(x: -60, y: 12)
                Ellipse()
                    .fill(LinearGradient(colors: [earColor.mix(with: .white, by: 0.05), earColor.mix(with: .black, by: 0.12)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 42, height: 62)
                    .offset(x: 60, y: 12)

                // 大圆头
                Circle()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.25), coatColor.mix(with: .black, by: 0.03)],
                        center: UnitPoint(x: 0.38, y: 0.3), startRadius: 0, endRadius: 74))
                    .frame(width: 140)
                    .shadow(color: coatColor.opacity(0.22), radius: 10, y: 5)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 斑纹色块（kawaii 小狗特征 — 覆盖左侧脸）
                Ellipse()
                    .fill(earColor.opacity(0.72))
                    .frame(width: 58, height: 50)
                    .offset(x: -26, y: -4)
                    .clipShape(Circle().scale(1.0).offset(x: 0, y: 0))

                // 眼睛
                HStack(spacing: 30) {
                    PetEyeView(eyeColor: eyeColor, size: 23)
                    PetEyeView(eyeColor: eyeColor, size: 23)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 吻部浅色区
                Ellipse()
                    .fill(coatColor.mix(with: .white, by: 0.35).opacity(0.6))
                    .frame(width: 50, height: 36)
                    .offset(y: 36)

                // 大圆鼻子
                Ellipse()
                    .fill(Color(hex: "2C2C2C").opacity(0.88))
                    .frame(width: 22, height: 16)
                    .offset(y: 30)
                // 鼻子高光
                Ellipse()
                    .fill(.white.opacity(0.38))
                    .frame(width: 8, height: 5)
                    .offset(x: -4, y: 27)
            }
            .offset(y: -18)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }

    @ViewBuilder private var patternOverlay: some View {
        if let p = patternName { BodyPatternDots(patternName: p) } else { Color.clear }
    }
}

// MARK: - Rabbit Silhouette（Kawaii 插画风）
private struct RabbitSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 地面阴影
            Ellipse()
                .fill(coatColor.opacity(0.16))
                .frame(width: 108, height: 16)
                .blur(radius: 5)
                .offset(y: 94)

            // 身体（蓬松大圆）
            Circle()
                .fill(RadialGradient(
                    colors: [coatColor.mix(with: .white, by: 0.2), coatColor.mix(with: .black, by: 0.05)],
                    center: UnitPoint(x: 0.42, y: 0.3), startRadius: 0, endRadius: 62))
                .frame(width: 126)
                .overlay(patternOverlay.clipShape(Circle()))
                .offset(y: 56)
                .onTapGesture { onTapCoat?() }

            // 头部组
            ZStack {
                // 左长耳（先画，被头覆盖基部）
                Capsule()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.1), coatColor.mix(with: .black, by: 0.08)],
                        center: .top, startRadius: 0, endRadius: 36))
                    .frame(width: 24, height: 72)
                    .offset(x: -28, y: -72)
                Capsule()
                    .fill(Color(hex: "C9A4D8").opacity(0.9))   // 紫色内耳
                    .frame(width: 11, height: 48)
                    .offset(x: -28, y: -72)

                // 右长耳
                Capsule()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.1), coatColor.mix(with: .black, by: 0.08)],
                        center: .top, startRadius: 0, endRadius: 36))
                    .frame(width: 24, height: 72)
                    .offset(x: 28, y: -72)
                Capsule()
                    .fill(Color(hex: "C9A4D8").opacity(0.9))
                    .frame(width: 11, height: 48)
                    .offset(x: 28, y: -72)

                // 大圆头
                Circle()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.28), coatColor.mix(with: .black, by: 0.04)],
                        center: UnitPoint(x: 0.38, y: 0.28), startRadius: 0, endRadius: 68))
                    .frame(width: 130)
                    .shadow(color: coatColor.opacity(0.22), radius: 10, y: 5)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 脸颊腮红（三点）
                Group {
                    ForEach([-1, 0, 1], id: \.self) { i in
                        Circle().fill(Color(hex: "FFB3C1").opacity(0.5)).frame(width: 5)
                            .offset(x: CGFloat(-42 + i * 8), y: 22)
                    }
                    ForEach([-1, 0, 1], id: \.self) { i in
                        Circle().fill(Color(hex: "FFB3C1").opacity(0.5)).frame(width: 5)
                            .offset(x: CGFloat(42 + i * 8 - 8), y: 22)
                    }
                }

                // 眼睛（粉红色调）
                HStack(spacing: 26) {
                    PetEyeView(eyeColor: eyeColor, size: 22)
                    PetEyeView(eyeColor: eyeColor, size: 22)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 小粉鼻
                Circle()
                    .fill(Color(hex: "FF9BAB"))
                    .frame(width: 10)
                    .offset(y: 34)

                // Y 形嘴
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: 7))
                    p.move(to: CGPoint(x: -9, y: 13))
                    p.addQuadCurve(to: CGPoint(x: 0, y: 7), control: CGPoint(x: -4, y: 9))
                    p.addQuadCurve(to: CGPoint(x: 9, y: 13), control: CGPoint(x: 4, y: 9))
                }
                .stroke(Color(hex: "FFB3C1").opacity(0.7), lineWidth: 1.6)
                .frame(width: 18, height: 14)
                .offset(y: 40)
            }
            .offset(y: -18)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }

    @ViewBuilder private var patternOverlay: some View {
        if let p = patternName { BodyPatternDots(patternName: p) } else { Color.clear }
    }
}

// MARK: - Hamster Silhouette（Kawaii 插画风）
private struct HamsterSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    // 仓鼠特征：橙/棕色顶部帽，奶白色圆脸
    private var capColor: Color { coatColor.mix(with: Color(hex: "E67E22"), by: 0.4) }
    private var faceColor: Color { coatColor.mix(with: .white, by: 0.55) }

    var body: some View {
        ZStack {
            // 地面阴影
            Ellipse()
                .fill(coatColor.opacity(0.15))
                .frame(width: 116, height: 16)
                .blur(radius: 5)
                .offset(y: 95)

            // 身体（胖圆身）
            Circle()
                .fill(RadialGradient(
                    colors: [faceColor, faceColor.mix(with: .black, by: 0.06)],
                    center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 60))
                .frame(width: 122)
                .overlay(patternOverlay.clipShape(Circle()))
                .offset(y: 56)
                .onTapGesture { onTapCoat?() }

            // 头部组
            ZStack {
                // 小圆耳（外，capColor）
                Circle()
                    .fill(capColor)
                    .frame(width: 30)
                    .offset(x: -46, y: -42)
                Circle()
                    .fill(Color(hex: "FFB3C1").opacity(0.75))
                    .frame(width: 16)
                    .offset(x: -46, y: -42)

                Circle()
                    .fill(capColor)
                    .frame(width: 30)
                    .offset(x: 46, y: -42)
                Circle()
                    .fill(Color(hex: "FFB3C1").opacity(0.75))
                    .frame(width: 16)
                    .offset(x: 46, y: -42)

                // 橙色"帽子"头部 — 上半圆
                Circle()
                    .fill(RadialGradient(
                        colors: [capColor.mix(with: .white, by: 0.15), capColor.mix(with: .black, by: 0.1)],
                        center: UnitPoint(x: 0.4, y: 0.25), startRadius: 0, endRadius: 72))
                    .frame(width: 144)
                    .shadow(color: capColor.opacity(0.25), radius: 8, y: 4)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 奶白色下半脸（遮盖头部下方）
                Ellipse()
                    .fill(RadialGradient(
                        colors: [faceColor.mix(with: .white, by: 0.2), faceColor],
                        center: UnitPoint(x: 0.5, y: 0.1), startRadius: 0, endRadius: 55))
                    .frame(width: 118, height: 82)
                    .offset(y: 24)

                // 大眼睛（低位，kawaii）
                HStack(spacing: 30) {
                    PetEyeView(eyeColor: eyeColor, size: 24)
                    PetEyeView(eyeColor: eyeColor, size: 24)
                }
                .offset(y: 10)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 小粉鼻
                Circle()
                    .fill(Color(hex: "FF9BAB"))
                    .frame(width: 10)
                    .offset(y: 40)
            }
            .offset(y: -16)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }

    @ViewBuilder private var patternOverlay: some View {
        if let p = patternName { BodyPatternDots(patternName: p) } else { Color.clear }
    }
}

// MARK: - Bird Silhouette（Kawaii 插画风）
private struct BirdSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 地面阴影
            Ellipse()
                .fill(coatColor.opacity(0.16))
                .frame(width: 100, height: 14)
                .blur(radius: 5)
                .offset(y: 96)

            // 身体（圆润泪滴形 — 整合头身）
            Ellipse()
                .fill(RadialGradient(
                    colors: [coatColor.mix(with: .white, by: 0.18), coatColor.mix(with: .black, by: 0.08)],
                    center: UnitPoint(x: 0.4, y: 0.25), startRadius: 0, endRadius: 80))
                .frame(width: 150, height: 180)
                .overlay(patternOverlay.clipShape(Ellipse()))
                .offset(y: 32)
                .onTapGesture { onTapCoat?() }

            // 白色肚皮椭圆
            Ellipse()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.95), coatColor.mix(with: .white, by: 0.6).opacity(0.7)],
                    center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 44))
                .frame(width: 76, height: 98)
                .offset(y: 52)

            // 头部区（圆，重叠在身体顶部）
            ZStack {
                // 冠羽（三根）
                BirdCrownFeather()
                    .fill(coatColor.mix(with: .black, by: 0.2))
                    .frame(width: 10, height: 28)
                    .rotationEffect(.degrees(-20))
                    .offset(x: -12, y: -66)
                BirdCrownFeather()
                    .fill(coatColor.mix(with: .black, by: 0.25))
                    .frame(width: 12, height: 36)
                    .offset(x: 0, y: -72)
                BirdCrownFeather()
                    .fill(coatColor.mix(with: .black, by: 0.2))
                    .frame(width: 10, height: 28)
                    .rotationEffect(.degrees(20))
                    .offset(x: 12, y: -66)

                // 头
                Circle()
                    .fill(RadialGradient(
                        colors: [coatColor.mix(with: .white, by: 0.22), coatColor.mix(with: .black, by: 0.04)],
                        center: UnitPoint(x: 0.38, y: 0.3), startRadius: 0, endRadius: 60))
                    .frame(width: 118)
                    .shadow(color: coatColor.opacity(0.22), radius: 8, y: 4)

                // 眼睛
                HStack(spacing: 24) {
                    PetEyeView(eyeColor: eyeColor, size: 22)
                    PetEyeView(eyeColor: eyeColor, size: 22)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 三角喙（橙黄色）
                BirdBeakShape()
                    .fill(LinearGradient(
                        colors: [Color(hex: "FFB830"), Color(hex: "E07B00")],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 14)
                    .offset(y: 34)
            }
            .offset(y: -28)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }

    @ViewBuilder private var patternOverlay: some View {
        if let p = patternName { BodyPatternDots(patternName: p) } else { Color.clear }
    }
}

// MARK: - Generic Silhouette（极简）
private struct GenericSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Ellipse()
                .fill(coatColor.opacity(0.15))
                .frame(width: 120, height: 20)
                .blur(radius: 4)
                .offset(y: 90)

            Ellipse()
                .fill(LinearGradient(
                    colors: [coatColor, coatColor.mix(with: .black, by: 0.12)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 120, height: 92)
                .overlay { if let p = patternName { BodyPatternDots(patternName: p).clipShape(Ellipse()) } }
                .offset(y: 56)
                .onTapGesture { onTapCoat?() }

            ZStack {
                Circle().fill(coatColor).frame(width: 30).offset(x: -42, y: -50)
                Circle().fill(coatColor).frame(width: 30).offset(x: 42, y: -50)
                Circle()
                    .fill(LinearGradient(
                        colors: [coatColor.mix(with: .white, by: 0.06), coatColor.mix(with: .black, by: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 124)
                    .shadow(color: coatColor.opacity(0.18), radius: 6, y: 3)
                    .overlay { if let p = patternName { BodyPatternDots(patternName: p).clipShape(Circle()) } }

                HStack(spacing: 22) {
                    PetEyeView(eyeColor: eyeColor, size: 20)
                    PetEyeView(eyeColor: eyeColor, size: 20)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }
            }
            .offset(y: -14)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .silhouetteIdleBlink(isEnabled: isAnimationEnabled, blinkScale: $blinkScale)
    }
}

// MARK: - Pattern Overlay（极简图案）
private struct BodyPatternDots: View {
    let patternName: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                switch patternName {
                case "奶牛色":
                    Ellipse().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.3, height: h * 0.26)
                        .offset(x: -w * 0.18, y: -h * 0.10)
                    Ellipse().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.22, height: h * 0.20)
                        .offset(x: w * 0.20, y: h * 0.12)
                    Circle().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.16)
                        .offset(x: w * 0.04, y: -h * 0.22)
                case "三花":
                    Ellipse().fill(Color(hex: "E67E22"))
                        .frame(width: w * 0.30, height: h * 0.24)
                        .offset(x: -w * 0.14, y: -h * 0.08)
                    Ellipse().fill(Color(hex: "2C2C2C"))
                        .frame(width: w * 0.24, height: h * 0.20)
                        .offset(x: w * 0.18, y: h * 0.10)
                case "玳瑁":
                    Ellipse().fill(Color(hex: "D35400"))
                        .frame(width: w * 0.28, height: h * 0.22)
                        .offset(x: -w * 0.12, y: -h * 0.06)
                    Ellipse().fill(Color(hex: "1A1A1A").opacity(0.7))
                        .frame(width: w * 0.26, height: h * 0.18)
                        .offset(x: w * 0.16, y: h * 0.10)
                case "蓝白双色":
                    Rectangle().fill(Color(hex: "6B7B8D"))
                        .frame(width: w, height: h * 0.5)
                        .offset(y: -h * 0.25)
                case "银渐层":
                    RadialGradient(
                        colors: [Color(hex: "888888").opacity(0.45), .clear],
                        center: .top, startRadius: 0, endRadius: h * 0.8)
                case "虎斑":
                    VStack(spacing: h * 0.13) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(Color.black.opacity(0.18))
                                .frame(width: w * (0.48 - CGFloat(i) * 0.06), height: h * 0.05)
                                .offset(x: CGFloat(i % 2 == 0 ? -w * 0.03 : w * 0.03))
                        }
                    }
                default:
                    Color.clear
                }
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Eye Component
struct PetEyeView: View {
    var eyeColor: Color
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // 外层白底
            Circle()
                .fill(.white)
                .frame(width: size * 1.25, height: size * 1.25)

            // 虹膜
            Circle()
                .fill(eyeColor)
                .frame(width: size, height: size)

            // 瞳孔
            Circle()
                .fill(.black)
                .frame(width: size * 0.45, height: size * 0.45)

            // 大高光
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: -size * 0.15, y: -size * 0.15)

            // 小高光
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.18, y: size * 0.18)
        }
    }
}

// MARK: - Shapes

/// 猫耳新形（圆润尖耳 — 用于极简设计）
private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX * 0.9, y: rect.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.maxY * 1.05))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: 0),
                       control: CGPoint(x: rect.maxX * 0.1, y: rect.height * 0.3))
        p.closeSubpath()
        return p
    }
}

/// 狗尾短弧
private struct DogTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control1: CGPoint(x: 0, y: rect.midY * 0.5),
            control2: CGPoint(x: rect.midX, y: 0)
        )
        return p
    }
}

/// 猫耳三角（尖耳，保留备用）
private struct CatEarTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 猫尾巴（弯曲弧线）
private struct CatTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control1: CGPoint(x: 0, y: rect.midY),
            control2: CGPoint(x: rect.midX, y: 0)
        )
        return p
    }
}

/// 狗垂耳（圆润下垂）
private struct DogFloppyEar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control1: CGPoint(x: 0, y: -rect.height * 0.1),
            control2: CGPoint(x: rect.maxX, y: -rect.height * 0.1)
        )
        p.addCurve(
            to: CGPoint(x: rect.midX + 6, y: rect.maxY),
            control1: CGPoint(x: rect.maxX + 4, y: rect.height * 0.5),
            control2: CGPoint(x: rect.maxX - 2, y: rect.maxY)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: rect.midX - 4, y: rect.maxY),
            control2: CGPoint(x: -4, y: rect.height * 0.5)
        )
        p.closeSubpath()
        return p
    }
}

/// 鸟冠羽毛（水滴形）
private struct BirdCrownFeather: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.5),
            control: CGPoint(x: rect.maxX + rect.width * 0.1, y: rect.height * 0.75))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: 0),
            control: CGPoint(x: rect.maxX * 0.8, y: rect.height * 0.2))
        p.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height * 0.5),
            control: CGPoint(x: rect.minX * 1.2, y: rect.height * 0.2))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.height * 0.75))
        p.closeSubpath()
        return p
    }
}

/// 鸟喙（向下钩形三角）
private struct BirdBeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.6),
            control2: CGPoint(x: rect.midX + 4, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: rect.midX - 4, y: rect.maxY),
            control2: CGPoint(x: 0, y: rect.height * 0.6))
        p.closeSubpath()
        return p
    }
}

// MARK: - Face Details

private struct CatFaceDetails: View {
    var body: some View {
        ZStack {
            // 胡须（位于鼻子两侧）
            HStack(spacing: 40) {
                WhiskerGroup(flip: false)
                WhiskerGroup(flip: true)
            }
            .offset(y: 2)

            VStack(spacing: 4) {
                // 鼻子（心形倒三角）
                CatNoseShape()
                    .fill(Color(hex: "FF9B9B"))
                    .frame(width: 13, height: 9)
                // 嘴（W 形）
                CatMouthShape()
                    .stroke(Color(hex: "2C2C2C").opacity(0.45), lineWidth: 1.4)
                    .frame(width: 22, height: 9)
            }
        }
    }
}

private struct WhiskerGroup: View {
    var flip: Bool
    var body: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(.white.opacity(0.6))
                .frame(width: 22, height: 1.2)
                .rotationEffect(.degrees(flip ? 8 : -8))
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 20, height: 1.2)
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: 18, height: 1.2)
                .rotationEffect(.degrees(flip ? -8 : 8))
        }
        .scaleEffect(x: flip ? -1 : 1)
    }
}

private struct CatNoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                    control1: CGPoint(x: rect.maxX * 0.8, y: 0),
                    control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.6))
        p.addCurve(to: CGPoint(x: 0, y: rect.maxY),
                    control1: CGPoint(x: rect.midX, y: rect.maxY * 1.2),
                    control2: CGPoint(x: 0, y: rect.maxY * 0.6))
        p.closeSubpath()
        return p
    }
}

private struct CatMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                        control: CGPoint(x: rect.midX * 0.5, y: rect.maxY * 0.3))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0),
                        control: CGPoint(x: rect.midX * 1.5, y: rect.maxY * 0.3))
        return p
    }
}

private struct DogFaceDetails: View {
    var tongueY: CGFloat = 0

    var body: some View {
        VStack(spacing: 3) {
            // 鼻子（大圆鼻）
            Ellipse()
                .fill(Color(hex: "2C2C2C"))
                .frame(width: 28, height: 20)
                .overlay(
                    Ellipse()
                        .fill(.white.opacity(0.28))
                        .frame(width: 9, height: 6)
                        .offset(x: -4, y: -4)
                )
            // 嘴 + 舌头
            ZStack {
                DogMouthShape()
                    .stroke(Color(hex: "2C2C2C").opacity(0.35), lineWidth: 1.5)
                    .frame(width: 28, height: 12)
                // 舌头（伸出）
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(colors: [Color(hex: "FF9B9B"), Color(hex: "FF6B6B")],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 13, height: 18 + tongueY)
                    .offset(y: 7 + tongueY * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

private struct DogMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                        control: CGPoint(x: rect.midX * 0.4, y: rect.maxY * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0),
                        control: CGPoint(x: rect.midX * 1.6, y: rect.maxY * 0.5))
        return p
    }
}

// MARK: - Preview

#Preview("Cat") {
    ZStack {
        Color(hex: "0A0F2C").ignoresSafeArea()
        PetSilhouetteView(species: "猫", coatColor: Color(hex: "F5F5F0"), eyeColor: Color(hex: "2A5C9A"))
    }
}

#Preview("Dog") {
    ZStack {
        Color(hex: "0A0F2C").ignoresSafeArea()
        PetSilhouetteView(species: "狗", coatColor: Color(hex: "E67E22"), eyeColor: Color(hex: "B9770E"))
    }
}

#Preview("Rabbit") {
    ZStack {
        Color(hex: "0A0F2C").ignoresSafeArea()
        PetSilhouetteView(species: "兔子", coatColor: Color(hex: "F0EAD6"), eyeColor: Color(hex: "D45A7A"))
    }
}

#Preview("Hamster") {
    ZStack {
        Color(hex: "0A0F2C").ignoresSafeArea()
        PetSilhouetteView(species: "仓鼠", coatColor: Color(hex: "D4A574"), eyeColor: Color(hex: "3C2A1E"))
    }
}

#Preview("Bird") {
    ZStack {
        Color(hex: "0A0F2C").ignoresSafeArea()
        PetSilhouetteView(species: "鸟", coatColor: Color(hex: "4CAF50"), eyeColor: Color(hex: "1B5E20"))
    }
}
