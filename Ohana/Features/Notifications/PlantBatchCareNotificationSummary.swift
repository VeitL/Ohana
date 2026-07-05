//
//  PlantBatchCareNotificationSummary.swift
//  Ohana
//
//  Value payload for aggregated plant-care reminder notifications.
//

import Foundation

nonisolated struct PlantBatchCareNotificationSummary: Equatable, Sendable {
    let notificationId: String
    let deliveryDate: Date
    let careType: PlantCareType
    let plantCount: Int
    let taskCount: Int
    let anchorReminderID: UUID
    let reminderIDs: [UUID]

    init(
        notificationId: String,
        deliveryDate: Date,
        careType: PlantCareType,
        plantCount: Int,
        taskCount: Int,
        anchorReminderID: UUID,
        reminderIDs: [UUID]
    ) {
        self.notificationId = notificationId
        self.deliveryDate = deliveryDate
        self.careType = careType
        self.plantCount = plantCount
        self.taskCount = taskCount
        self.anchorReminderID = anchorReminderID
        self.reminderIDs = reminderIDs
    }
}

nonisolated protocol PlantBatchCareSummaryNotificationScheduling: Sendable {
    func schedulePlantBatchCareSummary(_ summary: PlantBatchCareNotificationSummary)
}
