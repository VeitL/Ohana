//
//  VerticalSolidHomeTodayFocusChrome.swift
//  Ohana
//
//  Compact and accessibility-sized Today Focus chrome.
//

import SwiftUI

struct VerticalSolidHomeTodayFocusChrome: View {
    let snapshot: TodayFocusSnapshot
    let isLive: Bool
    let onOpenOasis: () -> Void
    let onOpenQuest: (IslandQuest) -> Void
    let onCompleteQuest: (IslandQuest) -> Void
    let onTapNegativeSignal: (IslandNegativeSignal) -> Void
    let onTapFamilyTask: (TodayFocusFamilyTaskSnapshot) -> Void
    let onPerformFamilyTask: (TodayFocusFamilyTaskSnapshot) -> Void
    let onOpenExchange: (TodayFocusExchangeRequestSnapshot) -> Void
    let onConfirmExchange: (TodayFocusExchangeRequestSnapshot) -> Void
    let onViewAllTasks: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityFocusButton
            } else {
                compactFocusDeck
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(isLive)
    }

    private var compactFocusDeck: some View {
        ZStack(alignment: .bottomTrailing) {
            TodayFocusCard(
                snapshot: snapshot,
                presentation: .compactStack,
                onOpenQuest: onOpenQuest,
                onCompleteQuest: onCompleteQuest,
                onTapNegativeSignal: onTapNegativeSignal,
                onTapOasis: onOpenOasis,
                onTapFamilyTask: onTapFamilyTask,
                onPerformFamilyTask: onPerformFamilyTask,
                onOpenExchange: onOpenExchange,
                onConfirmExchange: onConfirmExchange,
                freezesToFrontCard: !isLive,
                allowsAmbientMotion: false
            )
            .transaction { transaction in
                if !isLive {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }

            Button {
                OhanaFeedback.light()
                onViewAllTasks()
            } label: {
                Label(l.tr(zh: "全部", en: "All", de: "Alle"), systemImage: "checklist")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.arkInk.opacity(0.76))
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(Color.goCardWhite.opacity(0.72), in: Capsule())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!isLive)
            .accessibilityLabel(l.tr(zh: "查看全部待办", en: "View all tasks", de: "Alle Aufgaben anzeigen"))
            .accessibilityIdentifier("today-focus-view-all-tasks")
            .padding(.trailing, 24)
            .padding(.bottom, 1)
            .zIndex(30)
        }
    }

    private var accessibilityFocusButton: some View {
        VStack(spacing: 8) {
            if let task = snapshot.assignedFamilyTasks.first,
               let action = task.primaryAction {
                Button {
                    OhanaFeedback.medium()
                    onPerformFamilyTask(task)
                } label: {
                    Label(task.title, systemImage: accessibilityTaskActionIcon(action))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isLive)
                .accessibilityLabel(accessibilityTaskActionLabel(action, title: task.title))
                .accessibilityIdentifier("today-focus-task-action-\(task.id)")
            }

            Button {
                OhanaFeedback.light()
                onViewAllTasks()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        l.tr(zh: "待办", en: "Tasks", de: "Aufgaben"),
                        systemImage: "checklist"
                    )
                    .font(.headline)

                    Text(accessibilityFocusTitle)
                        .font(.body)
                        .foregroundStyle(.secondary) // native-ui: allow semantic secondary color inside native bordered Button
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!isLive)
            .accessibilityLabel("\(l.tr(zh: "查看全部待办", en: "View all tasks", de: "Alle Aufgaben anzeigen")), \(accessibilityFocusDetail)")
            .accessibilityIdentifier("today-focus-view-all-tasks")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var accessibilityFocusTitle: String {
        if !snapshot.negativeSignals.isEmpty {
            return l.tr(zh: "关注", en: "Alert", de: "Hinweis")
        }
        if !snapshot.assignedFamilyTasks.isEmpty {
            return l.tr(zh: "待办", en: "Task", de: "Aufgabe")
        }
        if CoconutExchangeFeatureGate.isEnabled, snapshot.pendingExchangeRequests.first != nil {
            return l.tr(zh: "收款", en: "Payment", de: "Zahlung")
        }
        if snapshot.refreshedQuests.contains(where: {
            !$0.isCompleted && IslandQuestEngine.isOasisBuildQuest($0.id)
        }) {
            return l.tr(zh: "成长引导", en: "Growth guide", de: "Wachstum")
        }
        return l.tr(zh: "已完成", en: "Done", de: "Erledigt")
    }

    private var accessibilityFocusDetail: String {
        if let signal = snapshot.negativeSignals.first {
            return signal.title
        }
        if let task = snapshot.assignedFamilyTasks.first {
            return task.title
        }
        if CoconutExchangeFeatureGate.isEnabled, snapshot.pendingExchangeRequests.first != nil {
            return l.tr(zh: "确认线下收款", en: "Confirm cash received", de: "Zahlung bestätigen")
        }
        if let quest = snapshot.refreshedQuests.first(where: {
            !$0.isCompleted && IslandQuestEngine.isOasisBuildQuest($0.id)
        }) {
            return quest.title
        }
        return accessibilityFocusTitle
    }

    private func accessibilityTaskActionIcon(_ action: TaskCenterAvailableAction) -> String {
        switch action {
        case .complete: "checkmark.circle.fill"
        case .claim: "hand.raised.fill"
        case .submitForReview: "paperplane.fill"
        case .approve: "checkmark.seal.fill"
        case .reject: "arrow.uturn.backward.circle.fill"
        }
    }

    private func accessibilityTaskActionLabel(
        _ action: TaskCenterAvailableAction,
        title: String
    ) -> String {
        let verb = switch action {
        case .complete: l.tr(zh: "完成", en: "Complete", de: "Erledigen")
        case .claim: l.tr(zh: "领取", en: "Claim", de: "Annehmen")
        case .submitForReview: l.tr(zh: "提交审核", en: "Submit for review", de: "Zur Prüfung senden")
        case .approve: l.tr(zh: "审核通过", en: "Approve", de: "Bestätigen")
        case .reject: l.tr(zh: "驳回", en: "Reject", de: "Ablehnen")
        }
        return "\(verb)：\(title)"
    }
}
