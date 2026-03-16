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

    var body: some View {
        switch species {
        case "猫": CatSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                   onTapCoat: onTapCoat, onTapEye: onTapEye)
        case "狗": DogSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                   onTapCoat: onTapCoat, onTapEye: onTapEye)
        default:   GenericSilhouette(coatColor: coatColor, eyeColor: eyeColor, patternName: patternName,
                                      onTapCoat: onTapCoat, onTapEye: onTapEye)
        }
    }
}

// MARK: - Cat Silhouette
private struct CatSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil

    @State private var blinkScale: CGFloat = 1.0
    @State private var tailWag: Double = 0
    @State private var eyePulse: CGFloat = 1.0

    private var isPointed: Bool { patternName == "重点色" }
    private var earColor: Color { isPointed ? Color(hex: "3E2723") : coatColor }
    private var tailColor: Color { isPointed ? Color(hex: "3E2723") : coatColor }

    var body: some View {
        ZStack {
            // ─── 身体
            bodyShape
                .onTapGesture { onTapCoat?() }

            // ─── 尾巴（轻柔摇摆）
            CatTailShape()
                .stroke(tailColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 50, height: 50)
                .offset(x: 72, y: 78)
                .rotationEffect(.degrees(tailWag), anchor: .leading)
                .onTapGesture { onTapCoat?() }

            // ─── 头部组（头+耳+面部）
            ZStack {
                // 头
                Circle()
                    .fill(coatColor)
                    .frame(width: 140)
                    .shadow(color: coatColor.opacity(0.18), radius: 8, y: 4)
                    .overlay { headPatternOverlay.clipShape(Circle()) }

                // 重点色面罩
                if isPointed {
                    Circle()
                        .fill(Color(hex: "3E2723").opacity(0.35))
                        .frame(width: 80)
                        .offset(y: 16)
                        .blur(radius: 12)
                }

                // 左耳（固定位置，不旋转）
                CatEarTriangle().fill(earColor)
                    .frame(width: 40, height: 44)
                    .offset(x: -38, y: -48)
                CatEarTriangle().fill(earColor.mix(with: .pink, by: 0.35))
                    .frame(width: 22, height: 24)
                    .offset(x: -38, y: -40)

                // 右耳（对称位置，不用 scaleEffect）
                CatEarTriangle().fill(earColor)
                    .frame(width: 40, height: 44)
                    .offset(x: 38, y: -48)
                CatEarTriangle().fill(earColor.mix(with: .pink, by: 0.35))
                    .frame(width: 22, height: 24)
                    .offset(x: 38, y: -40)

                // ─── 眼睛
                HStack(spacing: 26) {
                    PetEyeView(eyeColor: eyeColor, size: 24)
                    PetEyeView(eyeColor: eyeColor, size: 24)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { eyePulse = 1.25 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { eyePulse = 1.0 }
                    }
                    onTapEye?()
                }

                CatFaceDetails()
                    .offset(y: 30)
            }
            .offset(y: -22)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.5)) {
                tailWag = 8
            }
            startBlinkLoop()
        }
    }

    @ViewBuilder private var bodyShape: some View {
        ZStack {
            Ellipse()
                .fill(coatColor)
                .frame(width: 120, height: 90)
                .shadow(color: coatColor.opacity(0.3), radius: 12, y: 6)
            // 图案叠加
            if patternName != nil {
                BodyPatternDots(patternName: patternName!, isHead: false)
                    .clipShape(Ellipse())
                    .frame(width: 120, height: 90)
            }
        }
        .offset(y: 66)
    }

    @ViewBuilder private var headPatternOverlay: some View {
        if let p = patternName, !isPointed {
            BodyPatternDots(patternName: p, isHead: true)
        } else {
            Color.clear
        }
    }

    private func startBlinkLoop() {
        let interval = Double.random(in: 2.5...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            withAnimation(.easeIn(duration: 0.07)) { blinkScale = 0.04 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeOut(duration: 0.09)) { blinkScale = 1.0 }
                startBlinkLoop()
            }
        }
    }
}

// MARK: - Dog Silhouette
private struct DogSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil

    @State private var blinkScale: CGFloat = 1.0
    @State private var tongueY: CGFloat = 0
    @State private var eyePulse: CGFloat = 1.0

    private var earDarkColor: Color { coatColor.mix(with: .black, by: 0.13) }

    var body: some View {
        ZStack {
            // ─── 身体
            ZStack {
                Ellipse()
                    .fill(coatColor)
                    .frame(width: 130, height: 100)
                    .shadow(color: coatColor.opacity(0.28), radius: 12, y: 6)
                if let p = patternName {
                    BodyPatternDots(patternName: p, isHead: false)
                        .clipShape(Ellipse())
                        .frame(width: 130, height: 100)
                }
            }
            .offset(y: 64)
            .onTapGesture { onTapCoat?() }

            // ─── 头部组
            ZStack {
                // 左垂耳（固定，不旋转）
                DogFloppyEar()
                    .fill(earDarkColor)
                    .frame(width: 40, height: 56)
                    .offset(x: -58, y: 16)

                // 右垂耳（手动镜像位置，不用 scaleEffect）
                DogFloppyEar()
                    .fill(earDarkColor)
                    .frame(width: 40, height: 56)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .offset(x: 58, y: 16)

                // 头
                Circle()
                    .fill(coatColor)
                    .frame(width: 140)
                    .shadow(color: coatColor.opacity(0.15), radius: 8, y: 4)
                    .overlay {
                        Group {
                            if let p = patternName {
                                BodyPatternDots(patternName: p, isHead: true)
                            } else { Color.clear }
                        }
                        .clipShape(Circle())
                    }

                // ─── 眼睛
                HStack(spacing: 22) {
                    PetEyeView(eyeColor: eyeColor, size: 23)
                    PetEyeView(eyeColor: eyeColor, size: 23)
                }
                .offset(y: 2)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { eyePulse = 1.25 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { eyePulse = 1.0 }
                    }
                    onTapEye?()
                }

                DogFaceDetails(tongueY: tongueY)
                    .offset(y: 32)
            }
            .offset(y: -18)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.4)) {
                tongueY = 4
            }
            startBlinkLoop()
        }
    }

    private func startBlinkLoop() {
        let interval = Double.random(in: 2.5...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            withAnimation(.easeIn(duration: 0.07)) { blinkScale = 0.04 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeOut(duration: 0.09)) { blinkScale = 1.0 }
                startBlinkLoop()
            }
        }
    }
}

// MARK: - Generic Silhouette (other species)
private struct GenericSilhouette: View {
    var coatColor: Color
    var eyeColor: Color
    var patternName: String? = nil
    var onTapCoat: (() -> Void)? = nil
    var onTapEye: (() -> Void)? = nil

    @State private var blinkScale: CGFloat = 1.0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            ZStack {
                Ellipse()
                    .fill(coatColor)
                    .frame(width: 140, height: 120)
                    .shadow(color: coatColor.opacity(0.28), radius: 10, y: 6)
                if let p = patternName {
                    BodyPatternDots(patternName: p, isHead: false)
                        .clipShape(Ellipse())
                        .frame(width: 140, height: 120)
                }
            }
            .offset(y: 58)
            .onTapGesture { onTapCoat?() }

            ZStack {
                // 圆耳
                Circle().fill(coatColor).frame(width: 34)
                    .offset(x: -44, y: -50)
                Circle().fill(coatColor).frame(width: 34)
                    .offset(x: 44, y: -50)
                // 头
                Circle().fill(coatColor).frame(width: 130)
                    .shadow(color: coatColor.opacity(0.15), radius: 8, y: 4)
                    .overlay {
                        Group {
                            if let p = patternName {
                                BodyPatternDots(patternName: p, isHead: true)
                            } else { Color.clear }
                        }
                        .clipShape(Circle())
                    }

                HStack(spacing: 24) {
                    PetEyeView(eyeColor: eyeColor, size: 22)
                    PetEyeView(eyeColor: eyeColor, size: 22)
                }
                .offset(y: 6)
                .scaleEffect(y: blinkScale)
                .scaleEffect(eyePulse)
                .onTapGesture {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { eyePulse = 1.25 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { eyePulse = 1.0 }
                    }
                    onTapEye?()
                }

                Ellipse()
                    .fill(Color(hex: "2C2C2C"))
                    .frame(width: 14, height: 10)
                    .offset(y: 32)
            }
            .offset(y: -16)
            .onTapGesture { onTapCoat?() }
        }
        .frame(width: 210, height: 220)
        .onAppear { startBlinkLoop() }
    }

    private func startBlinkLoop() {
        let interval = Double.random(in: 3.0...5.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            withAnimation(.easeIn(duration: 0.07)) { blinkScale = 0.04 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeOut(duration: 0.09)) { blinkScale = 1.0 }
                startBlinkLoop()
            }
        }
    }
}

// MARK: - Pattern Dots Overlay（多色图案叠加层）
/// 在身体/头部上叠加色块，用 clipShape 裁切到对应形状
private struct BodyPatternDots: View {
    let patternName: String
    let isHead: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                switch patternName {
                case "奶牛色":
                    // 黑色斑块
                    Ellipse().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.3, height: h * 0.28)
                        .offset(x: -w * 0.18, y: isHead ? -h * 0.08 : -h * 0.12)
                    Ellipse().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.25, height: h * 0.22)
                        .offset(x: w * 0.2, y: isHead ? h * 0.12 : h * 0.15)
                    Circle().fill(Color(hex: "1A1A1A"))
                        .frame(width: w * 0.18)
                        .offset(x: w * 0.05, y: isHead ? -h * 0.2 : -h * 0.25)

                case "三花":
                    // 橘色+黑色斑块
                    Ellipse().fill(Color(hex: "E67E22"))
                        .frame(width: w * 0.32, height: h * 0.26)
                        .offset(x: -w * 0.15, y: -h * 0.08)
                    Ellipse().fill(Color(hex: "2C2C2C"))
                        .frame(width: w * 0.26, height: h * 0.22)
                        .offset(x: w * 0.2, y: h * 0.12)
                    Circle().fill(Color(hex: "E67E22"))
                        .frame(width: w * 0.16)
                        .offset(x: w * 0.08, y: isHead ? -h * 0.18 : h * 0.2)
                    Circle().fill(Color(hex: "2C2C2C"))
                        .frame(width: w * 0.14)
                        .offset(x: -w * 0.22, y: h * 0.18)

                case "玳瑁":
                    // 深橘+黑色混杂
                    Ellipse().fill(Color(hex: "D35400"))
                        .frame(width: w * 0.3, height: h * 0.25)
                        .offset(x: -w * 0.12, y: -h * 0.06)
                    Ellipse().fill(Color(hex: "1A1A1A").opacity(0.8))
                        .frame(width: w * 0.28, height: h * 0.2)
                        .offset(x: w * 0.16, y: h * 0.1)
                    Circle().fill(Color(hex: "D35400"))
                        .frame(width: w * 0.15)
                        .offset(x: w * 0.05, y: -h * 0.18)

                case "蓝白双色":
                    // 上半蓝灰，下半白
                    Rectangle().fill(Color(hex: "6B7B8D"))
                        .frame(width: w, height: h * 0.5)
                        .offset(y: -h * 0.25)

                case "银渐层":
                    // 深→浅径向渐变
                    RadialGradient(
                        colors: [Color(hex: "666666").opacity(0.5), .clear],
                        center: .top, startRadius: 0, endRadius: h * 0.8
                    )

                case "虎斑":
                    // 深色条纹
                    VStack(spacing: h * 0.12) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(Color.black.opacity(0.2))
                                .frame(width: w * (0.5 - CGFloat(i) * 0.06), height: h * 0.05)
                                .offset(x: CGFloat(i % 2 == 0 ? -w * 0.04 : w * 0.04))
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

/// 猫耳三角（尖耳）
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
