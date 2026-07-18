//
//  AddEventView+Actions.swift
//  Ohana
//
//  Persistence actions emitted by AddEventContentView.
//

import SwiftUI
import UIKit

extension AddEventContentView {
    func saveEvent() {
        guard canSave else { return }
        let input = eventCommandInput
        let command = DomainCommand.calendarEventPlan(eventID: editingEvent?.id)
        isSaving = true
        titleFocused = false
        GoKeyboard.dismiss()

        if let taskCreationPreset {
            saveCareAssignment(
                preset: taskCreationPreset,
                input: input,
                command: command
            )
            return
        }

        guard input.reminderLeadMinutes == nil else {
            Task { @MainActor in
                guard await appServices.userNotifications.requestPermission() else {
                    isSaving = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                enqueueSaveEvent(input: input, command: command)
            }
            return
        }

        enqueueSaveEvent(input: input, command: command)
    }

    private func saveCareAssignment(
        preset: TaskCreationPreset,
        input: CalendarEventPlanCommandInput,
        command: DomainCommand
    ) {
        let assignment = TaskCareAssignmentCommand(
            preset: preset,
            title: input.title,
            startDate: input.startDate,
            isAllDay: input.isAllDay,
            recurrenceDays: input.recurrenceDays,
            recurrenceEndDate: input.recurrenceEndDate,
            notificationLeadMinutes: input.reminderLeadMinutes,
            creatorHumanID: careAssignmentCreatorHumanID,
            assigneeHumanID: careAssignmentAssigneeHumanID,
            rewardCoconuts: AddEventCollaborationPolicy.normalizedReward(
                rewardCoconuts,
                activeHumanCount: activeHumans.count,
                creatorHumanID: careAssignmentCreatorHumanID,
                assigneeHumanID: careAssignmentAssigneeHumanID
            )
        )

        guard input.reminderLeadMinutes != nil else {
            enqueueCareAssignment(
                assignment,
                scheduleNotifications: false,
                command: command
            )
            return
        }

        Task { @MainActor in
            let permissionGranted = await appServices.userNotifications.requestPermission()
            enqueueCareAssignment(
                assignment,
                scheduleNotifications: permissionGranted,
                command: command
            )
        }
    }

    private func enqueueCareAssignment(
        _ assignment: TaskCareAssignmentCommand,
        scheduleNotifications: Bool,
        command: DomainCommand
    ) {
        commandQueue.enqueue(command) {
            do {
                _ = try TaskCareAssignmentCommandExecutor(
                    modelContext: modelContext,
                    services: appServices
                ).execute(
                    assignment,
                    scheduleNotifications: scheduleNotifications
                )
                finishSuccessfulSave()
            } catch let TaskCareAssignmentError.personalUpgradeRequired(denial) {
                isSaving = false
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } catch {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private func enqueueSaveEvent(input: CalendarEventPlanCommandInput, command: DomainCommand) {
        commandQueue.enqueue(command) {
            let executor = CalendarCommandExecutor(context: modelContext, services: appServices)
            do {
                let result: CalendarEventPlanCommandResult? = if let editingEvent {
                    try executor.updateEvent(event: editingEvent, input: input)
                } else {
                    try executor.createEvent(input: input)
                }
                guard result != nil else {
                    isSaving = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }

                finishSuccessfulSave()
            } catch let CalendarCommandError.personalUpgradeRequired(denial) {
                isSaving = false
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } catch {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }
}
