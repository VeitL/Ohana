//
//  BackdateCheckInSheet.swift
//  Ohana
//
//  TASK D — 补打卡券使用界面
//  选择宠物 + 打卡类型 + 目标日期，发放椰子并写入历史
//

import SwiftData
import SwiftUI

struct BackdateCheckInContentSheet: View {
    let pets: [Pet]
    let backdateDays: Int // 可补几天内

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @State private var selectedPet: Pet? = nil
    @State private var selectedDaysAgo: Int = 1
    @State private var selectedAction: CheckInActionType = .feed
    @State private var isDone = false
    @State private var earnedCoconuts = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    enum CheckInActionType: String, CaseIterable {
        case feed = "喂食 🍗"
        case water = "喂水 💧"
        case potty = "便便 💩"
        case walk = "散步 🦮"

        var commandKey: String {
            switch self {
            case .feed: "feed"
            case .water: "water"
            case .potty: "potty"
            case .walk: "walk"
            }
        }

        var emoji: String { String(rawValue.suffix(2)) }
    }

    private var availableDates: [Date] {
        (1 ... max(1, backdateDays)).map { days in
            Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }
    }

    private var livePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()

                if isDone {
                    doneView
                } else {
                    formView
                }
            }
            .navigationTitle("使用补打卡券 📅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - 表单
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                infoCard

                // 选择宠物
                sectionTitle("选择宠物")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(livePets) { pet in
                            petChip(pet)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // 选择打卡类型
                sectionTitle("打卡类型")
                    .padding(.horizontal, 24)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(CheckInActionType.allCases, id: \.self) { action in
                        actionChip(action)
                    }
                }
                .padding(.horizontal, 24)

                // 选择日期
                sectionTitle("补录日期")
                    .padding(.horizontal, 24)
                HStack(spacing: 10) {
                    ForEach(0 ..< availableDates.count, id: \.self) { i in
                        let days = i + 1
                        let date = availableDates[i]
                        Button {
                            selectedDaysAgo = days
                        } label: {
                            VStack(spacing: 4) {
                                Text(days == 1 ? "昨天" : "\(days)天前")
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                Text(date, format: .dateTime.month().day())
                                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                            }
                            .foregroundStyle(selectedDaysAgo == days ? Color.arkInk : Color.ohanaSecondaryText)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(
                                selectedDaysAgo == days ? Color.goPrimary : Color.ohanaControlFill,
                                in: Capsule()
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)

                // 确认按钮
                Button { submitBackdate() } label: {
                    HStack(spacing: 8) {
                        Text("📅")
                        Text("确认补打卡")
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(selectedPet != nil ? Color.arkInk : Color.ohanaTertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedPet != nil ? Color.goPrimary : Color.ohanaControlFill,
                        in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedPet == nil)
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - 成功界面
    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("✅")
                .font(OhanaFont.adaptive(size: 72))
            Text("补打卡成功！")
                .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            if earnedCoconuts > 0 {
                HStack(spacing: 6) {
                    Text("🥥 +\(earnedCoconuts)")
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.goYellow.opacity(0.15), in: Capsule())
            } else {
                Text("奖励已发放（或今日已超出冷却限制）")
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("关闭") { dismiss() }
                .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 子组件
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            .padding(.horizontal, 24)
    }

    private var infoCard: some View {
        HStack(spacing: 12) {
            Text("📅")
                .font(OhanaFont.adaptive(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text("补打卡券")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("可补录 \(backdateDays) 天内任意一次打卡，正常发放椰子奖励")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Color.goPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
            .strokeBorder(Color.goPrimary.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func petChip(_ pet: Pet) -> some View {
        Button { selectedPet = pet } label: {
            HStack(spacing: 6) {
                Text(pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 18))
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedPet?.id == pet.id ? Color.arkInk : Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                selectedPet?.id == pet.id ? Color.goPrimary : Color.ohanaControlFill,
                in: Capsule()
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func actionChip(_ action: CheckInActionType) -> some View {
        Button { selectedAction = action } label: {
            Text(action.rawValue)
                .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedAction == action ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedAction == action ? Color.goPrimary : Color.ohanaControlFill,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 提交
    private func submitBackdate() {
        guard let pet = selectedPet else { return }
        let action = selectedAction
        commandQueue.enqueue(.backdateCheckIn(petID: pet.id, action: action.commandKey)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).awardBackdateCheckIn(
                actionKey: action.commandKey,
                pet: pet,
                note: "backdateCheckIn.award"
            )
            earnedCoconuts = result.totalCoconuts
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(GoMotion.feedback) {
                isDone = true
            }
        }
    }
}
