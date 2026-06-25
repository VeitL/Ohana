//
//  PlantDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct PlantDetailContentView: View {
    let plant: Plant
    let households: [Household]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage("ohana_onboarding_has_pets") private var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") private var onboardingHasChildren = false

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var diagnosisResult: PlantDiagnosisResult?
    private var catalogEntry: PlantCatalogEntry? { PlantCatalog.entry(id: plant.catalogSpeciesId) }
    private var careTasks: [PlantCareTaskSnapshot] { PlantCarePlanService.tasks(for: plant) }
    private var recentLogs: [PlantCareLog] {
        plant.careLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard
                    nextTaskCard
                    environmentCard
                    safetyCard
                    catalogCard
                    diagnosisCard
                    wateringCard
                    fertilizingCard
                    quickActions
                    historyCard
                    notesCard
                    deleteSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditSheet = true } label: {
                    Image(systemName: "pencil.circle").accessibilityHidden(true)
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlantSheet(plant: plant)
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deletePlant()
            }
        } message: {
            Text("确定要删除 \(plant.name) 吗？")
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .task(id: plant.healthStatusRaw) {
            diagnosisResult = await LocalPlantIntelligenceFallback().diagnosePlant(
                imageData: nil,
                symptoms: diagnosisSymptoms
            )
        }
    }

    private var nextTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles") // a11y: allow decorative section glyph; heading names the next task.
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text("下一步")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            if let task = careTasks.first {
                Text(task.title)
                    .font(OhanaFont.adaptive(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                HStack(spacing: 10) {
                    Button("完成") {
                        recordCare(task.careType)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.goLime, in: Capsule())

                    Button("延后一天") {
                        deferTaskOneDay(task)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
            } else {
                Text("暂无任务")
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "sun.max.fill", title: "环境")
            detailRow("位置", value: plant.location.isEmpty ? "未设置" : plant.location)
            detailRow("场景", value: plant.isIndoor ? "室内" : "阳台/花园")
            detailRow("窗向", value: plant.windowDirection.displayName)
            detailRow("光照", value: plant.lightLevel.displayName)
            if plant.potDiameterCm > 0 {
                detailRow("盆径", value: "\(Int(plant.potDiameterCm)) cm")
            }
            if !plant.potMaterial.isEmpty {
                detailRow("盆材质", value: plant.potMaterial)
            }
            if !plant.soilType.isEmpty {
                detailRow("土壤", value: plant.soilType)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var safetyCard: some View {
        if plant.isToxicToCats || plant.isToxicToDogs || plant.isToxicToChildren || !plant.isIndoorSuitable {
            VStack(alignment: .leading, spacing: 10) {
                detailHeader(icon: "exclamationmark.triangle.fill", title: "安全提示")
                if onboardingHasPets, plant.isToxicToCats || plant.isToxicToDogs {
                    Text("对猫/狗有误食风险，请放在宠物够不到的位置。")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if onboardingHasChildren, plant.isToxicToChildren {
                    Text("对儿童有误食刺激风险，提醒文案会优先提示安全摆放。")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if (!onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
                    (!onboardingHasChildren && plant.isToxicToChildren) {
                    Text("资料库标记存在误食风险；若家里之后有宠物或儿童，可以在设置/详情中优先关注摆放安全。")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if !plant.isIndoorSuitable {
                    Text("资料库标记为不太适合室内长期养护。")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var catalogCard: some View {
        if let catalogEntry {
            VStack(alignment: .leading, spacing: 12) {
                detailHeader(icon: "books.vertical.fill", title: "资料库")
                detailRow("拉丁名", value: catalogEntry.latinName)
                detailRow("浇水", value: catalogEntry.wateringPreference)
                detailRow("湿度", value: catalogEntry.humidity)
                detailRow("温度", value: catalogEntry.temperature)
                detailRow("常见问题", value: catalogEntry.commonIssues)
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "stethoscope", title: "病虫害诊断")
            Text(diagnosisResult?.uncertaintyMessage ?? "当前未连接智能诊断服务，Ohana 会展示不确定性和可执行复查步骤。")
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach((diagnosisResult?.causes ?? []).prefix(3)) { cause in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cause.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(cause.severity)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.goYellow, in: Capsule())
                    }
                    Text(cause.steps.prefix(2).joined(separator: " · "))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(3)
                    Text(cause.shouldIsolate ? "建议先隔离，\(cause.recheckAfterDays) 天后复查" : "\(cause.recheckAfterDays) 天后复查")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(cause.shouldIsolate ? Color.goRed : Color.ohanaSecondaryText)
                }
                .padding(10)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    private var diagnosisSymptoms: [String] {
        switch plant.healthStatus {
        case .thriving, .stable:
            ["黄叶"]
        case .watching:
            ["黄叶", "停止生长"]
        case .stressed:
            ["黄叶", "叶片卷曲", "掉叶"]
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkMint.opacity(0.6), Color(hex: "27AE60")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Text(plant.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 52))
            }

            VStack(spacing: 8) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)

                HStack(spacing: 8) {
                    if !plant.species.isEmpty {
                        Text(plant.species)
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    if !plant.location.isEmpty {
                        Text("📍 \(plant.location)")
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.sheetCompact)
        .padding(.horizontal, 16)
    }

    // MARK: - Watering Card
    private var wateringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                    .foregroundStyle(.blue)
                Text("浇水状态")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceWatered {
                let progress = min(1.0, Double(days) / Double(plant.wateringIntervalDays))
                let color: Color = progress < 0.5 ? .blue : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text("距上次浇水 \(days) 天")
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text("周期 \(plant.wateringIntervalDays) 天")
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if plant.needsWatering {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(.orange)
                            .font(OhanaFont.adaptive(size: 12))
                        Text("该浇水了！")
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("还没有浇水记录")
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Fertilizing Card
    private var fertilizingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill").accessibilityHidden(true)
                    .foregroundStyle(.green)
                Text("施肥状态")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceFertilized {
                let progress = min(1.0, Double(days) / Double(plant.fertilizingIntervalDays))
                let color: Color = progress < 0.5 ? .green : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text("距上次施肥 \(days) 天")
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text("周期 \(plant.fertilizingIntervalDays) 天")
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if plant.needsFertilizing {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(.orange)
                            .font(OhanaFont.adaptive(size: 12))
                        Text("该施肥了！")
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("还没有施肥记录")
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button {
                waterPlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill").accessibilityHidden(true)
                    Text("浇水")
                }
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.6), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
                }
            }

            Button {
                fertilizePlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill").accessibilityHidden(true)
                    Text("施肥")
                }
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green.opacity(0.6), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
                }
            }

            careActionButton(type: .pestCheck, icon: "ladybug.fill", color: Color.goYellow)
            careActionButton(type: .leafCleaning, icon: "sparkles", color: Color.goTeal)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        Group {
            if !plant.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text").accessibilityHidden(true)
                            .foregroundStyle(.purple)
                        Text("备注")
                            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Text(plant.notes)
                        .font(OhanaFont.adaptive(size: 14))
                }
                .padding(16)
                .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
                .padding(.horizontal, 16)
            }
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "clock.arrow.circlepath", title: "护理历史")
            if recentLogs.isEmpty {
                Text("还没有护理日志")
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                ForEach(recentLogs.prefix(6)) { log in
                    HStack(spacing: 10) {
                        Text(log.careType.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.careType.displayName)
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            if !log.note.isEmpty, !log.note.hasPrefix("defer:") {
                                Text(log.note)
                                    .font(OhanaFont.adaptive(size: 12))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    private func detailHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.goLime)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
            Spacer()
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 16)
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Delete Section
    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash").accessibilityHidden(true)
                Text("删除植物")
            }
            .font(OhanaFont.adaptive(size: 14, weight: .semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions
    private func waterPlant() {
        recordCare(.watering)
    }

    private func fertilizePlant() {
        recordCare(.fertilizing)
    }

    private func careActionButton(type: PlantCareType, icon: String, color: Color) -> some View {
        Button {
            recordCare(type)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).accessibilityHidden(true)
                Text(type.displayName)
            }
            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.45), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private func recordCare(_ type: PlantCareType, careNote: String = "") {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            PlantCareCommandService.recordCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                context: modelContext,
                careNote: careNote
            )
        }
    }

    private func deferTaskOneDay(_ task: PlantCareTaskSnapshot) {
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        recordCare(.customNote, careNote: "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))")
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    private func deletePlant() {
        let command = DomainCommand.memberDeletion(entityID: plant.id, kind: EntityKind.plant.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                plant,
                note: "plant.detail.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}

// MARK: - Edit Plant Sheet
struct EditPlantSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var avatarEmoji = ""
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        OhanaSheetWrapper(title: "编辑植物", onDismiss: { dismiss() }) {
            VStack(spacing: 20) {
                formField("名称", text: $name)
                formField("品种", text: $species)
                formField("位置", text: $location)
                formField("头像 Emoji", text: $avatarEmoji)

                VStack(alignment: .leading, spacing: 8) {
                    Text("浇水周期")
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1 ... 90)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("施肥周期")
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1 ... 365)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.chip))
                }

                Button { save() } label: {
                    Text(isSaving ? "保存中…" : "保存").capsuleButton()
                }
                .padding(.top, 8)
                .disabled(isSaving)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            name = plant.name
            species = plant.species
            location = plant.location
            avatarEmoji = plant.avatarEmoji
            wateringInterval = plant.wateringIntervalDays
            fertilizingInterval = plant.fertilizingIntervalDays
            notes = plant.notes
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .medium))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        guard !isSaving else { return }
        let input = PlantProfileCommandInput(
            name: name,
            avatarImageData: plant.avatarImageData,
            avatarEmoji: avatarEmoji,
            species: species,
            location: location,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval,
            potDiameterCm: plant.potDiameterCm,
            potMaterialRaw: plant.potMaterialRaw,
            soilTypeRaw: plant.soilTypeRaw,
            isIndoor: plant.isIndoor,
            windowDirection: plant.windowDirection,
            lightLevel: plant.lightLevel,
            healthStatus: plant.healthStatus,
            catalogSpeciesId: plant.catalogSpeciesId,
            isToxicToCats: plant.isToxicToCats,
            isToxicToDogs: plant.isToxicToDogs,
            isToxicToChildren: plant.isToxicToChildren,
            isIndoorSuitable: plant.isIndoorSuitable,
            remindersEnabled: plant.remindersEnabled,
            themeHex: plant.themeColorHex,
            notes: notes
        )
        let command = DomainCommand.memberProfile(entityID: plant.id, kind: EntityKind.plant.rawValue)

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            MemberCommandExecutor(context: modelContext, services: appServices).updatePlantProfile(
                plant,
                input: input,
                note: "plant.detail.profile"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}
