//
//  MemberCardCreationMediaComponents.swift
//  Ohana
//
//  Portrait card surfaces, avatar candidates, cropper, and camera bridge.
//

import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct MemberPortraitDraftCardSurface<Controls: View>: View {
    let snapshot: MemberCardRenderSnapshot
    @ViewBuilder var controls: () -> Controls

    private var accent: Color {
        Color(hex: snapshot.themeColorHex)
    }

    private var useDarkText: Bool {
        WalletPetCardTheme.prefersDarkForeground(for: snapshot.themeColorHex)
    }

    private var primaryText: Color {
        useDarkText ? Color.arkInk : Color.goCardWhite
    }

    private var usesWidePhoto: Bool {
        snapshot.avatarSource == .customImage && !snapshot.avatarIsTransparent && snapshot.avatarImage != nil
    }

    private var statusPillForeground: Color {
        usesWidePhoto ? Color.goCardWhite : primaryText
    }

    private var statusPillFill: Color {
        if usesWidePhoto {
            return Color.arkInk.opacity(0.34)
        }
        return useDarkText ? Color.arkInk.opacity(0.10) : Color.goCardWhite.opacity(0.15)
    }

    private var statusPillStroke: Color {
        useDarkText ? Color.arkInk.opacity(0.14) : Color.goCardWhite.opacity(0.22)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let heroHeight = min(max(width * 0.78, 240), min(height * 0.45, 320))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero(width: width, height: heroHeight)
                        .frame(height: heroHeight)
                    Spacer(minLength: 0)
                    controls()
                }
                .frame(minHeight: height, alignment: .bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .background {
                cardBackground(width: width, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.goCardWhite.opacity(0.86),
                                Color.goCardWhite.opacity(0.22),
                                accent.opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort - 2, style: .continuous)
                    .inset(by: 1.2)
                    .strokeBorder(Color.goCardWhite.opacity(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: accent.opacity(0.20), radius: 22, x: -8, y: -6) // ui-v4: allow intentional member creation glass glow
            .shadow(color: Color.arkInk.opacity(0.28), radius: 26, x: 0, y: 18) // ui-v4: allow intentional member portrait card depth
        }
    }

    @ViewBuilder
    private func cardBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "3157F4").opacity(0.72),
                    accent.mix(with: .white, by: 0.34).opacity(0.58),
                    Color(hex: "4A2F86").opacity(0.56),
                    Color(hex: "091342").opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if usesWidePhoto, let image = snapshot.avatarImage {
                WalletCardVerticalPhotoBlendLayer(
                    image: image,
                    width: width,
                    height: height,
                    themeColorHex: snapshot.themeColorHex,
                    shadowDepth: 0.92
                )
            }

            Circle()
                .fill(accent.mix(with: .white, by: 0.18).opacity(0.46))
                .frame(width: width * 0.78, height: width * 0.78)
                .blur(radius: 34)
                .offset(x: -width * 0.30, y: -height * 0.34)

            Circle()
                .fill(Color.goPrimary.opacity(0.18))
                .frame(width: width * 0.56, height: width * 0.56)
                .blur(radius: 40)
                .offset(x: width * 0.32, y: -height * 0.28)

            MemberCreationLightTrail()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goCardWhite.opacity(0.00),
                            Color.goCardWhite.opacity(0.32),
                            accent.mix(with: .white, by: 0.20).opacity(0.48),
                            Color.goCardWhite.opacity(0.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                )
                .blur(radius: 0.3)
                .frame(width: width, height: height)
                .blendMode(.screen)

            watermarkSymbol(width: width)
                .position(x: width * 0.78, y: height * 0.18)

            LinearGradient(
                colors: [
                    Color.goCardWhite.opacity(0.26),
                    Color.goCardWhite.opacity(0.10),
                    Color.arkInk.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        let readableText = usesWidePhoto ? Color.goCardWhite : primaryText
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.title)
                            .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(readableText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(snapshot.subtitle.isEmpty ? snapshot.kind.typeLabel(L10n(AppLanguage.code)) : snapshot.subtitle)
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(readableText.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    Spacer()
                    if !snapshot.statusText.isEmpty {
                        Text(snapshot.statusText)
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(statusPillForeground)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(statusPillFill, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(statusPillStroke, lineWidth: 1)
                            }
                    }
                }
                .frame(height: 50, alignment: .top)
                Spacer(minLength: 18)
                avatar(width: width)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 12)
            }
            .padding(.top, 22)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)

            if !usesWidePhoto, snapshot.avatarImage == nil {
                watermarkSymbol(width: width * 0.74)
                    .opacity(0.22)
                    .position(x: width * 0.55, y: height * 0.56)
            }
        }
    }

    @ViewBuilder
    private func avatar(width: CGFloat) -> some View {
        if usesWidePhoto {
            Color.clear
                .frame(width: width * 0.72, height: width * 0.58)
        } else if let image = snapshot.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width * (snapshot.kind == .pet ? 0.72 : 0.58), height: width * 0.58)
                .shadow(color: Color.arkInk.opacity(snapshot.avatarIsTransparent ? 0.30 : 0.18), radius: 16, y: 10) // ui-v4: allow intentional avatar depth
        } else {
            Color.clear
                .frame(width: width * 0.72, height: width * 0.50)
        }
    }

    @ViewBuilder
    private func watermarkSymbol(width: CGFloat) -> some View {
        Image(systemName: snapshot.kind == .pet ? "pawprint.fill" : "person.crop.circle.fill")
            .font(OhanaFont.adaptive(size: min(width * 0.30, 118), weight: .black))
            .foregroundStyle(Color.goCardWhite.opacity(0.20))
            .symbolRenderingMode(.monochrome)
            .shadow(color: Color.goCardWhite.opacity(0.16), radius: 12) // ui-v4: allow soft glass watermark glow inside member creation card
            .accessibilityHidden(true)
    }
}

private struct MemberCreationLightTrail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.43))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.35),
            control1: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.31),
            control2: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.52)
        )
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.50))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.42),
            control1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.38),
            control2: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.48)
        )
        return path
    }
}

struct MemberCreationSection<Content: View>: View {
    let title: String
    let icon: String
    var foreground: Color = .ohanaPrimaryText
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(foreground)
            content()
        }
    }
}

struct MemberAvatarCandidateCell: View {
    let candidate: Avatar2DCandidate
    let isSelected: Bool
    let action: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var image: UIImage?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .fill(isSelected ? Color.goPrimary : Color.ohanaControlFill)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } else {
                        Image(systemName: "person.crop.square.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .frame(width: 76, height: 96)
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2)
                }
                Text(candidate.isDefault ? l.tr(zh: "智能", en: "Smart", de: "Smart") : candidate.subtitle)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 76)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .task(id: candidate.id) {
            let data = candidate.data
            image = await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                UIImage(data: data) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
            }.value
        }
    }
}

struct MemberPortraitCropView: View {
    let item: MemberPortraitCropItem
    let onComplete: (Data) -> Void
    let onCancel: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var loadedImage: UIImage?
    @State private var loadErrorText = ""
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isProcessing = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.arkInk.ignoresSafeArea()
                VStack(spacing: 18) {
                    if let loadedImage {
                        cropStage(image: loadedImage)
                    } else {
                        cropLoadingStage
                    }
                    HStack(spacing: 12) {
                        Button {
                            onCancel()
                        } label: {
                            Text(l.cancel)
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.goCardWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.arkCardDark, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing)

                        Button {
                            finishCrop()
                        } label: {
                            HStack(spacing: 8) {
                                if isProcessing {
                                    ProgressView()
                                        .tint(Color.arkInk)
                                }
                                Text(primaryButtonTitle)
                            }
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(loadedImage == nil ? Color.ohanaSecondaryText : Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(loadedImage == nil ? Color.ohanaControlFill : Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing || loadedImage == nil)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(isProcessing)
            .task(id: item.id) {
                await loadImageIfNeeded()
            }
        }
    }

    private var primaryButtonTitle: String {
        if isProcessing {
            return l.tr(zh: "处理中", en: "Processing", de: "Verarbeitet")
        }
        if loadedImage == nil {
            return l.tr(zh: "准备中", en: "Preparing", de: "Vorbereiten")
        }
        return l.done
    }

    private var cropLoadingStage: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - 36
            let availableHeight = proxy.size.height - 12
            let cropWidth = min(availableWidth, availableHeight / MemberAvatarImageProcessor.portraitAspect)
            let cropHeight = cropWidth * MemberAvatarImageProcessor.portraitAspect

            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .fill(Color.arkCardDark)
                    .frame(width: cropWidth, height: cropHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                            .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
                    }

                VStack(spacing: 12) {
                    if loadErrorText.isEmpty {
                        ProgressView()
                            .tint(Color.goPrimary)
                        Text(l.tr(zh: "正在准备照片", en: "Preparing photo", de: "Foto wird vorbereitet"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goCardWhite)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 24, weight: .black))
                            .foregroundStyle(Color.goYellow)
                        Text(loadErrorText)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goCardWhite)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }
                }
                .padding(.horizontal, 24)
                .frame(width: cropWidth, height: cropHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cropStage(image: UIImage) -> some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - 36
            let availableHeight = proxy.size.height - 12
            let cropWidth = min(availableWidth, availableHeight / MemberAvatarImageProcessor.portraitAspect)
            let cropHeight = cropWidth * MemberAvatarImageProcessor.portraitAspect
            let cropRect = CGRect(
                x: (proxy.size.width - cropWidth) / 2,
                y: (proxy.size.height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
            let baseScale = max(cropWidth / image.size.width, cropHeight / image.size.height)
            let renderedSize = CGSize(
                width: image.size.width * baseScale * scale,
                height: image.size.height * baseScale * scale
            )
            let imageFrame = CGRect(
                x: cropRect.midX - renderedSize.width / 2 + offset.width,
                y: cropRect.midY - renderedSize.height / 2 + offset.height,
                width: renderedSize.width,
                height: renderedSize.height
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: renderedSize.width, height: renderedSize.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)

                Color.arkInk.opacity(0.54)
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                                    .frame(width: cropWidth, height: cropHeight)
                                    .blendMode(.destinationOut)
                            }
                    }
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .strokeBorder(Color.goPrimary, lineWidth: 2)
                    .frame(width: cropWidth, height: cropHeight)
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "MemberPortraitCropSpace")
            .onChange(of: cropRect) { _, _ in
                clampOffset(cropRect: cropRect, imageFrame: imageFrame)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private func clampOffset(cropRect: CGRect, imageFrame: CGRect) {
        var newOffset = offset
        if imageFrame.width <= cropRect.width {
            newOffset.width = 0
        } else {
            let overflow = (imageFrame.width - cropRect.width) / 2
            newOffset.width = min(max(newOffset.width, -overflow), overflow)
        }
        if imageFrame.height <= cropRect.height {
            newOffset.height = 0
        } else {
            let overflow = (imageFrame.height - cropRect.height) / 2
            newOffset.height = min(max(newOffset.height, -overflow), overflow)
        }
        offset = newOffset
        lastOffset = newOffset
    }

    private func finishCrop() {
        guard !isProcessing, let sourceImage = loadedImage else { return }
        isProcessing = true
        let scaleSnapshot = scale
        let offsetSnapshot = offset
        DispatchQueue.global(qos: .userInitiated).async {
            let signpostID = MemberCreationPerformance.begin("Avatar Crop Encode")
            let data = MemberAvatarImageProcessor.encodedCroppedAvatarData(
                image: sourceImage,
                scale: scaleSnapshot,
                offset: offsetSnapshot
            )
            MemberCreationPerformance.end("Avatar Crop Encode", signpostID)
            DispatchQueue.main.async {
                isProcessing = false
                if let data {
                    onComplete(data)
                }
            }
        }
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard loadedImage == nil else { return }
        loadErrorText = ""
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
        await Task.yield()

        switch item.source {
        case let .image(image):
            loadedImage = image
        case let .photoItem(photoItem):
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            let loadID = MemberCreationPerformance.begin("PhotoPicker LoadTransferable")
            guard let data = try? await photoItem.loadTransferable(type: Data.self) else {
                MemberCreationPerformance.end("PhotoPicker LoadTransferable", loadID)
                loadErrorText = l.tr(zh: "无法读取这张照片", en: "Could not read this photo", de: "Dieses Foto konnte nicht gelesen werden")
                return
            }
            MemberCreationPerformance.end("PhotoPicker LoadTransferable", loadID)
            guard !Task.isCancelled else { return }

            let decodeID = MemberCreationPerformance.begin("Avatar Photo Decode")
            let image = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                MemberAvatarImageProcessor.image(from: data)
            }.value
            MemberCreationPerformance.end("Avatar Photo Decode", decodeID)
            guard !Task.isCancelled else { return }
            guard let image else {
                loadErrorText = l.tr(zh: "无法解析这张照片", en: "Could not decode this photo", de: "Dieses Foto konnte nicht dekodiert werden")
                return
            }
            loadedImage = image
        }
    }
}

struct MemberCameraCaptureView: UIViewControllerRepresentable {
    let maxPixel: CGFloat
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context _: Context) -> OhanaCameraViewController {
        let viewController = OhanaCameraViewController()
        viewController.maxCapturePixel = maxPixel
        viewController.onCapture = onImage
        viewController.onCancel = onCancel
        return viewController
    }

    func updateUIViewController(_: OhanaCameraViewController, context _: Context) {}
}
