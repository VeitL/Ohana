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
    @AppStorage("appLanguage") private var appLanguage = "zh"

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
    private var l: L10n { L10n(appLanguage) }

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
                    goFormField(l.tr(zh: "名称", en: "Name", de: "Name"), text: $name, placeholder: l.tr(zh: "我的绿萝", en: "My pothos", de: "Meine Efeutute"), identifier: "add-plant-name-input")
                    goFormField(l.tr(zh: "品种", en: "Species", de: "Art"), text: $species, placeholder: l.tr(zh: "绿萝、多肉…", en: "Pothos, succulent...", de: "Efeutute, Sukkulente..."), identifier: "add-plant-species-input")
                    catalogSearchSection
                    goFormField(l.tr(zh: "房间", en: "Room", de: "Raum"), text: $roomName, placeholder: l.tr(zh: "客厅、阳台…", en: "Living room, balcony...", de: "Wohnzimmer, Balkon..."), identifier: "add-plant-room-input")
                    goFormField(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), text: $location, placeholder: l.tr(zh: "南窗边、书桌、花架…", en: "South window, desk, plant stand...", de: "Südfenster, Schreibtisch, Pflanzenregal..."), identifier: "add-plant-location-input")
                    duplicateWarningSection
                    environmentSection
                    potSection
                    sourceSection
                    healthSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.tr(zh: "浇水周期", en: "Watering cadence", de: "Gießrhythmus"))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper(l.tr(zh: "每 \(wateringInterval) 天", en: "Every \(wateringInterval) days", de: "Alle \(wateringInterval) Tage"), value: $wateringInterval, in: 1 ... 90)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.tr(zh: "施肥周期", en: "Fertilizing cadence", de: "Düngerhythmus"))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper(l.tr(zh: "每 \(fertilizingInterval) 天", en: "Every \(fertilizingInterval) days", de: "Alle \(fertilizingInterval) Tage"), value: $fertilizingInterval, in: 1 ... 365)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)

                    Toggle(l.tr(zh: "植物提醒", en: "Plant reminders", de: "Pflanzenerinnerungen"), isOn: $remindersEnabled)
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
                    Text(name.isEmpty ? l.tr(zh: "请先输入名称", en: "Enter a name first", de: "Zuerst einen Namen eingeben") : (isSaving ? l.tr(zh: "正在添加…", en: "Adding...", de: "Wird hinzugefügt...") : l.tr(zh: "添加植物 🌿", en: "Add plant 🌿", de: "Pflanze hinzufügen 🌿")))
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
                .accessibilityIdentifier("add-plant-save-action")
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 36)
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .alert(l.tr(zh: "可能已经建过档", en: "This may already exist", de: "Vielleicht schon angelegt"), isPresented: $showDuplicateAlert) {
            Button(l.tr(zh: "返回检查", en: "Go back and check", de: "Zurück und prüfen"), role: .cancel) {}
            Button(l.tr(zh: "仍然添加", en: "Add anyway", de: "Trotzdem hinzufügen")) {
                duplicateAcknowledgementKey = currentDuplicateAcknowledgementKey
                savePlant()
            }
        } message: {
            Text(duplicateAlertMessage)
        }
    }

    private var catalogSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "资料库匹配", en: "Catalog match", de: "Katalogtreffer"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(spacing: 8) {
                Image(systemName: "leaf.circle.fill") // a11y: allow decorative catalog status glyph; adjacent text names catalog and AI state.
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text(l.tr(
                    zh: "本地资料库 \(PlantCatalog.entries.count) 种 · AI 识别未配置时不生成假候选",
                    en: "\(PlantCatalog.entries.count) local catalog plants · No fake AI candidates when recognition is not configured",
                    de: "\(PlantCatalog.entries.count) lokale Katalogpflanzen · Keine falschen KI-Kandidaten ohne Erkennungsdienst"
                ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(l.tr(zh: "搜索绿萝、Monstera、吊兰…", en: "Search pothos, Monstera, spider plant...", de: "Efeutute, Monstera, Grünlilie suchen..."), text: $catalogQuery) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .accessibilityIdentifier("add-plant-catalog-search-input")

            VStack(spacing: 8) {
                if catalogMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "没有找到匹配", en: "No match found", de: "Kein Treffer"))
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "可以继续手动建档；护理计划会使用你填写的光照、盆土和周期。",
                            en: "You can keep adding it manually. The care plan will use the light, pot, soil, and cadence you enter.",
                            de: "Du kannst sie manuell weiter anlegen. Der Pflegeplan nutzt Licht, Topf, Erde und Rhythmus aus deinen Angaben."
                        ))
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
                        Text(entry.localizedCommonName)
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
                    catalogChip(entry.localizedCareDifficulty, foreground: Color.arkInk, background: Color.goLime)
                    catalogChip(entry.lightRequirement.displayName, foreground: Color.ohanaPrimaryText, background: Color.ohanaControlFill.opacity(0.78))
                    catalogChip(
                        entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren
                            ? l.tr(zh: "误食风险", en: "Ingestion risk", de: "Verschluckrisiko")
                            : l.tr(zh: "宠物低风险", en: "Low pet risk", de: "Geringes Haustierrisiko"),
                        foreground: Color.ohanaPrimaryText,
                        background: Color.ohanaControlFill.opacity(0.78)
                    )
                }
                Text(l.tr(
                    zh: "默认计划：浇水 \(entry.defaultWateringDays) 天 · 施肥 \(entry.defaultFertilizingDays) 天",
                    en: "Default plan: water \(entry.defaultWateringDays)d · fertilize \(entry.defaultFertilizingDays)d",
                    de: "Standardplan: gießen \(entry.defaultWateringDays) T. · düngen \(entry.defaultFertilizingDays) T."
                ))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(12)
            .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName), \(result.matchSummary)")
        .accessibilityIdentifier("add-plant-catalog-result-\(entry.id)")
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
                    Text(l.tr(zh: "可能重复", en: "Possible duplicate", de: "Möglicherweise doppelt"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    if duplicateAcknowledgementKey == currentDuplicateAcknowledgementKey {
                        Text(l.tr(zh: "已确认", en: "Confirmed", de: "Bestätigt"))
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
                    Label(l.tr(zh: "仍然添加为新植物", en: "Still add as a new plant", de: "Trotzdem als neue Pflanze hinzufügen"), systemImage: "plus.circle")
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
            Toggle(l.tr(zh: "室内植物", en: "Indoor plant", de: "Zimmerpflanze"), isOn: $isIndoor)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
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
            Stepper(
                lightMeasurementLux > 0
                    ? l.tr(zh: "光照实测 \(lightMeasurementLux) lux", en: "Light reading \(lightMeasurementLux) lux", de: "Lichtmessung \(lightMeasurementLux) lux")
                    : l.tr(zh: "光照实测 未记录", en: "Light reading not recorded", de: "Lichtmessung nicht erfasst"),
                value: $lightMeasurementLux,
                in: 0 ... 20000,
                step: 250
            )
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
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
            Text(l.tr(zh: "盆土", en: "Pot and soil", de: "Topf und Erde"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            Stepper(l.tr(zh: "盆径 \(Int(potDiameterCm)) cm", en: "Pot diameter \(Int(potDiameterCm)) cm", de: "Topfdurchmesser \(Int(potDiameterCm)) cm"), value: $potDiameterCm, in: 0 ... 80, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "花盆有排水孔", en: "Pot has drainage hole", de: "Topf hat Abzugsloch"), isOn: $potHasDrainage)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            TextField(l.tr(zh: "盆材质，如陶盆、塑料盆", en: "Pot material, e.g. terracotta or plastic", de: "Topfmaterial, z. B. Ton oder Kunststoff"), text: $potMaterial) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            TextField(l.tr(zh: "土壤类型，如疏松排水型通用土", en: "Soil type, e.g. loose well-draining mix", de: "Erdtyp, z. B. lockere gut drainierende Erde"), text: $soilType) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
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
            Text(l.tr(zh: "来源与类型", en: "Source and type", de: "Quelle und Typ"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
            Toggle(l.tr(zh: "记录购入日期", en: "Record acquired date", de: "Kaufdatum erfassen"), isOn: $hasAcquiredDate)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            if hasAcquiredDate {
                DatePicker(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), selection: $acquiredDate, displayedComponents: .date)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goLime)
            }
            TextField(l.tr(zh: "来源，如花市、朋友分株", en: "Source, e.g. market or friend's cutting", de: "Quelle, z. B. Markt oder Ableger von Freunden"), text: $acquisitionSource) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            Stepper(l.tr(zh: "当前高度 \(Int(currentHeightCm)) cm", en: "Current height \(Int(currentHeightCm)) cm", de: "Aktuelle Höhe \(Int(currentHeightCm)) cm"), value: $currentHeightCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Stepper(l.tr(zh: "冠幅 \(Int(currentSpreadCm)) cm", en: "Spread \(Int(currentSpreadCm)) cm", de: "Breite \(Int(currentSpreadCm)) cm"), value: $currentSpreadCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"), isOn: $isHydroponic)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
            Toggle(l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus"), isOn: $isSucculent)
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
            Picker(l.tr(zh: "当前状态", en: "Current status", de: "Aktueller Zustand"), selection: $healthStatus) {
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
                    Text(l.tr(
                        zh: "已标记宠物/儿童误食风险，详情页和提醒会优先提示。",
                        en: "Marked as an ingestion risk for pets/children. Details and reminders will prioritize safety.",
                        de: "Als Verschluckrisiko für Haustiere/Kinder markiert. Details und Erinnerungen betonen Sicherheit."
                    ))
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

    private func goFormField(_ title: String, text: Binding<String>, placeholder: String, identifier: String) -> some View {
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
                .accessibilityIdentifier(identifier)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private func applyCatalog(_ entry: PlantCatalogEntry) {
        let defaults = PlantProfileUXPolicy.catalogDefaults(for: entry)
        selectedCatalogID = entry.id
        catalogQuery = "\(entry.localizedCommonName) · \(entry.latinName)"
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
            return l.tr(zh: "Ohana 没找到明显重复项，可以继续添加。", en: "Ohana did not find an obvious duplicate. You can keep adding it.", de: "Ohana hat kein offensichtliches Duplikat gefunden. Du kannst fortfahren.")
        }
        return l.tr(
            zh: "找到相似植物：\(first.title)。原因：\(first.reason)。如果这是另一盆植物，可以继续添加。",
            en: "Similar plant found: \(first.title). Reason: \(first.reason). If this is another pot, you can still add it.",
            de: "Ähnliche Pflanze gefunden: \(first.title). Grund: \(first.reason). Wenn es ein anderer Topf ist, kannst du sie trotzdem hinzufügen."
        )
    }
}
