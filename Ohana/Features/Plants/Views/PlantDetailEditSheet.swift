//
//  PlantDetailEditSheet.swift
//  Ohana
//
//  Edit form for the plant detail route.
//

import SwiftData
import SwiftUI

// MARK: - Edit Plant Sheet
struct EditPlantSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"

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
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaSheetWrapper(title: l.tr(zh: "编辑植物", en: "Edit plant", de: "Pflanze bearbeiten"), onDismiss: { dismiss() }) {
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
                    Text(isSaving ? l.tr(zh: "保存中…", en: "Saving...", de: "Speichern...") : l.tr(zh: "保存", en: "Save", de: "Speichern")).capsuleButton()
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
            formField(l.tr(zh: "名称", en: "Name", de: "Name"), text: $name)
            formField(l.tr(zh: "物种名", en: "Species", de: "Art"), text: $species)
            formField(l.tr(zh: "房间", en: "Room", de: "Raum"), text: $roomNameRaw)
            formField(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), text: $location)
            formField(l.tr(zh: "头像 Emoji", en: "Avatar emoji", de: "Avatar-Emoji"), text: $avatarEmoji)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "资料库", en: "Catalog", de: "Katalog"))
            Picker(l.tr(zh: "资料库物种", en: "Catalog species", de: "Katalogart"), selection: $catalogSpeciesId) {
                Text(l.tr(zh: "未链接", en: "Not linked", de: "Nicht verknüpft")).tag("")
                if !catalogSpeciesId.isEmpty, PlantCatalog.entry(id: catalogSpeciesId) == nil {
                    Text(catalogSpeciesId).tag(catalogSpeciesId)
                }
                ForEach(PlantCatalog.entries) { entry in
                    Text("\(entry.localizedCommonName) · \(entry.latinName)").tag(entry.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan"))
            Stepper(l.tr(zh: "浇水：每 \(wateringInterval) 天", en: "Water: every \(wateringInterval) days", de: "Gießen: alle \(wateringInterval) Tage"), value: $wateringInterval, in: 1 ... 90)
                .tint(Color.goLime)
            Stepper(l.tr(zh: "施肥：每 \(fertilizingInterval) 天", en: "Fertilize: every \(fertilizingInterval) days", de: "Düngen: alle \(fertilizingInterval) Tage"), value: $fertilizingInterval, in: 1 ... 365)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "植物提醒", en: "Plant reminders", de: "Pflanzenerinnerungen"), isOn: $remindersEnabled)
                .tint(Color.goLime)
        }
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "环境", en: "Environment", de: "Umgebung"))
            Toggle(l.tr(zh: "室内植物", en: "Indoor plant", de: "Zimmerpflanze"), isOn: $isIndoor)
                .tint(Color.goLime)
            Picker(l.tr(zh: "窗户朝向", en: "Window direction", de: "Fensterausrichtung"), selection: $windowDirection) {
                ForEach(PlantWindowDirection.allCases) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            Picker(l.tr(zh: "光照强度", en: "Light level", de: "Lichtstärke"), selection: $lightLevel) {
                ForEach(PlantLightLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Toggle(l.tr(zh: "记录光照实测", en: "Record light reading", de: "Lichtmessung erfassen"), isOn: $recordsLightMeasurement)
                .tint(Color.goLime)
            if recordsLightMeasurement {
                Stepper(l.tr(zh: "光照实测 \(lastLightMeasurementLux) lux", en: "Light reading \(lastLightMeasurementLux) lux", de: "Lichtmessung \(lastLightMeasurementLux) lux"), value: $lastLightMeasurementLux, in: 0 ... 20000, step: 250)
                    .tint(Color.goLime)
            }
            Picker(l.tr(zh: "湿度偏好", en: "Humidity preference", de: "Luftfeuchte"), selection: $humidityPreference) {
                ForEach(PlantHumidityPreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            Picker(l.tr(zh: "温度偏好", en: "Temperature preference", de: "Temperatur"), selection: $temperaturePreference) {
                ForEach(PlantTemperaturePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            Toggle(l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"), isOn: $isNearClimateSource)
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
            sectionTitle(l.tr(zh: "盆土", en: "Pot and soil", de: "Topf und Erde"))
            Stepper(l.tr(zh: "盆径 \(Int(potDiameterCm)) cm", en: "Pot diameter \(Int(potDiameterCm)) cm", de: "Topfdurchmesser \(Int(potDiameterCm)) cm"), value: $potDiameterCm, in: 0 ... 80, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "花盆有排水孔", en: "Pot has drainage hole", de: "Topf hat Abzugsloch"), isOn: $potHasDrainage)
                .tint(Color.goLime)
            formField(l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), text: $potMaterialRaw)
            formField(l.tr(zh: "土壤类型", en: "Soil type", de: "Erdtyp"), text: $soilTypeRaw)
            Toggle(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"), isOn: $isHydroponic)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus"), isOn: $isSucculent)
                .tint(Color.goLime)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var healthAndSafetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "健康与安全", en: "Health and safety", de: "Gesundheit und Sicherheit"))
            Picker(l.tr(zh: "当前状态", en: "Current status", de: "Aktueller Zustand"), selection: $healthStatus) {
                ForEach(PlantHealthStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            Toggle(l.tr(zh: "适合室内", en: "Suitable indoors", de: "Für drinnen geeignet"), isOn: $isIndoorSuitable)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "对猫有风险", en: "Risk for cats", de: "Risiko für Katzen"), isOn: $isToxicToCats)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "对狗有风险", en: "Risk for dogs", de: "Risiko für Hunde"), isOn: $isToxicToDogs)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "对儿童有风险", en: "Risk for children", de: "Risiko für Kinder"), isOn: $isToxicToChildren)
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
            sectionTitle(l.tr(zh: "来源与尺寸", en: "Source and size", de: "Quelle und Größe"))
            Toggle(l.tr(zh: "记录购入日期", en: "Record acquired date", de: "Kaufdatum erfassen"), isOn: $hasAcquiredDate)
                .tint(Color.goLime)
            if hasAcquiredDate {
                DatePicker(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), selection: $acquiredDate, displayedComponents: .date)
                    .tint(Color.goLime)
            }
            formField(l.tr(zh: "来源", en: "Source", de: "Quelle"), text: $acquisitionSourceRaw)
            Stepper(l.tr(zh: "当前高度 \(Int(currentHeightCm)) cm", en: "Current height \(Int(currentHeightCm)) cm", de: "Aktuelle Höhe \(Int(currentHeightCm)) cm"), value: $currentHeightCm, in: 0 ... 300, step: 1)
                .tint(Color.goLime)
            Stepper(l.tr(zh: "冠幅 \(Int(currentSpreadCm)) cm", en: "Spread \(Int(currentSpreadCm)) cm", de: "Breite \(Int(currentSpreadCm)) cm"), value: $currentSpreadCm, in: 0 ... 300, step: 1)
                .tint(Color.goLime)
        }
        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
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
                    Text(l.tr(zh: "保存后会重算", en: "Recalculated after saving", de: "Nach dem Speichern neu berechnet"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(l.tr(zh: "\(impacts.count) 项", en: "\(impacts.count) items", de: "\(impacts.count) Punkte"))
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
