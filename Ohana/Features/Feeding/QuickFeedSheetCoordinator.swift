//
//  QuickFeedSheetCoordinator.swift
//  Ohana
//
//  Route and presentation state for QuickFeedDetailSheet sheets.
//

import Combine
import SwiftUI

@MainActor
final class QuickFeedSheetCoordinator: ObservableObject {
    @Published var activeSheet: ActiveFeedSheet?
    @Published var nestedInlineSheet: ActiveFeedSheet?
    @Published var adaptiveSheetHeight: CGFloat = ActiveFeedSheet.defaultAdaptiveHeight
    @Published var inlineKeyboardHeight: CGFloat = 0
    @Published var inlineSheetDragOffset: CGFloat = 0
    @Published var inlineSheetVisible = false
    @Published var inlineSheetScrollTopOffset: CGFloat = 0
    @Published var inlineSheetTopPullDismissArmed = false
    @Published var inlineSheetDismissGestureShield = false

    private var feedSheetReturnStack: [ActiveFeedSheet] = []
    private var nestedInlineReturnStack: [ActiveFeedSheet] = []

    var activeInlineSheet: ActiveFeedSheet? {
        nestedInlineSheet ?? (activeSheet?.usesInlineOverlay == true ? activeSheet : nil)
    }

    var inlineOverlayBlocksBackground: Bool {
        activeInlineSheet != nil || inlineSheetDismissGestureShield
    }

    func resetForActiveSheetChange() {
        adaptiveSheetHeight = activeSheet?.defaultAdaptiveHeight ?? ActiveFeedSheet.defaultAdaptiveHeight
        inlineSheetDragOffset = 0
        inlineSheetScrollTopOffset = 0
        if activeSheet?.usesInlineOverlay != true {
            inlineKeyboardHeight = 0
            inlineSheetVisible = false
        }
        if activeSheet == nil {
            feedSheetReturnStack.removeAll()
            nestedInlineReturnStack.removeAll()
        }
    }

    func resetForNestedInlineSheetChange() {
        adaptiveSheetHeight = nestedInlineSheet?.defaultAdaptiveHeight ?? activeSheet?.defaultAdaptiveHeight ?? ActiveFeedSheet.defaultAdaptiveHeight
        inlineSheetDragOffset = 0
        inlineSheetScrollTopOffset = 0
        inlineSheetTopPullDismissArmed = false
        if nestedInlineSheet == nil {
            inlineKeyboardHeight = 0
            inlineSheetVisible = false
        }
    }

    func openRoot(_ sheet: ActiveFeedSheet) {
        nestedInlineSheet = nil
        nestedInlineReturnStack.removeAll()
        feedSheetReturnStack.removeAll()
        activeSheet = sheet
    }

    func open(_ sheet: ActiveFeedSheet) {
        if let currentNested = nestedInlineSheet, sheet.usesInlineOverlay {
            if currentNested.id != sheet.id {
                nestedInlineReturnStack.append(currentNested)
            }
            nestedInlineSheet = sheet
            return
        }

        if activeSheet?.usesInlineOverlay == false, sheet.usesInlineOverlay {
            nestedInlineSheet = sheet
            return
        }

        if let current = activeSheet, current.id != sheet.id {
            feedSheetReturnStack.append(current)
        } else if activeSheet == nil {
            feedSheetReturnStack.removeAll()
        }
        activeSheet = sheet
    }

    func closeActive() {
        if nestedInlineSheet != nil {
            if let returnSheet = nestedInlineReturnStack.popLast() {
                nestedInlineSheet = returnSheet
            } else {
                nestedInlineSheet = nil
            }
            return
        }

        if let returnSheet = feedSheetReturnStack.popLast() {
            activeSheet = returnSheet
        } else {
            activeSheet = nil
        }
    }

    func prepareInlinePresentation() {
        inlineSheetVisible = false
        inlineSheetTopPullDismissArmed = false
        inlineSheetDismissGestureShield = false
    }

    func showInlinePresentation() {
        withAnimation(GoMotion.page) {
            inlineSheetVisible = true
        }
    }

    func beginInlineDismiss() -> String? {
        guard let dismissingSheetID = activeInlineSheet?.id else {
            inlineSheetDismissGestureShield = false
            return nil
        }
        inlineSheetDismissGestureShield = true
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineKeyboardHeight = 0
            inlineSheetDragOffset = 0
            inlineSheetTopPullDismissArmed = false
        }
        return dismissingSheetID
    }

    func finishInlineDismiss(dismissingSheetID: String?) {
        if nestedInlineSheet?.id == dismissingSheetID {
            nestedInlineSheet = nil
        } else if activeSheet?.id == dismissingSheetID {
            closeActive()
        }
    }

    func clearInlineDismissShieldIfIdle() {
        if activeInlineSheet == nil {
            inlineSheetDismissGestureShield = false
        }
    }
}
