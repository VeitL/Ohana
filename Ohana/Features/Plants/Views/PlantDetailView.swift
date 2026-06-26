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
    @AppStorage("appLanguage") private var appLanguage = "zh"
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
    private var l: L10n { L10n(appLanguage) }
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
        .alert(l.tr(zh: "确认删除", en: "Confirm deletion", de: "Löschen bestätigen"), isPresented: $showingDeleteConfirm) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                stagePlantDelete()
            }
        } message: {
            Text(l.tr(
                zh: "确定要删除 \(plant.name) 吗？确认后会先保留 6 秒，可在本页撤销。",
                en: "Delete \(plant.name)? After confirming, Ohana keeps it for 6 seconds so you can undo here.",
                de: "\(plant.name) löschen? Nach der Bestätigung bleibt es 6 Sekunden lang hier widerrufbar."
            ))
        }
        .onDisappear {
            deleteUndoTask?.cancel()
            commandQueue.cancelAll()
        }
        .task(id: plant.healthStatusRaw) {
            diagnosisResult = await appServices.plantIntelligence.diagnosePlant(
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
                Text(l.tr(zh: "下一步", en: "Next step", de: "Nächster Schritt"))
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
                    Button(l.tr(zh: "完成", en: "Done", de: "Erledigt")) {
                        recordCare(task.careType)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.goLime, in: Capsule())

                    Button(l.tr(zh: "延后一天", en: "Defer one day", de: "Um einen Tag verschieben")) {
                        deferTaskOneDay(task)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                if task.careType == .watering {
                    Button(l.tr(zh: "土还湿，延后", en: "Soil still wet, defer", de: "Erde noch feucht, verschieben")) {
                        deferTaskOneDay(task, reason: "soilWet")
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
            } else {
                Text(l.tr(zh: "暂无任务", en: "No tasks yet", de: "Noch keine Aufgaben"))
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
            detailHeader(icon: "sun.max.fill", title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"))
            detailRow(l.tr(zh: "房间", en: "Room", de: "Raum"), value: plant.roomName.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.roomName)
            detailRow(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), value: plant.location.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.location)
            detailRow(l.tr(zh: "场景", en: "Scene", de: "Standortart"), value: plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "阳台/花园", en: "Balcony/garden", de: "Balkon/Garten"))
            detailRow(l.tr(zh: "窗向", en: "Window", de: "Fenster"), value: plant.windowDirection.displayName)
            detailRow(l.tr(zh: "光照", en: "Light", de: "Licht"), value: plant.lightLevel.displayName)
            if plant.lastLightMeasurementLux > 0 {
                detailRow(l.tr(zh: "光照实测", en: "Light reading", de: "Lichtmessung"), value: "\(plant.lastLightMeasurementLux) lux\(plant.lastLightMeasurementDate.map { " · \(shortDate($0))" } ?? "")")
            }
            detailRow(l.tr(zh: "湿度偏好", en: "Humidity preference", de: "Luftfeuchte"), value: plant.humidityPreference.displayName)
            detailRow(l.tr(zh: "温度偏好", en: "Temperature preference", de: "Temperatur"), value: plant.temperaturePreference.displayName)
            if plant.isNearClimateSource {
                detailRow(l.tr(zh: "环境风险", en: "Environment risk", de: "Umgebungsrisiko"), value: l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"))
            }
            if plant.potDiameterCm > 0 {
                detailRow(l.tr(zh: "盆径", en: "Pot diameter", de: "Topfdurchmesser"), value: "\(Int(plant.potDiameterCm)) cm")
            }
            detailRow(l.tr(zh: "排水孔", en: "Drainage hole", de: "Abzugsloch"), value: plant.potHasDrainage ? l.tr(zh: "有", en: "Yes", de: "Ja") : l.tr(zh: "无", en: "No", de: "Nein"))
            if !plant.potMaterial.isEmpty {
                detailRow(l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), value: plant.potMaterial)
            }
            if !plant.soilType.isEmpty {
                detailRow(l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: plant.soilType)
            }
            if let acquiredDate = plant.acquiredDate {
                detailRow(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), value: shortDate(acquiredDate))
            }
            if !plant.acquisitionSource.isEmpty {
                detailRow(l.tr(zh: "来源", en: "Source", de: "Quelle"), value: plant.acquisitionSource)
            }
            if plant.currentHeightCm > 0 || plant.currentSpreadCm > 0 {
                detailRow(
                    l.tr(zh: "当前尺寸", en: "Current size", de: "Aktuelle Größe"),
                    value: l.tr(
                        zh: "\(Int(plant.currentHeightCm)) cm 高 · \(Int(plant.currentSpreadCm)) cm 冠幅",
                        en: "\(Int(plant.currentHeightCm)) cm tall · \(Int(plant.currentSpreadCm)) cm spread",
                        de: "\(Int(plant.currentHeightCm)) cm hoch · \(Int(plant.currentSpreadCm)) cm breit"
                    )
                )
            }
            if plant.isHydroponic || plant.isSucculent {
                detailRow(l.tr(zh: "类型", en: "Type", de: "Typ"), value: [
                    plant.isHydroponic ? l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur") : nil,
                    plant.isSucculent ? l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus") : nil
                ].compactMap(\.self).joined(separator: " · "))
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
                detailHeader(icon: "exclamationmark.triangle.fill", title: l.tr(zh: "安全提示", en: "Safety note", de: "Sicherheitshinweis"))
                if onboardingHasPets, plant.isToxicToCats || plant.isToxicToDogs {
                    Text(l.tr(
                        zh: "对猫/狗有误食风险，请放在宠物够不到的位置。",
                        en: "May be risky if cats or dogs chew it. Keep it out of pets' reach.",
                        de: "Kann bei Katzen oder Hunden beim Anknabbern riskant sein. Außer Reichweite von Haustieren stellen."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if onboardingHasChildren, plant.isToxicToChildren {
                    Text(l.tr(
                        zh: "对儿童有误食刺激风险，提醒文案会优先提示安全摆放。",
                        en: "May irritate children if eaten. Reminders will prioritize safe placement.",
                        de: "Kann Kinder beim Verschlucken reizen. Erinnerungen betonen eine sichere Platzierung."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if (!onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
                    (!onboardingHasChildren && plant.isToxicToChildren) {
                    Text(l.tr(
                        zh: "资料库标记存在误食风险；若家里之后有宠物或儿童，可以在设置/详情中优先关注摆放安全。",
                        en: "The catalog marks an ingestion risk. If pets or children join later, prioritize safe placement in Settings or details.",
                        de: "Der Katalog markiert ein Verschluckrisiko. Wenn später Haustiere oder Kinder dazukommen, sichere Platzierung in Einstellungen oder Details priorisieren."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if !plant.isIndoorSuitable {
                    Text(l.tr(
                        zh: "资料库标记为不太适合室内长期养护。",
                        en: "The catalog marks this as less suitable for long-term indoor care.",
                        de: "Der Katalog markiert sie als weniger geeignet für langfristige Innenpflege."
                    ))
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
                detailHeader(icon: "books.vertical.fill", title: l.tr(zh: "资料库", en: "Catalog", de: "Katalog"))
                detailRow(l.tr(zh: "拉丁名", en: "Latin name", de: "Lateinischer Name"), value: catalogEntry.latinName)
                detailRow(l.tr(zh: "浇水", en: "Watering", de: "Gießen"), value: catalogEntry.localizedWateringPreference)
                detailRow(l.tr(zh: "湿度", en: "Humidity", de: "Luftfeuchte"), value: catalogEntry.localizedHumidity)
                detailRow(l.tr(zh: "温度", en: "Temperature", de: "Temperatur"), value: catalogEntry.localizedTemperature)
                detailRow(l.tr(zh: "常见问题", en: "Common issues", de: "Häufige Probleme"), value: catalogEntry.localizedCommonIssues)
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "stethoscope", title: l.tr(zh: "病虫害诊断", en: "Pest and disease check", de: "Schädlings- und Krankheitscheck"))
            Text(diagnosisResult?.uncertaintyMessage ?? l.tr(
                zh: "当前未连接智能诊断服务，Ohana 会展示不确定性和可执行复查步骤。",
                en: "Smart diagnosis is not connected yet. Ohana shows uncertainty and actionable recheck steps.",
                de: "Die intelligente Diagnose ist noch nicht verbunden. Ohana zeigt Unsicherheit und konkrete Schritte zur Kontrolle."
            ))
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
                    Text(cause.shouldIsolate
                        ? l.tr(zh: "建议先隔离，\(cause.recheckAfterDays) 天后复查", en: "Isolate first; recheck in \(cause.recheckAfterDays) days", de: "Zuerst isolieren; in \(cause.recheckAfterDays) Tagen prüfen")
                        : l.tr(zh: "\(cause.recheckAfterDays) 天后复查", en: "Recheck in \(cause.recheckAfterDays) days", de: "In \(cause.recheckAfterDays) Tagen prüfen"))
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
                Text(l.tr(zh: "浇水状态", en: "Watering status", de: "Gießstatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceWatered {
                let progress = min(1.0, Double(days) / Double(max(wateringIntervalDays, 1)))
                let color: Color = progress < 0.5 ? .blue : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text(l.tr(zh: "距上次浇水 \(days) 天", en: "\(days) days since watering", de: "\(days) Tage seit dem Gießen"))
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
                        Text(l.tr(zh: "该浇水了！", en: "Time to water!", de: "Zeit zum Gießen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有浇水记录", en: "No watering records yet", de: "Noch keine Gießprotokolle"))
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
                Text(l.tr(zh: "施肥状态", en: "Fertilizing status", de: "Düngestatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceFertilized {
                let progress = min(1.0, Double(days) / Double(max(fertilizingIntervalDays, 1)))
                let color: Color = progress < 0.5 ? .green : (progress < 0.8 ? .yellow : .red)

                HStack {
                    Text(l.tr(zh: "距上次施肥 \(days) 天", en: "\(days) days since fertilizing", de: "\(days) Tage seit dem Düngen"))
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
                        Text(l.tr(zh: "该施肥了！", en: "Time to fertilize!", de: "Zeit zum Düngen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有施肥记录", en: "No fertilizing records yet", de: "Noch keine Düngeprotokolle"))
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
                    Text(l.tr(zh: "浇水", en: "Water", de: "Gießen"))
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
                    Text(l.tr(zh: "施肥", en: "Fertilize", de: "Düngen"))
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
                        Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
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
            detailHeader(icon: "clock.arrow.circlepath", title: l.tr(zh: "护理历史", en: "Care history", de: "Pflegeverlauf"))
            if recentLogs.isEmpty {
                Text(l.tr(zh: "还没有护理日志", en: "No care logs yet", de: "Noch keine Pflegeprotokolle"))
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
                    Text(l.tr(zh: "即将删除 \(plant.name)", en: "Deleting \(plant.name) soon", de: "\(plant.name) wird gleich gelöscht"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "6 秒内可撤销；到时会清理相关日历和提醒。",
                        en: "Undo within 6 seconds; related calendar items and reminders will be cleaned up.",
                        de: "Innerhalb von 6 Sekunden widerrufbar; zugehörige Kalenderpunkte und Erinnerungen werden bereinigt."
                    ))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                Button(l.tr(zh: "撤销", en: "Undo", de: "Widerrufen")) {
                    cancelPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goLime)

                Button(l.tr(zh: "立即删除", en: "Delete now", de: "Jetzt löschen"), role: .destructive) {
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
                Text(l.tr(zh: "删除植物", en: "Delete plant", de: "Pflanze löschen"))
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
