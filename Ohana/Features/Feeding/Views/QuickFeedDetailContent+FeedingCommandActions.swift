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
        commandExecutor.saveManualSettings(
            pet: pet,
            foodKind: draftStore.manualFoodKindDraft,
            grams: grams,
            defaultEnabled: draftStore.manualDefaultEnabled
        )
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
        draftStore.inputError = nil
        let foodKind = selectedFoodKind ?? draftStore.manualFoodKindDraft
        let action = {
            let result = commandExecutor.recordManual(
                pet: pet,
                targets: selectedFeedTargets,
                grams: grams,
                foodKind: foodKind,
                saveAsDefault: saveAsDefault,
                foodRecords: observedFoodRecords,
                allEvents: allEvents,
                executorId: currentUserId,
                date: date
            )
            guard result.didRecord else { return }
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
            afterFoodLogSaved(message: message, tint: mainFoodTint, stockReminders: result.stockReminders)
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
        let action = {
            let result = commandExecutor.completePlanned(
                pet: pet,
                reminder: reminder,
                foodRecords: observedFoodRecords,
                allEvents: allEvents,
                executorId: currentUserId
            )
            guard result.didRecord else {
                reloadFeedSnapshots(forceSnapshot: true)
                triggerToast(
                    l.tr(zh: "补录窗口已过", en: "Catch-up window closed", de: "Nachtrag nicht mehr möglich"),
                    tint: Color.goRed
                )
                return
            }
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
        performWithAntiRepeat(action)
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
        let grams = parsePositiveDouble(draftStore.treatGramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : draftStore.treatGramsText)
        guard let grams else {
            draftStore.inputError = l.tr(zh: "请输入有效克数，或留空。", en: "Enter valid grams or leave it empty.", de: "Gültige Gramm oder leer lassen.")
            return
        }
        let result = commandExecutor.recordTreat(
            pet: pet,
            grams: grams,
            treatKind: draftStore.selectedTreatKind,
            executorId: currentUserId
        )
        guard result.didRecord else { return }
        guard result.allowsDerivedEffects else {
            reloadFeedSnapshots(forceSnapshot: true)
            return
        }
        showTreatSavedCelebration()
        triggerTreatCheckInFeedback(grams: result.grams)
        afterFoodLogSaved(message: l.tr(zh: "已记录零食", en: "Treat saved", de: "Snack gespeichert"), tint: treatTint)
    }
}
