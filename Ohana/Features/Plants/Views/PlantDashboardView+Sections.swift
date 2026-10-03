//
//  PlantDashboardView+Sections.swift
//  Ohana
//
//  Extracted Plant view sections.
//

import SwiftData
import SwiftUI

extension PlantDashboardView {
    func showBatchCarePersistenceFailure(_: String?) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        appServices.islandToasts.show(l.tr(
            zh: "保存失败，批量照护未完成",
            en: "Save failed. Batch care was not completed.",
            de: "Speichern fehlgeschlagen. Die Batch-Pflege wurde nicht abgeschlossen."
        ))
    }

    func showBatchCareSelectionChanged() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        appServices.islandToasts.show(l.tr(
            zh: "选择已变化，本次未记录；请检查刷新后的列表。",
            en: "The selection changed, so nothing was recorded. Review the refreshed list.",
            de: "Die Auswahl hat sich geändert; es wurde nichts gespeichert. Bitte die aktualisierte Liste prüfen."
        ))
    }

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
                }

                Spacer(minLength: 8)

                dashboardActionCapsule
            }

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
                tint: Color.ohanaPrimaryActionText,
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

    var plantCollectionSummaryLine: String {
        l.tr(
            zh: "\(plants.count) 株植物",
            en: "\(plants.count) plants",
            de: "\(plants.count) Pflanzen"
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
                        .foregroundStyle(selectedDashboardMode == mode ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
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

        return LazyVGrid(columns: dashboardQuickActionColumns, spacing: 8) {
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

    var dashboardQuickActionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 108), spacing: 8)]
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
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 70, alignment: .center)
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
        .searchable(
            text: $searchText,
            isPresented: $searchFocused,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(l.tr(
                zh: "搜索植物、品种、房间",
                en: "Search plants, species, rooms",
                de: "Pflanzen, Arten, Räume suchen"
            ))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-plants-view")
    }

    var sitesModeHeader: some View {
        Text(l.tr(zh: "位置", en: "Sites", de: "Orte"))
            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
        .accessibilityIdentifier("plant-dashboard-sites-header")
    }

    var plantsModeBanner: some View {
        Button {
            openDashboardCarePlan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: dueTasks.isEmpty ? "checkmark.seal.fill" : "calendar.badge.clock")
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(plantsModeBannerForeground)
                    .frame(width: 44, height: 44)
                    .background(Color.arkInk.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plantsModeBannerTitle)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(plantsModeBannerForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(plantsModeBannerSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(plantsModeBannerForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative banner navigation glyph; the button has a full label.
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(plantsModeBannerForeground)
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

    var plantsModeBannerForeground: Color {
        dueTasks.isEmpty ? Color.ohanaPrimaryActionText : Color.arkInk
    }

    var plantsModeBannerTitle: String {
        dueTasks.isEmpty
            ? l.tr(zh: "未来 7 天计划", en: "Next 7 days", de: "Nächste 7 Tage")
            : l.tr(zh: "今天有 \(dueTasks.count) 项护理", en: "\(dueTasks.count) care tasks today", de: "\(dueTasks.count) Pflegeaufgaben heute")
    }

    var plantsModeBannerSubtitle: String {
        if dueTasks.isEmpty {
            return l.tr(
                zh: "今天无到期",
                en: "Nothing due today",
                de: "Heute nichts fällig"
            )
        }
        return l.tr(
            zh: "查看护理计划",
            en: "View care plan",
            de: "Pflegeplan ansehen"
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
                    .foregroundStyle(Color.ohanaPrimaryActionText)
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
                            .foregroundStyle(Color.ohanaPrimaryActionText)
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
                    zh: "未来 7 天没有植物任务",
                    en: "No plant tasks in the next 7 days",
                    de: "Keine Pflanzenaufgaben in den nächsten 7 Tagen"
                ))
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(careWindowTasks.prefix(4)) { task in
                        taskRow(task)
                    }
                }

                if !dueTasks.isEmpty {
                    HStack(spacing: 10) {
                        Button(l.tr(zh: "全部完成", en: "Complete all", de: "Alle erledigen")) {
                            completeDueTasks()
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
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
                            .foregroundStyle(selectedFilter == filter ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
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
            }
            Spacer()
            Button {
                completeTask(task)
            } label: {
                Image(systemName: "checkmark") // a11y: allow decorative icon; button has explicit completion label.
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
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
        filterBar
        .accessibilityIdentifier("plant-dashboard-search-filter")
    }
}
