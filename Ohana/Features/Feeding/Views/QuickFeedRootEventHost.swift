//
//  QuickFeedRootEventHost.swift
//  Ohana
//
//  Root lifecycle, change, keyboard, and clock wiring for QuickFeedDetailSheet.
//

import Combine
import SwiftUI
import UIKit

struct QuickFeedRootEventHost: ViewModifier {
    let activeSheetID: String?
    let overviewRange: FeedOverviewRange
    let displayedMode: FeedOperatingMode
    let nestedInlineSheetID: String?
    let selectedTreatKindRawValue: String?
    let planCalendarMonth: Date
    let planCalendarSelectedDate: Date
    let eventCount: Int
    let feedingLedgerEventCount: Int
    let careLogCount: Int
    let foodRecordCount: Int
    let sharedSessionCount: Int
    let appLanguage: String
    let feedClockInterval: TimeInterval
    let workloadPolicy: AppWorkloadPolicy
    let onAppear: () -> Void
    let onDisappear: () -> Void
    let onActiveSheetChange: () -> Void
    let onOverviewRangeChange: () -> Void
    let onDisplayedModeChange: () -> Void
    let onNestedInlineSheetChange: () -> Void
    let onTreatFilterChange: () -> Void
    let onPlanCalendarChange: () -> Void
    let onEventCountChange: () -> Void
    let onFeedingLedgerEventCountChange: () -> Void
    let onCareLogCountChange: () -> Void
    let onFoodRecordCountChange: () -> Void
    let onSharedSessionCountChange: () -> Void
    let onLanguageChange: () -> Void
    let onKeyboardFrameChange: (Notification) -> Void
    let onKeyboardHide: () -> Void
    let onClockTick: (Date) -> Void

    private var clockPublisher: AnyPublisher<Date, Never> {
        guard workloadPolicy.refreshBudget(isVisible: true) != .paused else {
            return Empty().eraseToAnyPublisher()
        }
        return Timer.publish(every: feedClockInterval, on: .main, in: .common) // smoothness: allow visible Quick Feed clock publisher is workload-policy gated and replaced by Empty when paused.
            .autoconnect()
            .eraseToAnyPublisher()
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            .onChange(of: activeSheetID) { _, _ in onActiveSheetChange() }
            .onChange(of: overviewRange) { _, _ in onOverviewRangeChange() }
            .onChange(of: displayedMode) { _, _ in onDisplayedModeChange() }
            .onChange(of: nestedInlineSheetID) { _, _ in onNestedInlineSheetChange() }
            .onChange(of: selectedTreatKindRawValue) { _, _ in onTreatFilterChange() }
            .onChange(of: planCalendarMonth) { _, _ in onPlanCalendarChange() }
            .onChange(of: planCalendarSelectedDate) { _, _ in onPlanCalendarChange() }
            .onChange(of: eventCount) { _, _ in onEventCountChange() }
            .onChange(of: feedingLedgerEventCount) { _, _ in onFeedingLedgerEventCountChange() }
            .onChange(of: careLogCount) { _, _ in onCareLogCountChange() }
            .onChange(of: foodRecordCount) { _, _ in onFoodRecordCountChange() }
            .onChange(of: sharedSessionCount) { _, _ in onSharedSessionCountChange() }
            .onChange(of: appLanguage) { _, _ in onLanguageChange() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                onKeyboardFrameChange(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                onKeyboardHide()
            }
            .onReceive(clockPublisher) { date in
                onClockTick(date)
            }
    }
}
