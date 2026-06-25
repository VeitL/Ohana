//
//  AddPlantView.swift
//  Ohana
//
//  GO UI：由 `AddEntityView` 提供 `GoIslandWizardBackdrop`，本页使用岛景上的玻璃卡与青柠强调。
//

import SwiftData
import SwiftUI

struct AddPlantView: View {
    let onComplete: () -> Void
    let existingPlantSnapshots: [PlantDuplicateScanSnapshot]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var species = ""
    @State private var roomName = ""
    @State private var location = ""
    @State private var avatarEmoji = "🌱"
    @State private var catalogQuery = ""
    @State private var selectedCatalogID = ""
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var potDiameterCm = 0.0
    @State private var potMaterial = ""
    @State private var soilType = ""
    @State private var isIndoor = true
    @State private var windowDirection: PlantWindowDirection = .unknown
    @State private var lightLevel: PlantLightLevel = .medium
    @State private var lightMeasurementLux = 0
    @State private var humidityPreference: PlantHumidityPreference = .standard
    @State private var temperaturePreference: PlantTemperaturePreference = .standard
    @State private var isNearClimateSource = false
    @State private var potHasDrainage = true
    @State private var hasAcquiredDate = false
    @State private var acquiredDate = Date()
    @State private var acquisitionSource = ""
    @State private var currentHeightCm = 0.0
    @State private var currentSpreadCm = 0.0
    @State private var isHydroponic = false
    @State private var isSucculent = false
    @State private var healthStatus: PlantHealthStatus = .stable
    @State private var remindersEnabled = true
    @State private var isSaving = false
    @State private var showDuplicateAlert = false
    @State private var duplicateAcknowledgementKey = ""

    private let plantEmojis = ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]
    private var selectedCatalog: PlantCatalogEntry? {
        selectedCatalogID.isEmpty ? nil : PlantCatalog.entry(id: selectedCatalogID)
    }

    private var catalogMatches: [PlantCatalogSearchResult] {
        PlantCatalog.searchResults(catalogQuery, limit: 8)
    }

    private var duplicateDraft: PlantDuplicateScanDraft {
        PlantDuplicateScanDraft(
            name: name,
            species: species,
            roomName: roomName,
            location: location,
            catalogSpeciesId: selectedCatalogID
        )
    }

    private var duplicateCandidates: [PlantDuplicateCandidate] {
        PlantProfileUXPolicy.duplicateCandidates(
            draft: duplicateDraft,
            existingPlants: existingPlantSnapshots
        )
    }

    private var currentDuplicateAcknowledgementKey: String {
        PlantProfileUXPolicy.duplicateAcknowledgementKey(for: duplicateDraft)
    }

    private var requiresDuplicateAcknowledgement: Bool {
        !duplicateCandidates.isEmpty && duplicateAcknowledgementKey != currentDuplicateAcknowledgementKey
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 16)

                Text(avatarEmoji)
                    .font(OhanaFont.adaptive(size: 64))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(plantEmojis, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(emoji)
                                .font(OhanaFont.adaptive(size: 28))
                                .frame(width: 46, height: 46)
                                .background(
                                    avatarEmoji == emoji
                                        ? Color.goLime.opacity(0.22)
                                        : Color.ohanaControlFill.opacity(0.68),
                                    in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                                        .strokeBorder(
                                            avatarEmoji == emoji ? Color.goLime.opacity(0.55) : Color.ohanaCardSurface.opacity(0.16),
                                            lineWidth: avatarEmoji == emoji ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    goFormField("名称", text: $name, placeholder: "我的绿萝")
                    goFormField("品种", text: $species, placeholder: "绿萝、多肉…")
                    catalogSearchSection
                    goFormField("房间", text: $roomName, placeholder: "客厅、阳台…")
                    goFormField("具体位置", text: $location, placeholder: "南窗边、书桌、花架…")
                    duplicateWarningSection
                    environmentSection
                    potSection
                    sourceSection
                    healthSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("浇水周期")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1 ... 90)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("施肥周期")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1 ... 365)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)

                    Toggle("植物提醒", isOn: $remindersEnabled)
                        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .tint(Color.goLime)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
                }
                .padding(.horizontal, 20)

                Button {
                    savePlant()
                } label: {
                    Text(name.isEmpty ? "请先输入名称" : (isSaving ? "正在添加…" : "添加植物 🌿"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(name.isEmpty ? Color.ohanaTertiaryText : Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            name.isEmpty ? Color.ohanaControlFill.opacity(0.72) : Color.goLime,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 36)
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .alert("可能已经建过档", isPresented: $showDuplicateAlert) {
            Button("返回检查", role: .cancel) {}
            Button("仍然添加") {
                duplicateAcknowledgementKey = currentDuplicateAcknowledgementKey
                savePlant()
            }
        } message: {
            Text(duplicateAlertMessage)
        }
    }

    private var catalogSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资料库匹配")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(spacing: 8) {
                Image(systemName: "leaf.circle.fill") // a11y: allow decorative catalog status glyph; adjacent text names catalog and AI state.
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text("本地资料库 \(PlantCatalog.entries.count) 种 · AI 识别未配置时不生成假候选")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("搜索绿萝、Monstera、吊兰…", text: $catalogQuery) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

            VStack(spacing: 8) {
                if catalogMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("没有找到匹配")
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("可以继续手动建档；护理计划会使用你填写的光照、盆土和周期。")
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                } else {
                    ForEach(catalogMatches) { result in
                        catalogMatchButton(result)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private func catalogMatchButton(_ result: PlantCatalogSearchResult) -> some View {
        let entry = result.entry
        return Button {
            applyCatalog(entry)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: selectedCatalogID == entry.id ? "checkmark.circle.fill" : "leaf.circle")
                        .foregroundStyle(selectedCatalogID == entry.id ? Color.goLime : Color.ohanaSecondaryText)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.commonName)
                            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(entry.latinName)
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(result.matchSummary)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goLime)
                }
                HStack(spacing: 6) {
                    catalogChip(entry.careDifficulty, foreground: Color.arkInk, background: Color.goLime)
                    catalogChip(entry.lightRequirement.displayName, foreground: Color.ohanaPrimaryText, background: Color.ohanaControlFill.opacity(0.78))
                    catalogChip(
                        entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren ? "误食风险" : "宠物低风险",
                        foreground: Color.ohanaPrimaryText,
                        background: Color.ohanaControlFill.opacity(0.78)
                    )
                }
                Text("默认计划：浇水 \(entry.defaultWateringDays) 天 · 施肥 \(entry.defaultFertilizingDays) 天")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(12)
            .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.commonName)，\(entry.latinName)，\(result.matchSummary)")
    }

    private func catalogChip(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    @ViewBuilder
    private var duplicateWarningSection: some View {
        if !duplicateCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative warning glyph; adjacent title and rows explain duplicate risk.
                        .foregroundStyle(Color.goYellow)
                        .accessibilityHidden(true)
                    Text("可能重复")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    if duplicateAcknowledgementKey == currentDuplicateAcknowledgementKey {
                        Text("已确认")
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                }
                ForEach(duplicateCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("\(candidate.reason) · \(candidate.detail)")
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    duplicateAcknowledgementKey = currentDuplicateAcknowledgementKey
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("仍然添加为新植物", systemImage: "plus.circle")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(ScaleButtonStyle())
                .foregroundStyle(Color.goLime)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.goYellow.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goYellow.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("室内植物", isOn: $isIndoor)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
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
            Stepper(lightMeasurementLux > 0 ? "光照实测 \(lightMeasurementLux) lux" : "光照实测 未记录", value: $lightMeasurementLux, in: 0 ... 20000, step: 250)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
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
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
        }
        .pickerStyle(.menu)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var potSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("盆土")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            Stepper("盆径 \(Int(potDiameterCm)) cm", value: $potDiameterCm, in: 0 ... 80, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle("花盆有排水孔", isOn: $potHasDrainage)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            TextField("盆材质，如陶盆、塑料盆", text: $potMaterial) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            TextField("土壤类型，如疏松排水型通用土", text: $soilType) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("来源与类型")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
            Toggle("记录购入日期", isOn: $hasAcquiredDate)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            if hasAcquiredDate {
                DatePicker("购入日期", selection: $acquiredDate, displayedComponents: .date)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goLime)
            }
            TextField("来源，如花市、朋友分株", text: $acquisitionSource) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            Stepper("当前高度 \(Int(currentHeightCm)) cm", value: $currentHeightCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Stepper("冠幅 \(Int(currentSpreadCm)) cm", value: $currentSpreadCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle("水培", isOn: $isHydroponic)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle("多肉/仙人掌类", isOn: $isSucculent)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("当前状态", selection: $healthStatus) {
                ForEach(PlantHealthStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            if let catalog = selectedCatalog,
               catalog.isToxicToCats || catalog.isToxicToDogs || catalog.isToxicToChildren {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative warning glyph; adjacent text carries the warning.
                        .foregroundStyle(Color.goYellow)
                        .accessibilityHidden(true)
                    Text("已标记宠物/儿童误食风险，详情页和提醒会优先提示。")
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
        }
        .pickerStyle(.menu)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private func goFormField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            TextField(placeholder, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private func applyCatalog(_ entry: PlantCatalogEntry) {
        let defaults = PlantProfileUXPolicy.catalogDefaults(for: entry)
        selectedCatalogID = entry.id
        catalogQuery = "\(entry.commonName) · \(entry.latinName)"
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = defaults.name
        }
        species = defaults.species
        wateringInterval = defaults.wateringIntervalDays
        fertilizingInterval = defaults.fertilizingIntervalDays
        lightLevel = defaults.lightLevel
        soilType = defaults.soilTypeRaw
        isIndoor = defaults.isIndoor
        humidityPreference = defaults.humidityPreference
        temperaturePreference = defaults.temperaturePreference
        potHasDrainage = defaults.potHasDrainage
        isHydroponic = defaults.isHydroponic
        isSucculent = defaults.isSucculent
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func savePlant() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isSaving else { return }
        if requiresDuplicateAcknowledgement {
            showDuplicateAlert = true
            return
        }
        let catalog = selectedCatalog

        let input = PlantCreationCommandInput(
            name: name,
            species: species,
            location: location,
            avatarEmoji: avatarEmoji,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval,
            roomNameRaw: roomName,
            potDiameterCm: potDiameterCm,
            potMaterialRaw: potMaterial,
            soilTypeRaw: soilType,
            isIndoor: isIndoor,
            windowDirection: windowDirection,
            lightLevel: lightLevel,
            lastLightMeasurementLux: lightMeasurementLux,
            lastLightMeasurementDate: lightMeasurementLux > 0 ? Date() : nil,
            humidityPreference: humidityPreference,
            temperaturePreference: temperaturePreference,
            isNearClimateSource: isNearClimateSource,
            potHasDrainage: potHasDrainage,
            acquiredDate: hasAcquiredDate ? acquiredDate : nil,
            acquisitionSourceRaw: acquisitionSource,
            currentHeightCm: currentHeightCm,
            currentSpreadCm: currentSpreadCm,
            isHydroponic: isHydroponic,
            isSucculent: isSucculent,
            healthStatus: healthStatus,
            catalogSpeciesId: selectedCatalogID,
            isToxicToCats: catalog?.isToxicToCats ?? false,
            isToxicToDogs: catalog?.isToxicToDogs ?? false,
            isToxicToChildren: catalog?.isToxicToChildren ?? false,
            isIndoorSuitable: catalog?.isIndoorSuitable ?? true,
            remindersEnabled: remindersEnabled
        )
        let command = DomainCommand.memberCreation(entityID: input.id, kind: EntityKind.plant.rawValue)

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            PlantCreationCommandExecutor(context: modelContext, services: appServices).createPlant(
                input: input,
                note: "plant.creation"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        }
    }

    private var duplicateAlertMessage: String {
        guard let first = duplicateCandidates.first else {
            return "Ohana 没找到明显重复项，可以继续添加。"
        }
        return "找到相似植物：\(first.title)。原因：\(first.reason)。如果这是另一盆植物，可以继续添加。"
    }
}
