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
            sheetContent(sheet)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .petMemorialTone(isActive: pet.hasPassedAway)
                .navigationTitle(feedSheetChrome(for: sheet).title)
                .navigationBarTitleDisplayMode(.inline)
            .feedSheetScrollChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) {
                        closeActiveFeedSheet()
                    }
                    .accessibilityIdentifier("quick-feed-sheet-cancel-action")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        dismissFeedKeyboard()
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func updateInlineKeyboardHeight(_ notification: Notification) {
        guard activeInlineSheet != nil else { return }
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let height = max(0, frame.height)
        guard abs(inlineKeyboardHeight - height) > 0.5 else { return }
        inlineKeyboardHeight = height
    }
}
