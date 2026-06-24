//
//  Day0PromiseSheet.swift
//  Ohana
//
//  P0 留存：首日承诺 — 添加宠物向导保存后的今晚承诺勾选射入委托
//  把用户勾选的承诺自动生成 BountyTask，让家庭协作从 Day 0 就开始
//

import SwiftData
import SwiftUI

nonisolated struct Day0PromiseChoice: Identifiable, Equatable, Sendable {
    let id: String
    let emoji: String
    let title: String
    let reward: Int
}

nonisolated struct Day0PromiseCopy {
    let l: L10n

    init(_ l: L10n) {
        self.l = l
    }

    var footnote: String {
        l.tr(
            zh: "勾选的承诺会自动进入「家庭悬赏榜」——任何家人都可以帮你完成并领取椰子。",
            en: "Selected promises automatically go to the Family Bounty Board, so any family member can help complete them and earn coconuts."
        )
    }

    var skipTitle: String {
        l.tr(zh: "跳过", en: "Skip")
    }

    var headerSubtitle: String {
        l.tr(
            zh: "勾选几条你今晚或明天愿意完成的小承诺——它们会自动成为家庭任务，让家人一起参与。",
            en: "Pick a few small promises you can finish tonight or tomorrow. They become family tasks automatically so everyone can join in."
        )
    }

    var skipForNowTitle: String {
        l.tr(zh: "先跳过，以后再说", en: "Skip for now")
    }

    var creatorFallbackName: String {
        l.tr(zh: "我", en: "Me")
    }

    func navigationTitle(petEmoji: String) -> String {
        "\(petEmoji) \(l.tr(zh: "首日承诺", en: "Day 0 Promise"))"
    }

    func welcomeTitle(petName: String) -> String {
        l.tr(zh: "欢迎 \(petName) 🎉", en: "Welcome, \(petName) 🎉")
    }

    func sendPromisesTitle(count: Int) -> String {
        l.tr(
            zh: "把 \(count) 条承诺发给家人",
            en: "Send \(count) \(count == 1 ? "promise" : "promises") to family"
        )
    }

    func taskDescription(petName: String) -> String {
        l.tr(
            zh: "首日承诺 · 让家人一起帮 \(petName) 开启第一天",
            en: "Day 0 Promise · Let your family help \(petName) start day one"
        )
    }

    func promises(petName: String, species: String) -> [Day0PromiseChoice] {
        let base: [Day0PromiseChoice] = [
            Day0PromiseChoice(
                id: "photo",
                emoji: "📸",
                title: l.tr(zh: "今晚给 \(petName) 拍张照片留念", en: "Take a keepsake photo of \(petName) tonight"),
                reward: 10
            ),
            Day0PromiseChoice(
                id: "play",
                emoji: "🎾",
                title: l.tr(zh: "今晚陪 \(petName) 玩 10 分钟", en: "Play with \(petName) for 10 minutes tonight"),
                reward: 15
            ),
            Day0PromiseChoice(
                id: "record",
                emoji: "📝",
                title: l.tr(zh: "今晚记录 \(petName) 的一个小习惯", en: "Record one little habit of \(petName) tonight"),
                reward: 10
            ),
            Day0PromiseChoice(
                id: "weight",
                emoji: "⚖️",
                title: l.tr(zh: "这周给 \(petName) 称一次体重", en: "Weigh \(petName) once this week"),
                reward: 15
            )
        ]

        switch speciesKind(species) {
        case .dog:
            return base + [
                Day0PromiseChoice(
                    id: "walk",
                    emoji: "🦮",
                    title: l.tr(zh: "明天带 \(petName) 出去走 15 分钟", en: "Take \(petName) for a 15-minute walk tomorrow"),
                    reward: 20
                )
            ]
        case .cat:
            return base + [
                Day0PromiseChoice(
                    id: "groom",
                    emoji: "🪮",
                    title: l.tr(zh: "今晚给 \(petName) 梳毛放松一下", en: "Brush \(petName) tonight for a little wind-down"),
                    reward: 15
                )
            ]
        case .other:
            return base
        }
    }

    private func speciesKind(_ species: String) -> SpeciesKind {
        let normalized = species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("狗") || normalized.contains("犬") || normalized.contains("dog") || normalized.contains("puppy") {
            return .dog
        }
        if normalized.contains("猫") || normalized.contains("cat") || normalized.contains("kitten") {
            return .cat
        }
        return .other
    }

    private enum SpeciesKind {
        case dog
        case cat
        case other
    }
}

struct Day0PromiseContentSheet: View {
    let petName: String
    let species: String
    let petEmoji: String
    let humans: [Human]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @AppStorage("bountyTasks") private var tasksRaw: String = ""

    @State private var selected: Set<String> = []

    private var copy: Day0PromiseCopy {
        Day0PromiseCopy(L10n(appLanguage))
    }

    private var promises: [Day0PromiseChoice] {
        copy.promises(petName: petName, species: species)
    }

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        VStack(spacing: 10) {
                            ForEach(promises) { promise in
                                promiseRow(promise)
                            }
                        }
                        Text(copy.footnote)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }

                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .navigationTitle(copy.navigationTitle(petEmoji: petEmoji))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(copy.skipTitle) { finish() }
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.welcomeTitle(petName: petName))
                .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(copy.headerSubtitle)
                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promiseRow(_ p: Day0PromiseChoice) -> some View {
        let isOn = selected.contains(p.id)
        return Button {
            if isOn { selected.remove(p.id) } else { selected.insert(p.id) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.goPrimary : Color.goPrimary.opacity(0.12))
                        .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    if isOn {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .foregroundStyle(.black) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    }
                }
                Text(p.emoji).font(OhanaFont.adaptive(size: 22))
                Text(p.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack(spacing: 3) {
                    Text("+\(p.reward)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                    Text("🥥").font(OhanaFont.adaptive(size: 11))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .fill(isOn ? Color.goPrimary.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(
                        isOn ? Color.goPrimary.opacity(0.35) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var bottomBar: some View {
        Button {
            finish()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected.isEmpty ? "arrow.right.circle" : "checkmark.seal.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                Text(selected.isEmpty ? copy.skipForNowTitle : copy.sendPromisesTitle(count: selected.count))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.black) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func finish() {
        if !selected.isEmpty {
            injectBountyTasks()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
        onDone()
    }

    private func injectBountyTasks() {
        // 解析当前列表
        var current: [BountyTask] = {
            guard let data = tasksRaw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([BountyTask].self, from: data)
            else { return [] }
            return decoded
        }()

        let creator = currentHuman
        let creatorId = creator?.id.uuidString ?? "self"
        let creatorName = creator?.name ?? copy.creatorFallbackName
        let creatorEmoji = creator?.avatarEmoji ?? "🙂"

        for p in promises where selected.contains(p.id) {
            let task = BountyTask(
                title: p.title,
                description: copy.taskDescription(petName: petName),
                reward: p.reward,
                creatorId: creatorId,
                creatorName: creatorName,
                creatorEmoji: creatorEmoji,
                emoji: p.emoji,
                assignedToId: nil,
                assignedToName: nil,
                assignedToEmoji: nil
            )
            current.insert(task, at: 0)
        }

        if let data = try? JSONEncoder().encode(current),
           let str = String(data: data, encoding: .utf8) {
            tasksRaw = str
        }
    }
}
