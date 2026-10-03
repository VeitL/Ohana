//
//  FamilyCollaborationDashboardView+Editor.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    func scheduleLegacyBountySync() {
        legacyBountySyncTask?.cancel()
        legacyBountySyncTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            commandExecutor.migrateLegacyBountiesIfNeeded()
        }
    }

    func presentEditor(_ route: FamilyCollaborationEditorRoute) {
        if case .editTask = route, authorizedEditorContext(for: route) == nil {
            commandFailureMessage = l.tr(
                zh: "只有任务发布者可以编辑这项任务。",
                en: "Only the task publisher can edit this task.",
                de: "Nur der Ersteller kann diese Aufgabe bearbeiten."
            )
            return
        }
        activeEditor = route
        onEditorVisibilityChanged(true)
    }

    func dismissEditor() {
        activeEditor = nil
        onEditorVisibilityChanged(false)
    }

    func closeRoleScopedRoutes() {
        activeTaskDetail = nil
        activeSheetRoute = nil
        pendingPostSheetAction = nil
        dismissEditor()
    }

    func authorizedEditorContext(
        for route: FamilyCollaborationEditorRoute
    ) -> FamilyCollaborationEditorContext? {
        guard let context = FamilyCollaborationEditorContext.resolve(
            route: route,
            reminders: pendingReminders,
            tasks: familyTasks
        ) else { return nil }
        guard let task = context.task else { return context }
        return FamilyTaskCapabilities.resolve(
            task: task,
            currentHumanID: currentHuman?.id
        ).canEdit ? context : nil
    }

    @ViewBuilder
    func nativeTaskEditorSheet(_ route: FamilyCollaborationEditorRoute) -> some View {
        let editorContext = authorizedEditorContext(for: route)

        NavigationStack {
            Group {
                if let editorContext {
                    taskEditorPanel(editorContext)
                } else {
                    ContentUnavailableView(
                        l.tr(zh: "任务不可用", en: "Task unavailable", de: "Aufgabe nicht verfügbar"),
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .navigationTitle(editorTitle(for: route))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) {
                        dismissEditor()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func taskEditorPanel(_ editorContext: FamilyCollaborationEditorContext) -> some View {
        FamilyTaskPlanEditorDataContainer(planID: editorContext.task?.planId) { planConfiguration in
            FamilyTaskEditorPanel(
                context: editorContext,
                humans: humans,
                currentHuman: currentHuman,
                pets: pets,
                planConfiguration: planConfiguration,
                onClose: dismissEditor,
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
    }

    func editorTitle(for route: FamilyCollaborationEditorRoute) -> String {
        switch route {
        case .assignReminder:
            l.tr(zh: "分配提醒", en: "Assign reminder", de: "Erinnerung zuweisen")
        case .editTask:
            l.tr(zh: "编辑任务", en: "Edit task", de: "Aufgabe bearbeiten")
        case .create:
            l.tr(zh: "新建任务", en: "New task", de: "Neue Aufgabe")
        }
    }

    func inlineTaskEditorOverlay(_ route: FamilyCollaborationEditorRoute) -> some View { // native-ui: allow retired compatibility renderer; runtime uses sheet(item:)
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 6
            let bottomInset = max(proxy.safeAreaInsets.bottom, CGFloat(8))
            let maxHeight = min(proxy.size.height * 0.86, CGFloat(660))
            let hiddenOffset = maxHeight + bottomInset + 64
            let cornerRadius: CGFloat = 52
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let editorContext = authorizedEditorContext(for: route)

            ZStack(alignment: .bottom) {
                collaborationInlineBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture { dismissEditor() }

                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                        if let editorContext {
                            taskEditorPanel(editorContext)
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxHeight: maxHeight)
                    .clipShape(shape)

                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .gesture(editorDragGesture)
                        .zIndex(3)

                    HStack {
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                            dismissEditor()
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    FeedInlineSheetGlassSurface(cornerRadius: cornerRadius, glassMode: .regular)
                }
                .clipShape(shape)
                .frame(width: max(0, proxy.size.width - horizontalInset * 2))
                .shadow(color: Color.black.opacity(inlineEditorVisible ? 0.54 : 0), radius: 46, x: 0, y: -16) // ui-v4: allow liftedAlert inline popup shadow
                .shadow(color: Color(hex: "0B102C").opacity(inlineEditorVisible ? 0.38 : 0), radius: 26, x: 0, y: 12) // ui-v4: allow liftedAlert inline popup shadow
                .offset(y: inlineEditorVisible ? inlineEditorDragOffset : hiddenOffset)
                .opacity(inlineEditorVisible ? 1 : 0.94)
                .scaleEffect(inlineEditorVisible ? 1 : 0.982, anchor: .bottom)
                .padding(.bottom, bottomInset)
                .animation(GoMotion.feedback, value: inlineEditorDragOffset)
                .animation(GoMotion.page, value: inlineEditorVisible)
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                guard editorContext != nil else {
                    dismissEditor()
                    return
                }
                inlineEditorVisible = false
                inlineEditorDragOffset = 0
                DispatchQueue.main.async {
                    withAnimation(GoMotion.page) {
                        inlineEditorVisible = true
                    }
                }
            }
        }
    }

    var collaborationInlineBackdrop: some View {
        ZStack {
            Color.black.opacity(inlineEditorVisible ? 0.14 : 0) // ui-v4: allow modal scrim behind inline glass sheet
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(inlineEditorVisible ? 0.25 : 0) // ui-v4: allow grounding shade behind bottom glass sheet
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(GoMotion.page, value: inlineEditorVisible)
    }

    var editorDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                inlineEditorDragOffset = min(150, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 72 || value.predictedEndTranslation.height > 130 {
                    dismissEditor()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineEditorDragOffset = 0
                    }
                }
            }
    }
}
