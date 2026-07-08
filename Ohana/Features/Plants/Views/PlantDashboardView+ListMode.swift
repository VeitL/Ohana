//
//  PlantDashboardView+ListMode.swift
//  Ohana
//
//  Room-grouped list view for the Plants dashboard.
//

import SwiftData
import SwiftUI

extension PlantDashboardView {
    var currentPlantViewPlants: [Plant] {
        selectedPlantsViewStyle == .list ? plantListModePlants : visiblePlants
    }

    var plantRoomListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(plantListModeRoomSummaries) { summary in
                plantRoomListSection(summary)
            }

            addPlantListButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-list-view")
    }

    func plantRoomListSection(_ summary: PlantDashboardRoomSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            plantRoomListHeader(summary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(summary.plants) { plant in
                    plantRoomListCard(plant)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-list-section-\(roomZoneIdentifier(summary.id))")
    }

    func plantRoomListHeader(_ summary: PlantDashboardRoomSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                plantRoomListTitleBlock(summary)

                Spacer(minLength: 8)

                plantRoomListHeaderBadges(summary)
            }

            VStack(alignment: .leading, spacing: 8) {
                plantRoomListTitleBlock(summary)
                plantRoomListHeaderBadges(summary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(roomZoneAccessibilityLabel(summary, isSelected: false))
    }

    func plantRoomListTitleBlock(_ summary: PlantDashboardRoomSummary) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "house.fill") // a11y: allow decorative room glyph; heading text names the room.
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 28, height: 28) // a11y: allow non-interactive decorative room glyph; section heading carries the accessible label.
                .background(Color.goTeal.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l.tr(
                    zh: "\(summary.plantCount) 株植物",
                    en: "\(summary.plantCount) plants",
                    de: "\(summary.plantCount) Pflanzen"
                ))
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func plantRoomListHeaderBadges(_ summary: PlantDashboardRoomSummary) -> some View {
        HStack(alignment: .center, spacing: 6) {
            plantRoomListHeaderBadge(
                icon: "calendar.badge.clock",
                text: summary.dueTaskCount == 0
                    ? l.tr(zh: "无待办", en: "Clear", de: "Frei")
                    : l.tr(zh: "\(summary.dueTaskCount) 待办", en: "\(summary.dueTaskCount) due", de: "\(summary.dueTaskCount) fällig"),
                tint: summary.dueTaskCount == 0 ? Color.goTeal : Color.goYellow
            )

            if summary.watchCount > 0 {
                plantRoomListHeaderBadge(
                    icon: "eye.fill",
                    text: "\(summary.watchCount)",
                    tint: Color.goYellow
                )
            }
        }
    }

    func plantRoomListHeaderBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(Color.ohanaControlFill.opacity(0.64), in: Capsule())
    }

    func plantRoomListCard(_ plant: Plant) -> some View {
        let catalog = PlantCatalog.entry(id: plant.catalogSpeciesId)
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        let difficulty = plantRoomListDifficultySignal(for: plant, catalog: catalog)
        let attention = plantRoomListAttentionSignal(for: plant, catalog: catalog)
        let todo = plantRoomListTodoSignal(for: plant, nextTask: nextTask)
        let plantModelID = plant.persistentModelID

        return Button {
            onOpenPlant(plant.id)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                PlantDashboardPhotoTile(
                    imageID: "\(plant.id.uuidString)-list-avatar",
                    imageSignature: plant.avatarThumbnailSignature,
                    imageDataProvider: { await previewImageData(for: plantModelID, source: .profile) },
                    fallbackEmoji: plant.avatarEmoji,
                    tint: siteTint(for: plant)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 82)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke.opacity(0.48), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? l.tr(zh: "未命名植物", en: "Unnamed plant", de: "Unbenannte Pflanze")
                        : plant.name)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(plantRoomListSpeciesLine(for: plant, catalog: catalog))
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 6) {
                    plantRoomListInfoRow(signal: difficulty)
                    plantRoomListInfoRow(signal: attention)
                    plantRoomListInfoRow(signal: todo)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 234, alignment: .topLeading)
            .padding(10)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke.opacity(0.58), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(plantRoomListCardAccessibilityLabel(plant, difficulty: difficulty.text, attention: attention.text, todo: todo.text))
        .accessibilityIdentifier("plant-dashboard-room-list-card-\(plant.id.uuidString)")
    }

    func plantRoomListInfoRow(signal: (icon: String, text: String, tint: Color)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: signal.icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(signal.tint)
                .frame(width: 18, height: 18) // a11y: allow non-interactive status glyph; adjacent text carries the accessible value.
                .background(signal.tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(signal.text)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }

    func plantRoomListSpeciesLine(for plant: Plant, catalog: PlantCatalogEntry?) -> String {
        let species = plant.species.trimmingCharacters(in: .whitespacesAndNewlines)
        if !species.isEmpty {
            return species
        }
        if let catalog {
            return catalog.localizedCommonName
        }
        return plant.lightLevel.displayName
    }

    func plantRoomListDifficultySignal(
        for plant: Plant,
        catalog: PlantCatalogEntry?
    ) -> (icon: String, text: String, tint: Color) {
        let text = catalog?.localizedCareDifficulty ?? plantRoomListFallbackDifficulty(for: plant)
        return (
            icon: "speedometer",
            text: l.tr(zh: "难度 \(text)", en: "Care \(text)", de: "Pflege \(text)"),
            tint: plantRoomListDifficultyTint(text)
        )
    }

    func plantRoomListFallbackDifficulty(for plant: Plant) -> String {
        if plant.healthStatus == .stressed || plant.humidityPreference == .humid || plant.wateringIntervalDays <= 4 {
            return l.tr(zh: "进阶", en: "Advanced", de: "Fortgeschritten")
        }
        if plant.healthStatus == .watching || plant.wateringIntervalDays <= 7 {
            return l.tr(zh: "中等", en: "Medium", de: "Mittel")
        }
        return l.tr(zh: "简单", en: "Easy", de: "Einfach")
    }

    func plantRoomListDifficultyTint(_ text: String) -> Color {
        let normalized = normalizedForPlantSearch(text)
        if normalized.contains("进阶") || normalized.contains("advanced") || normalized.contains("fortgeschritten") {
            return Color.goYellow
        }
        if normalized.contains("中") || normalized.contains("medium") || normalized.contains("mittel") {
            return Color.goTeal
        }
        return Color.goPrimary
    }

    func plantRoomListAttentionSignal(
        for plant: Plant,
        catalog: PlantCatalogEntry?
    ) -> (icon: String, text: String, tint: Color) {
        if needsSafetyReview(plant) {
            return (
                icon: "shield.lefthalf.filled",
                text: l.tr(zh: "复核安全位置", en: "Review safe spot", de: "Sicheren Platz prüfen"),
                tint: Color.goYellow
            )
        }
        if plant.healthStatus == .stressed {
            return (
                icon: "exclamationmark.triangle.fill",
                text: plant.healthStatus.displayName,
                tint: Color.goRed
            )
        }
        if plant.healthStatus == .watching {
            return (
                icon: "eye.fill",
                text: plant.healthStatus.displayName,
                tint: Color.goYellow
            )
        }
        if !plant.remindersEnabled {
            return (
                icon: "bell.slash.fill",
                text: l.tr(zh: "提醒已关闭", en: "Reminders off", de: "Erinnerungen aus"),
                tint: Color.goYellow
            )
        }
        if let note = catalog?.localizedCautionNotes.first {
            return (
                icon: "info.circle.fill",
                text: note,
                tint: Color.goTeal
            )
        }
        return (
            icon: "checkmark.seal.fill",
            text: l.tr(zh: "暂无特别注意", en: "No special notes", de: "Keine besonderen Hinweise"),
            tint: Color.goPrimary
        )
    }

    func plantRoomListTodoSignal(
        for plant: Plant,
        nextTask: PlantCareTaskSnapshot?
    ) -> (icon: String, text: String, tint: Color) {
        if let nextTask {
            return (
                icon: careSymbol(for: nextTask.careType),
                text: "\(nextTask.careType.displayName(l: l)) · \(dueText(for: nextTask))",
                tint: nextTask.daysUntilDue <= 0 ? careTint(for: nextTask.careType) : Color.goTeal
            )
        }
        if plant.careLogs.isEmpty {
            return (
                icon: "clock.badge.checkmark.fill",
                text: l.tr(zh: "记录首次照护", en: "Log first care", de: "Erste Pflege erfassen"),
                tint: Color.goYellow
            )
        }
        return (
            icon: "checkmark.circle.fill",
            text: l.tr(zh: "暂无待办", en: "No tasks", de: "Keine Aufgaben"),
            tint: Color.goPrimary
        )
    }

    func plantRoomListCardAccessibilityLabel(
        _ plant: Plant,
        difficulty: String,
        attention: String,
        todo: String
    ) -> String {
        [
            plant.name,
            locationSummary(for: plant),
            difficulty,
            attention,
            todo,
            l.tr(zh: "打开植物详情", en: "Open plant detail", de: "Pflanzendetails öffnen")
        ].joined(separator: ", ")
    }
}
