//
//  PlantAllFeaturesSheet.swift
//  Ohana
//
//  Feature hub for plant detail pages.
//

import SwiftData
import SwiftUI

enum PlantFeatureDestination: Hashable, Sendable {
    case water
    case fertilize
    case maintenance
    case health
    case growth
    case pestCheck
    case leafCleaning
    case carePlan
    case reminders
    case healthReview
    case profile
    case photos
    case timeline
    case catalog
    case safety
}

extension PlantFeatureDestination {
    var careFeatureDestination: PlantCareFeatureDestination? {
        switch self {
        case .water:
            .water
        case .fertilize:
            .fertilize
        case .maintenance, .leafCleaning:
            .maintenance
        case .health, .pestCheck:
            .health
        case .growth:
            .growth
        case .carePlan, .reminders, .healthReview, .profile, .photos, .timeline, .catalog, .safety:
            nil
        }
    }

    func title(l: L10n) -> String {
        switch self {
        case .water:
            l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilize:
            l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .maintenance:
            PlantCareCategory.maintenance.title(l: l)
        case .health:
            PlantCareCategory.health.title(l: l)
        case .growth:
            PlantCareCategory.growth.title(l: l)
        case .pestCheck:
            l.tr(zh: "病虫复查", en: "Pest check", de: "Schädlingscheck")
        case .leafCleaning:
            l.tr(zh: "清洁叶片", en: "Clean leaves", de: "Blätter reinigen")
        case .carePlan:
            l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan")
        case .reminders:
            l.tr(zh: "植物提醒", en: "Reminders", de: "Erinnerungen")
        case .healthReview:
            l.tr(zh: "健康观察", en: "Health review", de: "Gesundheitscheck")
        case .profile:
            l.tr(zh: "植物档案", en: "Profile", de: "Profil")
        case .photos:
            l.tr(zh: "成长照片", en: "Photos", de: "Fotos")
        case .timeline:
            l.tr(zh: "护理时间线", en: "Timeline", de: "Zeitachse")
        case .catalog:
            l.tr(zh: "资料库", en: "Catalog", de: "Katalog")
        case .safety:
            l.tr(zh: "家庭安全", en: "Safety", de: "Sicherheit")
        }
    }

    var icon: String {
        switch self {
        case .water:
            "drop.fill"
        case .fertilize:
            "leaf.fill"
        case .maintenance:
            PlantCareCategory.maintenance.icon
        case .health:
            PlantCareCategory.health.icon
        case .growth:
            PlantCareCategory.growth.icon
        case .pestCheck:
            "ladybug.fill"
        case .leafCleaning:
            "sparkles"
        case .carePlan:
            "slider.horizontal.3"
        case .reminders:
            "bell.badge.fill"
        case .healthReview:
            "waveform.path.ecg"
        case .profile:
            "list.clipboard.fill"
        case .photos:
            "photo.stack.fill"
        case .timeline:
            "clock.arrow.circlepath"
        case .catalog:
            "books.vertical.fill"
        case .safety:
            "shield.checkered"
        }
    }
}

private struct PlantHubFocusAction {
    let id: String
    let eyebrow: String
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let destination: PlantFeatureDestination
}

struct PlantAllFeaturesSheet: View {
    let plant: Plant
    let careTasks: [PlantCareTaskSnapshot]
    let logCount: Int
    let photoCount: Int
    let profileCompletionPercent: Int
    let safetyWarningCount: Int
    let onOpenDestination: (PlantFeatureDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color {
        let trimmed = plant.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Color.goTeal : Color(hex: trimmed)
    }
    private var dueTaskCount: Int { careTasks.count { $0.daysUntilDue <= 0 } }
    private var nextTask: PlantCareTaskSnapshot? { careTasks.first }
    private var nextDueTask: PlantCareTaskSnapshot? { careTasks.first { $0.daysUntilDue <= 0 } }
    private var recentObservationWindowStart: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date().addingTimeInterval(-30 * 86400)
    }
    private var recentStressSignalCount: Int {
        plant.careLogs.count { log in
            log.date >= recentObservationWindowStart &&
                (log.careType == .yellowLeaf || log.careType == .pestFound)
        }
    }
    private var recentHealthReviewCount: Int {
        plant.careLogs.count { log in
            log.date >= recentObservationWindowStart &&
                [
                    PlantCareType.pestCheck,
                    .pestFound,
                    .yellowLeaf,
                    .newLeaf,
                    .leafCleaning,
                    .photo,
                    .customNote
                ].contains(log.careType)
        }
    }
    private var healthReviewSignalCount: Int {
        let statusSignal = plant.healthStatus == .stressed || plant.healthStatus == .watching ? 1 : 0
        let environmentSignal = plant.isNearClimateSource || !plant.potHasDrainage ? 1 : 0
        return statusSignal + environmentSignal + recentStressSignalCount + safetyWarningCount
    }
    private var placementSummary: String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactSpot = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !exactSpot.isEmpty, room != exactSpot {
            return "\(room) · \(exactSpot)"
        }
        if !room.isEmpty { return room }
        if !exactSpot.isEmpty { return exactSpot }
        return l.tr(zh: "未设置位置", en: "No location", de: "Kein Standort")
    }

    var body: some View {
        NavigationStack {
            FeatureHubScaffold {
                FeatureHubHeader(
                    title: plant.name,
                    subtitle: headerSubtitle,
                    eyebrow: l.tr(zh: "植物全部功能", en: "Plant Hub", de: "Pflanzen-Hub"),
                    onClose: { dismiss() },
                    avatar: {
                        FeatureHubAvatar(
                            imageCacheID: "plant-all-features-\(plant.id.uuidString)",
                            imageSignature: plant.avatarThumbnailSignature,
                            plantModelID: plant.persistentModelID,
                            emoji: plant.avatarEmoji,
                            fallback: "leaf",
                            tint: themeColor
                        )
                    }
                )
            } content: {
                focusActionBanner
                FeatureHubMetricStrip(metrics: metrics)

                ForEach(sections) { section in
                    FeatureHubSectionActionView(section: section) { destination in
                        open(destination)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("plant-detail-all-features-sheet")
    }

    private func open(_ destination: PlantFeatureDestination) {
        onOpenDestination(destination)
        dismiss()
    }

    private var headerSubtitle: String {
        let species = plant.species.trimmingCharacters(in: .whitespacesAndNewlines)
        if species.isEmpty {
            return placementSummary
        }
        return "\(species) · \(placementSummary)"
    }

    private var focusAction: PlantHubFocusAction {
        if let nextDueTask {
            return PlantHubFocusAction(
                id: "due-care",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "先完成今日护理", en: "Handle due care first", de: "Fällige Pflege zuerst"),
                detail: "\(nextDueTask.title) · \(dueText(for: nextDueTask))",
                icon: careSymbol(for: nextDueTask.careType),
                tint: careTint(for: nextDueTask.careType),
                destination: destination(for: nextDueTask)
            )
        }

        if healthReviewSignalCount > 0 {
            return PlantHubFocusAction(
                id: "health-review",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "复查健康信号", en: "Review health signals", de: "Gesundheitssignale prüfen"),
                detail: l.tr(
                    zh: "\(healthReviewSignalCount) 个信号需要确认，记录观察后护理计划更可靠。",
                    en: "\(healthReviewSignalCount) signals need review; log observations to improve care plans.",
                    de: "\(healthReviewSignalCount) Signale prüfen; Beobachtungen verbessern den Pflegeplan."
                ),
                icon: "waveform.path.ecg",
                tint: Color.goYellow,
                destination: .health
            )
        }

        if safetyWarningCount > 0 {
            return PlantHubFocusAction(
                id: "safety",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "复核家庭安全", en: "Review household safety", de: "Haushaltssicherheit prüfen"),
                detail: l.tr(
                    zh: "这株植物有安全提示，先确认宠物、儿童和摆放位置。",
                    en: "This plant has safety notes. Check pets, children, and placement first.",
                    de: "Diese Pflanze hat Sicherheitshinweise. Tiere, Kinder und Standort zuerst prüfen."
                ),
                icon: "shield.checkered",
                tint: Color.goYellow,
                destination: .safety
            )
        }

        if profileCompletionPercent < 80 {
            return PlantHubFocusAction(
                id: "profile",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "补齐植物档案", en: "Complete the profile", de: "Profil vervollständigen"),
                detail: l.tr(
                    zh: "当前档案 \(profileCompletionPercent)%，补齐身份、位置和盆土可提升护理建议。",
                    en: "Profile is \(profileCompletionPercent)% complete. Add identity, place, and potting for better guidance.",
                    de: "Profil ist zu \(profileCompletionPercent)% vollständig. Identität, Ort und Topf verbessern Hinweise."
                ),
                icon: "list.clipboard.fill",
                tint: themeColor,
                destination: .profile
            )
        }

        if photoCount == 0 {
            return PlantHubFocusAction(
                id: "photos",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "补第一张成长照片", en: "Add the first growth photo", de: "Erstes Wachstumsfoto ergänzen"),
                detail: l.tr(
                    zh: "照片会让位置、图库和成长日记更像真实植物档案。",
                    en: "Photos make Sites, gallery, and the growth diary feel like a real plant record.",
                    de: "Fotos machen Bereiche, Galerie und Tagebuch zu einer echten Pflanzenakte."
                ),
                icon: "photo.stack.fill",
                tint: Color.goTeal,
                destination: .growth
            )
        }

        if logCount == 0 {
            return PlantHubFocusAction(
                id: "first-log",
                eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
                title: l.tr(zh: "记录首次照护", en: "Log the first care", de: "Erste Pflege erfassen"),
                detail: l.tr(
                    zh: "第一条护理记录会启动时间线和后续护理节奏。",
                    en: "The first care log starts the timeline and future rhythm.",
                    de: "Der erste Pflegeeintrag startet Zeitachse und Rhythmus."
                ),
                icon: "drop.fill",
                tint: Color.goTeal,
                destination: .water
            )
        }

        return PlantHubFocusAction(
            id: "care-plan",
            eyebrow: l.tr(zh: "优先行动", en: "Priority", de: "Priorität"),
            title: l.tr(zh: "查看护理节奏", en: "Review the care rhythm", de: "Pflege-Rhythmus ansehen"),
            detail: nextTask.map { "\($0.title) · \(dueText(for: $0))" } ?? l.tr(
                zh: "当前状态稳定，可以从护理计划查看下一步。",
                en: "The plant looks steady. Use the care plan for the next step.",
                de: "Die Pflanze wirkt stabil. Der Pflegeplan zeigt den nächsten Schritt."
            ),
            icon: "slider.horizontal.3",
            tint: Color.goPrimary,
            destination: .carePlan
        )
    }

    private var focusActionBanner: some View {
        let action = focusAction
        return Button {
            open(action.destination)
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    focusActionIcon(action)
                    focusActionCopy(action)
                    Spacer(minLength: 8)
                    focusActionArrow
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        focusActionIcon(action)
                        focusActionCopy(action)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        focusActionArrow
                    }
                }
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                    .strokeBorder(action.tint.opacity(0.42), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(action.eyebrow), \(action.title), \(action.detail)")
        .accessibilityIdentifier("plant-detail-feature-focus-\(action.id)")
    }

    private func focusActionIcon(_ action: PlantHubFocusAction) -> some View {
        Image(systemName: action.icon) // a11y: allow decorative priority glyph; the banner label names the action.
            .font(OhanaFont.adaptive(size: 18, weight: .black))
            .foregroundStyle(action.tint)
            .frame(width: 44, height: 44)
            .background(action.tint.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    private func focusActionCopy(_ action: PlantHubFocusAction) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(action.eyebrow)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .textCase(.uppercase)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(action.title)
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(action.detail)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var focusActionArrow: some View {
        Image(systemName: "arrow.right") // a11y: allow decorative priority navigation glyph; button label is explicit.
            .font(OhanaFont.adaptive(size: 16, weight: .black))
            .foregroundStyle(Color.arkInk)
            .frame(width: 44, height: 44)
            .background(Color.goPrimary, in: Circle())
            .accessibilityHidden(true)
    }

    private var metrics: [FeatureHubMetric] {
        [
            FeatureHubMetric(
                id: "due",
                title: l.tr(zh: "到期", en: "Due", de: "Fällig"),
                value: "\(dueTaskCount)"
            ),
            FeatureHubMetric(
                id: "logs",
                title: l.tr(zh: "记录", en: "Logs", de: "Einträge"),
                value: "\(logCount)"
            ),
            FeatureHubMetric(
                id: "photos",
                title: l.tr(zh: "照片", en: "Photos", de: "Fotos"),
                value: "\(photoCount)"
            ),
            FeatureHubMetric(
                id: "profile",
                title: l.tr(zh: "档案", en: "Profile", de: "Profil"),
                value: "\(profileCompletionPercent)%"
            )
        ]
    }

    private var sections: [FeatureHubSectionData<PlantFeatureDestination>] {
        [
            FeatureHubSectionData(
                id: "daily",
                title: l.tr(zh: "护理分类", en: "Care Categories", de: "Pflegekategorien"),
                subtitle: l.tr(zh: "先选大类，再进入具体护理", en: "Pick a category before the exact care type", de: "Erst Kategorie, dann Pflegetyp"),
                items: dailyItems
            ),
            FeatureHubSectionData(
                id: "plan",
                title: l.tr(zh: "护理计划", en: "Care Plan", de: "Pflegeplan"),
                subtitle: l.tr(zh: "节奏、提醒、资料库和安全", en: "Cadence, reminders, catalog, and safety", de: "Rhythmus, Hinweise, Katalog und Sicherheit"),
                items: planItems
            ),
            FeatureHubSectionData(
                id: "archive",
                title: l.tr(zh: "植物档案", en: "Plant Profile", de: "Pflanzenprofil"),
                subtitle: l.tr(zh: "身份、照片和历史回顾", en: "Identity, photos, and history", de: "Identität, Fotos und Verlauf"),
                items: archiveItems
            )
        ]
    }

    private var dailyItems: [FeatureHubDestinationItem<PlantFeatureDestination>] {
        [
            item(
                id: "water",
                title: PlantCareCategory.hydration.title(l: l),
                value: dueValue(for: .hydration),
                subtitle: categorySubtitle(for: .hydration),
                icon: "drop.fill",
                tint: Color.goTeal,
                destination: .water
            ),
            item(
                id: "fertilize",
                title: PlantCareCategory.nutrition.title(l: l),
                value: dueValue(for: .nutrition),
                subtitle: categorySubtitle(for: .nutrition),
                icon: "leaf.fill",
                tint: Color.goPrimary,
                destination: .fertilize
            ),
            item(
                id: "maintenance",
                title: PlantCareCategory.maintenance.title(l: l),
                value: dueValue(for: .maintenance),
                subtitle: categorySubtitle(for: .maintenance),
                icon: PlantCareCategory.maintenance.icon,
                tint: Color.goYellow,
                destination: .maintenance
            ),
            item(
                id: "health",
                title: PlantCareCategory.health.title(l: l),
                value: healthReviewSignalCount == 0 ? dueValue(for: .health) : "\(healthReviewSignalCount)",
                subtitle: plant.healthStatus == .stressed
                    ? l.tr(zh: "优先排查", en: "Inspect first", de: "Zuerst prüfen")
                    : categorySubtitle(for: .health),
                icon: PlantCareCategory.health.icon,
                tint: healthReviewSignalCount == 0 ? Color.goTeal : Color.goYellow,
                destination: .health
            ),
            item(
                id: "growth",
                title: PlantCareCategory.growth.title(l: l),
                value: "\(photoCount)",
                subtitle: categorySubtitle(for: .growth),
                icon: PlantCareCategory.growth.icon,
                tint: Color.goPurple,
                destination: .growth
            )
        ]
    }

    private var planItems: [FeatureHubDestinationItem<PlantFeatureDestination>] {
        [
            item(
                id: "carePlan",
                title: l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan"),
                value: nextTask.map(dueText) ?? l.tr(zh: "无计划", en: "None", de: "Kein"),
                subtitle: nextTask?.title ?? l.tr(zh: "查看计划依据", en: "Review plan reasoning", de: "Planlogik ansehen"),
                icon: "slider.horizontal.3",
                tint: Color.goPrimary,
                destination: .carePlan
            ),
            item(
                id: "reminders",
                title: l.tr(zh: "植物提醒", en: "Reminders", de: "Erinnerungen"),
                value: plant.remindersEnabled ? l.tr(zh: "开启", en: "On", de: "An") : l.tr(zh: "关闭", en: "Off", de: "Aus"),
                subtitle: plant.remindersEnabled
                    ? l.tr(zh: "护理计划会生成本地提醒", en: "Care plans create local reminders", de: "Pflegepläne erzeugen lokale Erinnerungen")
                    : l.tr(zh: "打开后恢复后续护理提醒", en: "Turn on to resume future care alerts", de: "Aktivieren, um Pflegehinweise fortzusetzen"),
                icon: plant.remindersEnabled ? "bell.badge.fill" : "bell.slash.fill",
                tint: plant.remindersEnabled ? Color.goTeal : Color.goYellow,
                destination: .reminders
            ),
            item(
                id: "healthReview",
                title: l.tr(zh: "健康观察", en: "Health review", de: "Gesundheitscheck"),
                value: healthReviewSignalCount == 0 ? "OK" : "\(healthReviewSignalCount)",
                subtitle: recentHealthReviewCount == 0
                    ? l.tr(zh: "记录首次复查", en: "Log first check", de: "Ersten Check erfassen")
                    : l.tr(zh: "30 天 \(recentHealthReviewCount) 条观察", en: "\(recentHealthReviewCount) notes in 30 days", de: "\(recentHealthReviewCount) Notizen in 30 Tagen"),
                icon: "waveform.path.ecg",
                tint: healthReviewSignalCount == 0 ? Color.goTeal : Color.goYellow,
                destination: .healthReview
            ),
            item(
                id: "catalog",
                title: l.tr(zh: "资料库", en: "Catalog", de: "Katalog"),
                value: plant.catalogSpeciesId.isEmpty ? l.tr(zh: "待补", en: "Open", de: "Offen") : l.tr(zh: "已匹配", en: "Matched", de: "Gefunden"),
                subtitle: plant.species.isEmpty ? l.tr(zh: "补齐品种", en: "Add species", de: "Art ergänzen") : plant.species,
                icon: "books.vertical.fill",
                tint: Color.goYellow,
                destination: .catalog
            ),
            item(
                id: "safety",
                title: l.tr(zh: "家庭安全", en: "Safety", de: "Sicherheit"),
                value: safetyWarningCount == 0 ? "OK" : "\(safetyWarningCount)",
                subtitle: safetyWarningCount == 0
                    ? l.tr(zh: "低风险", en: "Low risk", de: "Geringes Risiko")
                    : l.tr(zh: "需要复核", en: "Needs review", de: "Prüfen"),
                icon: "shield.checkered",
                tint: safetyWarningCount == 0 ? Color.goTeal : Color.goYellow,
                destination: .safety
            )
        ]
    }

    private var archiveItems: [FeatureHubDestinationItem<PlantFeatureDestination>] {
        [
            item(
                id: "profile",
                title: l.tr(zh: "植物档案", en: "Profile", de: "Profil"),
                value: "\(profileCompletionPercent)%",
                subtitle: l.tr(zh: "身份、位置、盆土", en: "Identity, place, potting", de: "Identität, Ort, Topf"),
                icon: "list.clipboard.fill",
                tint: themeColor,
                destination: .profile
            ),
            item(
                id: "photos",
                title: l.tr(zh: "成长照片", en: "Photos", de: "Fotos"),
                value: "\(photoCount)",
                subtitle: photoCount == 0
                    ? l.tr(zh: "等待照片记录", en: "Waiting for photo logs", de: "Wartet auf Fotos")
                    : l.tr(zh: "查看图库", en: "Open gallery", de: "Galerie öffnen"),
                icon: "photo.stack.fill",
                tint: Color.goTeal,
                destination: .photos
            ),
            item(
                id: "timeline",
                title: l.tr(zh: "护理时间线", en: "Timeline", de: "Zeitachse"),
                value: "\(logCount)",
                subtitle: logCount == 0
                    ? l.tr(zh: "还没有记录", en: "No logs yet", de: "Noch keine Einträge")
                    : l.tr(zh: "查看历史", en: "Review history", de: "Verlauf ansehen"),
                icon: "clock.arrow.circlepath",
                tint: Color.goOrange,
                destination: .timeline
            )
        ]
    }

    private func item(
        id: String,
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        destination: PlantFeatureDestination
    ) -> FeatureHubDestinationItem<PlantFeatureDestination> {
        FeatureHubDestinationItem(
            data: FeatureHubTileData(
                id: id,
                title: title,
                value: value.isEmpty ? "--" : value,
                subtitle: subtitle,
                icon: icon,
                tint: tint
            ),
            destination: destination
        )
    }

    private func task(for type: PlantCareType) -> PlantCareTaskSnapshot? {
        careTasks.first { $0.careType == type }
    }

    private func tasks(for category: PlantCareCategory) -> [PlantCareTaskSnapshot] {
        careTasks.filter { category.contains($0.careType) }
    }

    private func dueValue(for category: PlantCareCategory) -> String {
        let categoryTasks = tasks(for: category)
        let dueCount = categoryTasks.count { $0.daysUntilDue <= 0 }
        if dueCount > 0 {
            return "\(dueCount)"
        }
        guard let next = categoryTasks.first else {
            return category == .growth ? "\(photoCount)" : "--"
        }
        if next.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return "\(next.daysUntilDue)d"
    }

    private func categorySubtitle(for category: PlantCareCategory) -> String {
        let categoryTasks = tasks(for: category)
        let dueCount = categoryTasks.count { $0.daysUntilDue <= 0 }
        if dueCount > 0 {
            return l.tr(zh: "\(dueCount) 项今天到期", en: "\(dueCount) due today", de: "\(dueCount) heute fällig")
        }
        if let next = categoryTasks.first {
            return next.subtitle
        }
        if category == .growth {
            return l.tr(zh: "拍照、新叶、备注观察", en: "Photos, new leaves, and notes", de: "Fotos, neue Blätter und Notizen")
        }
        let names = category.careTypes
            .map { $0.displayName(l: l) }
            .joined(separator: " / ")
        return names
    }

    private func dueValue(for type: PlantCareType) -> String {
        guard let task = task(for: type) else {
            return "--"
        }
        if task.daysUntilDue <= 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return "\(task.daysUntilDue)d"
    }

    private func dueSubtitle(for type: PlantCareType) -> String {
        guard let task = task(for: type) else {
            return l.tr(zh: "快速记录", en: "Quick log", de: "Schnell erfassen")
        }
        return task.subtitle
    }

    private func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            return l.tr(zh: "逾期", en: "Overdue", de: "Überfällig")
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return "\(task.daysUntilDue)d"
    }

    private func destination(for task: PlantCareTaskSnapshot) -> PlantFeatureDestination {
        switch task.careType.careCategory {
        case .hydration:
            .water
        case .nutrition:
            .fertilize
        case .maintenance:
            .maintenance
        case .health:
            .health
        case .growth:
            .growth
        }
    }

    private func careTint(for careType: PlantCareType) -> Color {
        careType.careCategory.tint
    }

    private func careSymbol(for careType: PlantCareType) -> String {
        switch careType {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .misting:
            "cloud.drizzle.fill"
        case .pestCheck, .pestFound:
            "ladybug.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .leafCleaning:
            "sparkles"
        case .newLeaf:
            "leaf.circle.fill"
        case .repotting:
            "shippingbox.fill"
        case .pruning:
            "scissors"
        case .rotating:
            "arrow.triangle.2.circlepath"
        case .photo:
            "camera.fill"
        case .customNote:
            "note.text"
        }
    }
}
