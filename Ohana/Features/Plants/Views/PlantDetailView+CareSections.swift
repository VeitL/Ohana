//
//  PlantDetailView+CareSections.swift
//  Ohana
//
//  Extracted Plant view sections.
//

import SwiftUI

extension PlantDetailContentView {
    var careOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "植物状态", en: "Plant status", de: "Pflanzenstatus"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(healthSummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 12)
                statusPill(
                    icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "leaf.fill",
                    title: plant.healthStatus.displayName,
                    tint: healthTone
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                overviewMetric(
                    icon: "calendar.badge.clock",
                    title: l.tr(zh: "待办", en: "Due", de: "Fällig"),
                    value: dueTaskCount == 0
                        ? l.tr(zh: "无到期", en: "None due", de: "Nichts fällig")
                        : l.tr(zh: "\(dueTaskCount) 项到期", en: "\(dueTaskCount) due", de: "\(dueTaskCount) fällig"),
                    tint: dueTaskCount == 0 ? Color.goTeal : Color.goYellow
                )
                overviewMetric(
                    icon: "arrow.forward.circle.fill",
                    title: l.tr(zh: "下一步", en: "Next", de: "Nächstes"),
                    value: nextTask.map { dueText(for: $0) } ?? l.tr(zh: "无计划", en: "No plan", de: "Kein Plan"),
                    tint: nextTask?.isOverdue == true ? Color.goRed : Color.goPrimary
                )
                overviewMetric(
                    icon: "drop.fill",
                    title: l.tr(zh: "浇水", en: "Water", de: "Gießen"),
                    value: wateringStatusText,
                    tint: isWateringDue ? Color.goYellow : Color.goTeal
                )
                overviewMetric(
                    icon: "mappin.and.ellipse",
                    title: l.tr(zh: "位置", en: "Place", de: "Ort"),
                    value: placementSummary,
                    tint: Color.goPrimary
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-detail-health-summary")
        .padding(.horizontal, 16)
    }

    var actionQueueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist.checked") // a11y: allow decorative queue glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive queue glyph; text carries the accessible content.
                    .background(Color.goPrimary.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "今日行动队列", en: "Today's action queue", de: "Aktionsliste heute"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(actionQueueSummary)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("\(profileCompletionPercent)%")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.goPrimary, in: Capsule())
                    .accessibilityLabel(l.tr(zh: "档案完成度 \(profileCompletionPercent)%", en: "Profile \(profileCompletionPercent)% complete", de: "Profil zu \(profileCompletionPercent)% vollständig"))
            }

            VStack(spacing: 10) {
                ForEach(careActionItems) { item in
                    actionQueueRow(item)
                }
            }

            actionQueueToolRail
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-queue")
        .padding(.horizontal, 16)
    }

    var actionQueueSummary: String {
        if dueTaskCount > 0 {
            return l.tr(
                zh: "\(dueTaskCount) 项照护到期，先完成高优先级动作。",
                en: "\(dueTaskCount) care tasks are due; start with the highest priority actions.",
                de: "\(dueTaskCount) Pflegeaufgaben sind fällig; mit hoher Priorität beginnen."
            )
        }
        if plant.healthStatus == .watching || plant.healthStatus == .stressed {
            return l.tr(
                zh: "当前重点是观察和复查，避免问题拖到下一次提醒。",
                en: "Focus on observation and checks before the next reminder.",
                de: "Beobachtung und Checks vor der nächsten Erinnerung priorisieren."
            )
        }
        if !profileMissingItems.isEmpty {
            return l.tr(
                zh: "没有紧急照护，适合补齐档案让计划更准确。",
                en: "No urgent care; complete the profile so the plan gets smarter.",
                de: "Keine dringende Pflege; Profil ergänzen, damit der Plan genauer wird."
            )
        }
        return l.tr(
            zh: "节奏稳定，可以做一次轻量观察或提前处理下一项。",
            en: "The rhythm is stable; log a small observation or handle the next item early.",
            de: "Der Rhythmus ist stabil; kleine Beobachtung oder nächste Aufgabe vorziehen."
        )
    }

    func actionQueueRow(_ item: PlantDetailActionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.icon) // a11y: allow decorative row glyph; row text and buttons carry context.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive action glyph; row label carries content.
                    .background(item.tint, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.detail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    performActionQueueItem(item)
                } label: {
                    Text(item.primaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minWidth: 92, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(item.tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(actionQueuePrimaryAccessibilityLabel(item))
                .accessibilityIdentifier("plant-detail-action-primary-\(item.id)")

                if let task = item.task, task.daysUntilDue <= 0 {
                    Button {
                        deferTaskOneDay(task)
                    } label: {
                        Text(l.tr(zh: "延后一天", en: "Defer 1 day", de: "1 Tag später"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(minWidth: 92, minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "延后\(task.title)一天", en: "Defer \(task.title) by one day", de: "\(task.title) um einen Tag verschieben"))
                    .accessibilityIdentifier("plant-detail-action-defer-\(item.id)")

                    Button {
                        skipTask(task)
                    } label: {
                        Text(l.tr(zh: "跳过", en: "Skip", de: "Überspringen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(minWidth: 68, minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "跳过\(task.title)", en: "Skip \(task.title)", de: "\(task.title) überspringen"))
                    .accessibilityIdentifier("plant-detail-action-skip-\(item.id)")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-item-\(item.id)")
    }

    var actionQueueToolRail: some View {
        HStack(spacing: 8) {
            actionQueueToolButton(
                id: "reminders",
                icon: plant.remindersEnabled ? "bell.badge.fill" : "bell.slash.fill",
                title: l.tr(zh: "提醒", en: "Reminders", de: "Hinweise"),
                subtitle: plant.remindersEnabled
                    ? l.tr(zh: "开启", en: "On", de: "An")
                    : l.tr(zh: "关闭", en: "Off", de: "Aus"),
                tint: plant.remindersEnabled ? Color.goPrimary : Color.goYellow,
                action: openReminderSettings
            )

            actionQueueToolButton(
                id: "photos",
                icon: "photo.on.rectangle.angled",
                title: l.tr(zh: "照片", en: "Photos", de: "Fotos"),
                subtitle: galleryPhotoItems.isEmpty
                    ? l.tr(zh: "补照片", en: "Add", de: "Ergänzen")
                    : l.tr(zh: "\(galleryPhotoItems.count) 张", en: "\(galleryPhotoItems.count)", de: "\(galleryPhotoItems.count)"),
                tint: galleryPhotoItems.isEmpty ? Color.goYellow : Color.goTeal,
                action: openPlantPhotos
            )
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-tools")
    }

    func actionQueueToolButton(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon) // a11y: allow decorative tool glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72, alignment: .center)
            .padding(.horizontal, 10)
            .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier("plant-detail-action-tool-\(id)")
    }

    func actionQueuePrimaryAccessibilityLabel(_ item: PlantDetailActionItem) -> String {
        "\(item.primaryTitle), \(item.title)"
    }

    var nextTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles") // a11y: allow decorative section glyph; heading names the next task.
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "下一步", en: "Next step", de: "Nächster Schritt"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            if let task = nextTask {
                Text(task.title)
                    .font(OhanaFont.adaptive(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(task.explanation)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button(l.tr(zh: "完成", en: "Done", de: "Erledigt")) {
                            openCareLogSheet(task.careType)
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                        .background(Color.goPrimary, in: Capsule())
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-detail-next-task-complete")

                        Button(l.tr(zh: "延后一天", en: "Defer one day", de: "Um einen Tag verschieben")) {
                            deferTaskOneDay(task)
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-detail-next-task-defer")
                    }

                    HStack(spacing: 10) {
                        Button(l.tr(zh: "跳过这项", en: "Skip task", de: "Aufgabe überspringen")) {
                            skipTask(task)
                        }
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-detail-next-task-skip")

                        if task.careType == .watering {
                            Button(l.tr(zh: "土还湿，延后", en: "Soil still wet, defer", de: "Erde noch feucht, verschieben")) {
                                deferTaskOneDay(task, reason: "soilWet")
                            }
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 14)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityIdentifier("plant-detail-next-task-soil-wet-defer")
                        }
                    }
                }
            } else {
                Text(l.tr(zh: "暂无任务", en: "No tasks yet", de: "Noch keine Aufgaben"))
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    var careRhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "metronome.fill", title: l.tr(zh: "护理节奏", en: "Care rhythm", de: "Pflegerhythmus"))
            rhythmRow(
                icon: "drop.fill",
                title: l.tr(zh: "浇水", en: "Watering", de: "Gießen"),
                status: wateringStatusText,
                detail: wateringIntervalText,
                tint: isWateringDue ? Color.goYellow : Color.goTeal,
                progress: plant.daysSinceWatered.map { min(1, Double($0) / Double(max(wateringIntervalDays, 1))) }
            )
            rhythmRow(
                icon: "leaf.fill",
                title: l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen"),
                status: fertilizingStatusText,
                detail: fertilizingIntervalText,
                tint: isFertilizingDue ? Color.goYellow : Color.goPrimary,
                progress: plant.daysSinceFertilized.map { min(1, Double($0) / Double(max(fertilizingIntervalDays, 1))) }
            )
            if let pestTask = taskSummary?.pestCheckTask {
                rhythmRow(
                    icon: "ladybug.fill",
                    title: PlantCareType.pestCheck.displayName(l: l),
                    status: dueText(for: pestTask),
                    detail: pestTask.subtitle,
                    tint: pestTask.isOverdue ? Color.goRed : Color.goYellow,
                    progress: nil
                )
            }
            if let cleaningTask = taskSummary?.leafCleaningTask {
                rhythmRow(
                    icon: "sparkles",
                    title: PlantCareType.leafCleaning.displayName(l: l),
                    status: dueText(for: cleaningTask),
                    detail: cleaningTask.subtitle,
                    tint: cleaningTask.isOverdue ? Color.goRed : Color.goTeal,
                    progress: nil
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-care-rhythm")
        .padding(.horizontal, 16)
    }

    var carePlanInsightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "slider.horizontal.3", title: l.tr(zh: "计划依据", en: "Plan reasoning", de: "Planlogik"))
            Text(l.tr(
                zh: "Ohana 会把资料库、环境、历史记录和健康状态合并成当前护理节奏。",
                en: "Ohana combines catalog, environment, history, and health to shape the current cadence.",
                de: "Ohana kombiniert Katalog, Umgebung, Verlauf und Zustand zum aktuellen Rhythmus."
            ))
            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(carePlanInsights.prefix(4)) { insight in
                    carePlanInsightRow(insight)
                }
            }

            Button {
                showingEditSheet = true
            } label: {
                Text(l.tr(zh: "调整植物档案", en: "Adjust plant profile", de: "Pflanzenprofil anpassen"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-detail-care-plan-edit-profile")
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-care-plan-insights")
        .padding(.horizontal, 16)
    }

    var placementFitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "mappin.and.ellipse", title: l.tr(zh: "位置适配", en: "Placement fit", de: "Standort-Eignung"))
            Text(l.tr(
                zh: "只做轻量判断：光照、安全和小环境够不够合适。",
                en: "A light check only: light, safety, and microclimate.",
                de: "Nur ein leichter Check: Licht, Sicherheit und Mikroklima."
            ))
            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(placementFitItems) { item in
                    placementFitRow(item)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-placement-fit")
        .padding(.horizontal, 16)
    }

    func placementFitRow(_ item: PlantPlacementFitItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon) // a11y: allow decorative placement glyph; row text carries the recommendation.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34) // a11y: allow non-interactive placement glyph; row text carries the recommendation.
                .background(item.tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-placement-fit-\(item.id)")
    }

    var seasonalGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "cloud.sun.fill", title: l.tr(zh: "天气/季节影响", en: "Weather and season", de: "Wetter und Saison"))
            VStack(alignment: .leading, spacing: 4) {
                Text(seasonalGuidanceTitle)
                    .font(OhanaFont.adaptive(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(seasonalGuidanceSummary)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(seasonalCareItems) { item in
                    seasonalGuidanceRow(item)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-seasonal-guidance")
        .padding(.horizontal, 16)
    }

    func seasonalGuidanceRow(_ item: PlantSeasonalCareItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon) // a11y: allow decorative seasonal glyph; row text carries the guidance.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34) // a11y: allow non-interactive seasonal glyph; row text carries the guidance.
                .background(item.tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-seasonal-guidance-\(item.id)")
    }

    func carePlanInsightRow(_ insight: PlantCarePlanInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon) // a11y: allow decorative plan-reason glyph; row text carries the insight.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 44, height: 44)
                .background(insight.tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    var environmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "sun.max.fill", title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"))
            detailRow(l.tr(zh: "房间", en: "Room", de: "Raum"), value: plant.roomName.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.roomName)
            detailRow(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), value: plant.location.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.location)
            detailRow(l.tr(zh: "场景", en: "Scene", de: "Standortart"), value: plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "阳台/花园", en: "Balcony/garden", de: "Balkon/Garten"))
            detailRow(l.tr(zh: "窗向", en: "Window", de: "Fenster"), value: plant.windowDirection.displayName)
            detailRow(l.tr(zh: "光照", en: "Light", de: "Licht"), value: plant.lightLevel.displayName)
            if plant.lastLightMeasurementLux > 0 {
                detailRow(l.tr(zh: "光照实测", en: "Light reading", de: "Lichtmessung"), value: "\(plant.lastLightMeasurementLux) lux\(plant.lastLightMeasurementDate.map { " · \(shortDate($0))" } ?? "")")
            }
            detailRow(l.tr(zh: "湿度偏好", en: "Humidity preference", de: "Luftfeuchte"), value: plant.humidityPreference.displayName)
            detailRow(l.tr(zh: "温度偏好", en: "Temperature preference", de: "Temperatur"), value: plant.temperaturePreference.displayName)
            if plant.isNearClimateSource {
                detailRow(l.tr(zh: "环境风险", en: "Environment risk", de: "Umgebungsrisiko"), value: l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"))
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    var growthProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "ruler.fill", title: l.tr(zh: "盆土与成长", en: "Potting and growth", de: "Topf und Wachstum"))
            if plant.potDiameterCm > 0 {
                detailRow(l.tr(zh: "盆径", en: "Pot diameter", de: "Topfdurchmesser"), value: "\(Int(plant.potDiameterCm)) cm")
            }
            detailRow(l.tr(zh: "排水孔", en: "Drainage hole", de: "Abzugsloch"), value: plant.potHasDrainage ? l.tr(zh: "有", en: "Yes", de: "Ja") : l.tr(zh: "无", en: "No", de: "Nein"))
            if !plant.potMaterial.isEmpty {
                detailRow(l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), value: plant.potMaterial)
            }
            if !plant.soilType.isEmpty {
                detailRow(l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: plant.soilType)
            }
            if plant.currentHeightCm > 0 || plant.currentSpreadCm > 0 {
                detailRow(
                    l.tr(zh: "当前尺寸", en: "Current size", de: "Aktuelle Größe"),
                    value: l.tr(
                        zh: "\(Int(plant.currentHeightCm)) cm 高 · \(Int(plant.currentSpreadCm)) cm 冠幅",
                        en: "\(Int(plant.currentHeightCm)) cm tall · \(Int(plant.currentSpreadCm)) cm spread",
                        de: "\(Int(plant.currentHeightCm)) cm hoch · \(Int(plant.currentSpreadCm)) cm breit"
                    )
                )
            }
            if let acquiredDate = plant.acquiredDate {
                detailRow(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), value: shortDate(acquiredDate))
            }
            if !plant.acquisitionSource.isEmpty {
                detailRow(l.tr(zh: "来源", en: "Source", de: "Quelle"), value: plant.acquisitionSource)
            }
            let typeSummary = [
                plant.isHydroponic ? l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur") : nil,
                plant.isSucculent ? l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus") : nil
            ].compactMap(\.self).joined(separator: " · ")
            if !typeSummary.isEmpty {
                detailRow(l.tr(zh: "类型", en: "Type", de: "Typ"), value: typeSummary)
            }
            if plant.potDiameterCm == 0,
               plant.potMaterial.isEmpty,
               plant.soilType.isEmpty,
               plant.currentHeightCm == 0,
               plant.currentSpreadCm == 0,
               plant.acquiredDate == nil,
               plant.acquisitionSource.isEmpty,
               typeSummary.isEmpty {
                Text(l.tr(
                    zh: "还没有补充盆土、尺寸和来源信息。完善后，护理计划会更像一份真正的植物档案。",
                    en: "Potting, size, and source details are still empty. Completing them makes this feel like a real plant profile.",
                    de: "Topf-, Größen- und Herkunftsdetails fehlen noch. Mit ihnen wirkt das Profil wie eine echte Pflanzenakte."
                ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-growth-profile")
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    var safetyCard: some View {
        if plant.isToxicToCats || plant.isToxicToDogs || plant.isToxicToChildren || !plant.isIndoorSuitable {
            VStack(alignment: .leading, spacing: 10) {
                detailHeader(icon: "exclamationmark.triangle.fill", title: l.tr(zh: "安全提示", en: "Safety note", de: "Sicherheitshinweis"))
                if onboardingHasPets, plant.isToxicToCats || plant.isToxicToDogs {
                    Text(l.tr(
                        zh: "对猫/狗有误食风险，请放在宠物够不到的位置。",
                        en: "May be risky if cats or dogs chew it. Keep it out of pets' reach.",
                        de: "Kann bei Katzen oder Hunden beim Anknabbern riskant sein. Außer Reichweite von Haustieren stellen."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if onboardingHasChildren, plant.isToxicToChildren {
                    Text(l.tr(
                        zh: "对儿童有误食刺激风险，提醒文案会优先提示安全摆放。",
                        en: "May irritate children if eaten. Reminders will prioritize safe placement.",
                        de: "Kann Kinder beim Verschlucken reizen. Erinnerungen betonen eine sichere Platzierung."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if (!onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
                    (!onboardingHasChildren && plant.isToxicToChildren) {
                    Text(l.tr(
                        zh: "资料库标记存在误食风险；若家里之后有宠物或儿童，可以在设置/详情中优先关注摆放安全。",
                        en: "The catalog marks an ingestion risk. If pets or children join later, prioritize safe placement in Settings or details.",
                        de: "Der Katalog markiert ein Verschluckrisiko. Wenn später Haustiere oder Kinder dazukommen, sichere Platzierung in Einstellungen oder Details priorisieren."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if !plant.isIndoorSuitable {
                    Text(l.tr(
                        zh: "资料库标记为不太适合室内长期养护。",
                        en: "The catalog marks this as less suitable for long-term indoor care.",
                        de: "Der Katalog markiert sie als weniger geeignet für langfristige Innenpflege."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    var catalogCard: some View {
        if let catalogEntry {
            VStack(alignment: .leading, spacing: 12) {
                detailHeader(icon: "books.vertical.fill", title: l.tr(zh: "资料库", en: "Catalog", de: "Katalog"))
                detailRow(l.tr(zh: "拉丁名", en: "Latin name", de: "Lateinischer Name"), value: catalogEntry.latinName)
                detailRow(l.tr(zh: "浇水", en: "Watering", de: "Gießen"), value: catalogEntry.localizedWateringPreference)
                detailRow(l.tr(zh: "湿度", en: "Humidity", de: "Luftfeuchte"), value: catalogEntry.localizedHumidity)
                detailRow(l.tr(zh: "温度", en: "Temperature", de: "Temperatur"), value: catalogEntry.localizedTemperature)
                detailRow(l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: catalogEntry.localizedSoil)
                detailRow(l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen"), value: catalogEntry.localizedFertilizing)
                detailRow(l.tr(zh: "繁殖", en: "Propagation", de: "Vermehrung"), value: catalogEntry.localizedPropagation)
                detailRow(l.tr(zh: "修剪", en: "Pruning", de: "Schnitt"), value: catalogEntry.localizedPruning)
                detailRow(l.tr(zh: "常见问题", en: "Common issues", de: "Häufige Probleme"), value: catalogEntry.localizedCommonIssues)
                detailRow(l.tr(zh: "毒性", en: "Toxicity", de: "Toxizität"), value: catalogEntry.localizedToxicity)
                detailRow(l.tr(zh: "难度", en: "Difficulty", de: "Schwierigkeit"), value: catalogEntry.localizedCareDifficulty)
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .accessibilityIdentifier("plant-detail-catalog-profile")
            .padding(.horizontal, 16)
        }
    }

    var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "stethoscope", title: l.tr(zh: "病虫害诊断", en: "Pest and disease check", de: "Schädlings- und Krankheitscheck"))
            Text(diagnosisResult?.uncertaintyMessage ?? l.tr(
                zh: "当前未连接智能诊断服务，Ohana 会展示不确定性和可执行复查步骤。",
                en: "Smart diagnosis is not connected yet. Ohana shows uncertainty and actionable recheck steps.",
                de: "Die intelligente Diagnose ist noch nicht verbunden. Ohana zeigt Unsicherheit und konkrete Schritte zur Kontrolle."
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach((diagnosisResult?.causes ?? []).prefix(3)) { cause in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cause.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(cause.severity)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.goYellow, in: Capsule())
                    }
                    Text(cause.steps.prefix(2).joined(separator: " · "))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(3)
                    Text(cause.shouldIsolate
                        ? l.tr(zh: "建议先隔离，\(cause.recheckAfterDays) 天后复查", en: "Isolate first; recheck in \(cause.recheckAfterDays) days", de: "Zuerst isolieren; in \(cause.recheckAfterDays) Tagen prüfen")
                        : l.tr(zh: "\(cause.recheckAfterDays) 天后复查", en: "Recheck in \(cause.recheckAfterDays) days", de: "In \(cause.recheckAfterDays) Tagen prüfen"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(cause.shouldIsolate ? Color.goRed : Color.ohanaSecondaryText)
                }
                .padding(10)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
            diagnosisQuickActions
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-diagnosis-card")
        .padding(.horizontal, 16)
    }

    var diagnosisQuickActions: some View {
        HStack(spacing: 8) {
            diagnosisActionButton(
                type: .pestCheck,
                icon: "ladybug.fill",
                tint: Color.goPrimary,
                isSubtle: false,
                identifier: "plant-detail-diagnosis-pest-check",
                accessibilityText: l.tr(zh: "记录\(plant.name)的病虫害复查", en: "Log a pest check for \(plant.name)", de: "Schädlingscheck für \(plant.name) erfassen")
            )
            diagnosisActionButton(
                type: .photo,
                icon: "camera.fill",
                tint: Color.goTeal,
                isSubtle: false,
                identifier: "plant-detail-diagnosis-photo",
                accessibilityText: l.tr(zh: "为\(plant.name)添加诊断照片", en: "Add a diagnosis photo for \(plant.name)", de: "Diagnosefoto für \(plant.name) hinzufügen")
            )
            diagnosisActionButton(
                type: .pestFound,
                icon: "exclamationmark.triangle.fill",
                tint: Color.goYellow,
                isSubtle: true,
                identifier: "plant-detail-diagnosis-pest-found",
                accessibilityText: l.tr(zh: "记录\(plant.name)发现虫害", en: "Log pest found for \(plant.name)", de: "Schädlingsfund für \(plant.name) erfassen")
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-diagnosis-actions")
    }

    func diagnosisActionButton(
        type: PlantCareType,
        icon: String,
        tint: Color,
        isSubtle: Bool,
        identifier: String,
        accessibilityText: String
    ) -> some View {
        Button {
            openCareLogSheet(type)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon) // a11y: allow decorative diagnosis-action glyph; text names the action.
                    .font(OhanaFont.adaptive(size: 10, weight: .black))
                    .accessibilityHidden(true)
                Text(type.displayName(l: l))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSubtle ? Color.ohanaPrimaryText : Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(tint.opacity(isSubtle ? 0.22 : 1), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(identifier)
    }
}
