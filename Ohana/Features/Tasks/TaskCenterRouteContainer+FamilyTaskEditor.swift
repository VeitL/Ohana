//
//  TaskCenterRouteContainer+FamilyTaskEditor.swift
//  Ohana
//
//  Family-task editor presentation kept separate from the route-data host.
//

import SwiftUI

extension TaskCenterRouteContainer {
    @ViewBuilder
    func familyTaskEditor(_ route: FamilyCollaborationEditorRoute) -> some View {
        let context = FamilyCollaborationEditorContext.resolve(
            route: route,
            reminders: routeData.reminders,
            tasks: routeData.familyTasks
        )
        let canPresentContext = context.map { editorContext in
            switch route {
            case .assignReminder, .create:
                true
            case .editTask:
                editorContext.task.map(canSelectedHumanEdit) == true
            }
        } ?? false
        let commandExecutor = familyTaskCommandExecutor
        NavigationStack {
            Group {
                if let context, canPresentContext {
                    FamilyTaskPlanEditorDataContainer(planID: context.task?.planId) { planConfiguration in
                        FamilyTaskEditorPanel(
                            context: context,
                            humans: activeHumans,
                            currentHuman: currentHuman,
                            pets: routeData.pets.filter { !$0.hasPassedAway },
                            planConfiguration: planConfiguration,
                            onClose: dismissFamilyTaskEditor,
                            onAssignReminder: { reminder, human, reward, note in
                                commandExecutor.assignReminder(
                                    reminder,
                                    to: human,
                                    by: currentHuman,
                                    rewardCoconuts: reward,
                                    note: note
                                )
                            },
                            onCreateTask: { title, note, human, reward, dueAt, emoji in
                                commandExecutor.createTask(
                                    title: title,
                                    note: note,
                                    assignedTo: human,
                                    by: currentHuman,
                                    rewardCoconuts: reward,
                                    dueAt: dueAt,
                                    emoji: emoji
                                )
                            },
                            onCreatePlan: { draft in
                                await commandExecutor.createPlan(draft)
                            },
                            onUpdateTask: { task, title, note, human, reward, dueAt, emoji in
                                commandExecutor.updateTask(
                                    task,
                                    title: title,
                                    note: note,
                                    assignedTo: human,
                                    rewardCoconuts: reward,
                                    dueAt: dueAt,
                                    emoji: emoji,
                                    by: currentHuman
                                )
                            },
                            onDeleteTask: { task in
                                commandExecutor.deleteTask(task, by: currentHuman)
                            },
                            onUpdatePlan: { planID, nominalAt, draft in
                                guard let currentHuman else { return false }
                                return await commandExecutor.updateThisAndFuture(
                                    planID: planID,
                                    from: nominalAt,
                                    draft: draft,
                                    by: currentHuman
                                )
                            },
                            onCancelPlan: { planID, nominalAt in
                                guard let currentHuman else { return false }
                                return await commandExecutor.cancelThisAndFuture(
                                    planID: planID,
                                    from: nominalAt,
                                    by: currentHuman
                                )
                            }
                        )
                    }
                } else {
                    ContentUnavailableView(
                        L10n.current.tr(zh: "任务不可用", en: "Task unavailable", de: "Aufgabe nicht verfügbar"),
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .navigationTitle(editorTitle(route))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.current.cancel, action: dismissFamilyTaskEditor)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    func dismissFamilyTaskEditor() {
        familyTaskEditorRoute = nil
        scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
    }

    func editorTitle(_ route: FamilyCollaborationEditorRoute) -> String {
        switch route {
        case .assignReminder:
            L10n.current.tr(zh: "分配提醒", en: "Assign reminder", de: "Erinnerung zuweisen")
        case .editTask:
            L10n.current.tr(zh: "编辑任务", en: "Edit task", de: "Aufgabe bearbeiten")
        case .create:
            L10n.current.tr(zh: "新建任务", en: "New task", de: "Neue Aufgabe")
        }
    }
}
