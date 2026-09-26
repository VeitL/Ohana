//
//  PetImageCropView.swift
//  Ohana
//

import SwiftUI
import UIKit

struct PetImageCropView: View {
    let image: UIImage
    var species: String = "dog"
    var silhouetteSystemName: String?
    let onCrop: (UIImage?) -> Void

    private let cropMargin: CGFloat = 7
    private let reservedVerticalSpace: CGFloat = 170
    private let cornerRadius: CGFloat = 24
    private let maxScale: CGFloat = 6.0

    @Environment(\.colorScheme) private var colorScheme

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var fitDisplaySize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @GestureState private var gestureMagnification: CGFloat = 1
    @GestureState private var gestureTranslation: CGSize = .zero
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        GeometryReader { geo in
            let (cropW, cropH) = cropSize(for: geo.size)
            let displayedScale = resolvedScale(cropW: cropW, cropH: cropH)
            let displayedOffset = resolvedOffset(scale: displayedScale, cropW: cropW, cropH: cropH)
            ZStack {
                Color.arkInk

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(displayedScale, anchor: .center)
                    .offset(displayedOffset)
                    .allowsHitTesting(false)

                CardCropOverlay(cropW: cropW, cropH: cropH, cornerRadius: cornerRadius)
                    .allowsHitTesting(false)

                cropGuide(cropW: cropW, cropH: cropH)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goPrimary, lineWidth: 2)
                    .frame(width: cropW, height: cropH)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Label(l.tr(zh: "头像取景", en: "Avatar crop", de: "Avatar zuschneiden"), systemImage: "crop")
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
            .contentShape(Rectangle())
            .clipped()
            .highPriorityGesture(cropGesture(cropW: cropW, cropH: cropH))
            .onAppear {
                configureImageFit(container: geo.size, cropW: cropW, cropH: cropH, resetsTransform: true)
            }
            .onChange(of: geo.size) { _, newValue in
                let newCropSize = cropSize(for: newValue)
                configureImageFit(
                    container: newValue,
                    cropW: newCropSize.w,
                    cropH: newCropSize.h,
                    resetsTransform: false
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            cropActions
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(edges: .top)
    }

    private func cropSize(for container: CGSize) -> (w: CGFloat, h: CGFloat) {
        let size = MemberAvatarImageProcessor.portraitCropSize(
            in: container,
            horizontalMargin: cropMargin,
            reservedVerticalSpace: reservedVerticalSpace
        )
        return (size.width, size.height)
    }

    private func minScale(cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 0.3 }
        let fw = cropW / fitDisplaySize.width
        let fh = cropH / fitDisplaySize.height
        return max(fw, fh)
    }

    private func cropGuide(cropW: CGFloat, cropH: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(4, cornerRadius - 4), style: .continuous)
                .fill(Color.goCardWhite.opacity(colorScheme == .dark ? 0.1 : 0.07))
            Image(systemName: silhouetteSystemName ?? Pet.speciesSilhouetteSymbol(forSpecies: species))
                .font(.system(size: min(cropW * 0.38, 128), weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goCardWhite.opacity(colorScheme == .dark ? 0.32 : 0.22))
        }
        .frame(width: cropW, height: cropH)
    }

    private func cropGesture(cropW: CGFloat, cropH: CGFloat) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .updating($gestureMagnification) { value, state, _ in
                    state = value.magnification
                },
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .updating($gestureTranslation) { value, state, _ in
                    state = value.translation
                }
        )
        .onEnded { value in
            let magnification = value.first?.magnification ?? 1
            let translation = value.second?.translation ?? .zero
            let committedScale = MemberAvatarImageProcessor.clampedCropScale(
                scale * magnification,
                minimum: minScale(cropW: cropW, cropH: cropH),
                maximum: maxScale
            )
            let proposedOffset = CGSize(
                width: offset.width + translation.width,
                height: offset.height + translation.height
            )
            scale = committedScale
            offset = clampedOffset(
                proposedOffset,
                scale: committedScale,
                cropW: cropW,
                cropH: cropH
            )
        }
    }

    private func resolvedScale(cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        MemberAvatarImageProcessor.clampedCropScale(
            scale * gestureMagnification,
            minimum: minScale(cropW: cropW, cropH: cropH),
            maximum: maxScale
        )
    }

    private func resolvedOffset(scale: CGFloat, cropW: CGFloat, cropH: CGFloat) -> CGSize {
        clampedOffset(
            CGSize(
                width: offset.width + gestureTranslation.width,
                height: offset.height + gestureTranslation.height
            ),
            scale: scale,
            cropW: cropW,
            cropH: cropH
        )
    }

    private func clampedOffset(
        _ proposed: CGSize,
        scale: CGFloat,
        cropW: CGFloat,
        cropH: CGFloat
    ) -> CGSize {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return .zero }
        return MemberAvatarImageProcessor.clampedCropOffset(
            proposed,
            displayedImageSize: CGSize(
                width: fitDisplaySize.width * scale,
                height: fitDisplaySize.height * scale
            ),
            cropSize: CGSize(width: cropW, height: cropH)
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
                    .foregroundStyle(Color.ohanaPrimaryActionText)
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

    private func configureImageFit(
        container: CGSize,
        cropW: CGFloat,
        cropH: CGFloat,
        resetsTransform: Bool
    ) {
        containerSize = container
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let aspectFit = min(container.width / imageSize.width, container.height / imageSize.height)
        fitDisplaySize = CGSize(width: imageSize.width * aspectFit, height: imageSize.height * aspectFit)
        let minimum = minScale(cropW: cropW, cropH: cropH)
        if resetsTransform || scale <= 0 {
            scale = minimum
            offset = .zero
            return
        }

        scale = MemberAvatarImageProcessor.clampedCropScale(
            scale,
            minimum: minimum,
            maximum: maxScale
        )
        offset = clampedOffset(offset, scale: scale, cropW: cropW, cropH: cropH)
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
