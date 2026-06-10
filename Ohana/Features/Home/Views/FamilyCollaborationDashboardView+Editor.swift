//
//  FamilyCollaborationDashboardView+Editor.swift
//  Ohana
//

import SwiftUI
import SwiftData

extension FamilyCollaborationDashboardView {
    func scheduleLegacyBountySync() {
        legacyBountySyncTask?.cancel()
        legacyBountySyncTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            commandExecutor.migrateLegacyBountiesIfNeeded()
        }
    }

    func presentEditor(_ route: FamilyCollaborationEditorRoute) {
        inlineEditorVisible = false
        inlineEditorDragOffset = 0
        activeEditor = route
        onEditorVisibilityChanged(true)
    }

    func dismissEditor() {
        withAnimation(GoMotion.page) {
            inlineEditorVisible = false
            inlineEditorDragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 340_000_000)
            activeEditor = nil
            onEditorVisibilityChanged(false)
        }
    }

    func inlineTaskEditorOverlay(_ route: FamilyCollaborationEditorRoute) -> some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 6
            let bottomInset = max(proxy.safeAreaInsets.bottom, CGFloat(8))
            let maxHeight = min(proxy.size.height * 0.86, CGFloat(660))
            let hiddenOffset = maxHeight + bottomInset + 64
            let cornerRadius: CGFloat = 52
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let editorContext = FamilyCollaborationEditorContext.resolve(
                route: route,
                reminders: pendingReminders,
                tasks: familyTasks
            )

            ZStack(alignment: .bottom) {
                collaborationInlineBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture { dismissEditor() }

                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                        if let editorContext {
                            FamilyTaskEditorPanel(
                                context: editorContext,
                                humans: humans,
                                currentHuman: currentHuman,
                                pets: pets,
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
                                onUpdateTask: { task, title, note, human, reward, dueAt, emoji in
                                    commandExecutor.updateTask(
                                        task,
                                        title: title,
                                        note: note,
                                        assignedTo: human,
                                        rewardCoconuts: reward,
                                        dueAt: dueAt,
                                        emoji: emoji
                                    )
                                },
                                onDeleteTask: { task in
                                    commandExecutor.deleteTask(task)
                                }
                            )
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
