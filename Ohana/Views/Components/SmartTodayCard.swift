//
//  SmartTodayCard.swift
//  Ohana
//
//  Smart Today Task Card (C5) - App 自动决定今日最重要待办
//

import SwiftUI
import SwiftData

// MARK: - Action Target
enum SmartTaskTarget {
    case pet(Pet)
    case plant(Plant)
    case reminder(Reminder)
    case none
}

// MARK: - Smart Task Model
struct SmartTask {
    let emoji: String
    let title: String
    let subtitle: String
    let urgencyLabel: String?
    let urgencyColor: Color
    let accentColor: Color
    let actionLabel: String
    let actionTarget: SmartTaskTarget
}

// MARK: - Smart Task Engine
struct SmartTaskEngine {
    static func topTask(pets: [Pet], reminders: [Reminder], plants: [Plant] = []) -> SmartTask {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)

        // 0. 里程碑提醒（最高优先级）——今日或未来3天内的 birthday/anniversary/关键词
        let upcomingMilestones = reminders.filter { r in
            guard r.isPending else { return false }
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: r.scheduledAt)).day ?? 999
            return days >= 0 && days <= 3 && isMilestone(r)
        }.sorted { $0.scheduledAt < $1.scheduledAt }

        if let milestone = upcomingMilestones.first {
            let title = milestone.event?.title ?? "里程碑纪念日"
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: milestone.scheduledAt)).day ?? 0
            let label = days == 0 ? "就是今天" : "\(days)天后"
            return SmartTask(
                emoji: "🎁",
                title: title,
                subtitle: days == 0 ? "快去准备一份特别惊喜吧 🎉" : "即将到来 · 别忘记庆祝",
                urgencyLabel: label,
                urgencyColor: .goYellow,
                accentColor: .goYellow,
                actionLabel: "查看",
                actionTarget: .reminder(milestone)
            )
        }

        // 1. 疫苗/驱虫 逾期或即将到期（最高优先级）
        for pet in pets {
            let vaccineLogs = pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }
                .sorted(by: { $0.date > $1.date })
            if let lastVaccine = vaccineLogs.first,
               let nextDue = cal.date(byAdding: .year, value: 1, to: lastVaccine.date) {
                let days = cal.dateComponents([.day], from: now, to: nextDue).day ?? 999
                if days <= 30 {
                    return SmartTask(
                        emoji: "💉",
                        title: "\(pet.name) 疫苗\(days < 0 ? "已逾期" : "即将到期")",
                        subtitle: days < 0 ? "请尽快联系兽医" : "还有 \(days) 天到期",
                        urgencyLabel: days < 0 ? "逾期" : "\(days)天",
                        urgencyColor: days < 0 ? .goRed : .goYellow,
                        accentColor: .goCardCyan,
                        actionLabel: "查看健康记录",
                        actionTarget: .pet(pet)
                    )
                }
            }
        }

        // 2. 今日日历提醒（最近一条）
        let todayReminders = reminders.filter { cal.isDateInToday($0.scheduledAt) }
        if let topReminder = todayReminders.first {
            let timeStr = topReminder.scheduledAt.formatted(.dateTime.hour().minute())
            let reminderTitle = topReminder.event?.title ?? "今日提醒"
            return SmartTask(
                emoji: "📅",
                title: reminderTitle,
                subtitle: "今日 \(timeStr)",
                urgencyLabel: "今天",
                urgencyColor: .goPrimary,
                accentColor: .goPrimary,
                actionLabel: "查看日历",
                actionTarget: .reminder(topReminder)
            )
        }

        // 3. 粮仓不足
        if let urgentPet = pets.filter({ $0.remainingFoodDays > 0 && $0.remainingFoodDays <= 5 })
            .min(by: { $0.remainingFoodDays < $1.remainingFoodDays }) {
            return SmartTask(
                emoji: "🛒",
                title: "需要给 \(urgentPet.name) 补粮",
                subtitle: "仅剩约 \(urgentPet.remainingFoodDays) 天的粮食",
                urgencyLabel: "\(urgentPet.remainingFoodDays)天",
                urgencyColor: .goRed,
                accentColor: .goOrange,
                actionLabel: "查看粮仓",
                actionTarget: .pet(urgentPet)
            )
        }

        // 3.5 植物紧急浇水（超期 >= 2 天）
        if let thirstyPlant = plants
            .filter({ ($0.daysSinceWatered ?? 0) >= $0.wateringIntervalDays + 2 })
            .max(by: { ($0.daysSinceWatered ?? 0) < ($1.daysSinceWatered ?? 0) }) {
            let overdue = (thirstyPlant.daysSinceWatered ?? 0) - thirstyPlant.wateringIntervalDays
            return SmartTask(
                emoji: "🥀",
                title: "\(thirstyPlant.name) 急需浇水",
                subtitle: "已超期 \(overdue) 天未浇水",
                urgencyLabel: "紧急",
                urgencyColor: .goRed,
                accentColor: .cyan,
                actionLabel: "去浇水",
                actionTarget: .plant(thirstyPlant)
            )
        }

        // 4. 遛狗提醒（遛狗时间：早6-9 / 晚17-19）
        if let dog = pets.first(where: { $0.species == "狗" }) {
            let todayWalked = dog.walkLogs.contains { cal.isDateInToday($0.startDate) }
            let isWalkTime = (hour >= 6 && hour < 10) || (hour >= 16 && hour < 20)
            if !todayWalked && isWalkTime {
                return SmartTask(
                    emoji: hour < 12 ? "🌅" : "🌇",
                    title: "该带 \(dog.name) 出门了",
                    subtitle: hour < 12 ? "早晨遛狗，活力满满" : "傍晚散步，黄金时刻",
                    urgencyLabel: "建议",
                    urgencyColor: .goPrimary,
                    accentColor: .goPrimary,
                    actionLabel: "开始遛狗",
                    actionTarget: .pet(dog)
                )
            }
        }

        // task32: 移除护理周期自动推断（只有真实 Reminder 才显示卡片，护理提醒需用户手动在日历设置）

        // 5. 默认：今日一切安好
        let petName = pets.first?.name ?? plants.first?.name ?? "家人们"
        return SmartTask(
            emoji: "✨",
            title: "今日一切安好",
            subtitle: "\(petName) 的所有事项都已处理",
            urgencyLabel: nil,
            urgencyColor: .goPrimary,
            accentColor: .goPrimary,
            actionLabel: "查看详情",
            actionTarget: .none
        )
    }

    // B8: 里程碑判断（Engine 内复用）
    static func isMilestone(_ reminder: Reminder) -> Bool {
        if let eventType = reminder.event?.eventTypeEnum {
            switch eventType {
            case .birthday, .anniversary: return true
            default: break
            }
        }
        let title = (reminder.event?.title ?? "").lowercased()
        let keywords = ["生日", "周年", "100天", "百日", "百天", "纪念", "相伴", "到家", "满月", "周岁"]
        return keywords.contains { title.contains($0) }
    }
}

// MARK: - Smart Today Card View
struct SmartTodayCard: View {
    let task: SmartTask
    let onAction: () -> Void
    /// 里程碑奖励完成回调（供首页触发椰子奖励等）
    var onMilestoneRewardCompleted: (() -> Void)? = nil

    private var textColor: Color {
        if task.accentColor == .goPrimary || task.accentColor == .goYellow {
            return Color.arkInk
        }
        return .white
    }

    var body: some View {
        Group {
            if case .reminder(let reminder) = task.actionTarget,
               isMilestoneReminder(reminder) {
                GoldenRewardRow(
                    reminder: reminder,
                    task: task,
                    onMilestoneRewardCompleted: onMilestoneRewardCompleted
                )
            } else {
                NormalTaskCard(task: task, textColor: textColor, onAction: onAction)
            }
        }
    }

    // MARK: - 里程碑识别（复用 Engine 逻辑）
    private func isMilestoneReminder(_ reminder: Reminder) -> Bool {
        SmartTaskEngine.isMilestone(reminder)
    }
}

// MARK: - NormalTaskCard
private struct NormalTaskCard: View {
    let task: SmartTask
    let textColor: Color
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(textColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text(task.emoji)
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(textColor)
                            .lineLimit(2)
                        if let label = task.urgencyLabel {
                            Text(label)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(textColor)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(textColor.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(task.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textColor.opacity(0.6))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

            Rectangle().fill(textColor.opacity(0.1)).frame(height: 1).padding(.horizontal, 20)

            Button(action: onAction) {
                HStack(spacing: 6) {
                    Text(task.actionLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(textColor)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 14)
            }
        }
        .background(task.accentColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - GoldenRewardRow（里程碑金色闪卡）
private struct GoldenRewardRow: View {
    let reminder: Reminder
    let task: SmartTask
    var onMilestoneRewardCompleted: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var didFeed = false
    @State private var feedScale: CGFloat = 1.0
    @State private var sparkleOpacity: CGFloat = 0.0
    @State private var showCoconutDrop = false
    private let milestoneReward = 20

    private var milestoneTitle: String {
        let t = reminder.event?.title ?? task.title
        // 展示为"相伴100天啦！"风格
        return t.isEmpty ? task.title : "\(t) 🎉"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // 左侧大礼物 Icon
                ZStack {
                    Circle()
                        .fill(Color.arkInk.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Text(didFeed ? "🍖" : "🎁")
                        .font(.system(size: 30))
                        .scaleEffect(feedScale)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: feedScale)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(milestoneTitle)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(2)
                        Text("里程碑")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.arkInk.opacity(0.12), in: Capsule())
                    }
                    Text("奖励宠物零食 🍖 庆祝这个特别时刻～")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.6))
                }
                Spacer()

                // 右侧「已投喂」胶囊按钮
                Button {
                    guard !didFeed else { return }
                    completeMilestone()
                } label: {
                    Text(didFeed ? "✓ 已投喂" : "已投喂 🍖")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(didFeed ? Color.goPrimary.opacity(0.5) : Color.goPrimary, in: Capsule())
                }
                .disabled(didFeed)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 18)

            // 底部装饰亮线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkInk.opacity(0), Color.arkInk.opacity(0.12), Color.arkInk.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        // 金色发光底板
        .background(Color.goYellow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.goYellow.opacity(sparkleOpacity), radius: 14, x: 0, y: 0)
        .shadow(color: Color.goYellow.opacity(sparkleOpacity * 0.5), radius: 28, x: 0, y: 4)
        .coconutRewardOverlay(trigger: $showCoconutDrop, amount: milestoneReward)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                sparkleOpacity = 0.65
            }
        }
    }

    private func completeMilestone() {
        let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        ReminderCompletionService.complete(reminder, by: activeHumanId, context: modelContext)

        // 2. 强触觉反馈 × 2（多巴胺闭环）
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            gen.impactOccurred()
        }

        // 3. 按钮动画
        withAnimation { didFeed = true }
        feedScale = 1.4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            feedScale = 1.0
        }

        // 4. 全屏椰子爆出动效 + 写入余额 + 回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            QuestManager.shared.addCoconuts(milestoneReward)
            showCoconutDrop = true
            onMilestoneRewardCompleted?()
        }
    }
}
