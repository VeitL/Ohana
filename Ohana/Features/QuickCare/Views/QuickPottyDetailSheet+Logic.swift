//
//  QuickPottyDetailSheet+Logic.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension QuickPottyDetailSheet {
    // MARK: - Persistence
    func loadSettings() {
        let settings = LitterCareSettingsStore.snapshot(petKey: petKey)
        scoopIntervalDays = settings.scoopIntervalDays
        scoopReminderOn = settings.scoopReminderOn
        scoopAnchorDate = settings.scoopAnchorDate
        litterChangeIntervalDays = settings.litterChangeIntervalDays
        litterReminderOn = settings.litterReminderOn
        litterCycleAnchorDate = settings.litterCycleAnchorDate
        if settings.createdScoopAnchor {
            LitterCareSettingsStore.saveScoopSettings(
                petKey: petKey,
                intervalDays: scoopIntervalDays,
                anchorDate: scoopAnchorDate,
                reminderOn: scoopReminderOn
            )
        }
        if settings.createdLitterCycleAnchor {
            LitterCareSettingsStore.saveLitterChangeSettings(
                petKey: petKey,
                intervalDays: litterChangeIntervalDays,
                anchorDate: litterCycleAnchorDate,
                reminderOn: litterReminderOn
            )
        }
    }

    func persistScoopSettings() {
        persistScoopSettings(for: pet)
    }

    func persistScoopSettings(for target: Pet) {
        let key = target.id.uuidString
        LitterCareSettingsStore.saveScoopSettings(
            petKey: key,
            intervalDays: scoopIntervalDays,
            anchorDate: scoopAnchorDate,
            reminderOn: scoopReminderOn
        )
    }

    func persistLitterChangeSettings() {
        persistLitterChangeSettings(for: pet)
    }

    func persistLitterChangeSettings(for target: Pet) {
        let key = target.id.uuidString
        LitterCareSettingsStore.saveLitterChangeSettings(
            petKey: key,
            intervalDays: litterChangeIntervalDays,
            anchorDate: litterCycleAnchorDate,
            reminderOn: litterReminderOn
        )
    }

    func startPottyPlanSave(_ operation: @escaping @MainActor () -> Void) {
        guard !isSavingPottyPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingPottyPlan = true
        pottyPlanSaveTask?.cancel()
        dismissInlinePoopSheet()
        pottyPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: pottyPlanSaveDelayMilliseconds) {
            operation()
            isSavingPottyPlan = false
            pottyPlanSaveTask = nil
        }
    }

    var pottyPlanSaveDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    func syncScoopPlan(showToast: Bool) {
        syncScoopPlan(for: selectedPottyTargets, showToast: showToast)
    }

    func syncScoopPlan(for targets: [Pet], showToast: Bool) {
        do {
            let events = try pottyCommandExecutor.syncScoopPlans(
                pets: targets,
                allEvents: allEvents,
                intervalDays: scoopIntervalDays,
                enabled: scoopReminderOn,
                anchor: scoopAnchorDate
            )
            for target in targets {
                persistScoopSettings(for: target)
            }
            if scoopReminderOn {
                scheduleCarePlanReminders(events.flatMap(\.reminders))
            }
            if showToast {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showSaveConfirmation(scoopReminderOn ? l.tr(zh: "铲砂提醒已保存", en: "Scoop reminder saved", de: "Klo-Erinnerung gespeichert") : l.tr(zh: "已保存", en: "Saved", de: "Gespeichert"))
            }
        } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
            if showToast {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
            }
        } catch {
            if showToast {
                appServices.domainRevisions.publishFailure(
                    command: .quickCare(entityID: pet.id, action: "scoopPlan"),
                    error: error
                )
                showSaveConfirmation(l.tr(zh: "保存失败，请重试", en: "Save failed. Please try again.", de: "Speichern fehlgeschlagen. Bitte erneut versuchen."))
            }
        }
    }

    func syncLitterChangePlan(showToast: Bool) {
        syncLitterChangePlan(for: selectedPottyTargets, showToast: showToast)
    }

    func syncLitterChangePlan(for targets: [Pet], showToast: Bool) {
        do {
            let events = try pottyCommandExecutor.syncLitterFullChangePlans(
                pets: targets,
                allEvents: allEvents,
                intervalDays: litterChangeIntervalDays,
                enabled: litterReminderOn,
                cycleAnchor: litterCycleAnchorDate
            )
            for target in targets {
                persistLitterChangeSettings(for: target)
            }
            if litterReminderOn {
                scheduleCarePlanReminders(events.flatMap(\.reminders))
            }
            if showToast {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showSaveConfirmation(litterReminderOn ? l.tr(zh: "换砂提醒已保存", en: "Litter reminder saved", de: "Streu-Erinnerung gespeichert") : l.tr(zh: "已保存", en: "Saved", de: "Gespeichert"))
            }
        } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
            if showToast {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
            }
        } catch {
            if showToast {
                appServices.domainRevisions.publishFailure(
                    command: .quickCare(entityID: pet.id, action: "litterChangePlan"),
                    error: error
                )
                showSaveConfirmation(l.tr(zh: "保存失败，请重试", en: "Save failed. Please try again.", de: "Speichern fehlgeschlagen. Bitte erneut versuchen."))
            }
        }
    }

    func deleteScoopPlan() {
        scoopReminderOn = false
        syncScoopPlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(l.tr(zh: "铲砂计划已删除", en: "Scoop plan deleted", de: "Klo-Plan gelöscht"))
    }

    func deleteLitterChangePlan() {
        litterReminderOn = false
        syncLitterChangePlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(l.tr(zh: "换砂计划已删除", en: "Litter plan deleted", de: "Streu-Plan gelöscht"))
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

    // MARK: - Actions
    @discardableResult
    func logPotty(type: PottyType) -> Bool {
        guard !isCommittingPottyLog, validateActionHumanDraft() else { return false }
        isCommittingPottyLog = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let executorId = selectedActionHumanID?.uuidString
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: type.rawValue)) {
            let result = pottyCommandExecutor.record(
                petID: pet.id,
                selectedType: type,
                isLitter: false,
                executorId: executorId,
                date: Date()
            )
            isCommittingPottyLog = false
            guard let result else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showSaveConfirmation(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let delta = result.coconutDelta
            pottyFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: delta > 0 ? "+\(delta)" : "+1", tint: pottyTint)
            scheduleFeedbackClear()
            showSaveConfirmation(delta > 0 ? "\(type.emoji) +\(delta)🥥" : l.tr(zh: "噗噗已记录", en: "Poop logged", de: "Häufchen erfasst"))
            onRecordChanged()
        }
        return true
    }

    @discardableResult
    func logUnknownGroupPotty() -> Bool {
        guard validateActionHumanDraft() else { return false }
        let targetIDs = Set(selectedPottyTargets.map(\.id))
        let executorId = selectedActionHumanID?.uuidString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: "unknownSharedPotty")) {
            guard pottyCommandExecutor.recordUnknownSharedPotty(
                sourcePetID: pet.id,
                targetIDs: targetIDs,
                type: .perfectPoop,
                executorId: executorId,
                date: Date()
            ) != nil else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showSaveConfirmation(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                return
            }
            SharedPetSelectionMemory.saveSelection(
                targetIDs,
                sourcePet: pet,
                scope: "quickCare.potty",
                candidates: sameSpeciesPottyPets
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            pottyFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: "+1", tint: pottyTint)
            scheduleFeedbackClear()
            onRecordChanged()
            showSaveConfirmation(l.tr(zh: "猫砂盆事件已记录", en: "Litter-box event logged", de: "Klo-Ereignis erfasst"))
        }
        return true
    }

    func doScoop() {
        guard !todayLitterLogs.isEmpty else {
            recordScoop()
            return
        }
        singleUseNoticeMessage = l.tr(
            zh: "\(pet.name) 今天已经铲砂过了。要修改的话，先在最近记录里删除。",
            en: "\(pet.name)'s litter was already scooped today. Delete the latest log to change it.",
            de: "\(pet.name)s Klo wurde heute schon gereinigt. Lösche den letzten Eintrag zum Ändern."
        )
        showSingleUseNotice = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    @discardableResult
    func recordScoop() -> Bool {
        guard validateActionHumanDraft() else { return false }
        let targets = selectedPottyTargets
        let targetIDs = Set(targets.map(\.id))
        let executorId = selectedActionHumanID?.uuidString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: "litterScoop")) {
            guard let result = pottyCommandExecutor.recordLitterCare(
                sourcePetID: pet.id,
                targetIDs: targetIDs,
                executorId: executorId,
                date: Date(),
                isFullChange: false,
                scoopPlan: SharedLitterScoopPlanSnapshot(
                    intervalDays: scoopIntervalDays,
                    anchorDate: scoopAnchorDate,
                    reminderOn: scoopReminderOn
                )
            ) else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showSaveConfirmation(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                return
            }
            if let undoToken = result.undoToken {
                appServices.sharedCareUndo.register(
                    undoToken,
                    targetCount: result.targetCount
                )
            } else {
                SharedPetSelectionMemory.saveSelection(
                    targetIDs,
                    sourcePet: pet,
                    scope: "quickCare.potty",
                    candidates: sameSpeciesPottyPets
                )
                syncScoopPlan(for: targets, showToast: false)
            }
            let delta = result.coconutDelta
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            scoopFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: scoopTint)
            scheduleFeedbackClear()
            let actionText = result.targetCount > 1
                ? l.tr(zh: "\(result.targetCount)只猫 已铲", en: "\(result.targetCount) cats scooped", de: "\(result.targetCount) Katzenklos sauber")
                : l.tr(zh: "铲砂已记录", en: "Scoop logged", de: "Klo erfasst")
            if result.undoToken == nil {
                showSaveConfirmation(delta > 0 ? "\(actionText) +\(delta)🥥" : actionText)
            }
            onRecordChanged()
        }
        return true
    }

    @discardableResult
    func doFullChange() -> Bool {
        guard validateActionHumanDraft() else { return false }
        let now = Date()
        let cycleAnchor = Calendar.current.startOfDay(for: now)
        let shouldRecordLitterCare = todayLitterLogs.isEmpty
        let targets = selectedPottyTargets
        let targetIDs = Set(targets.map(\.id))
        let executorId = selectedActionHumanID?.uuidString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: "litterFullChange")) {
            guard canApplyPottyDerivedEffects(executorId: executorId) else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showSaveConfirmation(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                return
            }

            if shouldRecordLitterCare {
                guard pottyCommandExecutor.recordLitterCare(
                    sourcePetID: pet.id,
                    targetIDs: targetIDs,
                    executorId: executorId,
                    date: now,
                    isFullChange: true
                ) != nil else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    showSaveConfirmation(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                    return
                }
            }
            LitterCareSettingsStore.markFullChange(petKey: petKey, changedAt: now, cycleAnchor: cycleAnchor)
            SharedPetSelectionMemory.saveSelection(
                targetIDs,
                sourcePet: pet,
                scope: "quickCare.potty",
                candidates: sameSpeciesPottyPets
            )
            litterCycleAnchorDate = cycleAnchor
            syncScoopPlan(for: targets, showToast: false)
            syncLitterChangePlan(for: targets, showToast: false)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            litterFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: litterTint)
            scheduleFeedbackClear()
            showSaveConfirmation(
                targets.count > 1
                    ? l.tr(zh: "\(targets.count)只猫 已换砂", en: "\(targets.count) litter boxes changed", de: "\(targets.count) Katzenstreus gewechselt")
                    : l.tr(zh: "换砂已记录", en: "Litter change logged", de: "Streuwechsel erfasst")
            )
            onRecordChanged()
        }
        return true
    }

    func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                pottyFeedbackToken = nil
                scoopFeedbackToken = nil
                litterFeedbackToken = nil
            }
        }
    }

    func deleteItem(_ item: PoopLogItem) {
        switch item {
        case let .potty(entry):
            guard let logId = entry.legacyLogId else {
                OhanaLog.warning(
                    "QuickPottyDetailSheet could not resolve potty log for ledger entry \(entry.id.uuidString)",
                    category: "Care"
                )
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            commandQueue.enqueue(.petPottyDelete(petID: pet.id, logID: logId)) {
                let executor = PetCareCommandExecutor(context: modelContext, services: appServices)
                guard let log = executor.pottyLog(id: logId) else {
                    OhanaLog.warning(
                        "QuickPottyDetailSheet could not resolve potty log \(logId.uuidString)",
                        category: "Care"
                    )
                    return
                }
                _ = executor.deletePottyLog(
                    log,
                    pet: pet,
                    note: "quickPotty.deletePotty"
                )
            }
        case let .unknownPotty(entry):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            commandQueue.enqueue(.petPottyDelete(petID: pet.id, logID: entry.id)) {
                let executor = PetCareCommandExecutor(context: modelContext, services: appServices)
                guard let log = executor.pottyLog(id: entry.id) else {
                    OhanaLog.warning(
                        "QuickPottyDetailSheet could not resolve unknown potty log \(entry.id.uuidString)",
                        category: "Care"
                    )
                    return
                }
                _ = executor.deletePottyLog(
                    log,
                    pet: pet,
                    note: "quickPotty.deletePotty"
                )
            }
        case let .litter(entry):
            guard let logId = entry.legacyLogId else {
                OhanaLog.warning(
                    "QuickPottyDetailSheet could not resolve litter care log for ledger entry \(entry.id.uuidString)",
                    category: "Care"
                )
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            commandQueue.enqueue(.petCareDelete(petID: pet.id, logID: logId)) {
                let executor = PetCareCommandExecutor(context: modelContext, services: appServices)
                guard let log = executor.careLog(id: logId) else {
                    OhanaLog.warning(
                        "QuickPottyDetailSheet could not resolve litter care log \(logId.uuidString)",
                        category: "Care"
                    )
                    return
                }
                _ = executor.deleteCareLog(
                    log,
                    pet: pet,
                    note: "quickPotty.deleteLitter"
                )
                syncScoopPlan(showToast: false)
            }
        }
    }

    func claimUnknownPotty(_ logId: UUID, target: Pet) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: target.id, action: "claimUnknownPotty")) {
            let executor = PetCareCommandExecutor(context: modelContext, services: appServices)
            guard let log = executor.pottyLog(id: logId) else {
                OhanaLog.warning(
                    "QuickPottyDetailSheet could not resolve unknown potty log \(logId.uuidString)",
                    category: "Care"
                )
                return
            }
            _ = executor.claimUnknownPottyLog(
                log,
                pet: target,
                note: "quickPotty.claimUnknown"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(
                l.tr(
                    zh: "已归到 \(target.name)",
                    en: "Assigned to \(target.name)",
                    de: "\(target.name) zugeordnet"
                )
            )
            pottyFeedbackToken = CheckInFeedbackToken(
                kind: .done,
                deltaText: "✓",
                tint: pottyTint
            )
            scheduleFeedbackClear()
        }
    }

    func canApplyPottyDerivedEffects(executorId: String?) -> Bool {
        EconomyWalletWritePolicy.canWrite(pet)
    }

    func normalizedSpecies(_ value: String) -> String {
        SharedPetTargetResolver.normalizedSpecies(value)
    }

    func scheduleCarePlanReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }

        Task { @MainActor in
            guard await appServices.userNotifications.requestPermission() else { return }
            await appServices.reminderScheduling.scheduleManyIfNeeded(
                reminders: reminders,
                context: modelContext,
                source: .detail
            )
        }
    }

    // MARK: - Formatting
    func daysSinceDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    func relativeDayText(for date: Date) -> String {
        let days = daysSinceDate(date)
        if days == 0 { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 { return dayCountText(daysUntil) }
        if daysUntil == 0 { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        let overdue = abs(daysUntil)
        return l.tr(zh: "逾期\(overdue)天", en: "\(overdue)d overdue", de: "\(overdue) T. fällig")
    }

    func timesText(_ count: Int) -> String {
        l.tr(zh: "\(count) 次", en: "\(count)x", de: "\(count)x")
    }

    func dayCountText(_ days: Int) -> String {
        l.tr(zh: "\(days)天", en: "\(days)d", de: "\(days) T.")
    }

    func cycleText(_ days: Int) -> String {
        l.tr(zh: "\(days)天周期", en: "\(days)d rhythm", de: "\(days)-Tage-Rhythmus")
    }

    func everyDaysText(_ days: Int) -> String {
        l.tr(zh: "每\(days)天", en: "Every \(days)d", de: "Alle \(days) Tage")
    }

    func progressDaysText(elapsed: Int, interval: Int) -> String {
        l.tr(zh: "\(elapsed)/\(interval)天", en: "\(elapsed)/\(interval)d", de: "\(elapsed)/\(interval) T.")
    }

    func petCountText(_ count: Int, species: String) -> String {
        l.tr(zh: "\(count)只\(species)", en: "\(count) \(species)", de: "\(count) \(species)")
    }

    func cycleProgress(elapsed: Int, interval: Int) -> Double {
        min(Double(max(elapsed, 0)) / Double(max(interval, 1)), 1)
    }

    func tint(for item: PoopLogItem) -> Color {
        switch item {
        case let .potty(entry):
            pottyTypeColor(entry.pottyType)
        case .unknownPotty:
            pottyTint
        case .litter:
            scoopTint
        }
    }

    func pottyTypeColor(_ type: PottyType) -> Color {
        switch type {
        case .perfectPoop: pottyTint
        case .softPoop: Color(hex: "F59E0B")
        case .liquidPoop: Color(hex: "EF4444")
        case .pee: Color(hex: "06B6D4")
        }
    }
}
