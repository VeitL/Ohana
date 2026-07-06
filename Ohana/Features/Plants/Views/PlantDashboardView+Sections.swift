//
//  PlantDashboardView+Sections.swift
//  Ohana
//
//  Extracted Plant view sections.
//

import SwiftData
import SwiftUI

extension PlantDashboardView {
    var dashboardOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                dashboardLibraryAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "我的植物", en: "My Plants", de: "Meine Pflanzen"))
                        .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(plantCollectionSummaryLine)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(dashboardStatusLine)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                dashboardActionCapsule
            }

            dashboardStatusRibbon
            dashboardQuickActionRail

            if let nextTask = upcomingTasks.first {
                nextCareStrip(nextTask)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-overview")
    }

    var dashboardLibraryAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.ohanaCardSurface)
                .overlay {
                    Circle().strokeBorder(Color.ohanaCardStroke.opacity(0.7), lineWidth: 1)
                }

            if let plant = dashboardLeadPlant {
                plantPreviewTile(for: plant)
                .clipShape(Circle())
                .padding(4)
            } else {
                Image(systemName: "person.crop.circle.fill") // a11y: allow decorative empty library avatar; surrounding header labels the plant library.
                    .font(OhanaFont.adaptive(size: 36, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 82, height: 82)
        .accessibilityHidden(true)
        .accessibilityIdentifier("plant-dashboard-library-avatar")
    }

    var dashboardActionCapsule: some View {
        HStack(spacing: 2) {
            dashboardHeaderIconButton(
                id: "search",
                icon: "magnifyingglass",
                tint: Color.ohanaPrimaryText,
                label: l.tr(zh: "搜索植物", en: "Search plants", de: "Pflanzen suchen")
            ) {
                selectedDashboardMode = .plants
                Task { @MainActor in
                    await OhanaFrameScheduler.waitAfterNextFrame()
                    searchFocused = true
                }
            }

            dashboardHeaderIconButton(
                id: "filters",
                icon: "line.3.horizontal.decrease",
                tint: Color.ohanaPrimaryText,
                label: l.tr(zh: "筛选植物", en: "Filter plants", de: "Pflanzen filtern"),
                action: openDashboardFilters
            )

            dashboardHeaderIconButton(
                id: "add",
                icon: "plus",
                tint: Color.arkInk,
                label: l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"),
                fill: Color.goPrimary
            ) {
                showingAddPlant = true
            }
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.ohanaCardStroke.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-action-capsule")
    }

    func dashboardHeaderIconButton(
        id: String,
        icon: String,
        tint: Color,
        label: String,
        fill: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon) // a11y: allow decorative header glyph; button label names the command.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(fill ?? Color.clear, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id == "search" ? "plant-dashboard-open-search" : id == "filters" ? "plant-dashboard-open-filters" : "plant-dashboard-add-action")
    }

    var dashboardStatusRibbon: some View {
        HStack(spacing: 8) {
            dashboardStatusChip(
                id: "tasks",
                icon: "calendar.badge.clock",
                title: dueTasks.isEmpty
                    ? l.tr(zh: "今日清爽", en: "Clear today", de: "Heute frei")
                    : l.tr(zh: "\(dueTasks.count) 项任务", en: "\(dueTasks.count) tasks", de: "\(dueTasks.count) Aufgaben"),
                tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow
            )

            dashboardStatusChip(
                id: "watch",
                icon: "eye.fill",
                title: watchedPlantsCount == 0
                    ? l.tr(zh: "状态稳定", en: "Stable", de: "Stabil")
                    : l.tr(zh: "\(watchedPlantsCount) 株观察", en: "\(watchedPlantsCount) watch", de: "\(watchedPlantsCount) beobachten"),
                tint: watchedPlantsCount == 0 ? Color.goPrimary : Color.goYellow
            )

            dashboardStatusChip(
                id: "sites",
                icon: "house.fill",
                title: l.tr(zh: "\(roomCareSummaries.count) 个位置", en: "\(roomCareSummaries.count) sites", de: "\(roomCareSummaries.count) Orte"),
                tint: Color.goTeal
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-status-ribbon")
    }

    func dashboardStatusChip(id: String, icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 34)
        .padding(.horizontal, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-status-chip-\(id)")
    }

    var plantCollectionSummaryLine: String {
        l.tr(
            zh: "\(plants.count) 株植物 · \(roomCareSummaries.count) 个位置",
            en: "\(plants.count) plants · \(roomCareSummaries.count) sites",
            de: "\(plants.count) Pflanzen · \(roomCareSummaries.count) Orte"
        )
    }

    var dashboardStatusLine: String {
        if !dueTasks.isEmpty {
            return l.tr(
                zh: "\(dueTasks.count) 项照护今天到期，先处理 \(plantsNeedingCareCount) 株植物",
                en: "\(dueTasks.count) care tasks due today across \(plantsNeedingCareCount) plants",
                de: "\(dueTasks.count) Pflegeaufgaben heute für \(plantsNeedingCareCount) Pflanzen"
            )
        }
        if let nextTask = upcomingTasks.first {
            return l.tr(
                zh: "下一项：\(nextTask.title)，\(dueText(for: nextTask))",
                en: "Next: \(nextTask.title), \(dueText(for: nextTask))",
                de: "Als Nächstes: \(nextTask.title), \(dueText(for: nextTask))"
            )
        }
        return l.tr(
            zh: "本周节奏稳定，适合记录观察和整理护理计划",
            en: "This week is calm: note observations and tidy the care plan",
            de: "Diese Woche ist ruhig: Beobachtungen notieren und Pflegeplan ordnen"
        )
    }

    var dashboardModePicker: some View {
        HStack(spacing: 6) {
            ForEach(PlantDashboardMode.primaryCases) { mode in
                Button {
                    selectedDashboardMode = mode
                    if mode == .sites {
                        searchFocused = false
                    }
                } label: {
                    Text(mode.title(l))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(selectedDashboardMode == mode ? Color.arkInk : Color.ohanaSecondaryText)
                        .frame(minWidth: 86)
                        .frame(height: 44)
                        .background(
                            selectedDashboardMode == mode ? Color.goPrimary : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-mode-\(mode.rawValue)")
            }
        }
        .padding(5)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-mode-picker")
    }

    @ViewBuilder
    var dashboardModeContent: some View {
        switch selectedDashboardMode {
        case .sites:
            sitesDashboardSection
        case .plants:
            plantsDashboardSection
        case .photos:
            photosDashboardSection
        }
    }

    func dashboardMetric(
        icon: String,
        title: String,
        value: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24) // a11y: allow non-interactive metric glyph; metric text provides the accessible value.
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(detail)")
    }

    var dashboardQuickActionRail: some View {
        let photoPreviewCount = min(plants.count, PlantDashboardPhotoPolicy.maxDashboardItems)

        return HStack(spacing: 8) {
            dashboardQuickActionButton(
                id: "care-plan",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan"),
                subtitle: dueTasks.isEmpty
                    ? l.tr(zh: "本周", en: "Week", de: "Woche")
                    : l.tr(zh: "\(dueTasks.count) 到期", en: "\(dueTasks.count) due", de: "\(dueTasks.count) fällig"),
                tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow,
                action: openDashboardCarePlan
            )

            dashboardQuickActionButton(
                id: "profile",
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "档案待办", en: "Profiles", de: "Profile"),
                subtitle: profileReadinessItems.isEmpty
                    ? l.tr(zh: "完成", en: "Ready", de: "Bereit")
                    : l.tr(zh: "\(profileReadinessItems.count) 项", en: "\(profileReadinessItems.count) items", de: "\(profileReadinessItems.count) Punkte"),
                tint: profileReadinessItems.isEmpty ? Color.goPrimary : Color.goYellow,
                action: openDashboardProfileQueue
            )

            dashboardQuickActionButton(
                id: "photos",
                icon: "photo.stack.fill",
                title: l.tr(zh: "成长照片", en: "Photos", de: "Fotos"),
                subtitle: photoPreviewCount == 0
                    ? l.tr(zh: "补照片", en: "Add", de: "Ergänzen")
                    : l.tr(zh: "\(photoPreviewCount) 株", en: "\(photoPreviewCount)", de: "\(photoPreviewCount)"),
                tint: photoPreviewCount == 0 ? Color.goYellow : Color.goTeal,
                action: openDashboardPhotos
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-quick-actions")
    }

    func dashboardQuickActionButton(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon) // a11y: allow decorative quick-action glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 74, alignment: .center)
            .padding(.horizontal, 10)
            .background(Color.ohanaControlFill.opacity(0.54), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier("plant-dashboard-quick-action-\(id)")
    }

    var metricDivider: some View {
        Rectangle()
            .fill(Color.ohanaControlFill.opacity(0.75))
            .frame(width: 1, height: 58)
            .padding(.horizontal, 10)
            .accessibilityHidden(true)
    }

    func nextCareStrip(_ task: PlantCareTaskSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: careSymbol(for: task.careType))
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: task.careType))
                .frame(width: 30, height: 30) // a11y: allow non-interactive next-care glyph; adjacent text names the task.
                .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "下一项照护", en: "Next care", de: "Nächste Pflege"))
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text("\(task.title) · \(dueText(for: task))")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.46), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    var sitesDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sitesModeHeader

            ForEach(roomCareSummaries) { summary in
                siteCard(summary)
            }

            if !profileReadinessItems.isEmpty {
                profileReadinessSection
            }

            if !careWindowTasks.isEmpty {
                taskSummarySection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-sites-view")
    }

    var plantsDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchAndFilterSection
            plantsModeBanner
            plantListSection

            if !profileReadinessItems.isEmpty {
                profileReadinessSection
            }

            if !plantsNeedingWater.isEmpty {
                urgentSection
            }

            if !careWindowTasks.isEmpty {
                taskSummarySection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-plants-view")
    }

    var sitesModeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "位置", en: "Sites", de: "Orte"))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.tr(
                    zh: "按摆放空间查看植物和待办",
                    en: "Browse plants and care tasks by where they live",
                    de: "Pflanzen und Pflege nach Standort durchsuchen"
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative sites count glyph; adjacent text gives the count.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "\(roomCareSummaries.count) 个", en: "\(roomCareSummaries.count)", de: "\(roomCareSummaries.count)"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(Color.goPrimary, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-sites-header")
    }

    var plantsModeBanner: some View {
        Button {
            openDashboardCarePlan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: dueTasks.isEmpty ? "checkmark.seal.fill" : "calendar.badge.clock")
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.arkInk.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plantsModeBannerTitle)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(plantsModeBannerSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative banner navigation glyph; the button has a full label.
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(dueTasks.isEmpty ? Color.goPrimary : Color.goYellow, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(plantsModeBannerTitle), \(plantsModeBannerSubtitle)")
        .accessibilityIdentifier("plant-dashboard-plants-banner")
    }

    var plantsModeBannerTitle: String {
        dueTasks.isEmpty
            ? l.tr(zh: "今天没有到期护理", en: "No care due today", de: "Heute keine Pflege fällig")
            : l.tr(zh: "今天有 \(dueTasks.count) 项护理", en: "\(dueTasks.count) care tasks today", de: "\(dueTasks.count) Pflegeaufgaben heute")
    }

    var plantsModeBannerSubtitle: String {
        if dueTasks.isEmpty {
            return l.tr(
                zh: "可以补照片、整理档案，或查看未来 7 天计划",
                en: "Add photos, tidy profiles, or review the 7-day plan",
                de: "Fotos ergänzen, Profile ordnen oder den 7-Tage-Plan prüfen"
            )
        }
        return l.tr(
            zh: "点这里打开护理计划，或在列表里逐株完成",
            en: "Open the care plan here or complete items from the list",
            de: "Plan hier öffnen oder Aufgaben in der Liste erledigen"
        )
    }

    var batchCareSheetTasks: [PlantBatchCareSheetTask] {
        makeBatchCareSheetTasks(careType: batchCareInitialType, roomID: batchCareRoomFilter)
    }

    func makeBatchCareSheetSnapshot(careType: PlantCareType?, roomID: String?) -> PlantBatchCareSheetSnapshot {
        PlantBatchCareSheetSnapshot(tasks: makeBatchCareSheetTasks(careType: careType, roomID: roomID))
    }

    func makeBatchCareSheetTasks(careType: PlantCareType?, roomID: String?) -> [PlantBatchCareSheetTask] {
        dueTasks.compactMap { task in
            guard careType == nil || task.careType == careType else { return nil }
            guard let plant = plants.first(where: { $0.id == task.plantID }) else { return nil }
            let roomName = locationFilterValue(for: plant)
            if let roomID, roomName != roomID {
                return nil
            }
            return PlantBatchCareSheetTask(
                id: task.id,
                plantID: plant.id,
                plantModelID: plant.persistentModelID,
                plantName: plant.name,
                roomName: roomName,
                careType: task.careType,
                subtitle: task.subtitle,
                dueText: dueText(for: task),
                avatarSignature: plant.avatarThumbnailSignature,
                tintHex: plant.themeColorHex
            )
        }
    }

    @ViewBuilder
    var batchCareUndoBanner: some View {
        if let token = pendingBatchCareUndoToken {
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill") // a11y: allow decorative glyph; adjacent text names the completed batch.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.goPrimary.opacity(0.16), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(
                            zh: "已完成 \(token.items.count) 项照护",
                            en: "Completed \(token.items.count) care tasks",
                            de: "\(token.items.count) Pflegeaufgaben erledigt"
                        ))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)

                        Text(l.tr(
                            zh: "6 秒内可撤销；奖励会在窗口结束后结算。",
                            en: "Undo within 6 seconds; rewards settle after the window.",
                            de: "6 Sekunden widerrufbar; Belohnungen folgen danach."
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Button(l.tr(zh: "撤销", en: "Undo", de: "Widerrufen")) {
                        undoPendingBatchCare()
                    }
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("plant-batch-care-undo")

                    Button(l.tr(zh: "统计", en: "Stats", de: "Statistik")) {
                        let feature = token.items.first.map { careAggregateFeature(for: $0.careType) }
                        openCareAggregate(feature)
                    }
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(minWidth: 50, minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "查看刚完成的植物照护统计", en: "View care statistics for completed plants", de: "Statistik der erledigten Pflanzenpflege anzeigen"))
                    .accessibilityIdentifier("plant-batch-care-view-stats")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.ohanaCardSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(Color.goPrimary.opacity(0.22), lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(60)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("plant-batch-care-undo-banner")
        }
    }

    var taskSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock") // a11y: allow decorative section glyph; heading names the task window.
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "今日与未来 7 天", en: "Today and next 7 days", de: "Heute und die nächsten 7 Tage"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()

                Button(l.tr(zh: "统计", en: "Stats", de: "Statistik")) {
                    openCareAggregate()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "查看植物照护统计", en: "View plant care statistics", de: "Pflanzenpflege-Statistik anzeigen"))
                .accessibilityIdentifier("plant-dashboard-care-stats-open")

                if !careWindowTasks.isEmpty {
                    Button {
                        showingCarePlanSheet = true
                    } label: {
                        Text(l.tr(zh: "全部", en: "All", de: "Alle"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "查看全部植物护理计划", en: "View all plant care plans", de: "Alle Pflanzenpflegepläne anzeigen"))
                    .accessibilityIdentifier("plant-dashboard-care-plan-open")
                }
            }

            if careWindowTasks.isEmpty {
                Text(l.tr(
                    zh: "未来 7 天没有植物任务，适合补照片或整理档案",
                    en: "No plant tasks in the next 7 days. Add photos or tidy profiles.",
                    de: "Keine Pflanzenaufgaben in den nächsten 7 Tagen. Fotos oder Profile ergänzen."
                ))
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(careWindowTasks.prefix(4)) { task in
                        taskRow(task)
                    }
                }

                if dueTasks.isEmpty {
                    Text(l.tr(
                        zh: "今天没有到期任务，以上是本周护理节奏。",
                        en: "Nothing is due today. This is the care rhythm for the week.",
                        de: "Heute ist nichts fällig. Das ist der Pflegerhythmus der Woche."
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }

                if !dueTasks.isEmpty {
                    HStack(spacing: 10) {
                        Button(l.tr(zh: "全部完成", en: "Complete all", de: "Alle erledigen")) {
                            completeDueTasks()
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                        .accessibilityIdentifier("plant-dashboard-complete-all-due")

                        Button(l.tr(zh: "全部延后一天", en: "Defer all one day", de: "Alle um einen Tag verschieben")) {
                            deferDueTasksOneDay()
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                        .accessibilityIdentifier("plant-dashboard-defer-all-due")
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-dashboard-task-summary")
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlantDashboardFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title(l))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedFilter == filter ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .accessibilityIdentifier("plant-dashboard-filter-bar")
    }

    func taskRow(_ task: PlantCareTaskSnapshot) -> some View {
        let careTypeName = task.careType.displayName(l: l)

        return HStack(spacing: 10) {
            Image(systemName: careSymbol(for: task.careType))
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: task.careType))
                .frame(width: 34, height: 34) // a11y: allow non-interactive care glyph; completion button is the hit target.
                .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                Text(task.explanation)
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                completeTask(task)
            } label: {
                Image(systemName: "checkmark") // a11y: allow decorative icon; button has explicit completion label.
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(l.tr(zh: "完成\(careTypeName)", en: "Complete \(careTypeName)", de: "\(careTypeName) erledigen"))
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    var searchAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            filterBar
        }
        .accessibilityIdentifier("plant-dashboard-search-filter")
    }

    var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass") // a11y: allow decorative search glyph; the text field carries the accessible label.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(searchFocused ? Color.goTeal : Color.ohanaSecondaryText)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            TextField( // ui-v4: allow dashboard search input; it is locally styled and covered by input responsiveness tests.
                l.tr(
                    zh: "搜索植物、品种、房间",
                    en: "Search plants, species, rooms",
                    de: "Pflanzen, Arten, Räume suchen"
                ),
                text: $searchText
            )
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .accessibilityLabel(l.tr(zh: "搜索植物", en: "Search plants", de: "Pflanzen suchen"))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative clear glyph; button label names the action.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "清空植物搜索", en: "Clear plant search", de: "Pflanzensuche leeren"))
                .accessibilityIdentifier("plant-dashboard-search-clear")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, searchText.isEmpty ? 14 : 2)
        .frame(minHeight: 52)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(searchFocused ? Color.goTeal.opacity(0.52) : Color.ohanaCardStroke, lineWidth: searchFocused ? 1.5 : 1)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-search-field")
    }
}
