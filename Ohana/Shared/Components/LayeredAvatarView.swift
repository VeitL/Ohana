//
//  LayeredAvatarView.swift
//  Ohana
//
//  Layered avatar with optional fur-color customization.

import SwiftUI

// MARK: - Fur Color Presets

struct AvatarColorPreset: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

extension AvatarColorPreset {
    static let furPresets: [AvatarColorPreset] = [
        .init(name: "象牙白", hex: "F5F0E8"),
        .init(name: "奶油", hex: "F0E0C0"),
        .init(name: "金黄", hex: "D4A847"),
        .init(name: "姜橙", hex: "C87941"),
        .init(name: "焦糖", hex: "8B5E3C"),
        .init(name: "巧克力", hex: "4A2C17"),
        .init(name: "银灰", hex: "A0A0A0"),
        .init(name: "炭黑", hex: "2A2A2A"),
        .init(name: "三花", hex: "D4A847"),
        .init(name: "虎纹", hex: "8B6914")
    ]

    func localizedName(_ l: L10n) -> String {
        switch name {
        case "象牙白": l.tr(zh: "象牙白", en: "Ivory", de: "Elfenbein")
        case "奶油": l.tr(zh: "奶油", en: "Cream", de: "Creme")
        case "金黄": l.tr(zh: "金黄", en: "Golden", de: "Gold")
        case "姜橙": l.tr(zh: "姜橙", en: "Ginger", de: "Ingwer")
        case "焦糖": l.tr(zh: "焦糖", en: "Caramel", de: "Karamell")
        case "巧克力": l.tr(zh: "巧克力", en: "Chocolate", de: "Schokolade")
        case "银灰": l.tr(zh: "银灰", en: "Silver gray", de: "Silbergrau")
        case "炭黑": l.tr(zh: "炭黑", en: "Charcoal", de: "Anthrazit")
        case "三花": l.tr(zh: "三花", en: "Calico", de: "Dreifarbig")
        case "虎纹": l.tr(zh: "虎纹", en: "Tabby", de: "Getigert")
        default: name
        }
    }
}

// MARK: - LayeredAvatarView

struct LayeredAvatarView: View {
    let imageData: Data?
    let petName: String
    let species: String

    @Binding var furHex: String

    /// When false, suppresses the picker popups (e.g. read-only display)
    var allowCustomize: Bool = true

    @State private var showFurPicker = false
    @State private var bodyPressScale: CGFloat = 1
    @State private var decodedAvatarImage: UIImage?
    @State private var decodedAvatarIsTransparent = false
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var furColor: Color { Color(hex: furHex.isEmpty ? "D4A847" : furHex) }
    private var avatarSignature: String {
        imageData.map { FocusWalletAvatarCache.signature(for: $0) } ?? "empty"
    }

    var body: some View {
        ZStack {
            if let uiImg = decodedAvatarImage {
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
        .sheet(isPresented: $showFurPicker) {
            ColorPickerPopup(
                title: l.tr(zh: "毛发颜色", en: "Fur color", de: "Fellfarbe"),
                presets: AvatarColorPreset.furPresets,
                selectedHex: $furHex
            )
            .presentationDetents(OhanaSheetDetents.compactMedium)
        }
        .task(id: avatarSignature) {
            guard let imageData else {
                decodedAvatarImage = nil
                decodedAvatarIsTransparent = false
                return
            }
            let key = MediaThumbnailKey(
                id: "layered-avatar-\(avatarSignature)",
                sourceSignature: MediaThumbnailProvider.signature(for: imageData),
                maxPixel: 1800
            )
            if let result = await MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: { imageData }) {
                decodedAvatarImage = result.image
                decodedAvatarIsTransparent = result.isTransparent
            } else {
                decodedAvatarImage = nil
                decodedAvatarIsTransparent = false
            }
        }
    }

    // MARK: – Photo avatar
    private func photoAvatar(_ img: UIImage) -> some View {
        ZStack {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                PetAvatarPortraitImage(
                    image: img,
                    isTransparentAvatar: decodedAvatarIsTransparent,
                    size: size
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }

            if allowCustomize {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Color.clear
                        .frame(width: w * 0.8, height: h * 0.55)
                        .position(x: w / 2, y: h / 2)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(GoMotion.feedback) { showFurPicker = true }
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
                .foregroundStyle(furColor.isDark ? Color.goCardWhite.opacity(0.15) : Color.arkInk.opacity(0.1))
                .font(OhanaFont.adaptive(size: 56)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .frame(width: 80, height: 80)

            // Fixed facial details keep the silhouette readable without adding another profile field.
            GeometryReader { geo in
                let w = geo.size.width
                let eyeY = w * 0.36
                let eyeSize: CGFloat = w * 0.12
                let spacing: CGFloat = w * 0.22
                ZStack {
                    // Left eye
                    Circle()
                        .fill(Color.arkInk)
                        .overlay(Circle().fill(Color.arkInk.opacity(0.6)).scaleEffect(0.5))
                        .overlay(Circle().fill(Color.goCardWhite.opacity(0.55)).scaleEffect(0.28).offset(x: -eyeSize * 0.15, y: -eyeSize * 0.15))
                        .frame(width: eyeSize, height: eyeSize)
                        .position(x: w / 2 - spacing, y: eyeY)
                    // Right eye
                    Circle()
                        .fill(Color.arkInk)
                        .overlay(Circle().fill(Color.arkInk.opacity(0.6)).scaleEffect(0.5))
                        .overlay(Circle().fill(Color.goCardWhite.opacity(0.55)).scaleEffect(0.28).offset(x: eyeSize * 0.15, y: -eyeSize * 0.15))
                        .frame(width: eyeSize, height: eyeSize)
                        .position(x: w / 2 + spacing, y: eyeY)
                }
            }

            // Interactive tap layers
            if allowCustomize {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Color.clear
                        .frame(width: w * 0.8, height: h * 0.7)
                        .position(x: w / 2, y: h / 2)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(GoMotion.feedback) {
                                bodyPressScale = 0.95
                                showFurPicker = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(GoMotion.feedback) { bodyPressScale = 1 }
                            }
                        }
                }
            }
        }
        .scaleEffect(bodyPressScale)
        .animation(GoMotion.feedback, value: bodyPressScale)
    }

    // MARK: – Customize hint badge
    private var customizeHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 9, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(l.tr(zh: "点击捏脸", en: "Tap to customize", de: "Zum Anpassen tippen"))
                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.goCardWhite)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.arkInk.opacity(0.5), in: Capsule())
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
        Pet.speciesSilhouetteSymbol(forSpecies: species)
    }
}

// MARK: - Color Picker Popup

struct ColorPickerPopup: View {
    let title: String
    let presets: [AvatarColorPreset]
    @Binding var selectedHex: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var surface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var bg: Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
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
                    .frame(width: 36, height: 5) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .padding(.top, 12)

                Text(title)
                    .font(OhanaFont.adaptive(size: 18, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)

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
            withAnimation(GoMotion.feedback) {
                selectedHex = preset.hex
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 44, height: 44)
                        .shadow(color: preset.color.opacity(0.4), radius: isSelected ? 8 : 3) // ui-v4: allow color swatch selection glow.
                    if isSelected {
                        Circle()
                            .strokeBorder(accent, lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite)
                            .shadow(color: Color.arkInk.opacity(0.22), radius: 2) // ui-v4: allow checkmark readability on bright swatches.
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(GoMotion.feedback, value: isSelected)

                Text(preset.localizedName(l))
                    .font(OhanaFont.adaptive(size: 10, weight: isSelected ? .bold : .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
        var body: some View {
            VStack(spacing: 24) {
                LayeredAvatarView(
                    imageData: nil,
                    petName: "小橘",
                    species: "猫",
                    furHex: $fur
                )
                .frame(width: 160, height: 160)
                Text("Fur: #\(fur)")
                    .font(.caption.monospaced())
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
