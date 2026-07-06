//
//  PlantDetailView+HeroTimelineDelete.swift
//  Ohana
//
//  Extracted Plant view sections.
//

import SwiftUI

extension PlantDetailContentView {
    // MARK: - Hero Card
    var heroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkMint.opacity(0.58), Color.goPrimary.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                Circle()
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.62), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Text(plant.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 48))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "植物档案", en: "Plant profile", de: "Pflanzenprofil"))
                    .font(OhanaFont.adaptive(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .textCase(.uppercase)

                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("plant-detail-name")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if !plant.species.isEmpty {
                            profileChip(icon: "leaf.fill", text: plant.species)
                        }
                        profileChip(icon: plant.isIndoor ? "house.fill" : "sun.max.fill", text: plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "户外", en: "Outdoor", de: "Draußen"))
                    }
                    profileChip(icon: "mappin.and.ellipse", text: placementSummary)
                    if activeSafetyWarningCount > 0 {
                        profileChip(
                            icon: "exclamationmark.triangle.fill",
                            text: l.tr(zh: "\(activeSafetyWarningCount) 个安全提示", en: "\(activeSafetyWarningCount) safety notes", de: "\(activeSafetyWarningCount) Sicherheitshinweise"),
                            tint: Color.goYellow
                        )
                    }
                }

                if let task = nextTask {
                    Text(l.tr(zh: "下一项：\(task.title) · \(dueText(for: task))", en: "Next: \(task.title) · \(dueText(for: task))", de: "Nächstes: \(task.title) · \(dueText(for: task))"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(task.isOverdue ? Color.goRed : Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous))
        .padding(.horizontal, 16)
    }

    func profileChip(icon: String, text: String, tint: Color = Color.goPrimary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
    }

    func statusPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .heavy))
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint, in: Capsule())
    }

    func overviewMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24) // a11y: allow non-interactive metric glyph; row text carries the accessible content.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                Text(value)
                    .font(OhanaFont.adaptive(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 46, alignment: .top)
    }

    func rhythmRow(
        icon: String,
        title: String,
        status: String,
        detail: String,
        tint: Color,
        progress: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26) // a11y: allow non-interactive rhythm glyph; row text carries the accessible content.
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(detail)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
                Text(status)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            if let progress {
                ProgressView(value: progress)
                    .tint(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }

    func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            let days = abs(task.daysUntilDue)
            return l.tr(zh: "逾期 \(days) 天", en: "\(days)d overdue", de: "\(days) T. überfällig")
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        if task.daysUntilDue == 1 {
            return l.tr(zh: "明天", en: "Tomorrow", de: "Morgen")
        }
        return l.tr(zh: "\(task.daysUntilDue) 天后", en: "In \(task.daysUntilDue)d", de: "In \(task.daysUntilDue) T.")
    }

    // MARK: - Watering Card
    var wateringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goTeal)
                Text(l.tr(zh: "浇水状态", en: "Watering status", de: "Gießstatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceWatered {
                let progress = min(1.0, Double(days) / Double(max(wateringIntervalDays, 1)))
                let color: Color = progress < 0.5 ? Color.goTeal : (progress < 0.8 ? Color.goYellow : Color.goRed)

                HStack {
                    Text(l.tr(zh: "距上次浇水 \(days) 天", en: "\(days) days since watering", de: "\(days) Tage seit dem Gießen"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(wateringIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isWateringDue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(Color.goYellow)
                            .font(OhanaFont.adaptive(size: 12))
                        Text(l.tr(zh: "该浇水了！", en: "Time to water!", de: "Zeit zum Gießen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有浇水记录", en: "No watering records yet", de: "Noch keine Gießprotokolle"))
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Fertilizing Card
    var fertilizingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "施肥状态", en: "Fertilizing status", de: "Düngestatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceFertilized {
                let progress = min(1.0, Double(days) / Double(max(fertilizingIntervalDays, 1)))
                let color: Color = progress < 0.5 ? Color.goPrimary : (progress < 0.8 ? Color.goYellow : Color.goRed)

                HStack {
                    Text(l.tr(zh: "距上次施肥 \(days) 天", en: "\(days) days since fertilizing", de: "\(days) Tage seit dem Düngen"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(fertilizingIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isFertilizingDue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(Color.goYellow)
                            .font(OhanaFont.adaptive(size: 12))
                        Text(l.tr(zh: "该施肥了！", en: "Time to fertilize!", de: "Zeit zum Düngen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有施肥记录", en: "No fertilizing records yet", de: "Noch keine Düngeprotokolle"))
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Notes Card
    var notesCard: some View {
        Group {
            if !plant.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text").accessibilityHidden(true)
                            .foregroundStyle(Color.goTeal)
                        Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Text(plant.notes)
                        .font(OhanaFont.adaptive(size: 14))
                }
                .padding(16)
                .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
                .padding(.horizontal, 16)
            }
        }
    }

    var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "clock.arrow.circlepath", title: l.tr(zh: "护理历史", en: "Care history", de: "Pflegeverlauf"))
            if (logSummary?.logCount ?? 0) == 0 {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "leaf.arrow.circlepath") // a11y: allow decorative empty timeline glyph; adjacent text explains the state.
                        .accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 36, height: 36) // a11y: allow non-interactive timeline glyph; row text carries the content.
                        .background(Color.goTeal.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "还没有护理日志", en: "No care logs yet", de: "Noch keine Pflegeprotokolle"))
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "完成一次浇水、施肥或观察后，这里会生成植物的活动时间线。",
                            en: "Water, fertilize, or observe once to start this plant's activity timeline.",
                            de: "Gießen, düngen oder beobachten startet hier die Aktivitäts-Zeitachse."
                        ))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                timelineSummaryStrip

                VStack(spacing: 0) {
                    ForEach(Array(recentLogs.prefix(6).enumerated()), id: \.element.id) { index, log in
                        timelineLogRow(log, isLast: index == min(logSummary?.logCount ?? 0, 6) - 1)
                    }
                }
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityIdentifier("plant-detail-care-timeline")
        .padding(.horizontal, 16)
    }

    var timelineSummaryStrip: some View {
        HStack(spacing: 8) {
            timelineSummaryPill(
                icon: "tray.full.fill",
                title: l.tr(zh: "记录", en: "Logs", de: "Protokolle"),
                value: "\(logSummary?.logCount ?? 0)",
                tint: Color.goPrimary
            )
            if let latest = logSummary?.latestLog {
                timelineSummaryPill(
                    icon: careSymbol(for: latest.careType),
                    title: l.tr(zh: "最近", en: "Latest", de: "Zuletzt"),
                    value: latest.careType.displayName(l: l),
                    tint: careTint(for: latest.careType)
                )
            }
        }
    }

    func timelineSummaryPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative summary glyph; pill text carries the value.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    func timelineLogRow(_ log: PlantDetailLogSnapshot, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: careSymbol(for: log.careType)) // a11y: allow decorative timeline glyph; row text names the care action.
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive care log glyph; row text carries the content.
                    .background(careTint(for: log.careType), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.ohanaControlFill.opacity(0.85))
                        .frame(width: 2, height: 26) // a11y: allow non-interactive timeline connector; timeline row text carries the content.
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.careType.displayName(l: l))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(timelineDateText(for: log))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if let note = timelineNoteText(for: log) {
                    Text(note)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    func timelineDateText(for log: PlantDetailLogSnapshot) -> String {
        log.date.formatted(date: .abbreviated, time: .shortened)
    }

    func timelineNoteText(for log: PlantDetailLogSnapshot) -> String? {
        let note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty,
              !note.hasPrefix("defer:"),
              !note.hasPrefix("skip:") else { return nil }
        return note
    }

    func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }

    // MARK: - Delete Section
    var archiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plant.isArchived {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox.fill") // a11y: allow decorative archive glyph; adjacent text describes the state.
                        .foregroundStyle(Color.goYellow)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "已归档", en: "Archived", de: "Archiviert"))
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        if let archivedAt = plant.archivedAt {
                            Text(archivedAt.formatted(.dateTime.year().month().day()))
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                    Spacer(minLength: 8)
                }
                Button {
                    showingRestoreConfirm = true
                } label: {
                    Label(l.tr(zh: "恢复活跃", en: "Restore active", de: "Aktiv wiederherstellen"), systemImage: "arrow.uturn.backward")
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(ScaleButtonStyle())
                .foregroundStyle(Color.goPrimary)
                .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .accessibilityIdentifier("plant-detail-restore-action")
            } else {
                Button {
                    showingArchiveConfirm = true
                } label: {
                    Label(l.tr(zh: "归档植物", en: "Archive plant", de: "Pflanze archivieren"), systemImage: "archivebox")
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(ScaleButtonStyle())
                .foregroundStyle(Color.goYellow)
                .background(Color.goYellow.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .accessibilityIdentifier("plant-detail-archive-action")
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    var pendingDeleteBanner: some View {
        if isDeletePending {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill") // a11y: allow decorative pending-delete glyph; adjacent text describes the state.
                    .foregroundStyle(Color.goRed)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "即将删除 \(plant.name)", en: "Deleting \(plant.name) soon", de: "\(plant.name) wird gleich gelöscht"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "6 秒内可撤销；到时会清理相关日历和提醒。",
                        en: "Undo within 6 seconds; related calendar items and reminders will be cleaned up.",
                        de: "Innerhalb von 6 Sekunden widerrufbar; zugehörige Kalenderpunkte und Erinnerungen werden bereinigt."
                    ))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                Button(l.tr(zh: "撤销", en: "Undo", de: "Widerrufen")) {
                    cancelPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
                .accessibilityIdentifier("plant-detail-delete-undo")

                Button(l.tr(zh: "立即删除", en: "Delete now", de: "Jetzt löschen"), role: .destructive) {
                    commitPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .accessibilityIdentifier("plant-detail-delete-now")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash").accessibilityHidden(true)
                Text(l.tr(zh: "删除植物", en: "Delete plant", de: "Pflanze löschen"))
            }
            .font(OhanaFont.adaptive(size: 14, weight: .semibold))
            .foregroundStyle(Color.goRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.goRed.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1)
            }
        }
        .disabled(isDeletePending || isDeleteCommitting)
        .opacity(isDeletePending || isDeleteCommitting ? 0.55 : 1)
        .accessibilityIdentifier("plant-detail-delete-action")
        .padding(.horizontal, 16)
    }
}
