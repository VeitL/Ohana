import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func commitManualFeed() {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(draftStore.manualGramsText), grams > 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        commitManualFeed(
            grams: grams,
            saveAsDefault: draftStore.saveManualAsDefault,
            date: draftStore.manualFeedDate
        )
    }

    func saveManualFeedSettings() {
        dismissFeedKeyboard()
        let grams = parsePositiveDouble(draftStore.manualGramsText) ?? 0
        guard !draftStore.manualDefaultEnabled || grams > 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        draftStore.inputError = nil
        guard commandExecutor.saveManualSettings(
            pet: pet,
            foodKind: draftStore.manualFoodKindDraft,
            grams: grams,
            defaultEnabled: draftStore.manualDefaultEnabled
        ) else {
            showFeedPersistenceFailure()
            return
        }
        defaultFeedGrams = draftStore.manualDefaultEnabled ? grams : 0
        reloadFeedSnapshots(forceSnapshot: true)
        collapseEmbeddedPanel()
        dismissInlineFeedSheet()
        triggerToast(
            l.tr(zh: "喂食设置已保存", en: "Feeding settings saved", de: "Fütterung gespeichert"),
            tint: mainFoodTint
        )
    }

    func commitManualFeed(
        grams: Double,
        saveAsDefault: Bool,
        foodKind selectedFoodKind: FeedFoodKind? = nil,
        date: Date = Date()
    ) {
        guard !isRecordingFeed, validateActionHumanSelection() else { return }
        draftStore.inputError = nil
        let foodKind = selectedFoodKind ?? draftStore.manualFoodKindDraft
        let executorId = selectedActionExecutorId
        let action = {
            guard !isRecordingFeed else { return }
            isRecordingFeed = true
            savedRecord = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            recordCommandQueue.enqueue(.quickCare(entityID: pet.id, action: "feeding")) {
            defer { isRecordingFeed = false }
            let result = commandExecutor.recordManual(
                pet: pet,
                targets: selectedFeedTargets,
                grams: grams,
                foodKind: foodKind,
                saveAsDefault: saveAsDefault,
                foodRecords: observedFoodRecords,
                allEvents: latestAllEvents(),
                executorId: executorId,
                date: date,
                note: draftStore.manualNote
            )
            guard result.didPersist else {
                showFeedPersistenceFailure()
                return
            }
            guard result.didRecord else { return }
            savedRecord = result.recordReference
            selectedActionHumanID = nil
            guard result.allowsDerivedEffects else {
                reloadFeedSnapshots(forceSnapshot: true)
                return
            }
            if saveAsDefault {
                defaultFeedGrams = grams
            }
            SharedPetSelectionMemory.saveSelection(
                Set(selectedFeedTargets.map(\.id)),
                sourcePet: pet,
                scope: "feeding.manual",
                candidates: sameSpeciesFeedPets
            )
            triggerFeedCheckInFeedback(foodKind: result.foodKind, grams: result.grams, affectsStock: result.affectsStock)
            let message = result.targetCount > 1
                ? l.tr(zh: "共同喂食 · \(result.targetCount)只", en: "Shared feeding · \(result.targetCount)", de: "Gemeinsam gefüttert · \(result.targetCount)")
                : l.tr(zh: "已记录\(result.foodKind.title(l))", en: "\(result.foodKind.title(l)) saved", de: "\(result.foodKind.title(l)) gespeichert")
            draftStore.selectedSharedFeedPetIds = [pet.id]
            afterFoodLogSaved(message: message, tint: mainFoodTint, stockReminders: result.stockReminders)
            }
        }
        performWithAntiRepeat(action)
    }

    func completeNextPlannedFeed() {
        dismissFeedKeyboard()
        guard let reminder = overviewSnapshot.nextPendingManualReminder else {
            prepareManualSheet()
            openFeedSheet(.manual)
            return
        }
        completePlannedFeed(reminder)
    }

    func completePlannedFeed(_ reminder: Reminder) {
        guard !isRecordingFeed, validateActionHumanSelection() else { return }
        let executorId = selectedActionExecutorId
        let action = {
            guard !isRecordingFeed else { return }
            isRecordingFeed = true
            savedRecord = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            recordCommandQueue.enqueue(.quickCare(entityID: pet.id, action: "feeding")) {
            defer { isRecordingFeed = false }
            let result = commandExecutor.completePlanned(
                pet: pet,
                reminder: reminder,
                foodRecords: observedFoodRecords,
                allEvents: latestAllEvents(),
                executorId: executorId
            )
            guard result.didPersist else {
                showFeedPersistenceFailure()
                return
            }
            guard result.didRecord else {
                reloadFeedSnapshots(forceSnapshot: true)
                triggerToast(
                    l.tr(zh: "补录窗口已过", en: "Catch-up window closed", de: "Nachtrag nicht mehr möglich"),
                    tint: Color.goRed
                )
                return
            }
            savedRecord = result.recordReference
            selectedActionHumanID = nil
            guard result.allowsDerivedEffects else {
                reloadFeedSnapshots(forceSnapshot: true)
                return
            }
            triggerFeedCheckInFeedback(foodKind: result.foodKind, grams: result.grams, affectsStock: result.affectsStock)
            afterFoodLogSaved(
                message: reminder.scheduledAt < clockTick
                    ? l.tr(zh: "计划餐已补录", en: "Planned meal caught up", de: "Planmahlzeit nachgetragen")
                    : l.tr(zh: "计划餐已完成", en: "Planned meal done", de: "Planmahlzeit erledigt"),
                tint: Color.goPurple,
                stockReminders: result.stockReminders
            )
            }
        }
        performWithAntiRepeat(action)
    }

    func showFeedPersistenceFailure() {
        draftStore.inputError = l.tr(
            zh: "保存失败，请检查存储空间后重试", en: "Couldn't save. Check storage and try again.",
            de: "Speichern fehlgeschlagen. Speicher prüfen und erneut versuchen."
        )
        reloadFeedSnapshots(forceSnapshot: true)
        triggerToast(
            l.tr(
                zh: "保存失败，请检查存储空间后重试",
                en: "Couldn't save. Check storage and try again.",
                de: "Speichern fehlgeschlagen. Speicher pruefen und erneut versuchen."
            ),
            tint: Color.goRed
        )
    }

    func completeSelectedPlanOccurrence(_ occurrence: FeedPlanCalendarOccurrence) {
        let reminder: Reminder = if let existingReminder = occurrence.reminder {
            existingReminder
        } else {
            commandExecutor.reminder(
                for: occurrence.event,
                scheduledAt: occurrence.date,
                existing: nil
            )
        }
        completePlannedFeed(reminder)
    }

    func commitTreatFeed() {
        dismissFeedKeyboard()
        guard !isRecordingFeed, validateActionHumanSelection() else { return }
        let grams = parsePositiveDouble(draftStore.treatGramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : draftStore.treatGramsText)
        guard let grams else {
            draftStore.inputError = l.tr(zh: "请输入有效克数，或留空。", en: "Enter valid grams or leave it empty.", de: "Gültige Gramm oder leer lassen.")
            return
        }
        let treatKind = draftStore.selectedTreatKind
        let executorId = selectedActionExecutorId
        isRecordingFeed = true
        savedRecord = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        recordCommandQueue.enqueue(.quickCare(entityID: pet.id, action: "treat")) {
            defer { isRecordingFeed = false }
            let result = commandExecutor.recordTreat(
                pet: pet,
                grams: grams,
                treatKind: treatKind,
                executorId: executorId
            )
            guard result.didRecord else { showFeedPersistenceFailure(); return }
            savedRecord = result.recordReference
            selectedActionHumanID = nil
            guard result.allowsDerivedEffects else {
                reloadFeedSnapshots(forceSnapshot: true)
                return
            }
            triggerTreatCheckInFeedback(grams: result.grams)
            afterFoodLogSaved(message: l.tr(zh: "已记录零食", en: "Treat saved", de: "Snack gespeichert"), tint: treatTint)
        }
    }
}
