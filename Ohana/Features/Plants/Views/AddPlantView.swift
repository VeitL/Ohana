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

    private let plantEmojis = ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]
    private var selectedCatalog: PlantCatalogEntry? {
        selectedCatalogID.isEmpty ? nil : PlantCatalog.entry(id: selectedCatalogID)
    }

    private var catalogMatches: [PlantCatalogEntry] {
        Array(PlantCatalog.search(catalogQuery).prefix(5))
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
    }

    private var catalogSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资料库匹配")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("拍照识别当前未配置供应商；请用资料库搜索或手动添加，Ohana 不会伪造识别结果。")
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            TextField("搜索绿萝、Monstera、吊兰…", text: $catalogQuery) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

            VStack(spacing: 8) {
                ForEach(catalogMatches) { entry in
                    Button {
                        applyCatalog(entry)
                    } label: {
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
                            Spacer()
                            Text(entry.careDifficulty)
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.goLime, in: Capsule())
                        }
                        .padding(12)
                        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
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
        selectedCatalogID = entry.id
        catalogQuery = entry.commonName
        if species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            species = entry.commonName
        }
        wateringInterval = entry.defaultWateringDays
        fertilizingInterval = entry.defaultFertilizingDays
        lightLevel = entry.lightRequirement
        soilType = entry.soil
        isIndoor = entry.isIndoorSuitable
        isSucculent = entry.aliases.contains { $0.localizedCaseInsensitiveContains("succulent") } ||
            entry.commonName.localizedCaseInsensitiveContains("多肉")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func savePlant() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isSaving else { return }
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
}
