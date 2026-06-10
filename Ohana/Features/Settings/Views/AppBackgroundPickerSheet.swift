import Foundation
import PhotosUI
import SwiftUI

struct AppBackgroundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage("appCustomBackgroundVersion") private var customBackgroundVersion = 0

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isSavingPhoto = false
    @State private var errorMessage: String? = nil

    private var l: L10n { L10n(appLanguage) }
    private var selectedStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goIsland
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        officialBackgrounds
                        customBackgroundSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: photoItem) { _, item in
            handlePhotoItem(item)
        }
        .alert(l.tr(zh: "背景保存失败", en: "Could not save background", de: "Hintergrund konnte nicht gespeichert werden"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "背景", en: "Background", de: "Hintergrund"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "选择一组背景，同时决定浅色和深色模式。",
                    en: "Choose one background pair for both light and dark mode.",
                    de: "Wähle ein Hintergrundpaar für Hell- und Dunkelmodus."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var officialBackgrounds: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "官方背景对", en: "Official background pairs", de: "Offizielle Hintergrundpaare"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AppBackgroundStyle.officialPairOptions) { style in
                    backgroundOptionCard(style)
                }
            }
        }
    }

    private var customBackgroundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "自定义", en: "Custom", de: "Eigenes Bild"))
            backgroundOptionCard(.customPhoto)

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 6) {
                        if isSavingPhoto {
                            ProgressView()
                                .tint(Color.goPrimary)
                                .scaleEffect(0.72)
                        } else {
                            Image(systemName: CustomAppBackgroundStore.exists ? "photo.on.rectangle.angled" : "plus")
                        }
                        Text(CustomAppBackgroundStore.exists
                            ? l.tr(zh: "更换图片", en: "Change photo", de: "Bild ändern")
                            : l.tr(zh: "上传图片", en: "Upload photo", de: "Bild hochladen"))
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.goPrimary, in: Capsule())
                }
                .disabled(isSavingPhoto)
                .buttonStyle(ScaleButtonStyle())

                if CustomAppBackgroundStore.exists {
                    Button {
                        withAnimation(GoMotion.page) {
                            CustomAppBackgroundStore.deleteImage()
                            customBackgroundVersion += 1
                            if selectedStyle == .customPhoto {
                                styleRaw = AppBackgroundStyle.goIsland.rawValue
                            }
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goRed)
                            .frame(width: 48, height: 46)
                            .background(Color.goRed.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .tracking(1.1)
    }

    private func backgroundOptionCard(_ style: AppBackgroundStyle) -> some View {
        let selected = selectedStyle == style
        return Button {
            guard style != .customPhoto || CustomAppBackgroundStore.exists else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            withAnimation(GoMotion.page) {
                styleRaw = style.rawValue
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                backgroundPairPreview(style)
                    .frame(height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goPrimary)
                                .padding(8)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.localizedName(appLanguage))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(style.localizedSubtitle(appLanguage))
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(selected ? Color.goPrimary.opacity(0.75) : Color.ohanaGlassStroke.opacity(0.36), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: selected)
    }

    @ViewBuilder
    private func backgroundPairPreview(_ style: AppBackgroundStyle) -> some View {
        if style == .customPhoto, let image = CustomAppBackgroundStore.image {
            HStack(spacing: 0) {
                customPhotoPairHalf(image: image, isDarkPreview: false)
                customPhotoPairHalf(image: image, isDarkPreview: true)
            }
        } else {
            HStack(spacing: 0) {
                officialPairHalf(style, scheme: .light, label: l.tr(zh: "浅", en: "Light", de: "Hell"))
                officialPairHalf(style, scheme: .dark, label: l.tr(zh: "深", en: "Dark", de: "Dunkel"))
            }
        }
    }

    private func officialPairHalf(_ style: AppBackgroundStyle, scheme: ColorScheme, label: String) -> some View {
        LinearGradient(
            colors: style.gradientColors(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomLeading) {
            Text(label)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(scheme == .dark ? Color(hex: "F8FAFC").opacity(0.82) : Color(hex: "26364D").opacity(0.72))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((scheme == .dark ? Color(hex: "0B1020") : Color(hex: "F8FAFC")).opacity(0.18), in: Capsule())
                .padding(7)
        }
    }

    private func customPhotoPairHalf(image: UIImage, isDarkPreview: Bool) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    colors: isDarkPreview
                        ? [Color(hex: "0B1020").opacity(0.58), Color(hex: "0F172A").opacity(0.48)]
                        : [Color(hex: "DDE8F6").opacity(0.54), Color(hex: "AEBFD4").opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(isDarkPreview ? l.tr(zh: "深", en: "Dark", de: "Dunkel") : l.tr(zh: "浅", en: "Light", de: "Hell"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(isDarkPreview ? Color(hex: "F8FAFC").opacity(0.82) : Color(hex: "26364D").opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isDarkPreview ? Color(hex: "0B1020") : Color(hex: "F8FAFC")).opacity(0.18), in: Capsule())
                    .padding(7)
            }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isSavingPhoto = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                try CustomAppBackgroundStore.saveImageData(data)
                await MainActor.run {
                    withAnimation(GoMotion.page) {
                        customBackgroundVersion += 1
                        styleRaw = AppBackgroundStyle.customPhoto.rawValue
                    }
                    photoItem = nil
                    isSavingPhoto = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    photoItem = nil
                    isSavingPhoto = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}
