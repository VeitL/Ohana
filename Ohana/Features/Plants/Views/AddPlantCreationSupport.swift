//
//  AddPlantCreationSupport.swift
//  Ohana
//
//  Lightweight card-step support for the Add Plant flow.
//

import SwiftUI
import UIKit

enum PlantCreationAvatarSource: String, Equatable {
    case builtIn
    case customImage
}

enum PlantCreationCatalogImageLoader {
    static func image(named assetName: String?) -> UIImage? {
        guard let assetName = normalizedAssetName(assetName) else { return nil }
        return UIImage(named: assetName)
    }

    static func normalizedAssetName(_ assetName: String?) -> String? {
        guard let normalized = assetName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return nil
        }
        return normalized
    }
}

enum AddPlantCreationStep: String, CaseIterable, Identifiable {
    case plant
    case avatar
    case care
    case confirm

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .plant:
            l.tr(zh: "植物与房间", en: "Plant and room", de: "Pflanze und Raum")
        case .avatar:
            l.tr(zh: "头像", en: "Avatar", de: "Avatar")
        case .care:
            l.tr(zh: "养护信息", en: "Care info", de: "Pflegeinfos")
        case .confirm:
            l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
        }
    }
}

struct PlantCreationStepIndicator: View {
    let steps: [AddPlantCreationStep]
    let currentStep: AddPlantCreationStep
    let l: L10n

    private var currentIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentStep.title(l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("\(currentIndex + 1) / \(steps.count)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? Color.goTeal : Color.ohanaControlFill.opacity(0.74))
                        .frame(width: index == currentIndex ? 26 : 9, height: 7)
                        .animation(GoMotion.selection, value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 42, alignment: .bottom)
    }
}

enum PlantCreationCardLayoutMode: Equatable {
    case standard
    case compact
    case avatarFocus
}

struct PlantCreationCardSurface<Content: View>: View {
    let title: String
    let subtitle: String
    let avatarImage: UIImage?
    let catalog: PlantCatalogEntry?
    let layoutMode: PlantCreationCardLayoutMode
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let heroHeight = resolvedHeroHeight(width: width, height: height)
            let controlsHeight = max(0, height - heroHeight)

            VStack(spacing: 0) {
                plantCardHero(width: width, height: heroHeight)
                    .frame(height: heroHeight)
                    .clipped()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Spacer(minLength: 0)
                        content()
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: controlsHeight, alignment: .bottomLeading)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: controlsHeight)
            }
            .background {
                PlantCreationDraftCardBackground()
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.34), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .environment(\.colorScheme, .light)
            .accessibilityIdentifier("add-plant-card-preview")
        }
    }

    private var displayedImage: UIImage? {
        avatarImage ?? PlantCreationCatalogImageLoader.image(named: catalog?.catalogImageAssetName)
    }

    private var usesFullBleedPhoto: Bool {
        avatarImage != nil
    }

    private func resolvedHeroHeight(width: CGFloat, height: CGFloat) -> CGFloat {
        switch layoutMode {
        case .standard:
            min(max(width * 0.38, 132), min(height * 0.26, 168))
        case .compact:
            min(max(width * 0.30, 108), min(height * 0.21, 138))
        case .avatarFocus:
            min(max(width * 0.78, 250), min(height * 0.48, 320))
        }
    }

    private func plantCardHero(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if usesFullBleedPhoto, let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [
                        Color.goCardWhite.opacity(0.92),
                        Color.goCardWhite.opacity(0.30),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            } else if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: width * (layoutMode == .compact ? 0.34 : 0.54),
                        height: max(72, height - 62)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: layoutMode == .compact ? 10 : 6)
                    .shadow(color: Color.arkInk.opacity(0.20), radius: 14, y: 8) // ui-v4: allow selected plant artwork depth
                    .allowsHitTesting(false)
            } else {
                Image(systemName: "leaf.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: min(width * 0.22, 86), weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goTeal.opacity(0.22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(.top, 22)
            .padding(.horizontal, 22)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            layoutMode == .avatarFocus ? "add-plant-avatar-preview" : "add-plant-card-hero"
        )
    }
}

private struct PlantCreationDraftCardBackground: View {
    var body: some View {
        ZStack {
            WalletMemberHeroBackground(
                themeColorHex: "21A88B",
                fallbackColor: Color.goTeal
            )

            LinearGradient(
                stops: [
                    .init(color: Color.goCardWhite.opacity(0.04), location: 0.00),
                    .init(color: Color.goCardWhite.opacity(0.42), location: 0.34),
                    .init(color: Color.goCardWhite.opacity(0.78), location: 0.68),
                    .init(color: Color(hex: "EAF7F2").opacity(0.92), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.goCardWhite.opacity(0.38), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 240
            )
        }
        .allowsHitTesting(false)
    }
}

struct PlantCreationAccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1) // a11y: allow invisible UI-test marker; it is not a user control.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(identifier)
            .accessibilityIdentifier(identifier)
    }
}

struct PlantCreationBufferedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let identifier: String
    let focusRequestID: Int
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    @State private var draftText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)

            TextField(placeholder, text: $draftText) // ui-v4: allow buffered add-plant input; parent draft commits on submit/blur to avoid whole-sheet invalidation per keystroke.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.goTeal.opacity(0.58) : Color.ohanaCardSurface.opacity(0.18),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .focused($isFocused)
                .submitLabel(submitLabel)
                .onSubmit {
                    commitDraft()
                    onSubmit()
                    isFocused = false
                }
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            draftText = text
            focusIfRequested(focusRequestID)
        }
        .onDisappear {
            commitDraft()
        }
        .onChange(of: text) { _, newValue in
            guard !isFocused, draftText != newValue else { return }
            draftText = newValue
        }
        .onChange(of: focusRequestID) { _, newValue in
            focusIfRequested(newValue)
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                commitDraft()
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func commitDraft() {
        guard text != draftText else { return }
        text = draftText
    }

    private func focusIfRequested(_ requestID: Int) {
        guard requestID > 0 else { return }
        OhanaFrameScheduler.runAfterNextFrame {
            isFocused = true
        }
    }
}

struct PlantCreationSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlantCreationMetricPill: View {
    let icon: String
    let title: String
    var isSelected = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText)
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(
            isSelected ? Color.goPrimary.opacity(0.96) : Color.ohanaControlFill.opacity(0.72),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }
}

struct PlantCreationAvatarPreview: View {
    let image: UIImage?
    let catalog: PlantCatalogEntry?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.goTeal.opacity(0.16))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let catalogImage {
                Image(uiImage: catalogImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            } else {
                Image(systemName: "leaf.fill") // a11y: allow decorative fallback avatar glyph; the avatar preview is hidden from VoiceOver.
                    .font(OhanaFont.adaptive(size: max(18, size * 0.36), weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.goTeal.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var catalogImage: UIImage? {
        PlantCreationCatalogImageLoader.image(named: catalog?.catalogImageAssetName)
    }
}

struct PlantCreationInfoRow<Control: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 28, height: 28) // a11y: allow decorative row glyph; surrounding row text provides the accessible content.
                    .background(Color.goTeal.opacity(0.13), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            control()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }
}
