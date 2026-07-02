//
//  PlantDetailPhotoGallerySheet.swift
//  Ohana
//
//  Photo gallery for the plant detail growth diary.
//

import SwiftUI
import UIKit

struct PlantPhotoGallerySheet: View {
    let plantName: String
    let photos: [PlantDetailPhotoItem]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @State private var selectedPhoto: PlantDetailPhotoItem?

    private var l: L10n { L10n(appLanguage) }
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "\(plantName)的照片", en: "\(plantName)'s photos", de: "Fotos von \(plantName)"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                galleryHeader

                if photos.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(photos) { photo in
                            galleryCard(photo)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-detail-photo-gallery-sheet")
        .sheet(item: $selectedPhoto) { photo in
            PlantPhotoDetailSheet(
                plantName: plantName,
                photo: photo
            )
        }
    }

    private var galleryHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.stack.fill") // a11y: allow decorative gallery glyph; heading and count name the content.
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "成长照片", en: "Growth photos", de: "Wachstumsfotos"))
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "集中查看档案照和带照片的护理记录。",
                    en: "Review profile images and care logs with photos in one place.",
                    de: "Profilbilder und Pflegeprotokolle mit Fotos an einem Ort ansehen."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text("\(photos.count)")
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 11)
                .frame(minHeight: 30)
                .background(Color.goLime, in: Capsule())
                .accessibilityLabel(l.tr(zh: "\(photos.count) 张照片", en: "\(photos.count) photos", de: "\(photos.count) Fotos"))
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "camera.metering.unknown") // a11y: allow decorative empty-state glyph; text explains the state.
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "还没有植物照片", en: "No plant photos yet", de: "Noch keine Pflanzenfotos"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "当档案照或带照片的护理记录出现后，这里会自动组成成长图库。",
                    en: "Profile images and photo care logs will automatically form a growth gallery here.",
                    de: "Profilbilder und Pflegeprotokolle mit Fotos bilden hier automatisch eine Wachstumsgalerie."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill.opacity(0.52), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func galleryCard(_ photo: PlantDetailPhotoItem) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                PlantDetailDecodedImageTile(
                    imageData: photo.imageData,
                    tint: photo.tint,
                    fillsContainer: true
                )
                .frame(height: 146)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(photo.title)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(photo.subtitle)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(photo.title), \(photo.subtitle), \(photo.detail)")
        .accessibilityIdentifier("plant-detail-photo-gallery-card-\(photo.id)")
    }
}

private struct PlantPhotoDetailSheet: View {
    let plantName: String
    let photo: PlantDetailPhotoItem

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaSheetWrapper(
            title: photo.title,
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PlantDetailDecodedImageTile(
                    imageData: photo.imageData,
                    tint: photo.tint,
                    fillsContainer: false
                )
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(plantName)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(photo.subtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(photo.detail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                Button {
                    dismiss()
                } label: {
                    Text(l.tr(zh: "完成", en: "Done", de: "Fertig"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-detail-photo-detail-done")
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-detail-photo-detail-sheet")
    }
}

struct PlantDetailDecodedImageTile: View {
    let imageData: Data
    let tint: Color
    let fillsContainer: Bool

    @State private var image: UIImage?

    private var imageSignature: String {
        "\(imageData.count)-\(imageData.first ?? 0)-\(imageData.last ?? 0)"
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(tint.opacity(0.18))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fillsContainer ? .fill : .fit)
            } else {
                Image(systemName: "leaf.fill") // a11y: allow decorative image fallback; parent labels describe the photo item.
                    .font(OhanaFont.adaptive(size: 28, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .clipped()
        .task(id: imageSignature) {
            image = await AttachmentImageDecoder.decode(imageData)
        }
        .accessibilityHidden(true)
    }
}
