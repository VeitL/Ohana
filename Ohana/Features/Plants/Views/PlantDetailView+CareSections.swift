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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    careOverviewTitleBlock
                    Spacer(minLength: 12)
                    careOverviewStatusPill
                }

                VStack(alignment: .leading, spacing: 10) {
                    careOverviewTitleBlock
                    careOverviewStatusPill
                }
            }

            LazyVGrid(columns: careOverviewMetricColumns, spacing: 14) {
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

    var careOverviewMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 132), spacing: 14)]
    }

    var careOverviewTitleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.tr(zh: "植物状态", en: "Plant status", de: "Pflanzenstatus"))
                .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(healthSummaryText)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var careOverviewStatusPill: some View {
        statusPill(
            icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "leaf.fill",
            title: plant.healthStatus.displayName,
            tint: healthTone
        )
    }

    var todayCarePanelTasks: [PlantCareTaskSnapshot] {
        if let tasks = taskSummary?.todayCareTasks, !tasks.isEmpty {
            return tasks
        }
        if let nextTask {
            return [nextTask]
        }
        return []
    }

    var todayCarePanelSubtitle: String {
        if dueTaskCount > 0 {
            return l.tr(
                zh: "\(dueTaskCount) 项待办，点名称看详情，点右侧快速记录。",
                en: "\(dueTaskCount) due. Tap a name for details or the right button to quick log.",
                de: "\(dueTaskCount) fällig. Name öffnet Details, rechter Button erfasst schnell."
            )
        }
        if let nextTask {
            return l.tr(
                zh: "今天清爽。下一项是 \(nextTask.careType.displayName(l: l))。",
                en: "Clear today. Next is \(nextTask.careType.displayName(l: l)).",
                de: "Heute frei. Als Nächstes: \(nextTask.careType.displayName(l: l))."
            )
        }
        return l.tr(zh: "还没有护理计划。", en: "No care plan yet.", de: "Noch kein Pflegeplan.")
    }

    var todayCarePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: dueTaskCount > 0 ? "calendar.badge.clock" : "checkmark.seal.fill") // a11y: allow decorative today-care status glyph; heading and count describe the state.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(dueTaskCount > 0 ? Color.goYellow : Color.goTeal)
                    .frame(width: 44, height: 44)
                    .background((dueTaskCount > 0 ? Color.goYellow : Color.goTeal).opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dueTaskCount > 0
                        ? l.tr(zh: "今日待护理", en: "Due today", de: "Heute fällig")
                        : l.tr(zh: "今日护理", en: "Today care", de: "Pflege heute"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(todayCarePanelSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(dueTaskCount > 0 ? "\(dueTaskCount)" : "0")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(dueTaskCount > 0 ? Color.arkInk : Color.ohanaPrimaryText)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(dueTaskCount > 0 ? Color.goYellow : Color.ohanaControlFill.opacity(0.72), in: Circle())
                    .accessibilityLabel(l.tr(zh: "今日到期 \(dueTaskCount) 项", en: "\(dueTaskCount) due today", de: "\(dueTaskCount) heute fällig"))
            }

            if todayCarePanelTasks.isEmpty {
                todayCareEmptyRow
            } else {
                VStack(spacing: 8) {
                    ForEach(todayCarePanelTasks) { task in
                        todayCareTaskRow(task)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-today-care-panel")
        .padding(.horizontal, 16)
    }

    var todayCareEmptyRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.circle.fill") // a11y: allow decorative empty-care glyph; row text describes the state.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.goPrimary.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "没有待办", en: "Nothing due", de: "Nichts fällig"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "需要补充观察时，可以从成长记录进入。", en: "Use growth record when you want to add an observation.", de: "Für Beobachtungen die Wachstumsakte nutzen."))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
            Button {
                openPlantCareFeatureDetail(for: .newLeaf)
            } label: {
                Image(systemName: "arrow.right") // a11y: allow decorative arrow; button label names the destination.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "打开成长记录详情", en: "Open growth record details", de: "Wachstumsdetails öffnen"))
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityIdentifier("plant-detail-today-care-empty")
    }

    func todayCareTaskRow(_ task: PlantCareTaskSnapshot) -> some View {
        let isPending = pendingDetailQuickCareTypes.contains(task.careType)
        let didComplete = completedDetailQuickCareTypes.contains(task.careType)
        let didFail = failedDetailQuickCareTypes.contains(task.careType)
        return HStack(spacing: 10) {
            Button {
                openPlantCareFeatureDetail(for: task.careType)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: careSymbol(for: task.careType)) // a11y: allow decorative care glyph inside labeled row button.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(careTint(for: task.careType), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.careType.displayName(l: l))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text("\(dueText(for: task)) · \(task.subtitle)")
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "打开\(task.careType.displayName(l: l))详情", en: "Open \(task.careType.displayName(l: l)) details", de: "\(task.careType.displayName(l: l))-Details öffnen"))
            .accessibilityIdentifier("plant-detail-today-care-detail-\(task.careType.rawValue)")

            Button {
                presentQuickCareConfirm(for: task)
            } label: {
                Image(systemName: isPending ? "hourglass" : didComplete ? "checkmark" : didFail ? "exclamationmark" : "bolt.fill")
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(isPending ? Color.ohanaTertiaryText : Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(isPending ? Color.ohanaControlFill.opacity(0.72) : careTint(for: task.careType), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isPending)
            .accessibilityLabel(l.tr(zh: "快速记录\(task.careType.displayName(l: l))", en: "Quick log \(task.careType.displayName(l: l))", de: "\(task.careType.displayName(l: l)) schnell erfassen"))
            .accessibilityIdentifier("plant-detail-today-care-quick-\(task.careType.rawValue)")
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-today-care-row-\(task.careType.rawValue)")
    }

    @ViewBuilder
    var plantQuickCareOverlay: some View {
        VStack(spacing: 10) {
            if let token = pendingBatchCareUndoToken {
                plantDetailBatchCareUndoCard(token)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast = quickCareToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative success glyph; toast text announces the result.
                        .foregroundStyle(Color.goPrimary)
                        .accessibilityHidden(true)
                    Text(toast.message)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .goGlassBackground(Capsule())
                .accessibilityIdentifier("plant-detail-quick-care-toast")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let draft = quickCareConfirmDraft {
                quickCareConfirmCard(draft)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .animation(GoMotion.feedback, value: quickCareConfirmDraft?.id)
        .animation(GoMotion.feedback, value: quickCareToast?.id)
        .animation(GoMotion.feedback, value: pendingBatchCareUndoToken?.id)
    }

    func quickCareConfirmCard(_ draft: PlantQuickCareConfirmDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: careSymbol(for: draft.careType)) // a11y: allow decorative quick-care glyph; card text names the care type.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(careTint(for: draft.careType), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.title)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(draft.detail)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button {
                    quickCareConfirmDraft = nil
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative close glyph; button label names the action.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Circle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭快速记录", en: "Close quick log", de: "Schnellerfassung schließen"))
            }

            HStack(spacing: 8) {
                Button {
                    recordQuickCare(draft.careType)
                } label: {
                    Label(l.tr(zh: "快速记录", en: "Quick log", de: "Schnell erfassen"), systemImage: "bolt.fill")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-detail-quick-care-quick-log")

                Button {
                    quickCareConfirmDraft = nil
                    openPlantCareFeatureDetail(for: draft.careType)
                } label: {
                    Label(l.tr(zh: "查看详情", en: "Details", de: "Details"), systemImage: "info.circle.fill")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-detail-quick-care-detail")
            }

            Button {
                openBatchQuickRecordFromDetail(careType: draft.careType)
            } label: {
                Label(
                    l.tr(zh: "选择更多植物", en: "Select more plants", de: "Weitere Pflanzen wählen"),
                    systemImage: "checklist"
                )
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityHint(l.tr(
                zh: "当前植物会保持选中，再选择其他植物后一次确认。",
                en: "Keeps this plant selected so you can add others and confirm once.",
                de: "Diese Pflanze bleibt ausgewählt; weitere können vor einer Bestätigung ergänzt werden."
            ))
            .accessibilityIdentifier("plant-detail-quick-care-select-more")
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-quick-care-popup")
    }

    func plantDetailBatchCareUndoCard(_ token: PlantBatchCareUndoToken) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative batch-success glyph; adjacent text describes the result.
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.goPrimary.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(
                    zh: "已为 \(token.items.count) 株植物记录",
                    en: "Logged care for \(token.items.count) plants",
                    de: "Pflege für \(token.items.count) Pflanzen erfasst"
                ))
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "6 秒内可整批撤销；奖励随后结算。",
                    en: "Undo the whole batch within 6 seconds; rewards settle after.",
                    de: "Gesamten Vorgang 6 Sekunden widerrufen; Belohnungen folgen danach."
                ))
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(l.tr(zh: "撤销", en: "Undo", de: "Widerrufen")) {
                undoPendingBatchCareFromDetail()
            }
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.goPrimary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("plant-detail-batch-care-undo")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-batch-care-result")
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
                plantDetailActionGrid {
                    plantDetailTextActionButton(
                        title: l.tr(zh: "完成", en: "Done", de: "Erledigt"),
                        foreground: Color.arkInk,
                        background: Color.goPrimary,
                        identifier: "plant-detail-next-task-complete"
                    ) {
                        openCareLogSheet(task.careType)
                    }

                    plantDetailTextActionButton(
                        title: l.tr(zh: "延后一天", en: "Defer one day", de: "Um einen Tag verschieben"),
                        identifier: "plant-detail-next-task-defer"
                    ) {
                        deferTaskOneDay(task)
                    }

                    plantDetailTextActionButton(
                        title: l.tr(zh: "跳过这项", en: "Skip task", de: "Aufgabe überspringen"),
                        identifier: "plant-detail-next-task-skip"
                    ) {
                        skipTask(task)
                    }

                    if task.careType == .watering {
                        plantDetailTextActionButton(
                            title: l.tr(zh: "土还湿，延后", en: "Soil still wet, defer", de: "Erde noch feucht, verschieben"),
                            identifier: "plant-detail-next-task-soil-wet-defer"
                        ) {
                            deferTaskOneDay(task, reason: "soilWet")
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
        plantDetailActionGrid {
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

    func plantDetailActionGrid(@ViewBuilder content: () -> some View) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: 10)],
            alignment: .leading,
            spacing: 10,
            content: content
        )
    }

    func plantDetailTextActionButton(
        title: String,
        foreground: Color = Color.ohanaPrimaryText,
        background: Color = Color.ohanaControlFill.opacity(0.72),
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(foreground)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(background, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
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
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSubtle ? Color.ohanaPrimaryText : Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(tint.opacity(isSubtle ? 0.22 : 1), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(identifier)
    }
}
