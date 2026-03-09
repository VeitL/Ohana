//
//  BackdateCheckInSheet.swift
//  Ohana
//
//  TASK D — 补打卡券使用界面
//  选择宠物 + 打卡类型 + 目标日期，发放椰子并写入历史
//

import SwiftUI
import SwiftData

struct BackdateCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]

    let backdateDays: Int   // 可补几天内

    @State private var selectedPet: Pet? = nil
    @State private var selectedDaysAgo: Int = 1
    @State private var selectedAction: CheckInActionType = .feed
    @State private var isDone = false
    @State private var earnedCoconuts = 0

    enum CheckInActionType: String, CaseIterable {
        case feed  = "喂食 🍗"
        case water = "喂水 💧"
        case potty = "便便 💩"
        case walk  = "散步 🦮"

        var questType: QuestManager.OhanaActionType {
            switch self {
            case .feed:  return .feed
            case .water: return .water
            case .potty: return .potty(isLitter: false)
            case .walk:  return .walk(distanceMeters: 300)
            }
        }
        var emoji: String { String(rawValue.suffix(2)) }
    }

    private var availableDates: [Date] {
        (1...max(1, backdateDays)).map { days in
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.goLime)
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
                    ForEach(0..<availableDates.count, id: \.self) { i in
                        let days = i + 1
                        let date = availableDates[i]
                        Button {
                            selectedDaysAgo = days
                        } label: {
                            VStack(spacing: 4) {
                                Text(days == 1 ? "昨天" : "\(days)天前")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Text(date, format: .dateTime.month().day())
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .foregroundStyle(selectedDaysAgo == days ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(
                                selectedDaysAgo == days ? Color.goLime : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                // 确认按钮
                Button { submitBackdate() } label: {
                    HStack(spacing: 8) {
                        Text("📅")
                        Text("确认补打卡")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(selectedPet != nil ? .black : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedPet != nil ? Color.goLime : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
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
                .font(.system(size: 72))
            Text("补打卡成功！")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if earnedCoconuts > 0 {
                HStack(spacing: 6) {
                    Text("🥥 +\(earnedCoconuts)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.goYellow.opacity(0.15), in: Capsule())
            } else {
                Text("奖励已发放（或今日已超出冷却限制）")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("关闭") { dismiss() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.goLime, in: Capsule())
                .buttonStyle(.plain)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 子组件
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 24)
    }

    private var infoCard: some View {
        HStack(spacing: 12) {
            Text("📅")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text("补打卡券")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("可补录 \(backdateDays) 天内任意一次打卡，正常发放椰子奖励")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Color.goLime.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.goLime.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func petChip(_ pet: Pet) -> some View {
        Button { selectedPet = pet } label: {
            HStack(spacing: 6) {
                Text(pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji)
                    .font(.system(size: 18))
                Text(pet.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedPet?.id == pet.id ? .black : .white.opacity(0.8))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                selectedPet?.id == pet.id ? Color.goLime : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func actionChip(_ action: CheckInActionType) -> some View {
        Button { selectedAction = action } label: {
            Text(action.rawValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedAction == action ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedAction == action ? Color.goLime : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 提交
    private func submitBackdate() {
        guard let pet = selectedPet else { return }
        let result = QuestManager.shared.awardAction(
            type: selectedAction.questType,
            pet: pet,
            context: modelContext
        )
        earnedCoconuts = result.humanGot + result.petGot
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isDone = true
        }
    }
}
