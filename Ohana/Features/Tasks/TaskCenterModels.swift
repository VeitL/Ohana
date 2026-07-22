//
//  TaskCenterModels.swift
//  Ohana
//
//  Value snapshots for the global actionable-task center.
//

import Foundation

nonisolated enum TaskCenterSurface: String, CaseIterable, Identifiable, Sendable {
    case tasks
    case calendar

    var id: String { rawValue }
}

nonisolated enum TaskCenterUrgency: String, Equatable, Sendable {
    case standard
    case overdue
    case critical
}

nonisolated struct TaskSubjectSnapshot: Equatable, Sendable {
    nonisolated enum Kind: String, Equatable, Sendable {
        case household
        case human
        case pet
        case plant
    }

    let kind: Kind
    let id: UUID?
    let name: String?
    let themeColorHex: String?

    static let household = TaskSubjectSnapshot(
        kind: .household,
        id: nil,
        name: nil,
        themeColorHex: nil
    )
}

nonisolated struct TaskMemberSnapshot: Equatable, Sendable {
    /// Legacy tasks can retain a trustworthy stored name even when their old ID is not a UUID.
    let id: UUID?
    let name: String
}

nonisolated enum TaskCenterItemSource: String, Equatable, Sendable {
    case event
    case familyTask
    case linked
    case systemJourney
}

nonisolated enum TaskCenterSystemDestination: String, Equatable, Hashable, Sendable {
    case createFirstPet
    case claimStarterGift
    case completeHumanProfile
    case completeFirstPetProfile
    case confirmPetIdentityProtection
    case confirmPetPreventiveCare
    case configureFirstCarePlan
    case recordFirstCare
}

nonisolated enum TaskCenterSystemJourneyPresentationState: String, Equatable, Sendable {
    case actionRequired
    case rewardReady
}

nonisolated enum TaskCenterWorkflowStatus: String, Equatable, Sendable {
    case scheduled
    case active
    case claimed
    case declined
    case pendingReview
    case completed
    case cancelled
}

nonisolated enum TaskCenterAvailableAction: String, Hashable, Sendable {
    case complete
    case claim
    case submitForReview
    case approve
    case reject
}

nonisolated enum TaskCenterMemberFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all

    // Compatibility storage cases. New call sites should use the semantic aliases
    // below so existing exhaustive switches keep compiling while the UI migrates.
    case currentMember
    case waitingForOthers
    case pendingReview

    static let actionRequired: Self = .currentMember
    static let waitingForFamily: Self = .waitingForOthers

    /// Pending review is an action for its creator, not a peer filter. Keep the
    /// legacy case readable, but do not expose it in the selectable filter list.
    static var allCases: [Self] { [.actionRequired, .waitingForFamily, .all] }

    var id: String {
        switch normalized {
        case .all:
            "all"
        case .currentMember:
            "actionRequired"
        case .waitingForOthers:
            "waitingForFamily"
        case .pendingReview:
            // `normalized` never preserves this compatibility case.
            "actionRequired"
        }
    }

    var normalized: Self {
        switch self {
        case .all:
            .all
        case .currentMember, .pendingReview:
            .actionRequired
        case .waitingForOthers:
            .waitingForFamily
        }
    }
}

nonisolated struct TaskCenterMemberFilterSummary: Equatable, Sendable {
    let actionRequiredCount: Int
    let waitingForFamilyCount: Int
    let allCount: Int
    let systemJourneyCount: Int

    static let empty = TaskCenterMemberFilterSummary(
        actionRequiredCount: 0,
        waitingForFamilyCount: 0,
        allCount: 0,
        systemJourneyCount: 0
    )

    var otherCount: Int {
        max(0, allCount - actionRequiredCount - waitingForFamilyCount - systemJourneyCount)
    }

    func count(for filter: TaskCenterMemberFilter) -> Int {
        switch filter.normalized {
        case .all:
            allCount
        case .currentMember:
            actionRequiredCount + systemJourneyCount
        case .waitingForOthers:
            waitingForFamilyCount + systemJourneyCount
        case .pendingReview:
            // `normalized` never preserves this compatibility case.
            actionRequiredCount + systemJourneyCount
        }
    }
}

nonisolated struct TaskCenterMemberFilterContext: Equatable, Sendable {
    let activeHumanName: String?
    let showsFilters: Bool
    let actionRequiredItemIDs: Set<String>
    let waitingForFamilyItemIDs: Set<String>
    let systemJourneyItemIDs: Set<String>
    let summary: TaskCenterMemberFilterSummary

    static let hidden = TaskCenterMemberFilterContext(
        activeHumanName: nil,
        showsFilters: false,
        actionRequiredItemIDs: [],
        waitingForFamilyItemIDs: [],
        systemJourneyItemIDs: [],
        allItemIDs: []
    )

    init(
        activeHumanName: String?,
        showsFilters: Bool,
        actionRequiredItemIDs: Set<String>,
        waitingForFamilyItemIDs: Set<String>,
        systemJourneyItemIDs: Set<String>,
        allItemIDs: Set<String>
    ) {
        self.activeHumanName = activeHumanName
        self.showsFilters = showsFilters
        self.actionRequiredItemIDs = actionRequiredItemIDs
        self.waitingForFamilyItemIDs = waitingForFamilyItemIDs
        self.systemJourneyItemIDs = systemJourneyItemIDs
        self.summary = TaskCenterMemberFilterSummary(
            actionRequiredCount: actionRequiredItemIDs.count,
            waitingForFamilyCount: waitingForFamilyItemIDs.count,
            allCount: allItemIDs.count,
            systemJourneyCount: systemJourneyItemIDs.count
        )
    }

    /// Compatibility names for readers that have not migrated to action queues.
    var currentMemberItemIDs: Set<String> { actionRequiredItemIDs }
    var waitingForOthersItemIDs: Set<String> { waitingForFamilyItemIDs }
    var pendingReviewItemIDs: Set<String> { actionRequiredItemIDs }

    func itemIDs(for filter: TaskCenterMemberFilter) -> Set<String>? {
        switch filter.normalized {
        case .all:
            nil
        case .currentMember:
            actionRequiredItemIDs
        case .waitingForOthers:
            waitingForFamilyItemIDs
        case .pendingReview:
            // `normalized` never preserves this compatibility case.
            actionRequiredItemIDs
        }
    }

    func restricted(to includedItemIDs: Set<String>) -> TaskCenterMemberFilterContext {
        TaskCenterMemberFilterContext(
            activeHumanName: activeHumanName,
            showsFilters: showsFilters,
            actionRequiredItemIDs: actionRequiredItemIDs.intersection(includedItemIDs),
            waitingForFamilyItemIDs: waitingForFamilyItemIDs.intersection(includedItemIDs),
            systemJourneyItemIDs: systemJourneyItemIDs.intersection(includedItemIDs),
            allItemIDs: includedItemIDs
        )
    }
}

nonisolated struct TaskCenterItemSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let eventID: UUID?
    let reminderID: UUID?
    let familyTaskID: UUID?
    let source: TaskCenterItemSource
    let systemDestination: TaskCenterSystemDestination?
    let systemJourneyPresentationState: TaskCenterSystemJourneyPresentationState?
    let title: String
    let subject: TaskSubjectSnapshot
    let eventType: EventType?
    let symbol: String
    let occurrenceDate: Date
    let scheduledAt: Date
    let dueAt: Date?
    let isAllDay: Bool
    let isRecurring: Bool
    let urgency: TaskCenterUrgency
    let workflowStatus: TaskCenterWorkflowStatus
    let availableActions: Set<TaskCenterAvailableAction>
    let participantHumanIDs: Set<UUID>
    let createdByMember: TaskMemberSnapshot?
    let assignedToMember: TaskMemberSnapshot?
    let claimedByMember: TaskMemberSnapshot?
    let completedByMember: TaskMemberSnapshot?
    let rewardCoconuts: Int

    init(
        id: String,
        eventID: UUID?,
        reminderID: UUID?,
        familyTaskID: UUID?,
        source: TaskCenterItemSource,
        systemDestination: TaskCenterSystemDestination? = nil,
        systemJourneyPresentationState: TaskCenterSystemJourneyPresentationState? = nil,
        title: String,
        subject: TaskSubjectSnapshot,
        eventType: EventType?,
        symbol: String,
        occurrenceDate: Date,
        scheduledAt: Date,
        dueAt: Date?,
        isAllDay: Bool,
        isRecurring: Bool,
        urgency: TaskCenterUrgency,
        workflowStatus: TaskCenterWorkflowStatus,
        availableActions: Set<TaskCenterAvailableAction>,
        participantHumanIDs: Set<UUID>,
        createdByMember: TaskMemberSnapshot? = nil,
        assignedToMember: TaskMemberSnapshot? = nil,
        claimedByMember: TaskMemberSnapshot? = nil,
        completedByMember: TaskMemberSnapshot? = nil,
        rewardCoconuts: Int = 0
    ) {
        self.id = id
        self.eventID = eventID
        self.reminderID = reminderID
        self.familyTaskID = familyTaskID
        self.source = source
        self.systemDestination = systemDestination
        self.systemJourneyPresentationState = systemJourneyPresentationState
        self.title = title
        self.subject = subject
        self.eventType = eventType
        self.symbol = symbol
        self.occurrenceDate = occurrenceDate
        self.scheduledAt = scheduledAt
        self.dueAt = dueAt
        self.isAllDay = isAllDay
        self.isRecurring = isRecurring
        self.urgency = urgency
        self.workflowStatus = workflowStatus
        self.availableActions = availableActions
        self.participantHumanIDs = participantHumanIDs
        self.createdByMember = createdByMember
        self.assignedToMember = assignedToMember
        self.claimedByMember = claimedByMember
        self.completedByMember = completedByMember
        self.rewardCoconuts = max(0, rewardCoconuts)
    }

    var subjectName: String? { subject.name }
    var themeColorHex: String? { subject.themeColorHex }
}

nonisolated struct TaskCenterSnapshot: Equatable, Sendable {
    let overdue: [TaskCenterItemSnapshot]
    let today: [TaskCenterItemSnapshot]
    let upcoming: [TaskCenterItemSnapshot]
    let unscheduled: [TaskCenterItemSnapshot]
    let todayCompletedCount: Int
    let todayTotalCount: Int
    let memberFilterContext: TaskCenterMemberFilterContext
    let starterJourney: HouseholdStarterJourneySnapshot?

    static let empty = TaskCenterSnapshot(
        overdue: [],
        today: [],
        upcoming: [],
        unscheduled: [],
        todayCompletedCount: 0,
        todayTotalCount: 0,
        memberFilterContext: .hidden,
        starterJourney: nil
    )

    var pendingCount: Int {
        overdue.count + today.count + upcoming.count + unscheduled.count
    }

    var allItems: [TaskCenterItemSnapshot] {
        overdue + today + upcoming + unscheduled
    }

    var systemJourneyItems: [TaskCenterItemSnapshot] {
        unscheduled.filter { $0.source == .systemJourney }
    }

    var ordinaryUnscheduledItems: [TaskCenterItemSnapshot] {
        unscheduled.filter { $0.source != .systemJourney }
    }

    var showsMemberFilters: Bool {
        memberFilterContext.showsFilters
    }

    var memberFilterSummary: TaskCenterMemberFilterSummary {
        memberFilterContext.summary
    }

    /// Multi-member households default to work that needs the current actor now.
    /// Hidden collaboration controls always mean the full list.
    func resolvedMemberFilter(
        explicitSelection: TaskCenterMemberFilter?
    ) -> TaskCenterMemberFilter {
        guard showsMemberFilters else { return .all }
        return (explicitSelection ?? .actionRequired).normalized
    }

    func filtered(for scope: TaskCenterScope) -> TaskCenterSnapshot {
        guard case .all = scope else {
            let includes: (TaskCenterItemSnapshot) -> Bool = { item in
                switch scope {
                case .all:
                    true
                case let .human(id):
                    (item.subject.kind == .human && item.subject.id == id)
                        || item.participantHumanIDs.contains(id)
                case let .pet(id):
                    item.subject.kind == .pet && item.subject.id == id
                case let .plant(id):
                    item.subject.kind == .plant && item.subject.id == id
                }
            }
            let scopedToday = today.filter(includes)
            let scopedOverdue = overdue.filter(includes)
            let scopedUpcoming = upcoming.filter(includes)
            let scopedUnscheduled = unscheduled.filter(includes)
            let scopedItemIDs = Set(
                (scopedOverdue + scopedToday + scopedUpcoming + scopedUnscheduled).map(\.id)
            )
            return TaskCenterSnapshot(
                overdue: scopedOverdue,
                today: scopedToday,
                upcoming: scopedUpcoming,
                unscheduled: scopedUnscheduled,
                todayCompletedCount: 0,
                todayTotalCount: scopedToday.count,
                memberFilterContext: memberFilterContext.restricted(to: scopedItemIDs),
                starterJourney: starterJourney
            )
        }
        return self
    }

    func filtered(for memberFilter: TaskCenterMemberFilter) -> TaskCenterSnapshot {
        guard showsMemberFilters,
              let includedItemIDs = memberFilterContext.itemIDs(for: memberFilter) else {
            return self
        }
        let includes: (TaskCenterItemSnapshot) -> Bool = {
            $0.source == .systemJourney || includedItemIDs.contains($0.id)
        }
        let filteredToday = today.filter(includes)
        return TaskCenterSnapshot(
            overdue: overdue.filter(includes),
            today: filteredToday,
            upcoming: upcoming.filter(includes),
            unscheduled: unscheduled.filter(includes),
            todayCompletedCount: 0,
            todayTotalCount: filteredToday.count,
            memberFilterContext: memberFilterContext,
            starterJourney: starterJourney
        )
    }

    var overdueCount: Int {
        overdue.count
    }

    var criticalCount: Int {
        overdue.count { $0.urgency == .critical }
    }

    var todayPendingCount: Int {
        max(0, todayTotalCount - todayCompletedCount)
    }

    var todayCompletionFraction: Double {
        guard todayTotalCount > 0 else { return pendingCount == 0 ? 1 : 0 }
        return min(1, max(0, Double(todayCompletedCount) / Double(todayTotalCount)))
    }
}

nonisolated struct TaskCenterBadgeSnapshot: Equatable, Sendable {
    let overdueCount: Int
    let criticalCount: Int
    let attentionCount: Int

    static let empty = TaskCenterBadgeSnapshot(overdueCount: 0, criticalCount: 0, attentionCount: 0)

    init(overdueCount: Int, criticalCount: Int, attentionCount: Int? = nil) {
        self.overdueCount = max(0, overdueCount)
        self.criticalCount = max(0, criticalCount)
        self.attentionCount = max(0, attentionCount ?? overdueCount)
    }

    init(snapshot: TaskCenterSnapshot) {
        let attentionItemIDs = Set(
            (snapshot.overdue + snapshot.today + snapshot.allItems.filter {
                $0.workflowStatus == .pendingReview || $0.source == .systemJourney
            }).map(\.id)
        )
        self.init(
            overdueCount: snapshot.overdueCount,
            criticalCount: snapshot.criticalCount,
            attentionCount: attentionItemIDs.count
        )
    }
}
