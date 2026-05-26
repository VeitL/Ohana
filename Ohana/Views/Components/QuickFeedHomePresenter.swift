//
//  QuickFeedHomePresenter.swift
//  Ohana
//
//  Lightweight render-state builder for the feeding home surface.
//

import SwiftUI

@MainActor
struct QuickFeedHomePresenter {
    let pet: Pet
    let localization: L10n
    let viewState: FeedHomeViewState
    let modeTransition: FeedModeTransitionRenderState?
    let isAuxiliaryReady: Bool
    let overviewChartProgress: Double
    let feedFeedbackToken: CheckInFeedbackToken?
    let feedFeedbackMetricId: String?
    let stockFeedbackToken: CheckInFeedbackToken?
    let dryFoodTint: Color
    let wetFoodTint: Color
    let stockTint: Color
    let treatTint: Color
    let mainFoodOverviewTint: Color
    let onModeTap: (FeedOperatingMode) -> Void
    let onPrimaryAction: () -> Void
    let onOpenFeedingOverview: () -> Void
    let onOpenStockOverview: () -> Void
    let onOpenTreatOverview: () -> Void
    let onOpenTaskSettings: () -> Void
    let onQuickAddTreat: () -> Void
    let onOpenManualHistory: () -> Void
    let onOpenModeHistory: () -> Void
    let inlineTaskPanel: AnyView?
    let inlineTreatPanel: AnyView?

    var body: some View {
        GuidedFeedHomeView(
            task: task,
            taskTransition: taskTransition,
            modeTitle: localization.tr(zh: "喂食模式", en: "Feeding mode", de: "Fütterungsmodus"),
            modeOptions: modeOptions,
            chart: isAuxiliaryReady ? chart : nil,
            dockItems: isAuxiliaryReady ? dockItems : lightweightDockItems,
            primaryAction: onPrimaryAction,
            taskSettingsAction: onOpenTaskSettings,
            inlineTaskPanel: inlineTaskPanel,
            inlineTreatPanel: inlineTreatPanel
        )
    }

    private var task: FeedGuidedTaskState {
        task(for: viewState.mode, state: viewState)
    }

    private var taskTransition: FeedGuidedTaskTransition? {
        guard let modeTransition else { return nil }
        return FeedGuidedTaskTransition(
            fromTask: task(for: modeTransition.fromMode, state: modeTransition.viewState),
            toTask: task(for: modeTransition.toMode, state: modeTransition.viewState),
            progress: modeTransition.progress
        )
    }

    private func task(for renderMode: FeedOperatingMode, state renderState: FeedHomeViewState) -> FeedGuidedTaskState {
        let todayMainFoodGrams = renderState.task.todayMainFoodGrams
        let title: String
        let metricTitle: String
        let metricValue: String
        let detail: String
        let primaryTitle: String
        let primaryIcon: String
        let isPrimaryEnabled: Bool

        if pet.hasPassedAway {
            title = localization.tr(zh: "纪念饮食记录", en: "Memorial food log", de: "Futter im Gedenken")
            metricTitle = localization.tr(zh: "今日", en: "Today", de: "Heute")
            metricValue = todayMainFoodGrams > 0 ? formattedFoodCardWeight(todayMainFoodGrams) : "--"
            detail = localization.tr(zh: "只保留历史查看。", en: "History only.", de: "Nur Verlauf.")
            primaryTitle = localization.tr(zh: "查看", en: "View", de: "Ansehen")
            primaryIcon = "clock.arrow.circlepath"
            isPrimaryEnabled = true
        } else {
            switch renderMode {
            case .manual where pet.dailyPortionGrams <= 0:
                title = localization.tr(zh: "先设置喂食量", en: "Set feeding amount", de: "Futtermenge festlegen")
                metricTitle = FeedFoodKind.dry.title(localization) + " / " + FeedFoodKind.wet.title(localization)
                metricValue = "50g"
                detail = localization.tr(zh: "保存一次默认克数后，就能一键打卡。", en: "Save a default amount for one-tap logging.", de: "Standardmenge speichern.")
                primaryTitle = localization.tr(zh: "设置", en: "Set", de: "Festlegen")
                primaryIcon = "slider.horizontal.3"
                isPrimaryEnabled = true
            case .manual:
                title = localization.tr(zh: "现在可以喂食", en: "Ready to feed", de: "Bereit zum Füttern")
                metricTitle = localization.tr(zh: "默认", en: "Default", de: "Standard")
                metricValue = formattedFoodCardWeight(pet.dailyPortionGrams)
                detail = localization.tr(
                    zh: "\(pet.mainFoodKind.title(localization)) · 今天 \(formattedFoodCardWeight(todayMainFoodGrams))",
                    en: "\(pet.mainFoodKind.title(localization)) · today \(formattedFoodCardWeight(todayMainFoodGrams))",
                    de: "\(pet.mainFoodKind.title(localization)) · heute \(formattedFoodCardWeight(todayMainFoodGrams))"
                )
                primaryTitle = localization.tr(zh: "喂食", en: "Feed", de: "Füttern")
                primaryIcon = "checkmark"
                isPrimaryEnabled = true
            case .manualReminder:
                let hasPending = renderState.task.hasNextManualReminder
                let hasMissedPlan = renderState.task.hasMissedManualPlan
                let completionText = renderState.task.todayManualPlanCompletionText
                title = hasMissedPlan
                    ? localization.tr(zh: "有计划餐待补", en: "Meal missed", de: "Mahlzeit verpasst")
                    : (hasPending ? localization.tr(zh: "有计划餐待打卡", en: "Planned meal ready", de: "Planmahlzeit bereit") : localization.tr(zh: "下一餐已安排", en: "Next meal is set", de: "Nächste Mahlzeit steht"))
                metricTitle = localization.tr(zh: "今日计划", en: "Today plan", de: "Heute Plan")
                metricValue = completionText
                detail = nextFeedDetailText(
                    events: renderState.task.manualPlanEvents,
                    fallback: localization.tr(zh: "今天 \(completionText)", en: "Today \(completionText)", de: "Heute \(completionText)")
                )
                primaryTitle = hasPending ? localization.tr(zh: "完成", en: "Complete", de: "Erledigen") : localization.tr(zh: "查看", en: "View", de: "Ansehen")
                primaryIcon = hasPending ? "checkmark" : "calendar"
                isPrimaryEnabled = true
            case .autoFeeder:
                title = localization.tr(zh: "自动记录中", en: "Auto logging", de: "Auto-Aufzeichnung")
                metricTitle = localization.tr(zh: "今日自动", en: "Auto today", de: "Heute Auto")
                metricValue = "\(renderState.task.todayAutoFeedCount)x"
                detail = nextFeedDetailText(events: renderState.task.autoFeederEvents, fallback: autoFeederStatusText(state: renderState))
                primaryTitle = localization.tr(zh: "历史", en: "History", de: "Verlauf")
                primaryIcon = "chart.line.uptrend.xyaxis"
                isPrimaryEnabled = true
            }
        }

        return FeedGuidedTaskState(
            modeTitle: renderMode.feedShortTitle(localization),
            modeIcon: renderMode.feedIconName,
            modeTint: renderMode.feedTint,
            title: title,
            metricTitle: metricTitle,
            metricValue: metricValue,
            detail: detail,
            primaryTitle: primaryTitle,
            primaryIcon: primaryIcon,
            isPrimaryEnabled: isPrimaryEnabled,
            metrics: metrics(state: renderState),
            feedbackToken: feedFeedbackToken,
            stockFeedbackToken: stockFeedbackToken
        )
    }

    private func metrics(state renderState: FeedHomeViewState) -> [FeedGuidedMetric] {
        [
            FeedGuidedMetric(
                id: FeedFoodKind.dry.rawValue,
                title: FeedFoodKind.dry.title(localization),
                value: stockMetricValue(grams: renderState.metrics.dryStockRemainingGrams),
                detail: stockMetricDetail(days: renderState.metrics.dryStockRemainingDays),
                tint: dryFoodTint,
                isHighlighted: pet.mainFoodKind == .dry || FeedFoodKind.dry.rawValue == feedFeedbackMetricId
            ),
            FeedGuidedMetric(
                id: FeedFoodKind.wet.rawValue,
                title: FeedFoodKind.wet.title(localization),
                value: stockMetricValue(grams: renderState.metrics.wetStockRemainingGrams),
                detail: stockMetricDetail(days: renderState.metrics.wetStockRemainingDays),
                tint: wetFoodTint,
                isHighlighted: pet.mainFoodKind == .wet || FeedFoodKind.wet.rawValue == feedFeedbackMetricId
            )
        ]
    }

    private var modeOptions: [FeedGuidedModeOption] {
        FeedOperatingMode.allCases.map { optionMode in
            FeedGuidedModeOption(
                id: optionMode.rawValue,
                title: optionMode.feedShortTitle(localization),
                icon: optionMode.feedIconName,
                tint: optionMode.feedTint,
                isSelected: viewState.mode == optionMode
            ) {
                onModeTap(optionMode)
            }
        }
    }

    private var chart: FeedGuidedChartState {
        let points = viewState.chartPoints
        let total = points.reduce(0) { $0 + $1.value }
        return FeedGuidedChartState(
            title: localization.tr(zh: "7日进食", en: "7-day food", de: "7 Tage Futter"),
            value: total > 0 ? formattedFoodCardWeight(total) : "--",
            subtitle: localization.tr(zh: "只看趋势，详情进总览。", en: "A quiet trend. Details in overview.", de: "Ruhiger Trend. Details im Überblick."),
            points: points,
            tint: mainFoodOverviewTint,
            progress: overviewChartProgress,
            emptyText: localization.tr(zh: "打卡后会出现趋势", en: "Log meals to see the trend", de: "Nach Einträgen erscheint ein Trend"),
            action: onOpenFeedingOverview
        )
    }

    private var dockItems: [FeedDiscoveryDockItem] {
        [
            dockItem(id: "stock", icon: "shippingbox.fill", title: localization.tr(zh: "粮仓", en: "Stock", de: "Vorrat"), value: stockCardValue, tint: stockTint, action: onOpenStockOverview),
            dockItem(
                id: "treat",
                icon: "birthday.cake.fill",
                title: localization.tr(zh: "零食", en: "Treats", de: "Snacks"),
                value: treatCardValue,
                tint: treatTint,
                secondaryIcon: "plus",
                secondaryAccessibilityLabel: localization.tr(zh: "快速添加零食", en: "Quick add treat", de: "Snack schnell hinzufügen"),
                action: onOpenTreatOverview,
                secondaryAction: onQuickAddTreat
            ),
            dockItem(id: "history", icon: "clock.arrow.circlepath", title: localization.tr(zh: "历史", en: "History", de: "Verlauf"), value: viewState.mode.feedShortTitle(localization), tint: viewState.mode.feedTint, action: {
                viewState.mode == .manual ? onOpenManualHistory() : onOpenModeHistory()
            })
        ]
    }

    private var lightweightDockItems: [FeedDiscoveryDockItem] {
        [
            dockItem(id: "stock", icon: "shippingbox.fill", title: localization.tr(zh: "粮仓", en: "Stock", de: "Vorrat"), value: "--", tint: stockTint, action: onOpenStockOverview),
            dockItem(
                id: "treat",
                icon: "birthday.cake.fill",
                title: localization.tr(zh: "零食", en: "Treats", de: "Snacks"),
                value: "--",
                tint: treatTint,
                secondaryIcon: "plus",
                secondaryAccessibilityLabel: localization.tr(zh: "快速添加零食", en: "Quick add treat", de: "Snack schnell hinzufügen"),
                action: onOpenTreatOverview,
                secondaryAction: onQuickAddTreat
            ),
            dockItem(id: "history", icon: "clock.arrow.circlepath", title: localization.tr(zh: "历史", en: "History", de: "Verlauf"), value: viewState.mode.feedShortTitle(localization), tint: viewState.mode.feedTint, action: {
                viewState.mode == .manual ? onOpenManualHistory() : onOpenModeHistory()
            })
        ]
    }

    private func dockItem(
        id: String,
        icon: String,
        title: String,
        value: String,
        tint: Color,
        secondaryIcon: String? = nil,
        secondaryAccessibilityLabel: String? = nil,
        action: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) -> FeedDiscoveryDockItem {
        FeedDiscoveryDockItem(
            id: id,
            icon: icon,
            title: title,
            value: value,
            tint: tint,
            secondaryIcon: secondaryIcon,
            secondaryAccessibilityLabel: secondaryAccessibilityLabel,
            action: action,
            secondaryAction: secondaryAction
        )
    }

    private func autoFeederStatusText(state renderState: FeedHomeViewState) -> String {
        let daily = formattedFoodWeight(renderState.task.autoDailyTotalGrams)
        if let latest = renderState.task.latestAutoFeedDate {
            return localization.tr(
                zh: "\(daily)/天 · 上次 \(latest.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · last \(latest.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · zuletzt \(latest.formatted(date: .omitted, time: .shortened))"
            )
        }
        if let next = renderState.task.nextAutoFeedDate {
            return localization.tr(
                zh: "\(daily)/天 · 下次 \(next.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · next \(next.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · nächste \(next.formatted(date: .omitted, time: .shortened))"
            )
        }
        return localization.tr(zh: "\(daily)/天 · 自动补记", en: "\(daily)/day · auto logging", de: "\(daily)/Tag · Auto")
    }

    private var stockCardValue: String {
        let grams = [viewState.metrics.dryStockRemainingGrams, viewState.metrics.wetStockRemainingGrams]
            .compactMap { $0 }
            .reduce(0, +)
        if grams > 0, let days = viewState.stockBadge.remainingDays {
            return "\(formattedFoodCardWeight(grams)) · \(days)\(localization.tr(zh: "天", en: "d", de: "T"))"
        }
        guard let days = viewState.stockBadge.remainingDays else { return "--" }
        return "\(days) \(localization.tr(zh: "天", en: "days", de: "Tage"))"
    }

    private var treatCardValue: String {
        if viewState.metrics.todayTreatCount > 0, viewState.metrics.todayTreatGrams > 0 {
            return "\(viewState.metrics.todayTreatCount)x · \(formattedFoodCardWeight(viewState.metrics.todayTreatGrams))"
        }
        if viewState.metrics.todayTreatCount > 0 {
            return "\(viewState.metrics.todayTreatCount)x"
        }
        return "--"
    }

    private func stockMetricValue(grams: Double?) -> String {
        guard let grams, grams > 0 else { return "--" }
        return formattedFoodCardWeight(grams)
    }

    private func stockMetricDetail(days: Int?) -> String? {
        guard let days else { return nil }
        return "\(days)\(localization.tr(zh: "天", en: "d", de: "T"))"
    }

    private func nextFeedDetailText(events: [Event], fallback: String) -> String {
        guard let next = events
            .compactMap({ event -> (Event, Date)? in
                guard let date = nextOccurrence(for: event) else { return nil }
                return (event, date)
            })
            .min(by: { $0.1 < $1.1 })
        else {
            return fallback
        }
        let time = next.1.formatted(date: .omitted, time: .shortened)
        let grams = formattedFoodWeight(FeedRuleMetadata.amountGrams(from: next.0, fallback: pet.dailyPortionGrams))
        let kind = next.0.foodKind.title(localization)
        return localization.tr(
            zh: "下次 \(time) · \(kind) · \(grams)",
            en: "Next \(time) · \(kind) · \(grams)",
            de: "Nächste \(time) · \(kind) · \(grams)"
        )
    }

    private func nextOccurrence(for event: Event, after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        if event.startDate > now { return event.startDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        var day = calendar.dateComponents([.year, .month, .day], from: now)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second
        guard var candidate = calendar.date(from: day) else { return nil }
        let intervalDays = max(event.recurrenceDays, 1)
        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: candidate) else { return nil }
            candidate = next
        }
        if let end = event.recurrenceEndDate, candidate > end { return nil }
        return candidate
    }

    private func formattedFoodWeight(_ grams: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(grams)
    }

    private func formattedFoodCardWeight(_ grams: Double) -> String {
        "\(Int(max(0, grams).rounded()))g"
    }
}

extension FeedOperatingMode {
    func feedShortTitle(_ localization: L10n) -> String {
        switch self {
        case .manual:
            return localization.tr(zh: "手动", en: "Manual", de: "Manuell")
        case .manualReminder:
            return localization.tr(zh: "计划", en: "Plan", de: "Plan")
        case .autoFeeder:
            return localization.tr(zh: "自动", en: "Auto", de: "Auto")
        }
    }

    func feedTitle(_ localization: L10n) -> String {
        switch self {
        case .manual:
            return localization.tr(zh: "手动打卡", en: "Manual logging", de: "Manuell")
        case .manualReminder:
            return localization.tr(zh: "喂食计划", en: "Reminder plan", de: "Fütterungsplan")
        case .autoFeeder:
            return localization.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat")
        }
    }

    var feedIconName: String {
        switch self {
        case .manual:
            return "hand.tap.fill"
        case .manualReminder:
            return FeedRuleKind.manualReminder.iconName
        case .autoFeeder:
            return FeedRuleKind.autoFeeder.iconName
        }
    }

    var feedTint: Color {
        switch self {
        case .manual:
            return Color.goOrange
        case .manualReminder:
            return Color.goPurple
        case .autoFeeder:
            return Color.goTeal
        }
    }
}
