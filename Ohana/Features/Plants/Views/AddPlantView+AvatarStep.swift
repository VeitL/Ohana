//
//  AddPlantView+AvatarStep.swift
//  Ohana
//
//  Step 2: built-in plant avatar or user photo.
//

import SwiftUI

extension AddPlantView {
    var plantAvatarStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PlantCreationSection(
                title: l.tr(zh: "植物头像", en: "Plant avatar", de: "Pflanzenavatar"),
                icon: "camera.aperture"
            ) {
                plantAvatarHero
                plantAvatarSourceActions
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-avatar")
        }
    }

    var plantAvatarHero: some View {
        VStack(alignment: .center, spacing: 12) {
            PlantCreationAvatarPreview(
                image: selectedAvatarSource == .customImage ? decodedAvatarImage : nil,
                catalog: selectedCatalog,
                size: 154
            )
            .accessibilityIdentifier("add-plant-avatar-preview")

            VStack(spacing: 4) {
                Text(resolvedPlantName)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(plantAvatarStatusText)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    var plantAvatarStatusText: String {
        switch selectedAvatarSource {
        case .builtIn:
            l.tr(zh: "使用所选品种的自带 3D 头像", en: "Using the selected species built-in 3D avatar", de: "Nutzt den integrierten 3D-Avatar der Art")
        case .customImage:
            l.tr(zh: "使用你上传或拍摄的照片", en: "Using your uploaded or captured photo", de: "Nutzt dein hochgeladenes oder aufgenommenes Foto")
        }
    }

    var plantAvatarSourceActions: some View {
        VStack(spacing: 10) {
            avatarSourceButton(
                title: l.tr(zh: "自带 3D 头像", en: "Built-in 3D avatar", de: "Integrierter 3D-Avatar"),
                subtitle: selectedCatalog?.localizedCommonName ?? l.tr(zh: "选择植物后自动匹配", en: "Matched after choosing a plant", de: "Nach Pflanzenwahl automatisch"),
                icon: "leaf.circle.fill",
                isSelected: selectedAvatarSource == .builtIn,
                identifier: "add-plant-avatar-builtin-action"
            ) {
                selectBuiltInPlantAvatar()
            }

            HStack(spacing: 10) {
                avatarSourceButton(
                    title: l.tr(zh: "上传照片", en: "Upload", de: "Hochladen"),
                    subtitle: l.tr(zh: "相册", en: "Library", de: "Mediathek"),
                    icon: "photo.on.rectangle.angled",
                    isSelected: false,
                    identifier: "add-plant-avatar-photo-action"
                ) {
                    openPlantPhotoLibraryAfterFirstFrame()
                }

                avatarSourceButton(
                    title: l.tr(zh: "拍照", en: "Camera", de: "Kamera"),
                    subtitle: isPreparingCamera ? l.tr(zh: "准备中", en: "Preparing", de: "Wird vorbereitet") : l.tr(zh: "现在拍", en: "Capture", de: "Aufnehmen"),
                    icon: "camera.fill",
                    isSelected: false,
                    identifier: "add-plant-avatar-camera-action"
                ) {
                    openPlantCameraAfterFirstFrame()
                }
            }

            if selectedAvatarSource == .customImage {
                Button {
                    selectBuiltInPlantAvatar()
                } label: {
                    Label(
                        l.tr(zh: "改回自带头像", en: "Use built-in avatar", de: "Integrierten Avatar nutzen"),
                        systemImage: "arrow.uturn.backward"
                    )
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goTeal)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.ohanaControlFill.opacity(0.44), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("add-plant-avatar-reset-action")
            }
        }
    }

    func avatarSourceButton(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? Color.arkInk : Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow decorative source glyph; parent button provides the 44pt target and label.
                    .background(isSelected ? Color.goPrimary.opacity(0.96) : Color.goTeal.opacity(0.13), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative selected glyph; button selected trait carries state.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background(Color.ohanaControlFill.opacity(0.50), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.goPrimary.opacity(0.40) : Color.ohanaCardSurface.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
