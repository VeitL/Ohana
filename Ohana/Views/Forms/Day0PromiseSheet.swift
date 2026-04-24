//
//  Day0PromiseSheet.swift
//  Ohana
//
//  P0 留存：首日承诺 — 添加宠物向导保存后的今晚承诺勾选射入委托
//  把用户勾选的承诺自动生成 BountyTask，让家庭协作从 Day 0 就开始
//

import SwiftUI
import SwiftData

struct Day0PromiseSheet: View {
    let petName: String
    let species: String
    let petEmoji: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @AppStorage("bountyTasks") private var tasksRaw: String = ""

    @State private var selected: Set<String> = []

    private struct Promise: Identifiable {
        let id: String
        let emoji: String
        let title: String
        let reward: Int
    }

    private var promises: [Promise] {
        let base: [Promise] = [
            Promise(id: "photo",   emoji: "📸", title: "今晚给 \(petName) 拍张照片留念",       reward: 10),
            Promise(id: "play",    emoji: "🎾", title: "今晚陪 \(petName) 玩 10 分钟",         reward: 15),
            Promise(id: "record",  emoji: "📝", title: "今晚记录 \(petName) 的一个小习惯",     reward: 10),
            Promise(id: "weight",  emoji: "⚖️", title: "这周给 \(petName) 称一次体重",         reward: 15)
        ]

        // 物种差异化
        if species.contains("狗") {
            return base + [
                Promise(id: "walk",  emoji: "🦮", title: "明天带 \(petName) 出去走 15 分钟",   reward: 20)
            ]
        } else if species.contains("猫") {
            return base + [
                Promise(id: "groom", emoji: "🪮", title: "今晚给 \(petName) 梳毛放松一下",      reward: 15)
            ]
        }
        return base
    }

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        VStack(spacing: 10) {
                            ForEach(promises) { promise in
                                promiseRow(promise)
                            }
                        }
                        Text("勾选的承诺会自动进入「家庭悬赏榜」——任何家人都可以帮你完成并领取椰子。")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
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
            .navigationTitle("\(petEmoji) 首日承诺")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳过") { finish() }
                        .foregroundStyle(.primary.opacity(0.55))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("欢迎 \(petName) 🎉")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text("勾选几条你今晚或明天愿意完成的小承诺——它们会自动成为家庭任务，让家人一起参与。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promiseRow(_ p: Promise) -> some View {
        let isOn = selected.contains(p.id)
        return Button {
            if isOn { selected.remove(p.id) } else { selected.insert(p.id) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.goPrimary : Color.goPrimary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
                Text(p.emoji).font(.system(size: 22))
                Text(p.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack(spacing: 3) {
                    Text("+\(p.reward)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                    Text("🥥").font(.system(size: 11))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? Color.goPrimary.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isOn ? Color.goPrimary.opacity(0.35) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        Button {
            finish()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected.isEmpty ? "arrow.right.circle" : "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(selected.isEmpty ? "先跳过，以后再说" : "把 \(selected.count) 条承诺发给家人")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
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
        let creatorName = creator?.name ?? "我"
        let creatorEmoji = creator?.avatarEmoji ?? "🙂"

        for p in promises where selected.contains(p.id) {
            let task = BountyTask(
                title: p.title,
                description: "首日承诺 · 让家人一起帮 \(petName) 开启第一天",
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
