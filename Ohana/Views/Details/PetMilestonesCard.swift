//
//  PetMilestonesCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetMilestonesCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goYellow)
                Text("里程碑")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(pet.milestones.count) 个")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }

            let sorted = pet.milestones.sorted { $0.date > $1.date }
            let recent = Array(sorted.prefix(6))
            let total = recent.count

            VStack(spacing: 0) {
                ForEach(Array(recent.enumerated()), id: \.offset) { i, milestone in
                    timelineRow(milestone: milestone, index: i, total: total)
                }
            }

            if pet.milestones.isEmpty {
                Text("暂无里程碑")
                    .font(OhanaFont.adaptive(size: 13, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private func timelineRow(milestone: PetMilestone, index: Int, total: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(index == 0 ? Color.goYellow : Color.primary.opacity(0.12))
                        .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    Text(milestone.emoji)
                        .font(OhanaFont.adaptive(size: 14))
                }
                if index < total - 1 {
                    Rectangle()
                        .fill(.primary.opacity(0.1))
                        .frame(width: 2, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(index == 0 ? Color.primary : Color.primary.opacity(0.7))
                Text(milestone.date, style: .date)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                if !milestone.notes.isEmpty {
                    Text(milestone.notes)
                        .font(OhanaFont.adaptive(size: 11))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        .lineLimit(2)
                }
            }
            .padding(.top, 4)
            Spacer()
        }
    }
}
