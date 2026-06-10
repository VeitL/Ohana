import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    // MARK: - Actions

    func openManualFeedSheet(settingsOnly: Bool = false) {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        collapseEmbeddedPanel()
        prepareManualSheet(settingsOnly: settingsOnly)
        openFeedSheet(.manual)
    }

    func openTreatFeedSheet() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.treatOverview)
            return
        }
        collapseEmbeddedPanel()
        prepareTreatSheet()
        openFeedSheet(.treat)
    }

    func openStockOverview() {
        collapseEmbeddedPanel()
        if stockSnapshot.records.isEmpty {
            prepareStockSheet()
            openFeedSheet(.stock)
        } else {
            prepareStockManageSheet()
            openFeedSheet(.stockManage)
        }
    }

    func openFeedingOverview() {
        collapseEmbeddedPanel()
        openRootFeedSheet(.feedingOverview)
    }

    func openFeedModeHistory() {
        collapseEmbeddedPanel()
        openRootFeedSheet(.feedModeHistory)
    }

    func handleFeedPrimaryTap() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        switch activeFeedingMode {
        case .manual:
            guard pet.dailyPortionGrams > 0 else {
                openManualFeedSheet()
                return
            }
            commitManualFeed(grams: pet.dailyPortionGrams, saveAsDefault: false, foodKind: pet.mainFoodKind)
        case .manualReminder:
            openFeedModeHistory()
        case .autoFeeder:
            openFeedModeHistory()
        }
    }

    func handleGuidedFeedPrimaryTap() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }

        switch activeFeedingMode {
        case .manual:
            if pet.dailyPortionGrams > 0 {
                handleFeedPrimaryTap()
            } else {
                openManualFeedSheet(settingsOnly: true)
            }
        case .manualReminder:
            if feedHomeController.viewState.primaryActionState == .completeManualPlan {
                completeNextPlannedFeed()
            } else {
                openFeedModeHistory()
            }
        case .autoFeeder:
            materializeAutoFeedLogs()
            reloadFeedSnapshots()
            openFeedModeHistory()
        }
    }

    func handleFeedSettingsTap() {
        toggleEmbeddedModeSettings()
    }
}
