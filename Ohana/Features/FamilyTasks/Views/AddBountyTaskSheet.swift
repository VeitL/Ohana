//
//  AddBountyTaskSheet.swift
//  Ohana
//
//  Sheet for publishing a legacy bounty task.
//

import SwiftUI

struct AddBountyTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let humans: [Human]
    let currentHumanId: String
    let onAdd: (BountyTask) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var reward = 20
    @State private var selectedEmoji = "🎯"
    @State private var assignedToId: String? = nil

    private let emojiOptions = ["🎯", "🧹", "🍳", "🛒", "📦", "🐾", "🌱", "💊", "🚗", "📚", "🎮", "🎂", "🧺", "💻", "🔧", "✏️", "🎵", "🏃"]
    private let rewardOptions = [10, 20, 30, 50, 80, 100, 150, 200]

    private var creator: Human? {
        humans.first { $0.id.uuidString == currentHumanId }
    }

    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.58) }
    private var tertiaryText: Color { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        emojiSelector
                        titleField
                        descriptionField
                        rewardSelector
                        assigneeSelector
                        creatorPreview
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("发布悬赏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ohanaCardSurface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: publishTask) {
                        Text("发布")
                            .font(OhanaFont.body(.bold))
                            .foregroundStyle(title.isEmpty ? Color.goPrimary.opacity(0.35) : Color.goPrimary)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .tint(Color.goPrimary)
    }

    private var emojiSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("任务图标")
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(tertiaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(OhanaFont.metric(size: 28))
                                .frame(width: 52, height: 52)
                                .background(
                                    selectedEmoji == emoji
                                        ? Color.goPrimary.opacity(0.25)
                                        : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08),
                                    in: RoundedRectangle(cornerRadius: OhanaRadius.row)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: OhanaRadius.row)
                                        .strokeBorder(
                                            selectedEmoji == emoji
                                                ? Color.goPrimary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var titleField: some View {
        formField(title: "任务标题") {
            TextField("", text: $title) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.headline(.semibold))
                .foregroundStyle(primaryText)
                .tint(Color.goPrimary)
                .placeholder(when: title.isEmpty) {
                    Text("例如：帮我给猫铲屎")
                        .foregroundStyle(tertiaryText)
                }
        }
    }

    private var descriptionField: some View {
        formField(title: "任务说明（可选）") {
            TextField("", text: $description, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(primaryText)
                .tint(Color.goPrimary)
                .lineLimit(3)
                .placeholder(when: description.isEmpty) {
                    Text("描述任务内容...")
                        .foregroundStyle(tertiaryText)
                }
        }
    }

    private var rewardSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("椰子奖励")
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(tertiaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rewardOptions, id: \.self) { val in
                        Button {
                            reward = val
                        } label: {
                            VStack(spacing: 2) {
                                Text("🥥")
                                    .font(OhanaFont.metric(size: 16, .medium))
                                Text("\(val)")
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(
                                        reward == val ? Color.arkInk : Color.goYellow
                                    )
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                reward == val ? Color.goPrimary : Color.goYellow.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: OhanaRadius.chip)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OhanaRadius.chip)
                                    .strokeBorder(
                                        reward == val ? Color.clear : Color.goYellow.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private var assigneeSelector: some View {
        if humans.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("指派给")
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(tertiaryText)
                    if assignedToId != nil {
                        Text("@")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        assigneeOption(id: nil, emoji: "👥", name: "所有人可接")
                        ForEach(humans.filter { $0.id.uuidString != currentHumanId }) { human in
                            assigneeOption(id: human.id.uuidString, emoji: human.avatarEmoji, name: human.name)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var creatorPreview: some View {
        if let human = creator {
            HStack(spacing: 10) {
                Text(human.avatarEmoji)
                    .font(OhanaFont.title2())
                VStack(alignment: .leading, spacing: 2) {
                    Text("发布人")
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(tertiaryText)
                    Text(human.name)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                }
                Spacer()
                Text("奖励 \(reward)🥥")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.goYellow)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.goYellow.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.row))
            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row).strokeBorder(Color.goYellow.opacity(0.15), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func assigneeOption(id: String?, emoji: String, name: String) -> some View {
        let isSelected = assignedToId == id
        Button {
            assignedToId = id
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? Color.goPrimary.opacity(0.25)
                                : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08)
                        )
                        .frame(width: 46, height: 46)
                    Text(emoji).font(OhanaFont.title3())
                }
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2)
                )
                Text(name)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(isSelected ? Color.goPrimary : secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 60)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func formField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(tertiaryText)
            content()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .fill(Color.ohanaCardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )
        }
    }

    private func publishTask() {
        guard !title.isEmpty, let human = creator else { return }
        let assignee = humans.first { $0.id.uuidString == assignedToId }
        let task = BountyTask(
            title: title,
            description: description,
            reward: reward,
            creatorId: human.id.uuidString,
            creatorName: human.name,
            creatorEmoji: human.avatarEmoji,
            emoji: selectedEmoji,
            assignedToId: assignee?.id.uuidString,
            assignedToName: assignee?.name,
            assignedToEmoji: assignee?.avatarEmoji
        )
        onAdd(task)
        dismiss()
    }
}

private extension View {
    @ViewBuilder
    func placeholder(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> some View
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
