//
//  HumanHealthObservationHistoryView.swift
//  Ohana
//
//  All-time raw state-log access with bounded, stable keyset pages.
//

import SwiftData
import SwiftUI

private enum HumanHealthObservationHistoryState: Equatable {
    case loading
    case loaded
    case failed
}

private enum HumanHealthObservationHistorySheet: Identifiable {
    case edit(UUID)

    var id: String {
        switch self {
        case let .edit(id): "edit-history-observation-\(id.uuidString)"
        }
    }
}

struct HumanHealthObservationHistoryView: View {
    let human: Human
    let condition: HumanHealthCondition
    let canViewMedication: Bool
    let isReadOnly: Bool
    let onRecordsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var records: [HumanHealthObservation] = []
    @State private var nextCursor: HumanHealthHistoryPageCursor?
    @State private var pageCursors: [HumanHealthHistoryPageCursor?] = [nil]
    @State private var pageIndex = 0
    @State private var state = HumanHealthObservationHistoryState.loading
    @State private var pageLoadTask: Task<Void, Never>?
    @State private var pageLoadFailed = false
    @State private var sheetDestination: HumanHealthObservationHistorySheet?
    @State private var pagePresentationToken = 0
    @State private var loadingTargetPageIndex: Int?
    @AccessibilityFocusState private var focusedObservationID: UUID?

    private var l: L10n { L10n(appLanguage) }
    private var appLocale: Locale { AppLanguage.effectiveLocale }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        historyHeader
                            .id("human-condition-history-page-top")
                        historyContent
                        if state == .loaded, !records.isEmpty {
                            pager
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: pagePresentationToken) { _, _ in
                    proxy.scrollTo("human-condition-history-page-top", anchor: .top)
                    focusedObservationID = records.first?.id
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: l.tr(
                            zh: "已读取第 \(pageIndex + 1) 页",
                            en: "Page \(pageIndex + 1) loaded",
                            de: "Seite \(pageIndex + 1) geladen"
                        )
                    )
                }
            }
        }
        .navigationTitle(l.tr(zh: "全部状态记录", en: "All State Logs", de: "Alle Status-Einträge"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case let .edit(id):
                if let observation = records.first(where: { $0.id == id }) {
                    HumanHealthObservationEditorSheet(
                        human: human,
                        condition: condition,
                        observation: observation,
                        canViewMedication: canViewMedication,
                        onSaved: recordsDidChange,
                        onDeleted: recordsDidChange
                    )
                } else {
                    ContentUnavailableView(
                        l.tr(zh: "记录已不存在", en: "Record unavailable", de: "Eintrag nicht verfügbar"),
                        systemImage: "list.clipboard"
                    )
                }
            }
        }
        .onAppear {
            guard state == .loading, pageLoadTask == nil else { return }
            loadPage(olderThan: nil, targetIndex: 0, replacingHistory: true)
        }
        .onDisappear {
            pageLoadTask?.cancel()
            pageLoadTask = nil
        }
        .accessibilityIdentifier("human-condition-all-observations")
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(condition.name)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(l.tr(
                zh: "完整原始记录 · 趋势按近期窗口",
                en: "Full raw history · trends use recent windows",
                de: "Vollständiger Rohverlauf · Trends nutzen aktuelle Zeiträume"
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var historyContent: some View {
        switch state {
        case .loading:
            VStack(spacing: 11) {
                ProgressView()
                Text(l.tr(zh: "正在读取状态记录…", en: "Loading state logs…", de: "Status-Einträge werden geladen …"))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 150)

        case .failed:
            ContentUnavailableView {
                Label(
                    l.tr(zh: "无法读取状态记录", en: "State logs couldn’t load", de: "Status-Einträge konnten nicht geladen werden"),
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
            } description: {
                Text(l.tr(
                    zh: "记录仍保存在本机，请重试。",
                    en: "The records remain on this device. Try again.",
                    de: "Die Einträge bleiben auf diesem Gerät. Versuche es erneut."
                ))
            } actions: {
                Button(l.tr(zh: "重试", en: "Try Again", de: "Erneut versuchen")) {
                    loadPage(olderThan: nil, targetIndex: 0, replacingHistory: true)
                }
                .ohanaPrimaryProminentButton()
            }

        case .loaded:
            if records.isEmpty {
                ContentUnavailableView(
                    l.tr(zh: "还没有状态记录", en: "No state logs yet", de: "Noch keine Status-Einträge"),
                    systemImage: "list.clipboard"
                )
            } else {
                if pageLoadFailed {
                    Label(
                        l.tr(
                            zh: "页面读取失败，仍保留当前记录。请再次选择较新或较早。",
                            en: "The page failed to load. Current records are preserved; choose Newer or Older again.",
                            de: "Die Seite konnte nicht geladen werden. Aktuelle Einträge bleiben erhalten; wähle erneut Neuere oder Ältere."
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.goOrange.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }

                ForEach(records) { observation in
                    if isReadOnly {
                        HumanHealthObservationCard(
                            observation: observation,
                            category: condition.category,
                            canViewMedication: canViewMedication,
                            expandsAllText: true
                        )
                        .accessibilityFocused($focusedObservationID, equals: observation.id)
                    } else {
                        Button {
                            sheetDestination = .edit(observation.id)
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HumanHealthObservationCard(
                                observation: observation,
                                category: condition.category,
                                canViewMedication: canViewMedication,
                                expandsAllText: true
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityFocused($focusedObservationID, equals: observation.id)
                    }
                }
            }
        }
    }

    private var pager: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                pageButton(
                    title: l.tr(zh: "较新", en: "Newer", de: "Neuere"),
                    systemImage: "chevron.backward",
                    enabled: pageIndex > 0,
                    action: loadNewerPage
                )
                Spacer(minLength: 8)
                pageLabel
                Spacer(minLength: 8)
                pageButton(
                    title: l.tr(zh: "较早", en: "Older", de: "Ältere"),
                    systemImage: "chevron.forward",
                    enabled: nextCursor != nil,
                    action: loadOlderPage
                )
            }

            VStack(spacing: 10) {
                pageLabel
                HStack(spacing: 10) {
                    pageButton(
                        title: l.tr(zh: "较新", en: "Newer", de: "Neuere"),
                        systemImage: "chevron.backward",
                        enabled: pageIndex > 0,
                        action: loadNewerPage
                    )
                    pageButton(
                        title: l.tr(zh: "较早", en: "Older", de: "Ältere"),
                        systemImage: "chevron.forward",
                        enabled: nextCursor != nil,
                        action: loadOlderPage
                    )
                }
            }
        }
    }

    private var pageLabel: some View {
        Group {
            if pageLoadTask != nil {
                let targetPage = (loadingTargetPageIndex ?? pageIndex) + 1
                ProgressView()
                    .accessibilityLabel(l.tr(
                        zh: "正在读取第 \(targetPage) 页",
                        en: "Loading page \(targetPage)",
                        de: "Seite \(targetPage) wird geladen"
                    ))
            } else {
                Text(l.tr(zh: "第 \(pageIndex + 1) 页", en: "Page \(pageIndex + 1)", de: "Seite \(pageIndex + 1)"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func pageButton(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled || pageLoadTask != nil)
    }

    @MainActor
    private func loadOlderPage() {
        guard let nextCursor else { return }
        loadPage(olderThan: nextCursor, targetIndex: pageIndex + 1)
    }

    @MainActor
    private func loadNewerPage() {
        guard pageIndex > 0 else { return }
        let targetIndex = pageIndex - 1
        loadPage(olderThan: pageCursors[targetIndex], targetIndex: targetIndex)
    }

    @MainActor
    private func loadPage(
        olderThan cursor: HumanHealthHistoryPageCursor?,
        targetIndex: Int,
        replacingHistory: Bool = false
    ) {
        guard pageLoadTask == nil else { return }
        if replacingHistory {
            state = .loading
            pageLoadFailed = false
        }
        loadingTargetPageIndex = targetIndex
        pageLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 0) {
            do {
                let page = try HumanHealthObservationHistoryQuery.page(
                    humanID: human.id,
                    conditionID: condition.id,
                    olderThan: cursor,
                    context: modelContext
                )
                records = page.records
                nextCursor = page.nextCursor
                if replacingHistory {
                    pageCursors = [nil]
                } else if targetIndex == pageCursors.count {
                    pageCursors.append(cursor)
                } else if pageCursors.indices.contains(targetIndex) {
                    pageCursors[targetIndex] = cursor
                }
                pageIndex = targetIndex
                state = .loaded
                pageLoadFailed = false
                pagePresentationToken += 1
            } catch {
                OhanaLog.warning(
                    "Human health observation history page failed to load: \(error.localizedDescription)",
                    category: "HumanHealth"
                )
                if records.isEmpty || replacingHistory {
                    state = .failed
                } else {
                    pageLoadFailed = true
                }
                UIAccessibility.post(
                    notification: .announcement,
                    argument: state == .failed
                        ? l.tr(
                            zh: "无法读取状态记录",
                            en: "State logs couldn’t load",
                            de: "Status-Einträge konnten nicht geladen werden"
                        )
                        : l.tr(
                            zh: "页面读取失败，当前记录已保留",
                            en: "Page load failed; current records were preserved",
                            de: "Seite konnte nicht geladen werden; aktuelle Einträge bleiben erhalten"
                        )
                )
            }
            loadingTargetPageIndex = nil
            pageLoadTask = nil
        }
    }

    @MainActor
    private func recordsDidChange() {
        onRecordsChanged()
        records = []
        nextCursor = nil
        pageCursors = [nil]
        pageIndex = 0
        focusedObservationID = nil
        state = .loading
        loadPage(olderThan: nil, targetIndex: 0, replacingHistory: true)
    }
}

struct HumanHealthObservationCard: View {
    let observation: HumanHealthObservation
    let category: HumanHealthConditionCategory
    let canViewMedication: Bool
    let expandsAllText: Bool

    init(
        observation: HumanHealthObservation,
        category: HumanHealthConditionCategory,
        canViewMedication: Bool,
        expandsAllText: Bool = false
    ) {
        self.observation = observation
        self.category = category
        self.canViewMedication = canViewMedication
        self.expandsAllText = expandsAllText
    }

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var appLocale: Locale { AppLanguage.effectiveLocale }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    recordedDate
                    Spacer(minLength: 8)
                    severityLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    recordedDate
                    severityLabel
                }
            }

            if !observation.symptomTags.isEmpty {
                Text(observation.symptomTags.joined(separator: " · "))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(expandsAllText ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let details = observationDetails
            if !details.isEmpty {
                Text(details.joined(separator: "  ·  "))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(expandsAllText ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let contextLines = observationContextLines
            if !contextLines.isEmpty {
                Text(contextLines.joined(separator: "\n"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(expandsAllText ? nil : 7)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !observation.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(observation.notes)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(expandsAllText ? nil : 5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(observation.severity) / 10")
        .accessibilityIdentifier("human-condition-observation-\(observation.id.uuidString)")
    }

    private var recordedDate: some View {
        Text(observation.recordedAt.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: appLocale
        )))
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var severityLabel: some View {
        Text("\(observation.severity)/10 · \(HumanHealthSeverityLabel.text(for: observation.severity, l: l))")
            .font(OhanaFont.caption(.black))
            .foregroundStyle(category.tint)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var observationDetails: [String] {
        var details: [String] = []
        if let mood = observation.moodScore {
            details.append(l.tr(zh: "心情 \(mood)/10", en: "Mood \(mood)/10", de: "Stimmung \(mood)/10"))
        }
        if let sleep = observation.sleepHours {
            let value = sleep.formatted(
                .number.precision(.fractionLength(1)).locale(appLocale)
            )
            details.append(l.tr(
                zh: "睡眠 \(value) 小时",
                en: "Sleep \(value) hr",
                de: "Schlaf \(value) Std."
            ))
        }
        if canViewMedication, observation.medicationResponse != .unknown {
            details.append(observation.medicationResponse.displayName(l))
        }
        return details
    }

    private var observationContextLines: [String] {
        var lines: [String] = []
        if !observation.possibleTriggers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(l.tr(
                zh: "可能诱因：\(observation.possibleTriggers)",
                en: "Possible trigger: \(observation.possibleTriggers)",
                de: "Möglicher Auslöser: \(observation.possibleTriggers)"
            ))
        }
        if !observation.careActions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(l.tr(
                zh: "采取行动：\(observation.careActions)",
                en: "Action: \(observation.careActions)",
                de: "Maßnahme: \(observation.careActions)"
            ))
        }
        if canViewMedication,
           !observation.sideEffects.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(l.tr(
                zh: "副作用/不适：\(observation.sideEffects)",
                en: "Side effect/discomfort: \(observation.sideEffects)",
                de: "Nebenwirkung/Beschwerde: \(observation.sideEffects)"
            ))
        }
        return lines
    }
}
