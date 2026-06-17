import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func afterFoodLogSaved(message: String, tint: Color, stockReminders: [Reminder] = []) {
        reloadFeedSnapshots()
        scheduleStockReminders(stockReminders)
        collapseEmbeddedPanel()
        closeActiveFeedSheet()
        triggerToast(message, tint: tint)
        checkDailyTargetToast()
    }

    func triggerFeedCheckInFeedback(foodKind: FeedFoodKind, grams: Double, affectsStock: Bool) {
        let tint = foodKindTint(foodKind)
        feedFeedbackMetricId = foodKind.title(l)
        feedFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: "+\(formattedFoodCardWeight(grams))", tint: tint)
        if affectsStock {
            stockFeedbackKind = foodKind
            stockFeedbackToken = CheckInFeedbackToken(kind: .loss, deltaText: "-\(formattedFoodCardWeight(grams))", tint: tint)
        }
        scheduleFeedbackClear()
    }

    func triggerTreatCheckInFeedback(grams: Double) {
        let delta = grams > 0 ? "+\(formattedFoodWeight(grams))" : "+1"
        treatFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: delta, tint: treatTint)
        scheduleFeedbackClear()
    }

    func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                presentationState.clearFeedback()
            }
        }
    }

    func performWithAntiRepeat(_ action: @escaping () -> Void) {
        let antiRepeatModel = QuickFeedAntiRepeatScreenModel(
            pet: pet,
            currentUserId: currentUserId,
            humans: allHumans,
            feedingLedgerEvents: feedingLedgerEvents,
            now: Date()
        )
        if let warning = antiRepeatModel.recentFeedingWarning() {
            pendingRepeatAction = action
            activeAlert = .antiRepeat(
                title: l.tr(zh: "重复喂食提醒", en: "Recent feeding", de: "Kürzlich gefüttert"),
                message: l.tr(
                    zh: "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name)。",
                    en: "\(warning.executorName) fed \(pet.name) \(warning.minutesAgo) minutes ago.",
                    de: "\(warning.executorName) hat \(pet.name) vor \(warning.minutesAgo) Minuten gefüttert."
                )
            )
        } else {
            action()
        }
    }

    func materializeAutoFeedLogs() {
        let currentEvents = latestAllEvents()
        let result = commandExecutor.materializeDueAutoLogs(
            pet: pet,
            allEvents: currentEvents
        )
        if result.insertedCount > 0 {
            reloadFeedSnapshots()
            scheduleStockReminders(result.stockReminders)
        }
    }

    func reloadFeedSnapshots(forceSnapshot: Bool = false) {
        if let visibleSheet = activeInlineSheet ?? activeSheet {
            if visibleSheet.needsFullCareLogs, dataController.hasLoadedFullCareLogs {
                loadFullCareLogs(force: true)
            }
            if visibleSheet.needsFullCareLogs, dataController.hasLoadedFullFeedingLedgerEvents {
                loadFullFeedingLedgerEvents(force: true)
            }
            if visibleSheet.needsFullFoodRecords, dataController.hasLoadedFullFoodRecords {
                loadFullFoodRecords(force: true)
            }
        }
        refreshStockSnapshot(force: forceSnapshot)
        refreshFeedHomeSnapshot(force: forceSnapshot)
        refreshOverviewSnapshot(force: forceSnapshot)
        refreshPlanCalendarSnapshot(force: forceSnapshot)
        refreshTreatSnapshot(force: forceSnapshot)
    }

    func refreshStockSnapshot(force: Bool = false) {
        stockSnapshotStore.rebuild(
            pet: pet,
            allEvents: currentAllEvents,
            careLogs: observedCareLogs,
            foodRecords: observedFoodRecords,
            sharedCareSessions: allSharedCareSessions,
            now: clockTick,
            force: force
        )
    }

    func refreshOverviewSnapshot(force: Bool = false) {
        overviewSnapshotStore.rebuild(
            pet: pet,
            manualPlanEvents: feedScheduleEvents,
            autoFeederEvents: autoFeederEvents,
            feedingLedgerEvents: observedFeedingLedgerEvents,
            legacyCareLogs: observedCareLogs,
            range: draftStore.overviewRange,
            activeMode: activeFeedingMode,
            defaultFeedGrams: defaultFeedGrams,
            now: clockTick,
            force: force
        )
    }

    func refreshPlanCalendarSnapshot(force: Bool = false) {
        planCalendarSnapshotStore.rebuild(
            manualEvents: feedScheduleEvents,
            autoEvents: autoFeederEvents,
            feedingLedgerEvents: observedFeedingLedgerEvents,
            activeMode: activeFeedingMode,
            month: draftStore.feedPlanCalendarMonth,
            selectedDate: draftStore.feedPlanCalendarSelectedDate,
            now: clockTick,
            force: force
        )
    }

    func refreshTreatSnapshot(force: Bool = false) {
        treatSnapshotStore.rebuild(
            pet: pet,
            feedingLedgerEvents: observedFeedingLedgerEvents,
            legacyCareLogs: observedCareLogs,
            range: draftStore.overviewRange,
            selectedKind: draftStore.selectedTreatOverviewKind,
            now: clockTick,
            force: force
        )
    }

    func ensureUpcomingPlanReminders() {
        let currentEvents = latestAllEvents()
        let reminders = commandExecutor.ensureUpcomingPlanReminders(
            pet: pet,
            allEvents: currentEvents,
            now: clockTick
        )
        scheduleReminders(reminders)
    }

    func scheduleReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        feedPlanReminderSchedulingTask?.cancel()
        feedPlanReminderSchedulingTask = Task { @MainActor in
            guard await appServices.userNotifications.requestPermission(),
                  !Task.isCancelled
            else { return }
            await commandExecutor.schedulePlanReminders(reminders)
        }
    }

    func scheduleStockReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        feedStockReminderSchedulingTask?.cancel()
        feedStockReminderSchedulingTask = Task { @MainActor in
            await commandExecutor.scheduleStockReminders(reminders)
        }
    }

    func checkDailyTargetToast() {
        guard pet.dailyPortionGrams > 0 else { return }
        let total = feedTaskState.todayMainFoodGrams
        if total > pet.dailyPortionGrams * 1.1 {
            triggerToast(l.tr(zh: "今日主粮偏多", en: "Main food is high today", de: "Heute viel Hauptfutter"), tint: Color.goYellow)
        }
    }

    func triggerToast(_ message: String, tint: Color) {
        toastTask?.cancel()
        let route = QuickFeedOverlayRoute.toast(message: message, tint: tint)
        withAnimation(GoMotion.feedback) {
            activeOverlay = route
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                guard activeOverlay?.id == route.id else { return }
                withAnimation(GoMotion.feedback) {
                    activeOverlay = nil
                }
                toastTask = nil
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showTreatSavedCelebration() {
        toastTask?.cancel()
        let route = QuickFeedOverlayRoute.treatCelebration(tint: treatTint)
        withAnimation(GoMotion.fab) {
            activeOverlay = route
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_650_000_000)
            await MainActor.run {
                guard activeOverlay?.id == route.id else { return }
                withAnimation(GoMotion.quick) {
                    activeOverlay = nil
                }
                toastTask = nil
            }
        }
    }

    func dismissFeedKeyboard() {
        dismissSystemFeedKeyboardIfNeeded()
        focusedField = nil
        draftStore.stockExpenseAmountKeypadVisible = false
    }

    func dismissSystemFeedKeyboardIfNeeded() {
        guard focusedField == .stockBrand else { return }
        GoKeyboard.dismiss()
    }

    var isInlineInputActive: Bool {
        focusedField != nil || draftStore.stockExpenseAmountKeypadVisible
    }
}
