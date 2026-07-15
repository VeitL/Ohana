//
//  QuickPottyDetailSheet+Navigation.swift
//  Ohana
//

import Foundation

extension QuickPottyDetailSheet {
    func openRootPottySheet(_ sheet: ActiveSheet) {
        let normalizedSheet = normalizedSheetForPet(sheet)
        prepareActionHumanDraft(for: normalizedSheet)
        nestedInlineSheet = nil
        pottySheetReturnStack.removeAll()
        activeSheet = normalizedSheet
    }

    func openPottySheet(_ sheet: ActiveSheet) {
        let sheet = normalizedSheetForPet(sheet)
        prepareActionHumanDraft(for: sheet)
        if activeSheet?.usesInlineOverlay == false, sheet.usesInlineOverlay {
            nestedInlineSheet = sheet
            return
        }
        if activeSheet?.usesInlineOverlay == true, sheet.usesInlineOverlay {
            activeSheet = sheet
            return
        }

        if let current = activeSheet, current.id != sheet.id {
            pottySheetReturnStack.append(current)
        } else if activeSheet == nil {
            pottySheetReturnStack.removeAll()
        }
        activeSheet = sheet
    }

    func normalizedSheetForPet(_ sheet: ActiveSheet) -> ActiveSheet {
        guard !isCatPet else { return sheet }
        switch sheet {
        case .scoopCheckIn, .litterChangeCheckIn, .scoopSettings, .litterSettings, .scoopOverview, .litterOverview:
            return .pottyOverview
        case .scoopHistory, .litterHistory:
            return .pottyHistory
        default:
            return sheet
        }
    }

    func closeActivePottySheet() {
        if nestedInlineSheet != nil {
            nestedInlineSheet = nil
            return
        }
        if let returnSheet = pottySheetReturnStack.popLast() {
            activeSheet = returnSheet
        } else {
            activeSheet = nil
        }
    }
}
