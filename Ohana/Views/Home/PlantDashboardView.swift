//
//  PlantDashboardView.swift
//  Ohana
//
//  植物 Tab 主面板：展示植物卡片网格 + 快捷浇水/施肥 + 空态引导
//

import SwiftUI
import SwiftData

struct PlantDashboardView: View {
    @Binding var selectedPlant: Plant?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var showingAddPlant = false

    private var l: L10n { L10n(appLanguage) }

    private var plantsNeedingWater: [Plant] {
        plants.filter { $0.needsWatering }
    }

    private var plantsNeedingFertilizer: [Plant] {
        plants.filter { $0.needsFertilizing }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Spacer().frame(height: 70)

            if plants.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    if !plantsNeedingWater.isEmpty {
                        urgentSection
                    }

                    plantGrid

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView { }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Text("🌱")
                .font(.system(size: 72))

            Text(appLanguage == "zh" ? "还没有植物" : "No Plants Yet")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text(appLanguage == "zh" ? "添加你的第一棵植物，开始记录浇水和施肥" : "Add your first plant and start tracking watering & fertilizing")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddPlant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(appLanguage == "zh" ? "添加植物" : "Add Plant")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Urgent Section

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(appLanguage == "zh" ? "需要浇水" : "Needs Watering")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    waterAll()
                } label: {
                    Text(appLanguage == "zh" ? "全部浇水" : "Water All")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plantsNeedingWater) { plant in
                        urgentPlantChip(plant)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func urgentPlantChip(_ plant: Plant) -> some View {
        HStack(spacing: 8) {
            Text(plant.avatarEmoji)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let days = plant.daysSinceWatered {
                    Text(appLanguage == "zh" ? "\(days)天未浇水" : "\(days)d overdue")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.cyan, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Plant Grid

    private var plantGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appLanguage == "zh" ? "我的植物" : "My Plants")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(plants.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(plants) { plant in
                    plantCard(plant)
                }

                addPlantButton
            }
        }
    }

    private func plantCard(_ plant: Plant) -> some View {
        Button {
            selectedPlant = plant
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(plant.needsWatering ? Color.cyan.opacity(0.2) : .primary.opacity(0.08))
                        .frame(width: 56, height: 56)
                    Text(plant.avatarEmoji)
                        .font(.system(size: 30))
                }

                Text(plant.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(plant.species)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                statusBadge(for: plant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for plant: Plant) -> some View {
        if plant.needsWatering {
            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(appLanguage == "zh" ? "需浇水" : "Water")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.cyan, in: Capsule())
        } else if plant.needsFertilizing {
            HStack(spacing: 3) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(appLanguage == "zh" ? "需施肥" : "Fertilize")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.orange, in: Capsule())
        } else if let days = plant.daysSinceWatered {
            Text(appLanguage == "zh" ? "\(days)天前浇水" : "\(days)d ago")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        } else {
            Text(appLanguage == "zh" ? "新植物" : "New")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var addPlantButton: some View {
        Button {
            showingAddPlant = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(appLanguage == "zh" ? "添加" : "Add")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(" ")
                    .font(.system(size: 10))

                Text(" ")
                    .font(.system(size: 9))
                    .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func waterPlant(_ plant: Plant) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        plant.lastWateredDate = Date()
        let log = PlantCareLog(date: Date(), careType: .watering)
        log.plant = plant
        modelContext.insert(log)
        let event = Event(
            title: "💧 给 \(plant.name) 浇水",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
    }

    private func waterAll() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for plant in plantsNeedingWater {
            plant.lastWateredDate = Date()
            let log = PlantCareLog(date: Date(), careType: .watering)
            log.plant = plant
            modelContext.insert(log)
            let event = Event(
                title: "💧 给 \(plant.name) 浇水",
                startDate: Date(),
                isAllDay: false,
                eventType: EventType.watering.rawValue,
                relatedEntityType: EntityKind.plant.rawValue,
                relatedEntityId: plant.id.uuidString
            )
            modelContext.insert(event)
        }
        modelContext.safeSave()
    }
}
