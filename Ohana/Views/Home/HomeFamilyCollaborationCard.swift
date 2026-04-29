//
//  HomeFamilyCollaborationCard.swift
//  Ohana
//
//  Compact family collaboration card for the GO home carousel.
//

import SwiftUI

struct HomeFamilyCollaborationCard: View {
    let pet: Pet
    let pendingReminders: [Reminder]
    let humans: [Human]
    var onOpenActivity: () -> Void
    var onOpenWeeklyReport: () -> Void

    private var shouldShowFamilyCollaboration: Bool {
        humans.count > 1
    }

    private var assignedReminders: [Reminder] {
        let petId = pet.id.uuidString
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders
            .filter { reminder in
                guard let event = reminder.event,
                      let assigneeId = event.assigneeId,
                      !assigneeId.isEmpty else { return false }
                let isThisPet = (event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet")
                    && event.relatedEntityId == petId
                return isThisPet && reminder.scheduledAt < tomorrow
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var body: some View {
        if shouldShowFamilyCollaboration {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                card
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FAMILY")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.primary.opacity(0.36))
                Text("家庭协作")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
            }
            Spacer()
            Button(action: onOpenWeeklyReport) {
                Label("周报", systemImage: "chart.bar.doc.horizontal")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            FamilyActivityStripView(pet: pet, style: .compact, onExpand: onOpenActivity)

            if assignedReminders.isEmpty {
                Text("今天还没有指派给具体成员的待办。添加日历事件时可选择“指派给”，家人就能看到任务归属。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(assignedReminders.prefix(1)) { reminder in
                        assignedReminderRow(reminder)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground(Color.goPrimary))
    }

    private func assignedReminderRow(_ reminder: Reminder) -> some View {
        let event = reminder.event
        let targetHuman: Human? = {
            guard let id = event?.assigneeId, !id.isEmpty else { return nil }
            return humans.first { $0.id.uuidString == id }
        }()
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event?.title ?? "家庭待办")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(reminder.scheduledAt, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let assigneeId = event?.assigneeId {
                AssigneeChip(assigneeId: assigneeId, allHumans: humans)
            }

            if let targetHuman {
                NudgeButton(targetHuman: targetHuman)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cardBackground(_ accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }
}
