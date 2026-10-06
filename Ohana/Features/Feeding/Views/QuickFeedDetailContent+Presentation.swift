//
//  QuickFeedDetailContent+Presentation.swift
//  Ohana
//
//  Presentation chrome and inline overlay routing for QuickFeedDetailContent.
//

import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var activeAlert: QuickFeedAlertRoute? {
        get { presentationState.activeAlert }
        nonmutating set { presentationState.activeAlert = newValue }
    }

    var activeAlertBinding: Binding<QuickFeedAlertRoute?> {
        Binding(
            get: { presentationState.activeAlert },
            set: { presentationState.activeAlert = $0 }
        )
    }

    var pendingRepeatAction: (() -> Void)? {
        get { presentationState.pendingRepeatAction }
        nonmutating set { presentationState.pendingRepeatAction = newValue }
    }

    var pendingRepeatActionBinding: Binding<(() -> Void)?> {
        Binding(
            get: { presentationState.pendingRepeatAction },
            set: { presentationState.pendingRepeatAction = $0 }
        )
    }

    var activeOverlay: QuickFeedOverlayRoute? {
        get { presentationState.activeOverlay }
        nonmutating set { presentationState.activeOverlay = newValue }
    }

    var toastTask: Task<Void, Never>? {
        get { presentationState.toastTask }
        nonmutating set { presentationState.toastTask = newValue }
    }

    var feedFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.feedFeedbackToken }
        nonmutating set { presentationState.feedFeedbackToken = newValue }
    }

    var feedFeedbackMetricId: String? {
        get { presentationState.feedFeedbackMetricId }
        nonmutating set { presentationState.feedFeedbackMetricId = newValue }
    }

    var stockFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.stockFeedbackToken }
        nonmutating set { presentationState.stockFeedbackToken = newValue }
    }

    var stockFeedbackKind: FeedFoodKind? {
        get { presentationState.stockFeedbackKind }
        nonmutating set { presentationState.stockFeedbackKind = newValue }
    }

    var treatFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.treatFeedbackToken }
        nonmutating set { presentationState.treatFeedbackToken = newValue }
    }

    var activeEmbeddedPanel: ActiveFeedEmbeddedPanel? {
        get { presentationState.activeEmbeddedPanel }
        nonmutating set { presentationState.activeEmbeddedPanel = newValue }
    }

    var feedbackClearTask: Task<Void, Never>? {
        get { presentationState.feedbackClearTask }
        nonmutating set { presentationState.feedbackClearTask = newValue }
    }

    func systemFeedSheetContent(_ sheet: ActiveFeedSheet) -> some View {
        NavigationStack {
            feedSheetWithEditorChrome(sheet)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .petMemorialTone(isActive: pet.hasPassedAway)
                .navigationTitle(feedSheetChrome(for: sheet).title)
                .navigationBarTitleDisplayMode(.inline)
            .feedSheetScrollChrome()
            .toolbar {
                if !sheet.isEditor {
                    OhanaModalToolbar(
                        onClose: closeActiveFeedSheet,
                        closeIdentifier: "quick-feed-sheet-cancel-action"
                    )
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        dismissFeedKeyboard()
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    @ViewBuilder
    func feedSheetWithEditorChrome(_ sheet: ActiveFeedSheet) -> some View {
        switch sheet {
        case .manual, .treat, .stock, .editLog:
            sheetContent(sheet)
                .ohanaEditorChrome(
                    hasChanges: draftStore.initialSheetEditorDraft != feedEditorDraft(sheet),
                    isSaving: isRecordingFeed,
                    closeIdentifier: "quick-feed-sheet-cancel-action",
                    saveIdentifier: feedEditorSaveIdentifier(sheet),
                    onCancel: {
                        // Shared stock management fields reflect committed settings after discard.
                        if sheet == .stock {
                            draftStore.stockReminderEnabled = pet.foodReminderEnabled
                            draftStore.stockReminderAdvanceDays = pet.foodReminderAdvanceDays
                        }
                        closeActiveFeedSheet()
                    },
                    onSave: { submitFeedEditor(sheet) }
                )
        default:
            sheetContent(sheet)
        }
    }

    func feedEditorDraft(_ sheet: ActiveFeedSheet) -> [String] {
        let recorder = selectedActionHumanID?.uuidString ?? ""
        switch sheet {
        case .manual:
            let values = [draftStore.manualFoodKindDraft.rawValue, draftStore.manualGramsText,
                          draftStore.manualNote, String(draftStore.manualFeedDate.timeIntervalSinceReferenceDate),
                          String(draftStore.manualDefaultEnabled), String(draftStore.saveManualAsDefault), recorder]
            return values + draftStore.selectedSharedFeedPetIds.map(\.uuidString).sorted()
        case .treat:
            return [draftStore.selectedTreatKind.rawValue, draftStore.treatGramsText, recorder]
        case .stock:
            var values = [draftStore.selectedStockFoodKind.rawValue, draftStore.stockBrandText,
                          draftStore.stockWeightText, draftStore.stockCalculationMode.rawValue]
            values += [String(draftStore.stockHasPurchaseDate), String(draftStore.stockPurchaseDate.timeIntervalSinceReferenceDate),
                       String(draftStore.stockHasOpenDate), String(draftStore.stockOpenDate.timeIntervalSinceReferenceDate)]
            values += [draftStore.stockExpenseAmountText, draftStore.stockExpensePayerId ?? "",
                       String(draftStore.stockReminderEnabled), String(draftStore.stockReminderAdvanceDays), recorder]
            return values
        case .editLog:
            return [draftStore.editFeedLogGrams, String(draftStore.editFeedLogDate.timeIntervalSinceReferenceDate)]
        default: return []
        }
    }

    func feedEditorSaveIdentifier(_ sheet: ActiveFeedSheet) -> String {
        switch sheet {
        case .manual:
            if draftStore.manualFeedSheetMode == .settingsOnly { return "quick-feed-manual-settings-save" }
            return overviewSnapshot.nextPendingManualReminder == nil ? "quick-feed-manual-log-save" : "quick-feed-planned-complete"
        case .treat: return "quick-feed-treat-save"
        case .stock: return "quick-feed-stock-save"
        default: return "quick-feed-log-edit-save"
        }
    }

    func submitFeedEditor(_ sheet: ActiveFeedSheet) {
        guard activeSheet == sheet, !draftStore.isSubmittingSheetEditor, !isRecordingFeed else { return }
        draftStore.isSubmittingSheetEditor = true
        defer { draftStore.isSubmittingSheetEditor = false }
        switch sheet {
        case .manual:
            if draftStore.manualFeedSheetMode == .settingsOnly {
                saveManualFeedSettings()
            } else if overviewSnapshot.nextPendingManualReminder == nil {
                commitManualFeed()
            } else {
                completeNextPlannedFeed()
            }
        case .treat: commitTreatFeed()
        case .stock: saveStock()
        case .editLog: saveFeedLogEdit()
        default: break
        }
    }

    func updateInlineKeyboardHeight(_ notification: Notification) {
        guard activeInlineSheet != nil else { return }
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let height = max(0, frame.height)
        guard abs(inlineKeyboardHeight - height) > 0.5 else { return }
        inlineKeyboardHeight = height
    }
}
