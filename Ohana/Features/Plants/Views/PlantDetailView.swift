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
    @State private var isDeletePending = false
    @State private var deleteUndoTask: Task<Void, Never>?
    @State private var diagnosisResult: PlantDiagnosisResult?
    private var catalogEntry: PlantCatalogEntry? { PlantCatalog.entry(id: plant.catalogSpeciesId) }
    private var careTasks: [PlantCareTaskSnapshot] { appServices.plantCarePlans.tasks(for: plant) }
    private var isWateringDue: Bool {
        careTasks.contains { $0.careType == .watering && $0.daysUntilDue <= 0 }
    }
    private var isFertilizingDue: Bool {
        careTasks.contains { $0.careType == .fertilizing && $0.daysUntilDue <= 0 }
    }
    var wateringIntervalDays: Int {
        careTasks.first { $0.careType == .watering }?.effectiveIntervalDays ?? plant.wateringIntervalDays
    }
    var fertilizingIntervalDays: Int {
        careTasks.first { $0.careType == .fertilizing }?.effectiveIntervalDays ?? plant.fertilizingIntervalDays
    }
    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }
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
        .safeAreaInset(edge: .bottom) {
            pendingDeleteBanner
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                stagePlantDelete()
            }
        } message: {
            Text("确定要删除 \(plant.name) 吗？确认后会先保留 6 秒，可在本页撤销。")
        }
        .onDisappear {
            deleteUndoTask?.cancel()
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
                Text(task.explanation)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
                if task.careType == .watering {
                    Button("土还湿，延后") {
                        deferTaskOneDay(task, reason: "soilWet")
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
            detailRow("房间", value: plant.roomName.isEmpty ? "未设置" : plant.roomName)
            detailRow("具体位置", value: plant.location.isEmpty ? "未设置" : plant.location)
            detailRow("场景", value: plant.isIndoor ? "室内" : "阳台/花园")
            detailRow("窗向", value: plant.windowDirection.displayName)
            detailRow("光照", value: plant.lightLevel.displayName)
            if plant.lastLightMeasurementLux > 0 {
                detailRow("光照实测", value: "\(plant.lastLightMeasurementLux) lux\(plant.lastLightMeasurementDate.map { " · \(shortDate($0))" } ?? "")")
            }
            detailRow("湿度偏好", value: plant.humidityPreference.displayName)
            detailRow("温度偏好", value: plant.temperaturePreference.displayName)
            if plant.isNearClimateSource {
                detailRow("环境风险", value: "靠近空调/暖气")
            }
            if plant.potDiameterCm > 0 {
                detailRow("盆径", value: "\(Int(plant.potDiameterCm)) cm")
            }
            detailRow("排水孔", value: plant.potHasDrainage ? "有" : "无")
            if !plant.potMaterial.isEmpty {
                detailRow("盆材质", value: plant.potMaterial)
            }
            if !plant.soilType.isEmpty {
                detailRow("土壤", value: plant.soilType)
            }
            if let acquiredDate = plant.acquiredDate {
                detailRow("购入日期", value: shortDate(acquiredDate))
            }
            if !plant.acquisitionSource.isEmpty {
                detailRow("来源", value: plant.acquisitionSource)
            }
            if plant.currentHeightCm > 0 || plant.currentSpreadCm > 0 {
                detailRow("当前尺寸", value: "\(Int(plant.currentHeightCm)) cm 高 · \(Int(plant.currentSpreadCm)) cm 冠幅")
            }
            if plant.isHydroponic || plant.isSucculent {
                detailRow("类型", value: [plant.isHydroponic ? "水培" : nil, plant.isSucculent ? "多肉/仙人掌类" : nil].compactMap(\.self).joined(separator: " · "))
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
                let progress = min(1.0, Double(days) / Double(max(wateringIntervalDays, 1)))
                let color: Color = progress < 0.5 ? .blue : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text("距上次浇水 \(days) 天")
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(wateringIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isWateringDue {
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
                let progress = min(1.0, Double(days) / Double(max(fertilizingIntervalDays, 1)))
                let color: Color = progress < 0.5 ? .green : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text("距上次施肥 \(days) 天")
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(fertilizingIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isFertilizingDue {
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
                            if !log.note.isEmpty,
                               !log.note.hasPrefix("defer:"),
                               !log.note.hasPrefix("skip:") {
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

    // MARK: - Delete Section
    @ViewBuilder
    private var pendingDeleteBanner: some View {
        if isDeletePending {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill") // a11y: allow decorative pending-delete glyph; adjacent text describes the state.
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("即将删除 \(plant.name)")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("6 秒内可撤销；到时会清理相关日历和提醒。")
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                Button("撤销") {
                    cancelPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goLime)

                Button("立即删除", role: .destructive) {
                    commitPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

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
        .disabled(isDeletePending)
        .opacity(isDeletePending ? 0.55 : 1)
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
            commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                careNote: careNote
            )
        }
    }

    private func deferTaskOneDay(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        let reasonSuffix = reason.map { "|\($0)" } ?? ""
        recordCare(.customNote, careNote: "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))\(reasonSuffix)")
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    private func stagePlantDelete() {
        guard !isDeletePending else { return }
        isDeletePending = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        deleteUndoTask?.cancel()
        deleteUndoTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                commitPendingDelete()
            }
        }
    }

    private func cancelPendingDelete() {
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func commitPendingDelete() {
        guard isDeletePending else { return }
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        deletePlant()
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
    @State private var roomNameRaw = ""
    @State private var location = ""
    @State private var avatarEmoji = ""
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var notes = ""
    @State private var potDiameterCm = 0.0
    @State private var potMaterialRaw = ""
    @State private var soilTypeRaw = ""
    @State private var isIndoor = true
    @State private var windowDirection: PlantWindowDirection = .unknown
    @State private var lightLevel: PlantLightLevel = .medium
    @State private var lastLightMeasurementLux = 0
    @State private var lastLightMeasurementDate = Date()
    @State private var recordsLightMeasurement = false
    @State private var humidityPreference: PlantHumidityPreference = .standard
    @State private var temperaturePreference: PlantTemperaturePreference = .standard
    @State private var isNearClimateSource = false
    @State private var potHasDrainage = true
    @State private var hasAcquiredDate = false
    @State private var acquiredDate = Date()
    @State private var acquisitionSourceRaw = ""
    @State private var currentHeightCm = 0.0
    @State private var currentSpreadCm = 0.0
    @State private var isHydroponic = false
    @State private var isSucculent = false
    @State private var healthStatus: PlantHealthStatus = .stable
    @State private var catalogSpeciesId = ""
    @State private var isToxicToCats = false
    @State private var isToxicToDogs = false
    @State private var isToxicToChildren = false
    @State private var isIndoorSuitable = true
    @State private var remindersEnabled = true
    @State private var isSaving = false

    var body: some View {
        OhanaSheetWrapper(title: "编辑植物", onDismiss: { dismiss() }) {
            VStack(spacing: 16) {
                profileSection
                catalogSection
                cycleSection
                environmentSection
                potSection
                sourceAndSizeSection
                healthAndSafetySection
                notesSection
                recalculationNoticeSection

                Button { save() } label: {
                    Text(isSaving ? "保存中…" : "保存").capsuleButton()
                }
                .padding(.top, 8)
                .disabled(isSaving)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            prepareState()
        }
        .onChange(of: catalogSpeciesId) { _, newValue in
            applyCatalogSelection(newValue)
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var profileSection: some View {
        VStack(spacing: 12) {
            formField("名称", text: $name)
            formField("物种名", text: $species)
            formField("房间", text: $roomNameRaw)
            formField("具体位置", text: $location)
            formField("头像 Emoji", text: $avatarEmoji)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("资料库")
            Picker("资料库物种", selection: $catalogSpeciesId) {
                Text("未链接").tag("")
                if !catalogSpeciesId.isEmpty, PlantCatalog.entry(id: catalogSpeciesId) == nil {
                    Text(catalogSpeciesId).tag(catalogSpeciesId)
                }
                ForEach(PlantCatalog.entries) { entry in
                    Text("\(entry.commonName) · \(entry.latinName)").tag(entry.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("护理计划")
            Stepper("浇水：每 \(wateringInterval) 天", value: $wateringInterval, in: 1 ... 90)
                .tint(Color.goLime)
            Stepper("施肥：每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1 ... 365)
                .tint(Color.goLime)
            Toggle("植物提醒", isOn: $remindersEnabled)
                .tint(Color.goLime)
        }
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("环境")
            Toggle("室内植物", isOn: $isIndoor)
                .tint(Color.goLime)
            Picker("窗户朝向", selection: $windowDirection) {
                ForEach(PlantWindowDirection.allCases) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            Picker("光照强度", selection: $lightLevel) {
                ForEach(PlantLightLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Toggle("记录光照实测", isOn: $recordsLightMeasurement)
                .tint(Color.goLime)
            if recordsLightMeasurement {
                Stepper("光照实测 \(lastLightMeasurementLux) lux", value: $lastLightMeasurementLux, in: 0 ... 20000, step: 250)
                    .tint(Color.goLime)
            }
            Picker("湿度偏好", selection: $humidityPreference) {
                ForEach(PlantHumidityPreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            Picker("温度偏好", selection: $temperaturePreference) {
                ForEach(PlantTemperaturePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            Toggle("靠近空调/暖气", isOn: $isNearClimateSource)
                .tint(Color.goLime)
        }
        .pickerStyle(.menu)
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var potSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("盆土")
            Stepper("盆径 \(Int(potDiameterCm)) cm", value: $potDiameterCm, in: 0 ... 80, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle("花盆有排水孔", isOn: $potHasDrainage)
                .tint(Color.goLime)
            formField("盆材质", text: $potMaterialRaw)
            formField("土壤类型", text: $soilTypeRaw)
            Toggle("水培", isOn: $isHydroponic)
                .tint(Color.goLime)
            Toggle("多肉/仙人掌类", isOn: $isSucculent)
                .tint(Color.goLime)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var healthAndSafetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("健康与安全")
            Picker("当前状态", selection: $healthStatus) {
                ForEach(PlantHealthStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            Toggle("适合室内", isOn: $isIndoorSuitable)
                .tint(Color.goLime)
            Toggle("对猫有风险", isOn: $isToxicToCats)
                .tint(Color.goLime)
            Toggle("对狗有风险", isOn: $isToxicToDogs)
                .tint(Color.goLime)
            Toggle("对儿童有风险", isOn: $isToxicToChildren)
                .tint(Color.goLime)
        }
        .pickerStyle(.menu)
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var sourceAndSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("来源与尺寸")
            Toggle("记录购入日期", isOn: $hasAcquiredDate)
                .tint(Color.goLime)
            if hasAcquiredDate {
                DatePicker("购入日期", selection: $acquiredDate, displayedComponents: .date)
                    .tint(Color.goLime)
            }
            formField("来源", text: $acquisitionSourceRaw)
            Stepper("当前高度 \(Int(currentHeightCm)) cm", value: $currentHeightCm, in: 0 ... 300, step: 1)
                .tint(Color.goLime)
            Stepper("冠幅 \(Int(currentSpreadCm)) cm", value: $currentSpreadCm, in: 0 ... 300, step: 1)
                .tint(Color.goLime)
        }
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("备注")
            TextEditor(text: $notes)
                .frame(height: 90)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    @ViewBuilder
    private var recalculationNoticeSection: some View {
        let impacts = recalculationImpacts
        if !impacts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath") // a11y: allow decorative recalculation glyph; section title names the effect.
                        .foregroundStyle(Color.goLime)
                        .accessibilityHidden(true)
                    Text("保存后会重算")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(impacts.count) 项")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.goLime, in: Capsule())
                }
                ForEach(impacts) { impact in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: impact.iconName)
                            .frame(width: 18)
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(impact.title)
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(impact.detail)
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func prepareState() {
        name = plant.name
        species = plant.species
        roomNameRaw = plant.roomNameRaw
        location = plant.location
        avatarEmoji = plant.avatarEmoji
        wateringInterval = plant.wateringIntervalDays
        fertilizingInterval = plant.fertilizingIntervalDays
        notes = plant.notes
        potDiameterCm = plant.potDiameterCm
        potMaterialRaw = plant.potMaterialRaw
        soilTypeRaw = plant.soilTypeRaw
        isIndoor = plant.isIndoor
        windowDirection = plant.windowDirection
        lightLevel = plant.lightLevel
        lastLightMeasurementLux = plant.lastLightMeasurementLux
        lastLightMeasurementDate = plant.lastLightMeasurementDate ?? Date()
        recordsLightMeasurement = plant.lastLightMeasurementLux > 0
        humidityPreference = plant.humidityPreference
        temperaturePreference = plant.temperaturePreference
        isNearClimateSource = plant.isNearClimateSource
        potHasDrainage = plant.potHasDrainage
        hasAcquiredDate = plant.acquiredDate != nil
        acquiredDate = plant.acquiredDate ?? Date()
        acquisitionSourceRaw = plant.acquisitionSourceRaw
        currentHeightCm = plant.currentHeightCm
        currentSpreadCm = plant.currentSpreadCm
        isHydroponic = plant.isHydroponic
        isSucculent = plant.isSucculent
        healthStatus = plant.healthStatus
        catalogSpeciesId = plant.catalogSpeciesId
        isToxicToCats = plant.isToxicToCats
        isToxicToDogs = plant.isToxicToDogs
        isToxicToChildren = plant.isToxicToChildren
        isIndoorSuitable = plant.isIndoorSuitable
        remindersEnabled = plant.remindersEnabled
    }

    private func applyCatalogSelection(_ id: String) {
        guard let entry = PlantCatalog.entry(id: id) else { return }
        let defaults = PlantProfileUXPolicy.catalogDefaults(for: entry)
        species = defaults.species
        lightLevel = defaults.lightLevel
        soilTypeRaw = defaults.soilTypeRaw
        wateringInterval = defaults.wateringIntervalDays
        fertilizingInterval = defaults.fertilizingIntervalDays
        isIndoor = defaults.isIndoor
        humidityPreference = defaults.humidityPreference
        temperaturePreference = defaults.temperaturePreference
        potHasDrainage = defaults.potHasDrainage
        isHydroponic = defaults.isHydroponic
        isSucculent = defaults.isSucculent
        isToxicToCats = entry.isToxicToCats
        isToxicToDogs = entry.isToxicToDogs
        isToxicToChildren = entry.isToxicToChildren
        isIndoorSuitable = entry.isIndoorSuitable
    }

    private func save() {
        guard !isSaving else { return }
        let input = makeProfileInput()
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

    private var recalculationImpacts: [PlantCarePlanRecalculationImpact] {
        PlantProfileUXPolicy.recalculationImpacts(
            old: originalRecalculationSnapshot,
            new: draftRecalculationSnapshot
        )
    }

    private var originalRecalculationSnapshot: PlantCarePlanRecalculationSnapshot {
        PlantCarePlanRecalculationSnapshot(
            roomName: plant.roomNameRaw,
            location: plant.location,
            wateringIntervalDays: plant.wateringIntervalDays,
            fertilizingIntervalDays: plant.fertilizingIntervalDays,
            potDiameterCm: plant.potDiameterCm,
            potMaterialRaw: plant.potMaterialRaw,
            soilTypeRaw: plant.soilTypeRaw,
            isIndoor: plant.isIndoor,
            windowDirection: plant.windowDirection,
            lightLevel: plant.lightLevel,
            lastLightMeasurementLux: plant.lastLightMeasurementLux,
            humidityPreference: plant.humidityPreference,
            temperaturePreference: plant.temperaturePreference,
            isNearClimateSource: plant.isNearClimateSource,
            potHasDrainage: plant.potHasDrainage,
            currentHeightCm: plant.currentHeightCm,
            currentSpreadCm: plant.currentSpreadCm,
            isHydroponic: plant.isHydroponic,
            isSucculent: plant.isSucculent,
            healthStatus: plant.healthStatus,
            catalogSpeciesId: plant.catalogSpeciesId,
            remindersEnabled: plant.remindersEnabled
        )
    }

    private var draftRecalculationSnapshot: PlantCarePlanRecalculationSnapshot {
        PlantCarePlanRecalculationSnapshot(
            roomName: roomNameRaw,
            location: location,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval,
            potDiameterCm: potDiameterCm,
            potMaterialRaw: potMaterialRaw,
            soilTypeRaw: soilTypeRaw,
            isIndoor: isIndoor,
            windowDirection: windowDirection,
            lightLevel: lightLevel,
            lastLightMeasurementLux: recordsLightMeasurement ? lastLightMeasurementLux : 0,
            humidityPreference: humidityPreference,
            temperaturePreference: temperaturePreference,
            isNearClimateSource: isNearClimateSource,
            potHasDrainage: potHasDrainage,
            currentHeightCm: currentHeightCm,
            currentSpreadCm: currentSpreadCm,
            isHydroponic: isHydroponic,
            isSucculent: isSucculent,
            healthStatus: healthStatus,
            catalogSpeciesId: catalogSpeciesId,
            remindersEnabled: remindersEnabled
        )
    }

    private func makeProfileInput() -> PlantProfileCommandInput {
        PlantProfileCommandInput(
            name: name,
            avatarImageData: plant.avatarImageData,
            avatarEmoji: avatarEmoji,
            species: species,
            location: location,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval,
            roomNameRaw: roomNameRaw,
            potDiameterCm: potDiameterCm,
            potMaterialRaw: potMaterialRaw,
            soilTypeRaw: soilTypeRaw,
            isIndoor: isIndoor,
            windowDirection: windowDirection,
            lightLevel: lightLevel,
            lastLightMeasurementLux: recordsLightMeasurement ? lastLightMeasurementLux : 0,
            lastLightMeasurementDate: recordsLightMeasurement
                ? (lastLightMeasurementLux == plant.lastLightMeasurementLux ? lastLightMeasurementDate : Date())
                : nil,
            humidityPreference: humidityPreference,
            temperaturePreference: temperaturePreference,
            isNearClimateSource: isNearClimateSource,
            potHasDrainage: potHasDrainage,
            acquiredDate: hasAcquiredDate ? acquiredDate : nil,
            acquisitionSourceRaw: acquisitionSourceRaw,
            currentHeightCm: currentHeightCm,
            currentSpreadCm: currentSpreadCm,
            isHydroponic: isHydroponic,
            isSucculent: isSucculent,
            healthStatus: healthStatus,
            catalogSpeciesId: catalogSpeciesId,
            isToxicToCats: isToxicToCats,
            isToxicToDogs: isToxicToDogs,
            isToxicToChildren: isToxicToChildren,
            isIndoorSuitable: isIndoorSuitable,
            remindersEnabled: remindersEnabled,
            themeHex: plant.themeColorHex,
            notes: notes
        )
    }
}
