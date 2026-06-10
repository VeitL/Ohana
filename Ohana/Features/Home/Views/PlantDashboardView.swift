//
//  PlantDashboardView.swift
//  Ohana
//
//  植物 Tab 主面板：展示植物卡片网格 + 快捷浇水/施肥 + 空态引导
//

import SwiftUI
import SwiftData

struct PlantDashboardView: View {
    let plants: [Plant]
    let onOpenPlant: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingAddPlant = false

    init(
        plants: [Plant] = [],
        onOpenPlant: @escaping (UUID) -> Void = { _ in }
    ) {
        self.plants = plants
        self.onOpenPlant = onOpenPlant
    }

    private var l: L10n { L10n(appLanguage) }
    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }

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
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Text("🌱")
                .font(OhanaFont.adaptive(size: 72)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup

            Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)

            Text(l.tr(
                zh: "添加你的第一棵植物，开始记录浇水和施肥",
                en: "Add your first plant and start tracking watering and fertilizing",
                de: "Füge deine erste Pflanze hinzu und tracke Gießen und Düngen"
            ))
                .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddPlant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    // MARK: - Urgent Section

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(.cyan)
                Text(l.tr(zh: "需要浇水", en: "Needs watering", de: "Braucht Wasser"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    waterAll()
                } label: {
                    Text(l.tr(zh: "全部浇水", en: "Water all", de: "Alle gießen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func urgentPlantChip(_ plant: Plant) -> some View {
        HStack(spacing: 8) {
            Text(plant.avatarEmoji)
                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if let days = plant.daysSinceWatered {
                    Text(l.tr(
                        zh: "\(days)天未浇水",
                        en: "\(days)d overdue",
                        de: "\(days) T. überfällig"
                    ))
                        .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(.cyan, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    // MARK: - Plant Grid

    private var plantGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "我的植物", en: "My plants", de: "Meine Pflanzen"))
                    .font(OhanaFont.adaptive(size: 17, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(plants.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
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
            onOpenPlant(plant.id)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(plant.needsWatering ? Color.cyan.opacity(0.2) : .primary.opacity(0.08))
                        .frame(width: 56, height: 56)
                    Text(plant.avatarEmoji)
                        .font(OhanaFont.adaptive(size: 30)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }

                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)

                Text(plant.species)
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)

                statusBadge(for: plant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func statusBadge(for plant: Plant) -> some View {
        if plant.needsWatering {
            HStack(spacing: 3) {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 8, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "需浇水", en: "Water", de: "Gießen"))
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.cyan, in: Capsule())
        } else if plant.needsFertilizing {
            HStack(spacing: 3) {
                Image(systemName: "leaf.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 8, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "需施肥", en: "Fertilize", de: "Düngen"))
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.orange, in: Capsule())
        } else if let days = plant.daysSinceWatered {
            Text(l.tr(zh: "\(days)天前浇水", en: "\(days)d ago", de: "vor \(days) T."))
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        } else {
            Text(l.tr(zh: "新植物", en: "New", de: "Neu"))
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
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
                    Image(systemName: "plus") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 22, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Text(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)

                Text(" ")
                    .font(OhanaFont.adaptive(size: 10)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup

                Text(" ")
                    .font(OhanaFont.adaptive(size: 9)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ohanaCardSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Actions

    private func waterPlant(_ plant: Plant) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
            commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
        }
    }

    private func waterAll() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for plantID in plantsNeedingWater.map(\.id) {
            commandQueue.enqueue(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
                commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
            }
        }
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }
}
