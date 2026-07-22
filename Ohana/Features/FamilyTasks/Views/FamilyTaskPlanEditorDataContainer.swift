//
//  FamilyTaskPlanEditorDataContainer.swift
//  Ohana
//
//  Bounded route data for editing one recurring family-task plan.
//

import SwiftData
import SwiftUI

nonisolated struct FamilyTaskPlanEditorSnapshot: Equatable, Sendable {
    let id: UUID
    let recurrenceRule: FamilyTaskRecurrenceRule
    let anchorAt: Date
    let startsAt: Date?
    let endsAt: Date?
    let isAllDay: Bool
    let reminderLeadMinutes: Int?
    let subjectName: String
    let timeZoneIdentifier: String
    let eventTypeRaw: String
    let taskCareKindRaw: String
    let scheduleVersion: Int

    init(plan: FamilyTaskPlan) {
        id = plan.id
        recurrenceRule = plan.recurrenceRule
        anchorAt = plan.anchorAt
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        isAllDay = plan.isAllDay
        reminderLeadMinutes = plan.reminderLeadMinutes
        subjectName = plan.subjectName
        timeZoneIdentifier = plan.timeZoneIdentifier
        eventTypeRaw = plan.eventTypeRaw
        taskCareKindRaw = plan.taskCareKindRaw
        scheduleVersion = plan.scheduleVersion
    }
}

@MainActor
struct FamilyTaskPlanEditorDataContainer<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var routeData: FamilyTaskPlanEditorRouteData

    private let planID: UUID?
    private let content: (FamilyTaskPlanEditorSnapshot?) -> Content

    init(
        planID rawPlanID: String?,
        @ViewBuilder content: @escaping (FamilyTaskPlanEditorSnapshot?) -> Content
    ) {
        planID = rawPlanID.flatMap(UUID.init(uuidString:))
        _routeData = State(
            initialValue: planID == nil
                ? FamilyTaskPlanEditorRouteData(snapshot: nil, hasLoaded: true)
                : FamilyTaskPlanEditorRouteData()
        )
        self.content = content
    }

    var body: some View {
        Group {
            if routeData.hasLoaded {
                content(routeData.snapshot)
                    .id(routeData.snapshot?.id)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .accessibilityLabel(L10n.current.tr(
                        zh: "正在载入任务设置",
                        en: "Loading task settings",
                        de: "Aufgabeneinstellungen werden geladen"
                    ))
            }
        }
        .task(id: planID) {
            await loadPlanIfNeeded()
        }
    }

    private func loadPlanIfNeeded() async {
        guard let planID else { return }
        let loader = FamilyTaskPlanEditorDataActor(modelContainer: modelContext.container)
        do {
            let snapshot = try await loader.load(planID: planID)
            guard !Task.isCancelled else { return }
            routeData = FamilyTaskPlanEditorRouteData(snapshot: snapshot, hasLoaded: true)
        } catch {
            guard !Task.isCancelled else { return }
            routeData = FamilyTaskPlanEditorRouteData(snapshot: nil, hasLoaded: true)
        }
    }
}

private nonisolated struct FamilyTaskPlanEditorRouteData: Equatable, Sendable {
    var snapshot: FamilyTaskPlanEditorSnapshot?
    var hasLoaded: Bool

    init(snapshot: FamilyTaskPlanEditorSnapshot? = nil, hasLoaded: Bool = false) {
        self.snapshot = snapshot
        self.hasLoaded = hasLoaded
    }
}

@ModelActor
private actor FamilyTaskPlanEditorDataActor {
    func load(planID: UUID) throws -> FamilyTaskPlanEditorSnapshot? {
        var descriptor = FetchDescriptor<FamilyTaskPlan>(
            predicate: #Predicate<FamilyTaskPlan> { $0.id == planID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(FamilyTaskPlanEditorSnapshot.init)
    }
}
