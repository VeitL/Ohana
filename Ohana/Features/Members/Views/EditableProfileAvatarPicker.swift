//
//  EditableProfileAvatarPicker.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftUI
import UIKit

private enum AvatarImageEditingSupport {
    nonisolated static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    nonisolated static func optimizedAvatarAsset(_ image: UIImage, preserveAlpha: Bool, maxPixel: CGFloat = 900) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveAlpha
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct EditableProfileAvatarPicker: View {
    @Binding var avatarImageData: Data?
    let fallbackEmoji: String
    let accentColor: Color
    let cropSpecies: String
    let silhouetteSystemName: String?

    @State private var showingPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var pendingCapturedAvatarImage: UIImage? = nil
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var cropPresentationTask: Task<Void, Never>? = nil
    @State private var isPasting = false
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                avatarActionButton(icon: "doc.on.clipboard.fill", title: l.tr(zh: "粘贴", en: "Paste", de: "Einfuegen")) {
                    pastePasteboardImage()
                }

                Button {
                    presentPhotoLibrary()
                } label: {
                    avatarActionLabel(icon: "photo.on.rectangle.angled", title: l.tr(zh: "相册", en: "Photos", de: "Fotos"))
                }
                .buttonStyle(ScaleButtonStyle())

                avatarActionButton(icon: "camera.fill", title: l.tr(zh: "拍照", en: "Camera", de: "Kamera")) {
                    presentCamera()
                }
            }

            if avatarImageData != nil {
                Button {
                    avatarImageData = nil
                } label: {
                    Text(l.tr(zh: "移除头像", en: "Remove avatar", de: "Avatar entfernen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .disabled(isPasting)
        .onChange(of: photosPickerItem) { _, item in
            handlePhotosPickerItemChanged(item)
        }
        .onChange(of: cropImageItem) { _, new in
            guard new == nil else { return }
            cropPresentationTask?.cancel()
            cropPresentationTask = nil
        }
        .onDisappear {
            cropPresentationTask?.cancel()
            cropPresentationTask = nil
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if let img = pendingCapturedAvatarImage {
                pendingCapturedAvatarImage = nil
                prepareCapturedAvatarForCrop(img)
            }
        }) {
            PetCameraPickerView(maxPixel: 1600) { img in
                AppPerformanceMonitor.shared.markStart("avatar.camera.to.crop")
                pendingCapturedAvatarImage = img
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
        .sheet(item: $cropImageItem) { item in
            NavigationStack {
                PetImageCropView(
                    image: item.image,
                    species: cropSpecies,
                    silhouetteSystemName: silhouetteSystemName
                ) { cropped in
                    if let cropped {
                        let hasAlpha = ImageSubjectCutoutProcessor.imageHasTransparentPixels(cropped)
                        let optimized = AvatarImageEditingSupport.optimizedAvatarAsset(cropped, preserveAlpha: hasAlpha)
                        avatarImageData = hasAlpha
                            ? optimized.pngData()
                            : optimized.jpegData(compressionQuality: 0.88)
                    }
                    cropImageItem = nil
                    photosPickerItem = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(l.cancel) {
                            cropImageItem = nil
                            photosPickerItem = nil
                        }
                    }
                }
            }
            .presentationDetents([.large]) // ui-v4: allow photo crop editor needs full-height system sheet
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfuegbar"), isPresented: $showCameraPermissionAlert) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "请在系统设置中允许 Ohana 访问相机。", en: "Allow Ohana to access the camera in system settings.", de: "Erlaube Ohana den Kamerazugriff in den Systemeinstellungen."))
        }
    }

    private func avatarActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            avatarActionLabel(icon: icon, title: title)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func avatarActionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .symbolRenderingMode(.monochrome)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accentColor, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
    }

    private func handlePhotosPickerItemChanged(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                    AddPetWizardView.cropReadyImage(from: data, maxPixel: 1600)
                }.value
                await MainActor.run {
                    photosPickerItem = nil
                    if let resized {
                        presentAvatarCropAfterMediaDismissal(resized, delayMilliseconds: 360) {
                            AppPerformanceMonitor.shared.record("相册到裁剪页", startedAt: startedAt, note: cropSpecies)
                        }
                    }
                }
            } else {
                await MainActor.run {
                    photosPickerItem = nil
                }
            }
        }
    }

    private func presentPhotoLibrary() {
        GoKeyboard.dismiss()
        cropPresentationTask?.cancel()
        showingPhotoPicker = true
    }

    private func presentCamera() {
        cropPresentationTask?.cancel()
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }

    private func pastePasteboardImage() {
        guard let img = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let startedAt = CFAbsoluteTimeGetCurrent()
        isPasting = true
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                AddPetWizardView.preparedCropImage(img, maxPixel: 1600)
            }.value
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.record("粘贴到裁剪页", startedAt: startedAt, note: cropSpecies)
            isPasting = false
        }
    }

    private func prepareCapturedAvatarForCrop(_ image: UIImage) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                AddPetWizardView.preparedCropImage(image, maxPixel: 1600)
            }.value
            await MainActor.run {
                presentAvatarCropAfterMediaDismissal(prepared, delayMilliseconds: 320) {
                    AppPerformanceMonitor.shared.markEnd("avatar.camera.to.crop", name: "拍照到裁剪页", note: cropSpecies)
                }
            }
        }
    }

    private func presentAvatarCropAfterMediaDismissal(
        _ image: UIImage,
        delayMilliseconds: UInt64,
        onPresented: @escaping @MainActor () -> Void
    ) {
        cropPresentationTask?.cancel()
        cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard !showingPhotoPicker, !showingCamera else {
                presentAvatarCropAfterMediaDismissal(image, delayMilliseconds: 140, onPresented: onPresented)
                return
            }
            cropImageItem = IdentifiableCropImage(image: image)
            cropPresentationTask = nil
            onPresented()
        }
    }
}
