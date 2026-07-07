//
//  PlantDashboardView+DiscoverySections.swift
//  Ohana
//
//  Extracted Plant dashboard discovery sections.
//

import SwiftUI

nonisolated enum PlantDashboardWalletSectionPolicy {
    static let sectionSpacing: CGFloat = 18

    static func sectionCount(cardCount: Int) -> Int {
        cardCount > 0 ? 1 : 0
    }

    static func sectionHeight(cardCount: Int) -> CGFloat {
        guard cardCount > 0 else { return 0 }
        let legacyHeight = cardCount <= 1 ? CGFloat(420) : min(620, max(500, CGFloat(cardCount) * 86 + 310))
        return max(
            legacyHeight,
            FocusHomeVerticalSolidCollapsedLayoutPolicy.scrollExtendedMinimumSceneHeight(cardCount: cardCount)
        )
    }
}

struct PlantDashboardWalletCardSection: Identifiable {
    let ordinal: Int
    let cards: [FocusCard]

    var id: String {
        "\(ordinal)-\(cards.map(\.id.uuidString).joined(separator: "|"))"
    }

    func contains(cardID: UUID?) -> Bool {
        guard let cardID else { return false }
        return cards.contains { $0.id == cardID }
    }
}

extension PlantDashboardView {
    var photosDashboardSection: some View {
        let items = photoDashboardItems

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "照片", en: "Photos", de: "Fotos"))
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "按最近档案照片和照护照片回看植物状态",
                        en: "Review profile and care photos across your plants",
                        de: "Profil- und Pflegefotos deiner Pflanzen prüfen"
                    ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("\(items.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 30)
                    .background(Color.goPrimary, in: Capsule())
            }

            photoJournalSummaryCard(items)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(items) { item in
                    photoDashboardCard(item)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-photos-view")
    }

    func photoJournalSummaryCard(_ items: [PlantDashboardPhotoItem]) -> some View {
        let realPhotoItems = items.filter(\.hasRealPhoto)
        let plantsWithPhotos = Set(realPhotoItems.map(\.plant.id)).count
        let missingPhotoPlants = plants.filter { !plantHasPreviewImage($0) }
        let latestPhoto = realPhotoItems.first

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "photo.stack.fill") // a11y: allow decorative photo journal glyph; heading names the summary.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive summary glyph; text carries content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "成长照片档案", en: "Growth photo journal", de: "Wachstumsfoto-Archiv"))
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(photoJournalSummaryText(realPhotoCount: realPhotoItems.count, missingCount: missingPhotoPlants.count))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                photoJournalMetric(
                    id: "real",
                    icon: "photo.fill",
                    title: l.tr(zh: "真实照片", en: "Real photos", de: "Echte Fotos"),
                    value: "\(realPhotoItems.count)",
                    tint: realPhotoItems.isEmpty ? Color.goYellow : Color.goTeal
                )
                photoJournalMetric(
                    id: "covered",
                    icon: "leaf.circle.fill",
                    title: l.tr(zh: "已覆盖", en: "Covered", de: "Erfasst"),
                    value: "\(plantsWithPhotos)/\(plants.count)",
                    tint: plantsWithPhotos == plants.count ? Color.goPrimary : Color.goYellow
                )
                photoJournalMetric(
                    id: "missing",
                    icon: "camera.badge.ellipsis",
                    title: l.tr(zh: "待补", en: "Missing", de: "Fehlt"),
                    value: "\(missingPhotoPlants.count)",
                    tint: missingPhotoPlants.isEmpty ? Color.goPrimary : Color.goYellow
                )
            }

            if let firstMissing = missingPhotoPlants.first {
                Button {
                    openCareLogSheet(for: firstMissing, type: .photo)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill") // a11y: allow decorative add-photo glyph; button text names the action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "给 \(firstMissing.name) 补照片", en: "Add photo for \(firstMissing.name)", de: "Foto für \(firstMissing.name) ergänzen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-photo-log-missing")
            } else if let latestPhoto {
                Button {
                    selectedDashboardPhoto = latestPhoto
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath") // a11y: allow decorative latest-photo glyph; button text names the action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "查看最近照片", en: "Review latest photo", de: "Neuestes Foto ansehen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-photo-open-latest")
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-photo-journal-summary")
    }

    func photoJournalMetric(
        id: String,
        icon: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 68)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-photo-metric-\(id)")
    }

    func photoJournalSummaryText(realPhotoCount: Int, missingCount: Int) -> String {
        if realPhotoCount == 0 {
            return l.tr(
                zh: "还没有真实照片，先为植物补一张档案照或护理照片。",
                en: "No real photos yet. Start with a profile or care photo.",
                de: "Noch keine echten Fotos. Beginne mit Profil- oder Pflegefoto."
            )
        }
        if missingCount > 0 {
            return l.tr(
                zh: "\(realPhotoCount) 张照片已沉淀，仍有 \(missingCount) 株植物缺少照片。",
                en: "\(realPhotoCount) photos saved; \(missingCount) plants still need photos.",
                de: "\(realPhotoCount) Fotos gespeichert; \(missingCount) Pflanzen brauchen noch Fotos."
            )
        }
        return l.tr(
            zh: "\(realPhotoCount) 张照片覆盖全部植物，可用于回看成长变化。",
            en: "\(realPhotoCount) photos cover every plant for growth review.",
            de: "\(realPhotoCount) Fotos decken alle Pflanzen für den Wachstumsrückblick ab."
        )
    }

    func photoDashboardCard(_ item: PlantDashboardPhotoItem) -> some View {
        Button {
            selectedDashboardPhoto = item
        } label: {
            ZStack(alignment: .bottomLeading) {
                PlantDashboardPhotoTile(
                    imageID: item.id,
                    imageSignature: item.mediaSignature,
                    imageDataProvider: { await photoImageData(for: item) },
                    fallbackEmoji: item.fallbackEmoji,
                    tint: item.tint
                )
                .frame(maxWidth: .infinity)
                .frame(height: 168)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.subtitle)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface.opacity(0.86))
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(photoDashboardAccessibilityLabel(item))
        .accessibilityIdentifier("plant-dashboard-photo-card-\(item.id)")
    }

    func siteCard(_ summary: PlantDashboardRoomSummary) -> some View {
        Button {
            selectedSiteSummary = summary
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                siteImageMosaic(for: summary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.title)
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    siteTaskBadge(summary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(siteCardAccessibilityLabel(summary))
        .accessibilityIdentifier("plant-dashboard-site-card-\(roomZoneIdentifier(summary.id))")
    }

    @ViewBuilder
    func siteImageMosaic(for summary: PlantDashboardRoomSummary) -> some View {
        let previewPlants = Array(summary.plants.prefix(4))
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
        if previewPlants.isEmpty {
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .fill(Color.ohanaControlFill.opacity(0.7))
                .frame(height: 172)
                .accessibilityHidden(true)
        } else {
            HStack(spacing: 3) {
                plantPreviewTile(for: previewPlants[0])
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if previewPlants.count > 1 {
                    VStack(spacing: 3) {
                        plantPreviewTile(for: previewPlants[1])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if previewPlants.count > 2 {
                            plantPreviewTile(for: previewPlants[2])
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if previewPlants.count > 3 {
                    plantPreviewTile(for: previewPlants[3])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 172)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
            }
            .accessibilityHidden(true)
        }
    }

    func siteTaskBadge(_ summary: PlantDashboardRoomSummary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: summary.dueTaskCount == 0 ? "checkmark.circle.fill" : "calendar.badge.clock")
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .accessibilityHidden(true)
            Text(summary.dueTaskCount == 0
                ? l.tr(zh: "无任务", en: "clear", de: "frei")
                : l.tr(zh: "\(summary.dueTaskCount) 任务", en: "\(summary.dueTaskCount) tasks", de: "\(summary.dueTaskCount) Aufgaben"))
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(summary.dueTaskCount == 0 ? Color.goTeal : Color.goRed)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
    }

    var plantListSection: some View {
        let displayedPlants = currentPlantViewPlants
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedPlantsViewStyle == .list
                    ? l.tr(zh: "植物列表", en: "Plant list", de: "Pflanzenliste")
                    : l.tr(zh: "植物", en: "Plants", de: "Pflanzen"))
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(isNarrowingPlants ? "\(displayedPlants.count)/\(plants.count)" : "\(displayedPlants.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if displayedPlants.isEmpty {
                plantSearchEmptyState
            } else {
                if selectedPlantsViewStyle == .deck {
                    plantWalletDeck
                    addPlantListButton
                } else {
                    plantRoomListView
                }
            }
        }
    }

    var plantWalletCards: [FocusCard] {
        visiblePlants.map { plant in
            FocusCard.fromPlant(
                plant,
                catalog: PlantCatalog.entry(id: plant.catalogSpeciesId),
                nextTask: appServices.plantCarePlans.nextTask(for: plant),
                localization: l
            )
        }
    }

    var profileReadinessSection: some View {
        let items = Array(profileReadinessItems.prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist.checked") // a11y: allow decorative section glyph; heading names the checklist.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28, height: 28) // a11y: allow non-interactive section glyph; heading names the checklist.
                    .background(Color.goPrimary.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "档案待办", en: "Profile queue", de: "Profil-Queue"))
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "像成员档案一样补齐关键信息，让护理计划更可靠。",
                        en: "Complete key facts like a household profile so care plans stay reliable.",
                        de: "Ergänze Kerndaten wie bei Haushaltsprofilen, damit Pflegepläne verlässlich bleiben."
                    ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("\(profileReadinessItems.count)")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Color.goPrimary, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    profileReadinessRow(item)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-profile-readiness")
    }

    func profileReadinessRow(_ item: PlantDashboardReadinessItem) -> some View {
        Button {
            onOpenPlant(item.plant.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon) // a11y: allow decorative row glyph; row text describes the action.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(item.tint)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive row glyph; the whole row button has a full label.
                    .background(item.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.plant.name)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative row navigation glyph; the row button has a full plant label.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.ohanaControlFill.opacity(0.56), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(profileReadinessAccessibilityLabel(item))
        .accessibilityIdentifier("plant-dashboard-profile-readiness-row-\(item.id)")
    }

    var addPlantListButton: some View {
        Button {
            showingAddPlant = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus") // a11y: allow decorative add glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
                Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }
            .padding(10)
            .background(Color.ohanaCardSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-dashboard-list-add-action")
    }

    var roomCareMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "house.and.flag.fill") // a11y: allow decorative section glyph; heading names the room map.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "家中植物分区", en: "Home plant zones", de: "Pflanzenzonen zuhause"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(roomCareMapSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    allRoomZoneButton

                    ForEach(roomCareSummaries.prefix(6)) { summary in
                        roomZoneButton(summary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-map")
    }

    var roomCareMapSubtitle: String {
        if let selectedLocation {
            return l.tr(
                zh: "正在查看 \(selectedLocation) 的植物和到期照护",
                en: "Viewing plants and due care in \(selectedLocation)",
                de: "Pflanzen und fällige Pflege in \(selectedLocation)"
            )
        }
        if !dueTasks.isEmpty {
            return l.tr(
                zh: "按房间先处理到期和需观察的植物",
                en: "Work through due care and watch items room by room",
                de: "Fällige Pflege und Beobachtung Raum für Raum erledigen"
            )
        }
        return l.tr(
            zh: "按摆放位置快速查看每个空间的植物状态",
            en: "Scan each room by where plants live",
            de: "Jeden Raum nach Pflanzenstandort prüfen"
        )
    }

    var allRoomZoneButton: some View {
        let isSelected = selectedLocation == nil
        return Button {
            selectedLocation = nil
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "square.grid.2x2.fill")
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.goTeal)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Text("\(plants.count)")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                roomZoneTitle(l.tr(zh: "全部区域", en: "All zones", de: "Alle Zonen"), isSelected: isSelected)

                if watchedPlantsCount > 0 {
                    roomZoneStatusStack(
                        primary: roomZoneStatusChip(
                            icon: "calendar.badge.clock",
                            text: dueTasks.isEmpty
                                ? l.tr(zh: "无到期", en: "clear", de: "frei")
                                : l.tr(zh: "\(dueTasks.count) 到期", en: "\(dueTasks.count) due", de: "\(dueTasks.count) fällig"),
                            tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow,
                            isSelected: isSelected
                        ),
                        secondary: roomZoneStatusChip(
                            icon: "eye.fill",
                            text: "\(watchedPlantsCount)",
                            tint: Color.goYellow,
                            isSelected: isSelected
                        )
                    )
                } else {
                    roomZoneStatusStack(primary: roomZoneStatusChip(
                        icon: "calendar.badge.clock",
                        text: dueTasks.isEmpty
                            ? l.tr(zh: "无到期", en: "clear", de: "frei")
                            : l.tr(zh: "\(dueTasks.count) 到期", en: "\(dueTasks.count) due", de: "\(dueTasks.count) fällig"),
                        tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow,
                        isSelected: isSelected
                    ))
                }
            }
            .roomZoneCardFrame()
            .padding(12)
            .background(
                isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.6),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(allRoomZoneAccessibilityLabel(isSelected: isSelected))
        .accessibilityIdentifier("plant-dashboard-room-zone-all")
    }

    func roomZoneButton(_ summary: PlantDashboardRoomSummary) -> some View {
        let isSelected = selectedLocation == summary.id
        return Button {
            selectedLocation = isSelected ? nil : summary.id
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "house.fill")
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.goTeal)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Text("\(summary.plantCount)")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                roomZoneTitle(summary.title, isSelected: isSelected)

                if summary.watchCount > 0 {
                    roomZoneStatusStack(
                        primary: roomZoneStatusChip(
                            icon: "calendar.badge.clock",
                            text: summary.dueTaskCount == 0
                                ? l.tr(zh: "无到期", en: "clear", de: "frei")
                                : l.tr(zh: "\(summary.dueTaskCount) 到期", en: "\(summary.dueTaskCount) due", de: "\(summary.dueTaskCount) fällig"),
                            tint: summary.dueTaskCount == 0 ? Color.goTeal : Color.goYellow,
                            isSelected: isSelected
                        ),
                        secondary: roomZoneStatusChip(
                            icon: "eye.fill",
                            text: "\(summary.watchCount)",
                            tint: Color.goYellow,
                            isSelected: isSelected
                        )
                    )
                } else {
                    roomZoneStatusStack(primary: roomZoneStatusChip(
                        icon: "calendar.badge.clock",
                        text: summary.dueTaskCount == 0
                            ? l.tr(zh: "无到期", en: "clear", de: "frei")
                            : l.tr(zh: "\(summary.dueTaskCount) 到期", en: "\(summary.dueTaskCount) due", de: "\(summary.dueTaskCount) fällig"),
                        tint: summary.dueTaskCount == 0 ? Color.goTeal : Color.goYellow,
                        isSelected: isSelected
                    ))
                }
            }
            .roomZoneCardFrame()
            .padding(12)
            .background(
                isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.6),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(roomZoneAccessibilityLabel(summary, isSelected: isSelected))
        .accessibilityIdentifier("plant-dashboard-room-zone-\(roomZoneIdentifier(summary.id))")
    }

    func roomZoneTitle(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    func roomZoneStatusStack(primary: some View) -> some View {
        primary
    }

    func roomZoneStatusStack(primary: some View, secondary: some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                primary
                secondary
            }
            VStack(alignment: .leading, spacing: 5) {
                primary
                secondary
            }
        }
    }

    func roomZoneStatusChip(
        icon: String,
        text: String,
        tint: Color,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(isSelected ? Color.arkInk : tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            isSelected ? Color.arkInk.opacity(0.09) : Color.ohanaCardSurface.opacity(0.78),
            in: Capsule()
        )
    }

    func allRoomZoneAccessibilityLabel(isSelected: Bool) -> String {
        [
            l.tr(zh: "全部区域", en: "All zones", de: "Alle Zonen"),
            l.tr(zh: "\(plants.count) 株植物", en: "\(plants.count) plants", de: "\(plants.count) Pflanzen"),
            l.tr(zh: "\(dueTasks.count) 项到期", en: "\(dueTasks.count) due tasks", de: "\(dueTasks.count) fällige Aufgaben"),
            l.tr(zh: "\(watchedPlantsCount) 株需观察", en: "\(watchedPlantsCount) watch items", de: "\(watchedPlantsCount) Beobachtungen"),
            isSelected
                ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
                : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        ].joined(separator: ", ")
    }

    func roomZoneAccessibilityLabel(
        _ summary: PlantDashboardRoomSummary,
        isSelected: Bool
    ) -> String {
        [
            summary.title,
            l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"),
            l.tr(zh: "\(summary.dueTaskCount) 项到期", en: "\(summary.dueTaskCount) due tasks", de: "\(summary.dueTaskCount) fällige Aufgaben"),
            l.tr(zh: "\(summary.watchCount) 株需观察", en: "\(summary.watchCount) watch items", de: "\(summary.watchCount) Beobachtungen"),
            isSelected
                ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
                : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        ].joined(separator: ", ")
    }

    func roomZoneIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "unknown"
            : value
    }

    func siteCardAccessibilityLabel(_ summary: PlantDashboardRoomSummary) -> String {
        [
            summary.title,
            l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"),
            l.tr(zh: "\(summary.dueTaskCount) 项任务", en: "\(summary.dueTaskCount) tasks", de: "\(summary.dueTaskCount) Aufgaben"),
            l.tr(zh: "\(summary.watchCount) 株需观察", en: "\(summary.watchCount) watch items", de: "\(summary.watchCount) Beobachtungen"),
            l.tr(zh: "打开位置详情", en: "Open site detail", de: "Standortdetails öffnen")
        ].joined(separator: ", ")
    }

    func careTasks(for summary: PlantDashboardRoomSummary) -> [PlantCareTaskSnapshot] {
        let plantIDs = Set(summary.plants.map(\.id))
        return careWindowTasks.filter { plantIDs.contains($0.plantID) }
    }

    func photoDashboardAccessibilityLabel(_ item: PlantDashboardPhotoItem) -> String {
        [
            item.title,
            item.subtitle,
            locationSummary(for: item.plant)
        ].joined(separator: ", ")
    }
}

private extension View {
    func roomZoneCardFrame() -> some View {
        frame(minWidth: 150, idealWidth: 164, maxWidth: 190, alignment: .topLeading)
            .frame(minHeight: 114, alignment: .topLeading)
    }
}
