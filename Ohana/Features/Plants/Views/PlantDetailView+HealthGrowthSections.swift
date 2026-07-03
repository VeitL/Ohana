//
//  PlantDetailView+HealthGrowthSections.swift
//  Ohana
//
//  Health review and growth diary cards for Plant detail.
//

import SwiftUI

extension PlantDetailContentView {
    var healthReviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.path.ecg") // a11y: allow decorative health-review glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive health-review glyph; text carries the content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "健康观察", en: "Health review", de: "Gesundheitscheck"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(healthReviewSummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                healthReviewMetric(
                    icon: "waveform.path.ecg.rectangle.fill",
                    title: l.tr(zh: "状态", en: "Status", de: "Status"),
                    value: plant.healthStatus.displayName,
                    tint: healthTone
                )
                healthReviewMetric(
                    icon: "tray.full.fill",
                    title: l.tr(zh: "30天观察", en: "30d notes", de: "30T Notizen"),
                    value: "\(recentObservationLogCount)",
                    tint: recentStressSignalLogs.isEmpty ? Color.goTeal : Color.goYellow
                )
                healthReviewMetric(
                    icon: "clock.badge.checkmark.fill",
                    title: l.tr(zh: "最近复查", en: "Latest", de: "Zuletzt"),
                    value: latestHealthReviewText,
                    tint: latestHealthReviewLog == nil ? Color.goYellow : Color.goLime
                )
            }

            VStack(spacing: 8) {
                ForEach(healthReviewSignals.prefix(4)) { signal in
                    healthReviewSignalRow(signal)
                }
            }

            HStack(spacing: 10) {
                Button {
                    openCareLogSheet(.pestCheck)
                } label: {
                    Text(PlantCareType.pestCheck.displayName(l: l))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录一次病虫害复查", en: "Log a pest check for \(plant.name)", de: "Schädlingscheck für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-health-review-pest-check")

                Button {
                    openCareLogSheet(.yellowLeaf)
                } label: {
                    Text(PlantCareType.yellowLeaf.displayName(l: l))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录黄叶观察", en: "Log a yellow-leaf note for \(plant.name)", de: "Gelbblattnotiz für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-health-review-yellow-leaf")

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-health-review")
        .padding(.horizontal, 16)
    }

    func healthReviewMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative health metric glyph; metric text carries value.
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    func healthReviewSignalRow(_ signal: PlantHealthReviewSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: signal.icon) // a11y: allow decorative health signal glyph; row text carries signal details.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(signal.tint)
                .frame(width: 34, height: 34) // a11y: allow non-interactive signal glyph; row label carries the content.
                .background(signal.tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(signal.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signal.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-health-review-signal-\(signal.id)")
    }

    var growthDiaryCard: some View {
        let photos = galleryPhotoItems

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass") // a11y: allow decorative diary glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive diary glyph; text carries the content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "成长档案", en: "Growth diary", de: "Wachstumstagebuch"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(growthDiarySummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                diaryStatPill(
                    icon: "tray.full.fill",
                    title: l.tr(zh: "记录", en: "Logs", de: "Protokolle"),
                    value: "\(recentLogs.count)",
                    tint: Color.goLime
                )
                diaryStatPill(
                    icon: "photo.on.rectangle.angled",
                    title: l.tr(zh: "照片", en: "Photos", de: "Fotos"),
                    value: "\(growthDiaryPhotoCount)",
                    tint: Color.goTeal
                )
                diaryStatPill(
                    icon: "calendar",
                    title: l.tr(zh: "跨度", en: "Range", de: "Zeitraum"),
                    value: growthDiaryDateRangeText,
                    tint: Color.goYellow
                )
            }

            if photos.isEmpty {
                emptyPhotoGalleryHint
            } else {
                photoGalleryPreviewStrip(photos)
            }

            HStack(spacing: 10) {
                ShareLink(item: growthDiaryMarkdown) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up") // a11y: allow decorative share glyph; button label names export action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "导出 Markdown", en: "Export Markdown", de: "Markdown exportieren"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color.goLime, in: Capsule())
                }
                .accessibilityLabel(l.tr(zh: "导出\(plant.name)成长档案", en: "Export \(plant.name)'s growth diary", de: "Wachstumstagebuch von \(plant.name) exportieren"))
                .accessibilityIdentifier("plant-detail-growth-diary-export")

                if !photos.isEmpty {
                    Button {
                        showingPhotoGallery = true
                    } label: {
                        Text(l.tr(zh: "查看照片", en: "View photos", de: "Fotos ansehen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "查看\(plant.name)的植物照片", en: "View \(plant.name)'s plant photos", de: "Pflanzenfotos von \(plant.name) ansehen"))
                    .accessibilityIdentifier("plant-detail-photo-gallery-open")
                }

                Button {
                    openCareLogSheet(.newLeaf)
                } label: {
                    Text(l.tr(zh: "记录观察", en: "Log observation", de: "Beobachtung erfassen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录一次成长观察", en: "Log a growth observation for \(plant.name)", de: "Wachstumsbeobachtung für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-growth-diary-log-observation")

                Button {
                    openCareLogSheet(.photo)
                } label: {
                    Text(l.tr(zh: "添加照片", en: "Add photo", de: "Foto hinzufügen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)添加成长照片", en: "Add a growth photo for \(plant.name)", de: "Wachstumsfoto für \(plant.name) hinzufügen"))
                .accessibilityIdentifier("plant-detail-growth-diary-add-photo")

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-growth-diary")
        .padding(.horizontal, 16)
    }

    var emptyPhotoGalleryHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled") // a11y: allow decorative photo hint glyph; text explains the empty gallery.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "还没有照片线索", en: "No photo notes yet", de: "Noch keine Foto-Hinweise"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "带照片的档案图或护理记录会自动进入这里，方便回看叶片变化。",
                    en: "Profile photos and care logs with images appear here for leaf-change review.",
                    de: "Profilfotos und Pflegeprotokolle mit Bildern erscheinen hier zur Blattkontrolle."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-photo-gallery-empty")
    }

    func photoGalleryPreviewStrip(_ photos: [PlantDetailPhotoItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos.prefix(5)) { photo in
                    Button {
                        showingPhotoGallery = true
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            PlantDetailDecodedImageTile(
                                imageData: photo.imageData,
                                tint: photo.tint,
                                fillsContainer: true
                            )
                            .frame(width: 118, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                            Text(photo.title)
                                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(photo.subtitle)
                                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 118, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("\(photo.title), \(photo.subtitle)")
                    .accessibilityIdentifier("plant-detail-photo-preview-\(photo.id)")
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-photo-gallery-preview")
    }

    func diaryStatPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative stat glyph; pill text carries value.
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
