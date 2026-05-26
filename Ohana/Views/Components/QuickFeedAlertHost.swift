//
//  QuickFeedAlertHost.swift
//  Ohana
//
//  Alert modifier extracted from QuickFeedDetailSheet to keep the root view type small.
//

import SwiftUI

struct QuickFeedAlertHost: ViewModifier {
    let antiRepeatTitle: String
    let antiRepeatMessage: String
    let logAnywayTitle: String
    let cancelTitle: String
    let deleteFeedLogTitle: String
    let deleteFeedLogConfirmTitle: String
    let deleteFeedLogMessage: String
    let deleteFoodRecordTitle: String
    let deleteFoodRecordConfirmTitle: String
    let deleteFoodRecordMessage: String
    @Binding var showingAntiRepeatAlert: Bool
    @Binding var pendingRepeatAction: (() -> Void)?
    @Binding var showingDeleteFeedLogConfirm: Bool
    @Binding var feedLogPendingDelete: PetCareLog?
    @Binding var showingDeleteFoodRecordConfirm: Bool
    @Binding var foodRecordPendingDelete: PetFoodRecord?
    let onDeleteFeedLog: (PetCareLog) -> Void
    let onDeleteFoodRecord: (PetFoodRecord) -> Void

    func body(content: Content) -> some View {
        content
            .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
                Button(logAnywayTitle) {
                    pendingRepeatAction?()
                    pendingRepeatAction = nil
                }
                Button(cancelTitle, role: .cancel) {
                    pendingRepeatAction = nil
                }
            } message: {
                Text(antiRepeatMessage)
            }
            .alert(deleteFeedLogTitle, isPresented: $showingDeleteFeedLogConfirm) {
                Button(deleteFeedLogConfirmTitle, role: .destructive) {
                    if let log = feedLogPendingDelete { onDeleteFeedLog(log) }
                    feedLogPendingDelete = nil
                }
                Button(cancelTitle, role: .cancel) {
                    feedLogPendingDelete = nil
                }
            } message: {
                Text(deleteFeedLogMessage)
            }
            .alert(deleteFoodRecordTitle, isPresented: $showingDeleteFoodRecordConfirm) {
                Button(deleteFoodRecordConfirmTitle, role: .destructive) {
                    if let record = foodRecordPendingDelete { onDeleteFoodRecord(record) }
                    foodRecordPendingDelete = nil
                }
                Button(cancelTitle, role: .cancel) {
                    foodRecordPendingDelete = nil
                }
            } message: {
                Text(deleteFoodRecordMessage)
            }
    }
}
