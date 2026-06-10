//
//  QuickFeedDetailContent+SheetRouting.swift
//  Ohana
//
//  Typed feed sheet destination routing and chrome.
//

import SwiftUI

extension QuickFeedDetailContent {
    @ViewBuilder
    func sheetContent(_ sheet: ActiveFeedSheet) -> some View {
        switch sheet {
        case .manual:
            manualFeedSheet
        case .treat:
            treatFeedSheet
        case let .plan(kind):
            planEditorSheet(kind)
        case .stock:
            stockSheet
        case .stockManage:
            stockManageSheet
        case .manage:
            manageSheet
        case .history:
            historySheet
        case .feedModeHistory:
            feedModeHistorySheet
        case .stockRecords:
            stockRecordsSheet
        case .editLog:
            editFeedLogSheet
        case .feedingOverview:
            feedingOverviewSheet
        case .stockOverview:
            stockOverviewSheet
        case .treatOverview:
            treatOverviewSheet
        }
    }

    func sheetHero(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
    }

    func feedSheetTopChrome(_ sheet: ActiveFeedSheet) -> some View {
        HStack(spacing: 12) {
            feedSheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActiveFeedSheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    func feedSheetChromeTitle(_ sheet: ActiveFeedSheet) -> some View {
        let chrome = feedSheetChrome(for: sheet)
        return HStack(spacing: 10) {
            Image(systemName: chrome.icon)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(chrome.tint)
                .frame(width: 30, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            Text(chrome.title)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    func feedSheetChrome(for sheet: ActiveFeedSheet) -> (icon: String, title: String, tint: Color) {
        switch sheet {
        case .feedingOverview:
            return (
                feedModeIcon(activeFeedingMode),
                l.tr(zh: "喂食总览", en: "Feeding overview", de: "Futterübersicht"),
                feedingModeTint
            )
        case .feedModeHistory:
            return ("chart.line.uptrend.xyaxis", feedModeHistoryTitle, feedingModeTint)
        case .stockOverview:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮总览", en: "Stock overview", de: "Vorratsübersicht"),
                stockTint
            )
        case .treatOverview:
            return (
                "birthday.cake.fill",
                l.tr(zh: "零食总览", en: "Treat overview", de: "Snackübersicht"),
                treatTint
            )
        case .history:
            return (
                "clock.arrow.circlepath",
                l.tr(zh: "喂食历史", en: "Feeding history", de: "Fütterungshistorie"),
                Color.goPrimary
            )
        case .stockRecords:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮记录", en: "Stock records", de: "Vorratseinträge"),
                stockTint
            )
        case .manual:
            return (
                "fork.knife.circle.fill",
                manualFeedSheetTitle,
                mainFoodTint
            )
        case .treat:
            return (
                "birthday.cake.fill",
                l.tr(zh: "记录零食", en: "Log treats", de: "Snack eintragen"),
                treatTint
            )
        case let .plan(kind):
            return (
                kind.iconName,
                kind == .autoFeeder
                    ? l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat")
                    : l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan"),
                kind == .autoFeeder ? Color.goTeal : Color.goPurple
            )
        case .stock:
            return (
                "shippingbox.fill",
                draftStore.editingFoodRecord == nil
                    ? l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen")
                    : l.tr(zh: "编辑余粮", en: "Edit stock", de: "Vorrat bearbeiten"),
                stockTint
            )
        case .stockManage:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"),
                stockTint
            )
        case .manage:
            return ("slider.horizontal.3", l.tr(zh: "管理", en: "Manage", de: "Verwalten"), Color.goPrimary)
        case .editLog:
            return ("pencil", l.tr(zh: "编辑记录", en: "Edit log", de: "Eintrag bearbeiten"), mainFoodTint)
        }
    }
}
