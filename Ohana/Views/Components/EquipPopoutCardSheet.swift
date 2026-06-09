//
//  EquipPopoutCardSheet.swift
//  Ohana
//
//  3D 破框卡片素材管理。破框主体独立于普通头像，只影响卡片特效。
//

import SwiftUI
import SwiftData
import PhotosUI

enum PetPopoutCardSource: String, Codable {
    case photoCutout
    case avatar2d
}

struct EquipPopoutCardSheet: View {
    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewData: Data?
    @State private var previewSource: PetPopoutCardSource?
    @State private var isProcessing = false
    @State private var toast: Toast?

    private struct Toast: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let tint: Color
    }

    private var l: L10n { L10n(appLanguage) }
    private var currentPreviewData: Data? { previewData ?? pet.cardPopoutImageData ?? pet.avatarImageData }
    private var currentPreviewImage: UIImage? { currentPreviewData.flatMap(UIImage.init(data:)) }
    private var isPopoutActive: Bool { pet.cardStyleRaw == "popout" }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.28))
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 18)

                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        popoutPreview
                        sourceActions
                        statusBlock
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }

            if let toast {
                toastView(toast)
                    .transition(.ohanaPop)
                    .zIndex(20)
            }
        }
        .tint(Color.goPrimary)
        .interactiveDismissDisabled(isProcessing)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            processPhoto(item)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "3D 破框卡片", en: "3D Popout Card", de: "3D-Popout-Karte"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isProcessing)
        }
    }

    private var popoutPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: pet.safeThemeColorHex).opacity(0.86),
                            Color(hex: pet.safeThemeColorHex).mix(with: .black, by: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 190)
                .overlay(alignment: .topTrailing) {
                    Text(isPopoutActive ? l.tr(zh: "已启用", en: "Active", de: "Aktiv") : l.tr(zh: "预览", en: "Preview", de: "Vorschau"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                        .padding(14)
                }

            if let image = currentPreviewImage {
                ZStack(alignment: .bottomLeading) {
                    Ellipse()
                        .fill(Color.arkInk.opacity(0.32))
                        .frame(width: 160, height: 30)
                        .blur(radius: 16)
                        .offset(x: 26, y: -8)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 218, alignment: .bottom)
                        .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0), anchor: .bottomLeading, perspective: 0.55)
                        .offset(x: 4, y: -28)
                        .shadow(color: Color.arkInk.opacity(0.34), radius: 20, x: 0, y: 14) // ui-v4: allow popout preview depth
                }
            } else {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name.isEmpty ? l.tr(zh: "宠物", en: "Pet", de: "Tier") : pet.name)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(WalletPetCardTheme.foreground(for: pet.safeThemeColorHex))
                Text(l.tr(zh: "从卡片里跳出来", en: "Pops out of the card", de: "Springt aus der Karte"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(WalletPetCardTheme.foreground(for: pet.safeThemeColorHex, opacity: 0.72))
            }
            .padding(18)
            .padding(.leading, 150)
        }
        .frame(maxWidth: .infinity)
    }

    private var sourceActions: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                sourceButton(
                    icon: "photo.on.rectangle.angled",
                    title: l.tr(zh: "相册抠图", en: "Photo cutout", de: "Foto-Freisteller"),
                    isSelected: previewSource == .photoCutout || pet.cardPopoutSourceRaw == PetPopoutCardSource.photoCutout.rawValue
                )
            }
            .disabled(isProcessing)

            Button {
                useAvatar2D()
            } label: {
                sourceButton(
                    icon: "sparkles",
                    title: "2.5D",
                    isSelected: previewSource == .avatar2d || pet.cardPopoutSourceRaw == PetPopoutCardSource.avatar2d.rawValue
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isProcessing)
        }
    }

    private func sourceButton(icon: String, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
            Text(title)
                .font(OhanaFont.caption(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isPopoutActive ? "checkmark.seal.fill" : "wand.and.stars")
                    .foregroundStyle(isPopoutActive ? Color.goPrimary : Color.goPurple)
                Text(isPopoutActive
                     ? l.tr(zh: "破框素材已保存，不会改变普通头像。", en: "Popout asset saved. Regular avatar is unchanged.", de: "Popout-Motiv gespeichert. Normaler Avatar bleibt unverändert.")
                     : l.tr(zh: "先选择素材，再启用破框卡片。", en: "Pick a subject, then enable popout.", de: "Wähle ein Motiv und aktiviere Popout."))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isProcessing {
                ProgressView()
                    .tint(Color.goPrimary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                savePopout()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(l.tr(zh: "启用破框卡片", en: "Enable popout card", de: "Popout-Karte aktivieren"))
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isProcessing || currentPreviewData == nil)

            if isPopoutActive {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    commandQueue.enqueue(.petCardAppearance(petID: pet.id, action: "restoreClassic")) {
                        _ = RewardEconomyCommandExecutor(context: modelContext).restoreClassicPetCard(
                            pet: pet,
                            note: "petCardAppearance.restoreClassic"
                        )
                        notifyPetProfileChanged()
                        dismiss()
                    }
                } label: {
                    Text(l.tr(zh: "恢复普通卡片", en: "Restore regular card", de: "Normale Karte wiederherstellen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isProcessing)
            }
        }
    }

    private func toastView(_ toast: Toast) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: toast.icon)
                    .foregroundStyle(toast.tint)
                Text(toast.title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface, in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private func processPhoto(_ item: PhotosPickerItem) {
        isProcessing = true
        Task {
            defer { Task { @MainActor in isProcessing = false } }
            guard let rawData = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: rawData) else {
                showError(l.tr(zh: "无法读取这张图片。", en: "Could not read this photo.", de: "Dieses Foto konnte nicht gelesen werden."))
                return
            }

            let cutout = (try? await ImageCutoutService.shared.removeBackground(from: image)) ?? image
            let trimmed = ImageCutoutService.trimmedTransparentSubjectImage(from: cutout) ?? cutout
            let downsampled = AddPetWizardView.downsample(trimmed, maxDim: 1024)
            guard let data = downsampled.pngData() else {
                showError(l.tr(zh: "无法生成透明素材。", en: "Could not create a transparent asset.", de: "Transparentes Motiv konnte nicht erstellt werden."))
                return
            }
            await MainActor.run {
                previewData = data
                previewSource = .photoCutout
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func useAvatar2D() {
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor,
            eyeColor: pet.eyeColor
        ) else {
            showToast(l.tr(zh: "请先补全物种、品种或外貌信息。", en: "Complete species, breed, or appearance first.", de: "Ergänze zuerst Art, Rasse oder Aussehen."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        previewData = data
        previewSource = .avatar2d
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func savePopout() {
        guard let data = currentPreviewData else { return }
        let sourceRaw = (previewSource ?? PetPopoutCardSource(rawValue: pet.cardPopoutSourceRaw ?? "") ?? .avatar2d).rawValue
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.petCardAppearance(petID: pet.id, action: "enablePopout")) {
            _ = RewardEconomyCommandExecutor(context: modelContext).enablePetPopoutCard(
                pet: pet,
                imageData: data,
                sourceRaw: sourceRaw,
                note: "petCardAppearance.enablePopout"
            )
            notifyPetProfileChanged()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(l.tr(zh: "破框卡片已启用", en: "Popout card enabled", de: "Popout-Karte aktiviert"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                dismiss()
            }
        }
    }

    private func notifyPetProfileChanged() {
        NotificationCenter.default.post(
            name: .ohanaMemberProfileDidChange,
            object: nil,
            userInfo: ["id": pet.id.uuidString, "kind": "pet"]
        )
    }

    @MainActor
    private func showError(_ message: String) {
        showToast(message, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
    }

    private func showToast(_ message: String, icon: String, tint: Color) {
        withAnimation(GoMotion.feedback) {
            toast = Toast(title: message, icon: icon, tint: tint)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(GoMotion.feedback) {
                toast = nil
            }
        }
    }
}
