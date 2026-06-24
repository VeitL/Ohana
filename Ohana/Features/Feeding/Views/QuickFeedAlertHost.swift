//
//  QuickFeedAlertHost.swift
//  Ohana
//
//  Alert modifier extracted from QuickFeedDetailSheet to keep the root view type small.
//

import SwiftUI

struct QuickFeedAlertHost: ViewModifier {
    let logAnywayTitle: String
    let cancelTitle: String
    let deleteFeedLogTitle: String
    let deleteFeedLogConfirmTitle: String
    let deleteFeedLogMessage: String
    let deleteFoodRecordTitle: String
    let deleteFoodRecordConfirmTitle: String
    let deleteFoodRecordMessage: String
    @Binding var activeAlert: QuickFeedAlertRoute?
    @Binding var pendingRepeatAction: (() -> Void)?
    let onDeleteFeedLog: (UUID) -> Void
    let onDeleteFoodRecord: (PetFoodRecord) -> Void

    func body(content: Content) -> some View {
        content
            .alert(antiRepeatText?.title ?? "", isPresented: antiRepeatBinding) {
                Button(logAnywayTitle) {
                    pendingRepeatAction?()
                    pendingRepeatAction = nil
                    activeAlert = nil
                }
                Button(cancelTitle, role: .cancel) {
                    pendingRepeatAction = nil
                    activeAlert = nil
                }
            } message: {
                Text(antiRepeatText?.message ?? "")
            }
            .alert(deleteFeedLogTitle, isPresented: deleteFeedLogBinding) {
                Button(deleteFeedLogConfirmTitle, role: .destructive) {
                    if let id = activeAlert?.feedLogPendingDeleteId {
                        onDeleteFeedLog(id)
                    }
                    activeAlert = nil
                }
                Button(cancelTitle, role: .cancel) {
                    activeAlert = nil
                }
            } message: {
                Text(deleteFeedLogMessage)
            }
            .alert(deleteFoodRecordTitle, isPresented: deleteFoodRecordBinding) {
                Button(deleteFoodRecordConfirmTitle, role: .destructive) {
                    if let record = activeAlert?.foodRecordPendingDelete {
                        onDeleteFoodRecord(record)
                    }
                    activeAlert = nil
                }
                Button(cancelTitle, role: .cancel) {
                    activeAlert = nil
                }
            } message: {
                Text(deleteFoodRecordMessage)
            }
    }

    private var antiRepeatText: (title: String, message: String)? {
        activeAlert?.antiRepeatText
    }

    private var antiRepeatBinding: Binding<Bool> {
        Binding(
            get: { activeAlert?.isAntiRepeat == true },
            set: { isPresented in
                if !isPresented, activeAlert?.isAntiRepeat == true {
                    pendingRepeatAction = nil
                    activeAlert = nil
                }
            }
        )
    }

    private var deleteFeedLogBinding: Binding<Bool> {
        Binding(
            get: { activeAlert?.feedLogPendingDeleteId != nil },
            set: { isPresented in
                if !isPresented, activeAlert?.feedLogPendingDeleteId != nil {
                    activeAlert = nil
                }
            }
        )
    }

    private var deleteFoodRecordBinding: Binding<Bool> {
        Binding(
            get: { activeAlert?.foodRecordPendingDelete != nil },
            set: { isPresented in
                if !isPresented, activeAlert?.foodRecordPendingDelete != nil {
                    activeAlert = nil
                }
            }
        )
    }
}
