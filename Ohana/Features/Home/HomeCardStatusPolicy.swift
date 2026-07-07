//
//  HomeCardStatusPolicy.swift
//  Ohana
//
//  Shared card status projection for wallet/home entity cards.
//

import Foundation

nonisolated struct HomeCardStatusSnapshot: Equatable, Sendable {
    let text: String?
    let tone: FocusCardStatusBadgeTone

    var isWarning: Bool {
        tone == .urgent
    }
}

nonisolated enum HomeCardStatusPolicy {
    static func snapshot(urgentCount: Int, dueCount: Int) -> HomeCardStatusSnapshot {
        if urgentCount > 0 {
            return HomeCardStatusSnapshot(
                text: badgeCountText(urgentCount),
                tone: .urgent
            )
        }
        if dueCount > 0 {
            return HomeCardStatusSnapshot(
                text: badgeCountText(dueCount),
                tone: .due
            )
        }
        return HomeCardStatusSnapshot(text: nil, tone: .ok)
    }

    static func apply(
        to card: inout FocusCard,
        urgentCount: Int,
        dueCount: Int
    ) {
        let status = snapshot(urgentCount: urgentCount, dueCount: dueCount)
        card.statusBadgeText = status.text
        card.statusBadgeTone = status.tone
    }

    static func plantSnapshot(
        overdueCareCount: Int,
        dueCareCount: Int,
        hasUrgentHealthSignal: Bool = false
    ) -> HomeCardStatusSnapshot {
        snapshot(
            urgentCount: max(0, overdueCareCount) + (hasUrgentHealthSignal ? 1 : 0),
            dueCount: max(0, dueCareCount)
        )
    }

    private static func badgeCountText(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }
}
