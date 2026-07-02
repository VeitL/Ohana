//
//  PlantAllFeaturesSheet.swift
//  Ohana
//
//  Feature hub for plant detail pages.
//

import SwiftUI

enum PlantFeatureDestination: Hashable {
    case water
    case fertilize
    case pestCheck
    case leafCleaning
    case carePlan
    case calendar
    case reminders
    case healthReview
    case profile
    case photos
    case timeline
    case catalog
    case safety
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
    @AppStorage("appLanguage") private var appLanguage = "zh"

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
                            imageData: plant.avatarImageData,
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
        dismiss()
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            onOpenDestination(destination)
        }
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
                destination: .healthReview
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
                destination: .photos
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
            tint: Color.goLime,
            destination: .carePlan
        )
    }

    private var focusActionBanner: some View {
        let action = focusAction
        return Button {
            open(action.destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon) // a11y: allow decorative priority glyph; the banner label names the action.
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(action.tint)
                    .frame(width: 44, height: 44)
                    .background(action.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.eyebrow)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Text(action.title)
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(action.detail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative priority navigation glyph; button label is explicit.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
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
                title: l.tr(zh: "高频照护", en: "Daily Care", de: "Tägliche Pflege"),
                subtitle: l.tr(zh: "打卡、复查和日常动作", en: "Logs, checks, and routine actions", de: "Einträge, Checks und Routinen"),
                items: dailyItems
            ),
            FeatureHubSectionData(
                id: "plan",
                title: l.tr(zh: "计划与诊断", en: "Plan and Checks", de: "Plan und Checks"),
                subtitle: l.tr(zh: "护理节奏、资料库和安全", en: "Cadence, catalog, and safety", de: "Rhythmus, Katalog und Sicherheit"),
                items: planItems
            ),
            FeatureHubSectionData(
                id: "archive",
                title: l.tr(zh: "档案与回顾", en: "Archive", de: "Archiv"),
                subtitle: l.tr(zh: "档案、照片和时间线", en: "Profile, photos, and timeline", de: "Profil, Fotos und Zeitachse"),
                items: archiveItems
            )
        ]
    }

    private var dailyItems: [FeatureHubDestinationItem<PlantFeatureDestination>] {
        [
            item(
                id: "water",
                title: l.tr(zh: "浇水", en: "Water", de: "Gießen"),
                value: dueValue(for: .watering),
                subtitle: dueSubtitle(for: .watering),
                icon: "drop.fill",
                tint: Color.goTeal,
                destination: .water
            ),
            item(
                id: "fertilize",
                title: l.tr(zh: "施肥", en: "Fertilize", de: "Düngen"),
                value: dueValue(for: .fertilizing),
                subtitle: dueSubtitle(for: .fertilizing),
                icon: "leaf.fill",
                tint: Color.goLime,
                destination: .fertilize
            ),
            item(
                id: "pest",
                title: l.tr(zh: "病虫复查", en: "Pest check", de: "Schädlingscheck"),
                value: dueValue(for: .pestCheck),
                subtitle: plant.healthStatus == .stressed
                    ? l.tr(zh: "优先排查", en: "Inspect first", de: "Zuerst prüfen")
                    : dueSubtitle(for: .pestCheck),
                icon: "ladybug.fill",
                tint: Color.goYellow,
                destination: .pestCheck
            ),
            item(
                id: "clean",
                title: l.tr(zh: "清洁叶片", en: "Clean leaves", de: "Blätter reinigen"),
                value: dueValue(for: .leafCleaning),
                subtitle: dueSubtitle(for: .leafCleaning),
                icon: "sparkles",
                tint: Color.goTeal,
                destination: .leafCleaning
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
                tint: Color.goLime,
                destination: .carePlan
            ),
            item(
                id: "calendar",
                title: l.tr(zh: "护理日历", en: "Care calendar", de: "Pflegekalender"),
                value: dueTaskCount == 0 ? "7d" : "\(dueTaskCount)",
                subtitle: plant.remindersEnabled
                    ? l.tr(zh: "计划会同步到日历和本地提醒", en: "Plans sync to Calendar and local alerts", de: "Pläne werden mit Kalender und lokalen Hinweisen synchronisiert")
                    : l.tr(zh: "开启提醒后恢复日历计划", en: "Turn reminders on to restore calendar plans", de: "Aktiviere Hinweise, um Kalenderpläne wiederherzustellen"),
                icon: "calendar.badge.clock",
                tint: plant.remindersEnabled ? Color.goLime : Color.goYellow,
                destination: .calendar
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
        switch task.careType {
        case .watering, .misting:
            .water
        case .fertilizing, .newLeaf:
            .fertilize
        case .pestCheck, .pestFound, .yellowLeaf:
            .pestCheck
        case .leafCleaning:
            .leafCleaning
        default:
            .carePlan
        }
    }

    private func careTint(for careType: PlantCareType) -> Color {
        switch careType {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goLime
        case .pestCheck, .pestFound, .yellowLeaf:
            Color.goYellow
        default:
            Color.goYellow
        }
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
        default:
            "slider.horizontal.3"
        }
    }
}
