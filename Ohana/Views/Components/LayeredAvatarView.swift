//
//  LayeredAvatarView.swift
//  Ohana
//
//  Phase 1+2: 分层 Avatar 引擎 + ColorPickerPopup
//  - 有头像时：图片叠加色彩滤镜层可调整
//  - 无头像时：矢量剪影 + 可着色
//  - 点击眼部区域 → 眼色选择器弹窗
//  - 点击躯体区域 → 毛色选择器弹窗

import SwiftUI

// MARK: - Eye & Fur Color Presets

struct AvatarColorPreset: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

enum AvatarColorCategory { case eye, fur }

extension AvatarColorPreset {
    static let eyePresets: [AvatarColorPreset] = [
        .init(name: "琥珀", hex: "D4A017"),
        .init(name: "深棕", hex: "5C3317"),
        .init(name: "浅棕", hex: "8B5E3C"),
        .init(name: "蓝灰", hex: "7BA7BC"),
        .init(name: "绿色", hex: "4A7C59"),
        .init(name: "冰蓝", hex: "A8D8EA"),
        .init(name: "灰色", hex: "9E9E9E"),
        .init(name: "榛色", hex: "8E6B3E"),
        .init(name: "黑色", hex: "1A1A1A"),
    ]

    static let furPresets: [AvatarColorPreset] = [
        .init(name: "象牙白", hex: "F5F0E8"),
        .init(name: "奶油",   hex: "F0E0C0"),
        .init(name: "金黄",   hex: "D4A847"),
        .init(name: "姜橙",   hex: "C87941"),
        .init(name: "焦糖",   hex: "8B5E3C"),
        .init(name: "巧克力", hex: "4A2C17"),
        .init(name: "银灰",   hex: "A0A0A0"),
        .init(name: "炭黑",   hex: "2A2A2A"),
        .init(name: "三花",   hex: "D4A847"),
        .init(name: "虎纹",   hex: "8B6914"),
    ]
}

// MARK: - LayeredAvatarView

struct LayeredAvatarView: View {
    let imageData: Data?
    let petName: String
    let species: String

    @Binding var furHex: String
    @Binding var eyeHex: String

    /// When false, suppresses the picker popups (e.g. read-only display)
    var allowCustomize: Bool = true

    @State private var showEyePicker  = false
    @State private var showFurPicker  = false
    @State private var eyePressScale: CGFloat  = 1
    @State private var bodyPressScale: CGFloat = 1

    private var furColor: Color  { Color(hex: furHex.isEmpty ? "D4A847" : furHex) }
    private var eyeColor: Color  { Color(hex: eyeHex.isEmpty ? "D4A017" : eyeHex) }

    var body: some View {
        ZStack {
            if let data = imageData, let uiImg = UIImage(data: data) {
                // ── Photo path: real avatar ──
                photoAvatar(uiImg)
            } else {
                // ── Fallback path: vector silhouette ──
                silhouetteAvatar
            }
        }
        .overlay(alignment: .bottom) {
            if allowCustomize {
                customizeHint
            }
        }
        .sheet(isPresented: $showEyePicker) {
            ColorPickerPopup(
                title: "眼睛颜色",
                presets: AvatarColorPreset.eyePresets,
                selectedHex: $eyeHex
            )
            .presentationDetents([.height(340)])
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showFurPicker) {
            ColorPickerPopup(
                title: "毛发颜色",
                presets: AvatarColorPreset.furPresets,
                selectedHex: $furHex
            )
            .presentationDetents([.height(340)])
            .presentationCornerRadius(32)
        }
    }

    // MARK: – Photo avatar
    private func photoAvatar(_ img: UIImage) -> some View {
        ZStack {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())

            // Eye region overlay (top-third of circle, centered)
            if allowCustomize {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // Eye tap zone: upper third
                    Color.clear
                        .frame(width: w * 0.6, height: h * 0.3)
                        .position(x: w / 2, y: h * 0.35)
                        .contentShape(Circle().scale(0.6).offset(y: -h * 0.15))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) { showEyePicker = true }
                        }
                    // Body tap zone: lower two-thirds
                    Color.clear
                        .frame(width: w * 0.8, height: h * 0.55)
                        .position(x: w / 2, y: h * 0.7)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) { showFurPicker = true }
                        }
                }
            }
        }
    }

    // MARK: – Silhouette avatar
    private var silhouetteAvatar: some View {
        ZStack {
            // Background fill (fur color)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [furColor.opacity(0.9), furColor.opacity(0.6)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )

            // Species silhouette SVG path
            PetSilhouetteIcon(species: species)
                .foregroundStyle(furColor.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                .font(.system(size: 56))
                .frame(width: 80, height: 80)

            // Eye dots overlay
            GeometryReader { geo in
                let w = geo.size.width
                let eyeY = w * 0.36
                let eyeSize: CGFloat = w * 0.12
                let spacing: CGFloat = w * 0.22
                ZStack {
                    // Left eye
                    Circle()
                        .fill(eyeColor)
                        .overlay(Circle().fill(.black.opacity(0.6)).scaleEffect(0.5))
                        .overlay(Circle().fill(.white.opacity(0.55)).scaleEffect(0.28).offset(x: -eyeSize * 0.15, y: -eyeSize * 0.15))
                        .frame(width: eyeSize, height: eyeSize)
                        .position(x: w / 2 - spacing, y: eyeY)
                    // Right eye
                    Circle()
                        .fill(eyeColor)
                        .overlay(Circle().fill(.black.opacity(0.6)).scaleEffect(0.5))
                        .overlay(Circle().fill(.white.opacity(0.55)).scaleEffect(0.28).offset(x: eyeSize * 0.15, y: -eyeSize * 0.15))
                        .frame(width: eyeSize, height: eyeSize)
                        .position(x: w / 2 + spacing, y: eyeY)
                }
            }

            // Interactive tap layers
            if allowCustomize {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // Eye zone
                    Color.clear
                        .frame(width: w * 0.7, height: h * 0.32)
                        .position(x: w / 2, y: h * 0.38)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                eyePressScale = 0.95
                                showEyePicker = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation { eyePressScale = 1 }
                            }
                        }
                    // Body zone
                    Color.clear
                        .frame(width: w * 0.8, height: h * 0.5)
                        .position(x: w / 2, y: h * 0.7)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                bodyPressScale = 0.95
                                showFurPicker = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation { bodyPressScale = 1 }
                            }
                        }
                }
            }
        }
        .scaleEffect(bodyPressScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bodyPressScale)
    }

    // MARK: – Customize hint badge
    private var customizeHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9, weight: .bold))
            Text("点击捏脸")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.black.opacity(0.5), in: Capsule())
        .offset(y: 8)
    }
}

// MARK: - Pet Silhouette Icon

private struct PetSilhouetteIcon: View {
    let species: String
    var body: some View {
        Image(systemName: systemIconName)
    }
    private var systemIconName: String {
        switch species {
        case "狗":   return "dog.fill"
        case "猫":   return "cat.fill"
        case "兔子": return "hare.fill"
        case "鸟":   return "bird.fill"
        default:     return "pawprint.fill"
        }
    }
}

// MARK: - Color Picker Popup

struct ColorPickerPopup: View {
    let title: String
    let presets: [AvatarColorPreset]
    @Binding var selectedHex: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var surface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var bg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var textSec: Color { colorScheme == .light ? Color(hex: "8E8E93") : Color(hex: "64748B") }
    private let accent = Color(hex: "FF5A00")

    private let columns = [
        GridItem(.adaptive(minimum: 52), spacing: 12)
    ]

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 20) {
                // Handle bar
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                // Color grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(presets) { preset in
                        colorSwatch(preset)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func colorSwatch(_ preset: AvatarColorPreset) -> some View {
        let isSelected = selectedHex.uppercased() == preset.hex.uppercased()
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                selectedHex = preset.hex
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 44, height: 44)
                        .shadow(color: preset.color.opacity(0.4), radius: isSelected ? 8 : 3)
                    if isSelected {
                        Circle()
                            .strokeBorder(accent, lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(.spring(response: 0.3), value: isSelected)

                Text(preset.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? accent : textSec)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Color Helper

private extension Color {
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var fur = "D4A847"
        @State var eye = "D4A017"
        var body: some View {
            VStack(spacing: 24) {
                LayeredAvatarView(
                    imageData: nil,
                    petName: "小橘",
                    species: "猫",
                    furHex: $fur,
                    eyeHex: $eye
                )
                .frame(width: 160, height: 160)
                Text("Fur: #\(fur)  Eye: #\(eye)")
                    .font(.caption.monospaced())
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
