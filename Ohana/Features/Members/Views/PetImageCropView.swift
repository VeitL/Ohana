//
//  PetImageCropView.swift
//  Ohana
//

import SwiftUI
import UIKit

struct PetImageCropView: View {
    let image: UIImage
    var species: String = "狗"
    var silhouetteSystemName: String?
    let onCrop: (UIImage?) -> Void

    private let cardMargin: CGFloat = 7
    private let cardAspectRatio: CGFloat = 1.586
    private let cornerRadius: CGFloat = 24
    private let maxScale: CGFloat = 6.0

    @Environment(\.colorScheme) private var colorScheme

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var fitDisplaySize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        GeometryReader { geo in
            let (cropW, cropH) = cropSize(for: geo.size)
            ZStack {
                Color.arkInk

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale, anchor: .center)
                    .offset(offset)
                    .allowsHitTesting(false)

                CardCropOverlay(cropW: cropW, cropH: cropH, cornerRadius: cornerRadius)
                    .allowsHitTesting(false)

                cropGuide(cropW: cropW, cropH: cropH)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goPrimary, lineWidth: 2)
                    .frame(width: cropW, height: cropH)
                    .allowsHitTesting(false)

                CardCropCorners(width: cropW, height: cropH, radius: cornerRadius)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Label(l.tr(zh: "卡片取景", en: "Card crop", de: "Kartenausschnitt"), systemImage: "crop")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goCardWhite.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.arkInk.opacity(0.22), in: Capsule())
                        .padding(.bottom, 104)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .simultaneousGesture(cropGesture(cropW: cropW, cropH: cropH))
            .onAppear {
                configureInitialImageFit(container: geo.size, cropW: cropW, cropH: cropH)
            }
            .onChange(of: geo.size) { _, newValue in
                containerSize = newValue
            }
        }
        .safeAreaInset(edge: .bottom) {
            cropActions
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    private func cropSize(for container: CGSize) -> (w: CGFloat, h: CGFloat) {
        let targetW = max(container.width - cardMargin * 2, 220)
        let targetH = targetW / cardAspectRatio
        let availableH = max(container.height - 170, 260)
        if targetH <= availableH {
            return (targetW, targetH)
        }
        return (availableH * cardAspectRatio, availableH)
    }

    private func minScale(cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 0.3 }
        let fw = cropW / fitDisplaySize.width
        let fh = cropH / fitDisplaySize.height
        return max(min(fw, fh), 0.3)
    }

    private func cropGuide(cropW: CGFloat, cropH: CGFloat) -> some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: max(4, cornerRadius - 4), style: .continuous)
                    .fill(Color.goCardWhite.opacity(colorScheme == .dark ? 0.1 : 0.07))
                    .frame(width: cropW / 2, height: cropH)
                Image(systemName: silhouetteSystemName ?? Pet.speciesSilhouetteSymbol(forSpecies: species))
                    .font(.system(size: min(cropH * 0.52, 128), weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goCardWhite.opacity(colorScheme == .dark ? 0.38 : 0.26))
            }
            .frame(width: cropW / 2, height: cropH)
            Color.clear.frame(width: cropW / 2, height: cropH)
        }
        .frame(width: cropW, height: cropH)
    }

    private func cropGesture(cropW: CGFloat, cropH: CGFloat) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let proposed = lastScale * value.magnification
                    let minimum = minScale(cropW: cropW, cropH: cropH)
                    scale = min(maxScale, max(minimum, proposed))
                }
                .onEnded { _ in lastScale = scale },
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    private var cropActions: some View {
        HStack(spacing: 12) {
            Button { onCrop(nil) } label: {
                Text(l.cancel)
                    .font(OhanaFont.adaptive(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.arkCardDark, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button { performCrop() } label: {
                Text(l.tr(zh: "确认裁剪", en: "Crop", de: "Zuschneiden"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.arkInk.opacity(0.8))
    }

    private func configureInitialImageFit(container: CGSize, cropW: CGFloat, cropH: CGFloat) {
        containerSize = container
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let aspectFit = min(container.width / imageSize.width, container.height / imageSize.height)
        fitDisplaySize = CGSize(width: imageSize.width * aspectFit, height: imageSize.height * aspectFit)
        let minimum = minScale(cropW: cropW, cropH: cropH)
        let fw = fitDisplaySize.width > 0 ? cropW / fitDisplaySize.width : 1.0
        let fh = fitDisplaySize.height > 0 ? cropH / fitDisplaySize.height : 1.0
        let initialScale = max(minimum, max(fw, fh))
        scale = initialScale
        lastScale = initialScale
    }

    private func performCrop() {
        let viewSize: CGSize = (containerSize.width > 10 && containerSize.height > 10)
            ? containerSize
            : CGSize(width: ScreenCompat.width, height: max(ScreenCompat.height - 300, 420))
        let (cropW, cropH) = cropSize(for: viewSize)
        let source = image
        let imageSize = source.size
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            onCrop(source)
            return
        }

        let fitScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let totalScale = fitScale * scale
        let displayW = imageSize.width * totalScale
        let displayH = imageSize.height * totalScale

        let imgOriginX = (viewSize.width - displayW) / 2 + offset.width
        let imgOriginY = (viewSize.height - displayH) / 2 + offset.height
        let cropOriginX = (viewSize.width - cropW) / 2
        let cropOriginY = (viewSize.height - cropH) / 2

        let drawRect = CGRect(
            x: imgOriginX - cropOriginX,
            y: imgOriginY - cropOriginY,
            width: displayW,
            height: displayH
        )

        let sourceHasAlpha = ImageSubjectCutoutProcessor.imageHasTransparentPixels(source)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIGraphicsImageRendererFormat.default().scale
        format.opaque = !sourceHasAlpha
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropW, height: cropH), format: format)
        let cropped = renderer.image { _ in
            if !sourceHasAlpha {
                UIColor(Color.arkInk).setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: cropW, height: cropH))
            }
            source.draw(in: drawRect)
        }
        onCrop(cropped)
    }
}

private struct CardCropOverlay: View {
    let cropW: CGFloat
    let cropH: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                let x = (geo.size.width - cropW) / 2
                let y = (geo.size.height - cropH) / 2
                path.addRoundedRect(
                    in: CGRect(x: x, y: y, width: cropW, height: cropH),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
            }
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(Color.arkInk.opacity(0.62))
        }
    }
}

private struct CardCropCorners: View {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    private let len: CGFloat = 20
    private let thick: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(0 ..< 4, id: \.self) { index in
                let xSign: CGFloat = index < 2 ? -1 : 1
                let ySign: CGFloat = (index % 2 == 0) ? -1 : 1
                ZStack {
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goPrimary)
                        .frame(width: len, height: thick)
                        .offset(x: xSign * (width / 2 - len / 2), y: ySign * (height / 2))
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goPrimary)
                        .frame(width: thick, height: len)
                        .offset(x: xSign * (width / 2), y: ySign * (height / 2 - len / 2))
                }
            }
        }
    }
}
