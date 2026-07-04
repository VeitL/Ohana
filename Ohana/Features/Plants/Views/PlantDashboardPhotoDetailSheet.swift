//
//  PlantDashboardPhotoDetailSheet.swift
//  Ohana
//
//  Photo preview sheet for the Plants dashboard Photos tab.
//

import SwiftUI
import UIKit

struct PlantDashboardPhotoDetailSheet: View {
    let item: PlantDashboardPhotoItem
    let imageDataProvider: @Sendable (PlantDashboardPhotoItem) async -> Data?
    let onOpenPlant: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaSheetWrapper(
            title: item.title,
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                photoPreview
                contextCard
                openPlantButton
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-dashboard-photo-detail-sheet")
    }

    private var photoPreview: some View {
        PlantDashboardPhotoPreviewTile(
            imageID: item.id,
            imageSignature: item.mediaSignature,
            imageDataProvider: { await imageDataProvider(item) },
            tint: item.tint
        )
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel(photoAccessibilityLabel)
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: item.hasRealPhoto ? "photo.fill" : "camera.badge.ellipsis") // a11y: allow decorative photo context glyph; text names the state.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(item.hasRealPhoto ? Color.goTeal : Color.goYellow)
                    .frame(width: 28, height: 28) // a11y: allow non-interactive context glyph; adjacent text names the photo state.
                    .background((item.hasRealPhoto ? Color.goTeal : Color.goYellow).opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.plant.name)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.subtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }

            Text(detailText)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-photo-detail-context")
    }

    private var openPlantButton: some View {
        Button {
            onOpenPlant(item.plant.id)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill") // a11y: allow decorative navigation glyph; button text names destination.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "打开植物详情", en: "Open plant detail", de: "Pflanzendetails öffnen"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-dashboard-photo-detail-open-plant")
    }

    private var detailText: String {
        if !item.hasRealPhoto {
            return l.tr(
                zh: "这株植物还没有真实照片。打开详情后可补档案照或记录带照片的护理。",
                en: "This plant does not have a real photo yet. Open detail to add a profile image or photo care log.",
                de: "Diese Pflanze hat noch kein echtes Foto. Öffne Details, um Profilbild oder Fotopflege zu ergänzen."
            )
        }
        return l.tr(
            zh: "这张照片来自植物档案或带照片的护理记录，可作为成长状态回看。",
            en: "This photo comes from the profile or a photo care log and helps review growth state.",
            de: "Dieses Foto stammt aus Profil oder Pflegeprotokoll und hilft beim Wachstumsrückblick."
        )
    }

    private var photoAccessibilityLabel: String {
        [
            item.title,
            item.subtitle,
            item.hasRealPhoto
                ? l.tr(zh: "植物照片", en: "Plant photo", de: "Pflanzenfoto")
                : l.tr(zh: "没有真实照片", en: "No real photo", de: "Kein echtes Foto")
        ].joined(separator: ", ")
    }
}

private struct PlantDashboardPhotoPreviewTile: View {
    let imageID: String
    let imageSignature: String
    let imageDataProvider: @Sendable () async -> Data?
    let tint: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(tint.opacity(0.18))

            PlantDetailDecodedImageTile(
                imageID: imageID,
                imageSignature: imageSignature,
                imageDataProvider: { await imageDataProvider() },
                tint: tint,
                fillsContainer: false,
                maxPixel: 900
            )
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
