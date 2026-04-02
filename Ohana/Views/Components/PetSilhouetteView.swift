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

// MARK: - Cat Silhouette（极简重设计）
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
            // ── 阴影底（blur 减小以降低 GPU 压力）
            Ellipse()
                .fill(coatColor.opacity(0.18))
                .frame(width: 110, height: 22)
                .blur(radius: 5)
                .offset(y: 90)

            // ── 身体
            Ellipse()
                .fill(LinearGradient(
                    colors: [coatColor, coatColor.mix(with: .black, by: 0.12)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 104, height: 80)
                .overlay(patternOverlay.clipShape(Ellipse()))
                .offset(y: 58)
                .onTapGesture { onTapCoat?() }

            // ── 尾巴（静态，不再持续摇尾动画）
            CatTailShape()
                .stroke(
                    LinearGradient(colors: [coatColor, coatColor.mix(with: .black, by: 0.1)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 48, height: 48)
                .offset(x: 66, y: 68)
                .onTapGesture { onTapCoat?() }

            // ── 头部组
            ZStack {
                // 耳朵（先画，被头覆盖基部）
                CatEarShape()
                    .fill(LinearGradient(colors: [coatColor.mix(with: .black, by: 0.08), coatColor], startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 38)
                    .offset(x: -36, y: -44)
                CatEarShape()
                    .fill(LinearGradient(colors: [coatColor.mix(with: .black, by: 0.08), coatColor], startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 38)
                    .scaleEffect(x: -1)
                    .offset(x: 36, y: -44)
                // 内耳粉
                CatEarShape()
                    .fill(coatColor.mix(with: Color(hex: "FFB3C1"), by: 0.45).opacity(0.6))
                    .frame(width: 18, height: 20)
                    .offset(x: -36, y: -38)
                CatEarShape()
                    .fill(coatColor.mix(with: Color(hex: "FFB3C1"), by: 0.45).opacity(0.6))
                    .frame(width: 18, height: 20)
                    .scaleEffect(x: -1)
                    .offset(x: 36, y: -38)

                // 头
                Circle()
                    .fill(LinearGradient(
                        colors: [coatColor.mix(with: .white, by: 0.08), coatColor.mix(with: .black, by: 0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 122)
                    .shadow(color: coatColor.opacity(0.2), radius: 6, y: 3)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 眼睛
                HStack(spacing: 24) {
                    PetEyeView(eyeColor: eyeColor, size: 22)
                    PetEyeView(eyeColor: eyeColor, size: 22)
                }
                .offset(y: 4)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }
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

// MARK: - Dog Silhouette（极简重设计）
private struct DogSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil
    var isAnimationEnabled: Bool = true

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    private var earColor: Color { coatColor.mix(with: .black, by: 0.15) }

    var body: some View {
        ZStack {
            // ── 阴影底
            Ellipse()
                .fill(coatColor.opacity(0.18))
                .frame(width: 118, height: 24)
                .blur(radius: 5)
                .offset(y: 92)

            // ── 身体
            Ellipse()
                .fill(LinearGradient(
                    colors: [coatColor, coatColor.mix(with: .black, by: 0.12)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 114, height: 88)
                .overlay(patternOverlay.clipShape(Ellipse()))
                .offset(y: 56)
                .onTapGesture { onTapCoat?() }

            // ── 尾巴（静态）
            DogTailShape()
                .stroke(
                    LinearGradient(colors: [earColor, coatColor], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 36, height: 36)
                .offset(x: 62, y: 38)
                .onTapGesture { onTapCoat?() }

            // ── 头部组
            ZStack {
                // 垂耳（先画）
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [earColor, earColor.mix(with: .black, by: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 52)
                    .offset(x: -60, y: 10)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [earColor, earColor.mix(with: .black, by: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 52)
                    .offset(x: 60, y: 10)

                // 头
                Circle()
                    .fill(LinearGradient(
                        colors: [coatColor.mix(with: .white, by: 0.08), coatColor.mix(with: .black, by: 0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 128)
                    .shadow(color: coatColor.opacity(0.2), radius: 7, y: 4)
                    .overlay(patternOverlay.clipShape(Circle()))

                // 眼睛
                HStack(spacing: 26) {
                    PetEyeView(eyeColor: eyeColor, size: 22)
                    PetEyeView(eyeColor: eyeColor, size: 22)
                }
                .offset(y: 2)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    SilhouetteEyeTapFeedback.play(eyePulse: $eyePulse)
                    onTapEye?()
                }

                // 简洁鼻子（小圆点）
                Ellipse()
                    .fill(coatColor.mix(with: .black, by: 0.55).opacity(0.85))
                    .frame(width: 20, height: 14)
                    .offset(y: 36)
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
