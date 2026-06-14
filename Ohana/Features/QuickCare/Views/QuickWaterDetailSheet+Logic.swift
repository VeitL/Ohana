//
//  QuickWaterDetailSheet+Logic.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension QuickWaterDetailSheet {
    // MARK: - Persistence
    func loadSettings() {
        let settings = WaterCareSettingsStore.snapshot(petKey: petKey)
        waterIntervalDays = settings.waterIntervalDays
        filterCleanIntervalDays = settings.filterCleanIntervalDays
        filterReplaceIntervalDays = settings.filterReplaceIntervalDays
        waterReminderOn = settings.waterReminderOn
        filterReminderOn = settings.filterReminderOn
        waterAmountEnabled = settings.waterAmountEnabled
        waterAmountMlText = String(format: "%.0f", settings.waterAmountMl)
        waterChangeAnchorDate = settings.waterChangeAnchorDate
        if settings.createdWaterChangeAnchor {
            persistWaterSettings()
        }
    }

    func persistWaterSettings() {
        commandExecutor.persistWaterSettings(
            pet: pet,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
    }

    func persistWaterAmountSettings() {
        commandExecutor.persistWaterAmountSettings(
            pet: pet,
            enabled: waterAmountEnabled,
            amountMl: defaultWaterAmountMl
        )
    }

    func persistFilterSettings() {
        commandExecutor.persistFilterSettings(
            pet: pet,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn
        )
    }

    func saveWaterChangePlanToCalendar(toast: String) {
        let reminders = commandExecutor.saveWaterChangePlan(
            pet: pet,
            allEvents: allEvents,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
        scheduleCarePlanReminders(reminders)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(toast)
    }

    func syncFilterPlan(showToast: Bool) {
        let reminders = commandExecutor.syncFilterPlan(
            pet: pet,
            allEvents: allEvents,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn
        )
        scheduleCarePlanReminders(reminders)
        if showToast {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(filterReminderOn ? l.tr(zh: "已保存滤芯提醒", en: "Filter reminder saved", de: "Filtererinnerung gespeichert") : l.tr(zh: "已保存", en: "Saved", de: "Gespeichert"))
        }
    }

    func showSaveConfirmation(_ message: String) {
        saveToastTask?.cancel()
        saveToastMessage = message
        withAnimation(GoMotion.feedback) {
            showSaveToast = true
        }
        saveToastTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(GoMotion.quick) {
                    showSaveToast = false
                }
            }
        }
    }

    func rebuildWaterSnapshot(force: Bool = false) {
        guard force || waterSnapshotRefreshTask == nil else { return }
        performWaterModeUpdatesWithoutAnimation {
            let snapshot = QuickWaterRenderSnapshot.build(
                pet: pet,
                allEvents: allEvents,
                waterLedgerEvents: waterLedgerEvents
            )
            waterSnapshot = snapshot
            if !snapshot.rule.planEvents.isEmpty {
                optimisticWaterPlanEvents = []
            }
        }
    }

    func scheduleWaterSnapshotRefresh(milliseconds: UInt64 = 0, syncModeAfterRefresh: Bool = false) {
        var request: QuickWaterRefreshRequest = .reloadSnapshot
        if syncModeAfterRefresh {
            request.insert(.syncDisplayedMode)
        }
        scheduleDeferredWaterRefresh(request, milliseconds: milliseconds)
    }

    func scheduleDeferredWaterRefresh(
        _ request: QuickWaterRefreshRequest,
        milliseconds: UInt64 = 0
    ) {
        pendingWaterRefreshRequest.formUnion(request)
        if let currentDelay = waterRefreshDelayMilliseconds,
           waterSnapshotRefreshTask != nil,
           currentDelay <= milliseconds {
            return
        }

        waterSnapshotRefreshTask?.cancel()
        waterRefreshDelayMilliseconds = milliseconds
        waterSnapshotRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            let request = pendingWaterRefreshRequest
            pendingWaterRefreshRequest = QuickWaterRefreshRequest()
            waterRefreshDelayMilliseconds = nil
            waterSnapshotRefreshTask = nil
            performDeferredWaterRefresh(request)
        }
    }

    func performDeferredWaterRefresh(_ request: QuickWaterRefreshRequest) {
        guard !request.isEmpty else { return }
        if request.contains(.reloadSnapshot) {
            rebuildWaterSnapshot(force: true)
        }
        if request.contains(.syncDisplayedMode) {
            syncDisplayedWaterMode(
                animated: activeWaterModeTransitionID == nil,
                force: request.contains(.forceDisplayedMode)
            )
        }
    }

    @discardableResult
    func scheduleDeferredWaterAction(
        milliseconds: UInt64 = 48,
        _ action: @escaping @MainActor () -> Void
    ) -> Bool {
        guard waterActionTask == nil else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return false
        }
        waterActionTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            action()
            waterActionTask = nil
        }
        return true
    }

    func scheduleOverviewChartReplay(milliseconds: UInt64) {
        overviewChartReplayTask?.cancel()
        overviewChartReplayTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            withAnimation(GoMotion.page) {
                overviewChartProgress = 1
            }
            overviewChartReplayTask = nil
        }
    }

    // MARK: - Actions
    func handleWaterModeTap(_ mode: WaterOperatingMode) {
        guard !isAquatic else {
            openRootWaterSheet(.waterOverview)
            return
        }
        guard mode != waterMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        switch mode {
        case .manual:
            activateManualWaterMode()
        case .reminder:
            if latestWaterPlanEvents().isEmpty {
                openWaterPlanSettings()
            } else {
                activateExistingWaterPlanMode()
            }
        }
    }

    func handleWaterSettingsTap() {
        if waterMode == .reminder {
            openWaterPlanSettings()
        } else {
            openWaterSheet(.waterAmount)
        }
    }

    func openWaterPlanSettings() {
        let events = latestWaterPlanEvents()
        if events.isEmpty {
            waterPlanCount = 3
            waterPlanTimes = commandExecutor.suggestedWaterPlanTimes(count: waterPlanCount)
        } else {
            waterPlanCount = min(max(events.count, 1), 6)
            waterPlanTimes = commandExecutor.normalizedWaterPlanTimes(events.map(\.startDate), count: waterPlanCount)
        }
        openWaterSheet(.waterPlan)
    }

    func syncWaterPlanTimesCount(_ count: Int) {
        withAnimation(GoMotion.feedback) {
            waterPlanTimes = commandExecutor.normalizedWaterPlanTimes(waterPlanTimes, count: count)
        }
    }

    func startWaterPlanSave() {
        guard !isSavingWaterPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingWaterPlan = true
        waterPlanSaveTask?.cancel()
        dismissInlineWaterSheet()
        performWaterModeUpdatesWithoutAnimation {
            displayedWaterMode = .reminder
        }
        UISelectionFeedbackGenerator().selectionChanged()
        waterPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: waterPlanSaveDelayMilliseconds) {
            saveWaterPlan()
        }
    }

    func startWaterCalendarPlanSave(_ operation: @escaping @MainActor () -> Void) {
        guard !isSavingWaterPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingWaterPlan = true
        waterPlanSaveTask?.cancel()
        dismissInlineWaterSheet()
        UISelectionFeedbackGenerator().selectionChanged()
        waterPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: waterPlanSaveDelayMilliseconds) {
            operation()
            isSavingWaterPlan = false
            waterPlanSaveTask = nil
        }
    }

    func saveWaterPlan() {
        SharedPetSelectionMemory.saveSelection(
            Set(selectedWaterTargets.map(\.id)),
            sourcePet: pet,
            scope: "quickCare.water",
            candidates: sameSpeciesWaterPets
        )
        let result = commandExecutor.saveWaterPlan(
            pet: pet,
            targets: selectedWaterTargets,
            times: waterPlanTimes,
            count: waterPlanCount,
            allEvents: latestAllEvents()
        )
        waterPlanTimes = result.normalizedTimes
        optimisticWaterPlanEvents = result.optimisticPlanEvents
        scheduleWaterReminders(
            result.reminders,
            delayMilliseconds: waterPlanPostSaveReminderDelayMilliseconds,
            requiresReminderMode: true
        )
        scheduleWaterSnapshotRefresh(milliseconds: waterPlanPostSaveSnapshotDelayMilliseconds)
        scheduleWaterPlanMaintenance(delayMilliseconds: waterPlanPostSaveMaintenanceDelayMilliseconds)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        setActiveWaterMode(.reminder)
        showSaveConfirmation(result.targetCount > 1 ? localizedSharedWaterPlanSaved(result.targetCount) : l.tr(zh: "已保存喂水计划", en: "Water plan saved", de: "Trinkplan gespeichert"))
        isSavingWaterPlan = false
        waterPlanSaveTask = nil
    }

    func activateManualWaterMode() {
        waterReminderSchedulingTask?.cancel()
        waterReminderSchedulingID = nil
        commitWaterModeSideEffects(.manual)
        beginWaterModeVisualTransition(to: .manual) {
            scheduleSettledWaterModeMaintenance(for: .manual) {
                commandExecutor.deactivateWaterPlanReminders(
                    pet: pet,
                    allEvents: latestAllEvents()
                )
                showSaveConfirmation(l.tr(zh: "已切换到手动喂水", en: "Switched to manual water logging", de: "Auf manuelles Trinken umgestellt"))
            }
        }
    }

    func activateExistingWaterPlanMode() {
        let events = latestWaterPlanEvents()
        guard !events.isEmpty else {
            openWaterPlanSettings()
            return
        }
        commitWaterModeSideEffects(.reminder)
        beginWaterModeVisualTransition(to: .reminder) {
            scheduleSettledWaterModeMaintenance(for: .reminder) {
                ensureUpcomingWaterPlanReminders()
                showSaveConfirmation(l.tr(zh: "已切换到喂水计划", en: "Switched to water plan", de: "Auf Trinkplan umgestellt"))
            }
        }
    }

    func deleteWaterPlanAndSwitchToManual() {
        optimisticWaterPlanEvents = []
        waterReminderSchedulingTask?.cancel()
        waterReminderSchedulingID = nil
        commitWaterModeSideEffects(.manual)
        beginWaterModeVisualTransition(to: .manual, commitWhenUnchanged: true) {
            scheduleSettledWaterModeMaintenance(for: .manual) {
                commandExecutor.deleteWaterPlan(pet: pet, allEvents: latestAllEvents())
                showSaveConfirmation(l.tr(zh: "已删除喂水计划", en: "Water plan deleted", de: "Trinkplan gelöscht"))
            }
        }
    }

    func setActiveWaterMode(_ mode: WaterOperatingMode) {
        performWaterModeUpdatesWithoutAnimation {
            displayedWaterMode = isAquatic ? .manual : mode
            commitWaterModeSideEffects(mode)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func commitWaterModeSideEffects(_ mode: WaterOperatingMode) {
        commandExecutor.setWaterMode(mode, pet: pet)
        waterModeStorageTick += 1
    }

    func resolvedWaterModeFromStorageAndSnapshot() -> WaterOperatingMode {
        guard !isAquatic else { return .manual }
        let hasPlan = !latestWaterPlanEvents().isEmpty
        if let storedMode = WaterOperatingMode.stored(pet.id) {
            return storedMode == .reminder && !hasPlan ? .manual : storedMode
        }
        return hasPlan ? .reminder : .manual
    }

    func syncDisplayedWaterMode(animated: Bool = false, force: Bool = false) {
        guard force || activeWaterModeTransitionID == nil else { return }
        let resolvedMode = resolvedWaterModeFromStorageAndSnapshot()
        guard displayedWaterMode != resolvedMode else { return }
        if animated {
            withAnimation(waterModeTransitionAnimation) {
                displayedWaterMode = resolvedMode
            }
        } else {
            performWaterModeUpdatesWithoutAnimation {
                displayedWaterMode = resolvedMode
            }
        }
    }

    func beginWaterModeVisualTransition(
        to targetMode: WaterOperatingMode,
        commitWhenUnchanged: Bool = false,
        commitAfterAnimation: @escaping @MainActor () -> Void
    ) {
        let fromMode = waterMode
        guard fromMode != targetMode || commitWhenUnchanged else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        waterModeTransitionTask?.cancel()
        waterModeMaintenanceTask?.cancel()
        waterPlanMaintenanceTask?.cancel()
        let transitionID = UUID()
        activeWaterModeTransitionID = transitionID

        if fromMode != targetMode {
            withAnimation(waterModeTransitionAnimation) {
                displayedWaterMode = targetMode
            }
        }

        UISelectionFeedbackGenerator().selectionChanged()
        scheduleWaterModeTransitionFinish(transitionID: transitionID, commit: commitAfterAnimation)
    }

    var waterModeTransitionAnimation: Animation {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? GoMotion.page : GoMotion.reduced
    }

    var waterModeTransitionDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 320 : 120
    }

    func scheduleWaterModeTransitionFinish(
        transitionID: UUID,
        commit: @escaping @MainActor () -> Void
    ) {
        waterModeTransitionTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: waterModeTransitionDelayMilliseconds)
            guard !Task.isCancelled,
                  activeWaterModeTransitionID == transitionID else { return }

            performWaterModeUpdatesWithoutAnimation {
                activeWaterModeTransitionID = nil
            }
            commit()
            waterModeTransitionTask = nil
        }
    }

    var waterModeMaintenanceDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 850 : 300
    }

    var waterPlanPostSaveSnapshotDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 180 : 80
    }

    var waterPlanSaveDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    var waterPlanPostSaveReminderDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 980 : 320
    }

    var waterPlanPostSaveMaintenanceDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 1120 : 420
    }

    func scheduleSettledWaterModeMaintenance(
        for mode: WaterOperatingMode,
        _ maintenance: @escaping @MainActor () -> Void
    ) {
        waterModeMaintenanceTask?.cancel()
        waterModeMaintenanceTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: waterModeMaintenanceDelayMilliseconds)
            guard !Task.isCancelled,
                  activeWaterModeTransitionID == nil,
                  waterMode == mode,
                  !pet.hasPassedAway
            else { return }

            performWaterModeUpdatesWithoutAnimation {
                maintenance()
            }
            scheduleWaterSnapshotRefresh()
            syncDisplayedWaterMode(force: true)
            waterModeMaintenanceTask = nil
        }
    }

    func scheduleWaterPlanMaintenance(delayMilliseconds: UInt64) {
        guard !pet.hasPassedAway, !isAquatic else { return }
        waterPlanMaintenanceTask?.cancel()
        waterPlanMaintenanceTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard activeWaterModeTransitionID == nil else {
                waterPlanMaintenanceTask = nil
                scheduleWaterPlanMaintenance(delayMilliseconds: waterModeMaintenanceDelayMilliseconds)
                return
            }
            performWaterModeUpdatesWithoutAnimation {
                ensureUpcomingWaterPlanReminders()
            }
            scheduleWaterSnapshotRefresh(milliseconds: 80)
            waterPlanMaintenanceTask = nil
        }
    }

    func performWaterModeUpdatesWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    func ensureUpcomingWaterPlanReminders() {
        guard !isAquatic else { return }
        let reminders = commandExecutor.ensureUpcomingWaterPlanReminders(pet: pet, allEvents: latestAllEvents())
        scheduleWaterReminders(reminders, delayMilliseconds: 480, requiresReminderMode: true)
    }

    func latestAllEvents() -> [Event] {
        commandExecutor.latestAllEvents(fallback: allEvents)
    }

    func latestWaterPlanEvents() -> [Event] {
        if !waterRuleState.planEvents.isEmpty {
            return waterRuleState.planEvents
        }
        if !optimisticWaterPlanEvents.isEmpty {
            return optimisticWaterPlanEvents
        }
        return commandExecutor.waterPlanEvents(pet: pet, allEvents: allEvents)
    }

    func scheduleWaterReminders(
        _ reminders: [Reminder],
        delayMilliseconds: UInt64 = 0,
        requiresReminderMode: Bool = false
    ) {
        guard !reminders.isEmpty else { return }
        waterReminderSchedulingTask?.cancel()
        let requestID = UUID()
        waterReminderSchedulingID = requestID
        waterReminderSchedulingTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled,
                  waterReminderSchedulingID == requestID
            else {
                finishWaterReminderScheduling(requestID)
                return
            }
            if requiresReminderMode {
                guard activeWaterModeTransitionID == nil,
                      waterMode == .reminder
                else {
                    finishWaterReminderScheduling(requestID)
                    return
                }
            }
            guard !Task.isCancelled,
                  waterReminderSchedulingID == requestID
            else {
                finishWaterReminderScheduling(requestID)
                return
            }
            await commandExecutor.scheduleReminders(reminders, requestPermission: true)
            finishWaterReminderScheduling(requestID)
        }
    }

    func finishWaterReminderScheduling(_ requestID: UUID) {
        guard waterReminderSchedulingID == requestID else { return }
        waterReminderSchedulingTask = nil
        waterReminderSchedulingID = nil
    }

    func scheduleCarePlanReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        carePlanReminderSchedulingTask?.cancel()
        let requestID = UUID()
        carePlanReminderSchedulingID = requestID
        carePlanReminderSchedulingTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 180)
            guard !Task.isCancelled,
                  carePlanReminderSchedulingID == requestID
            else {
                finishCarePlanReminderScheduling(requestID)
                return
            }
            guard !Task.isCancelled,
                  carePlanReminderSchedulingID == requestID
            else {
                finishCarePlanReminderScheduling(requestID)
                return
            }
            await commandExecutor.scheduleReminders(reminders, requestPermission: true)
            finishCarePlanReminderScheduling(requestID)
        }
    }

    func finishCarePlanReminderScheduling(_ requestID: UUID) {
        guard carePlanReminderSchedulingID == requestID else { return }
        carePlanReminderSchedulingTask = nil
        carePlanReminderSchedulingID = nil
    }

    func completeNextPlannedWaterOrOpenOverview() {
        guard let reminder = waterRuleState.nextPendingReminder else {
            openRootWaterSheet(.waterOverview)
            return
        }
        guard scheduleDeferredWaterAction({ completePlannedWater(reminder) }) else { return }
    }

    func completePlannedWater(_ reminder: Reminder) {
        let result = commandExecutor.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: defaultWaterAmountMl ?? 0,
            executorId: commandExecutor.activeExecutorId()
        )
        guard result.didRecord else { return }
        guard result.allowsDerivedEffects else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterFeedback()
        showSaveConfirmation(result.coconutDelta > 0 ? localizedWaterPlanReward(result.coconutDelta) : l.tr(zh: "已完成喂水", en: "Water check-in complete", de: "Trink-Check-in erledigt"))
        scheduleWaterPlanMaintenance(delayMilliseconds: 180)
    }

    func commitWater() {
        guard scheduleDeferredWaterAction(commitWaterBusiness) else { return }
    }

    func commitWaterBusiness() {
        let result = commandExecutor.recordWater(
            pet: pet,
            targets: selectedWaterTargets,
            amountMl: defaultWaterAmountMl ?? 0,
            executorId: commandExecutor.activeExecutorId()
        )
        guard result.didRecord, result.allowsDerivedEffects else { return }
        SharedPetSelectionMemory.saveSelection(
            Set(selectedWaterTargets.map(\.id)),
            sourcePet: pet,
            scope: "quickCare.water",
            candidates: sameSpeciesWaterPets
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterFeedback()
        let actionText = result.targetCount > 1 ? localizedSharedWaterLogged(result.targetCount) : l.tr(zh: "已记录喂水", en: "Water logged", de: "Trinken eingetragen")
        showSaveConfirmation(result.coconutDelta > 0 ? "\(actionText) +\(result.coconutDelta)🥥" : actionText)
    }

    func doWaterChange() {
        guard scheduleDeferredWaterAction(recordWaterChangeBusiness) else { return }
    }

    func recordWaterChangeBusiness() {
        let result = commandExecutor.recordWaterChange(
            pet: pet,
            targets: selectedWaterTargets,
            allEvents: allEvents,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate,
            executorId: commandExecutor.activeExecutorId()
        )
        guard result.didRecord, result.allowsDerivedEffects else { return }
        SharedPetSelectionMemory.saveSelection(
            Set(selectedWaterTargets.map(\.id)),
            sourcePet: pet,
            scope: "quickCare.water",
            candidates: sameSpeciesWaterPets
        )
        scheduleCarePlanReminders(result.reminders)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterChangeFeedback()
        showSaveConfirmation(l.tr(zh: "已记录换水", en: "Water change logged", de: "Wasserwechsel eingetragen"))
    }

    func doFilterClean() {
        guard scheduleDeferredWaterAction(recordFilterCleanBusiness) else { return }
    }

    func recordFilterCleanBusiness() {
        let result = commandExecutor.recordFilterClean(
            pet: pet,
            targets: selectedWaterTargets,
            allEvents: allEvents,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn,
            executorId: commandExecutor.activeExecutorId()
        )
        guard result.didRecord, result.allowsDerivedEffects else { return }
        SharedPetSelectionMemory.saveSelection(
            Set(selectedWaterTargets.map(\.id)),
            sourcePet: pet,
            scope: "quickCare.water",
            candidates: sameSpeciesWaterPets
        )
        scheduleCarePlanReminders(result.reminders)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerFilterFeedback()
        showSaveConfirmation(l.tr(zh: "滤芯已清洗", en: "Filter cleaned", de: "Filter gereinigt"))
    }

    func triggerWaterFeedback() {
        let text = defaultWaterAmountMl.map { "+\(Int($0.rounded()))ml" } ?? "+1"
        waterFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: text, tint: waterMode == .reminder ? Color.goTeal : chromeTint)
        scheduleFeedbackClear()
    }

    func triggerWaterChangeFeedback() {
        waterChangeFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: waterChangeTint)
        scheduleFeedbackClear()
    }

    func triggerFilterFeedback() {
        filterFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: filterTint)
        scheduleFeedbackClear()
    }

    func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                waterFeedbackToken = nil
                waterChangeFeedbackToken = nil
                filterFeedbackToken = nil
            }
        }
    }

    func deleteLog(_ entry: QuickWaterLedgerEntry) {
        guard let log = legacyWaterDeleteLog(for: entry) else {
            OhanaLog.warning(
                "QuickWaterDetailSheet could not resolve care log for ledger entry \(entry.id.uuidString)",
                category: "Care"
            )
            return
        }
        guard scheduleDeferredWaterAction({ deleteLogBusiness(log) }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func deleteLogBusiness(_ log: PetCareLog) {
        switch commandExecutor.deleteLog(log) {
        case .waterChange:
            saveWaterChangePlanToCalendar(toast: l.tr(zh: "已更新换水周期", en: "Water change cycle updated", de: "Wasserwechselzyklus aktualisiert"))
        case .filterClean:
            syncFilterPlan(showToast: false)
        case .other:
            break
        }
    }

    func normalizedSpecies(_ value: String) -> String {
        SharedPetTargetResolver.normalizedSpecies(value)
    }

    // MARK: - Formatting
    func daysSinceDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 {
            return l.tr(
                zh: "\(daysUntil)天",
                en: "in \(daysUntil) days",
                de: "in \(daysUntil) Tagen"
            )
        }
        if daysUntil == 0 { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        return l.tr(
            zh: "逾期\(abs(daysUntil))天",
            en: "\(abs(daysUntil)) days overdue",
            de: "\(abs(daysUntil)) Tage überfällig"
        )
    }

    func optionalDueText(_ daysUntil: Int?) -> String {
        guard let daysUntil else { return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag") }
        return dueText(daysUntil: daysUntil)
    }

    func cycleProgress(elapsed: Int, interval: Int) -> Double {
        min(Double(max(elapsed, 0)) / Double(max(interval, 1)), 1)
    }

    func relativeDayText(for date: Date) -> String {
        let days = daysSinceDate(date)
        if days == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return l.tr(
            zh: "\(days)天前",
            en: "\(days) days ago",
            de: "Vor \(days) Tagen"
        )
    }

    func legacyWaterDeleteLog(for entry: QuickWaterLedgerEntry) -> PetCareLog? {
        guard let legacyLogId = entry.legacyLogId else { return nil }
        return legacyWaterDeleteLogs.first { $0.id == legacyLogId }
    }

    func tint(for log: QuickWaterLedgerEntry) -> Color {
        if log.careType == .waterChange {
            return waterChangeTint
        }
        if log.careType == .filterClean {
            return filterTint
        }
        return chromeTint
    }

    var parsedWaterAmountMl: Double? {
        Double(waterAmountMlText.replacingOccurrences(of: ",", with: "."))
    }

    var defaultWaterAmountMl: Double? {
        guard waterAmountEnabled else { return nil }
        guard let amount = parsedWaterAmountMl, amount > 0 else { return 250 }
        return amount
    }

    var waterPrimaryTitle: String {
        if isAquatic { return l.tr(zh: "总览", en: "Overview", de: "Übersicht") }
        if waterMode == .reminder {
            if waterRuleState.missedCount > 0 { return l.tr(zh: "补打卡", en: "Catch up", de: "Nachholen") }
            return waterRuleState.nextPendingReminder == nil ? waterRuleState.completionText : l.tr(zh: "完成", en: "Done", de: "Fertig")
        }
        guard let amount = defaultWaterAmountMl else { return l.tr(zh: "打卡", en: "Check in", de: "Eintragen") }
        return "\(Int(amount.rounded()))ml"
    }

    var waterPrimaryIcon: String {
        if isAquatic { return "chart.line.uptrend.xyaxis" }
        if waterMode == .reminder {
            return waterRuleState.nextPendingReminder == nil ? "checkmark.seal.fill" : "checkmark"
        }
        return "plus"
    }

    func localizedSharedWaterPlanSaved(_ count: Int) -> String {
        l.tr(
            zh: "共同喂水计划已保存 · \(count)只",
            en: "Shared water plan saved · \(count) pets",
            de: "Gemeinsamer Trinkplan gespeichert · \(count) Tiere"
        )
    }

    func localizedWaterPlanReward(_ coconutDelta: Int) -> String {
        l.tr(
            zh: "喂水计划 +\(coconutDelta)🥥",
            en: "Water plan +\(coconutDelta)🥥",
            de: "Trinkplan +\(coconutDelta)🥥"
        )
    }

    func localizedSharedWaterLogged(_ count: Int) -> String {
        l.tr(
            zh: "共同喂水 · \(count)只",
            en: "Shared water · \(count) pets",
            de: "Gemeinsam trinken · \(count) Tiere"
        )
    }
}
