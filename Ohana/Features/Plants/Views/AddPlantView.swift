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
    @FocusState private var focusedField: AddPlantFocusField?

    private let plantEmojis = ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]

    private enum AddPlantFocusField: Hashable {
        case name
        case species
        case catalogSearch
        case room
        case location
        case potMaterial
        case soil
        case source
    }

    private struct PlantProfileReadinessItem: Identifiable {
        let id: String
        let title: String
        let isComplete: Bool
    }

    private struct PlantCreationOutcomeItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        let icon: String
        let tint: Color
        let isReady: Bool
    }

    private var selectedCatalog: PlantCatalogEntry? {
        selectedCatalogID.isEmpty ? nil : PlantCatalog.entry(id: selectedCatalogID)
    }
    private var l: L10n { L10n(appLanguage) }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSpecies: String {
        species.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedRoomName: String {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var catalogMatches: [PlantCatalogSearchResult] {
        PlantCatalog.searchResults(catalogQuery, limit: 8)
    }

    private var profileReadinessItems: [PlantProfileReadinessItem] {
        [
            PlantProfileReadinessItem(
                id: "name",
                title: l.tr(zh: "名字", en: "Name", de: "Name"),
                isComplete: !trimmedName.isEmpty
            ),
            PlantProfileReadinessItem(
                id: "species",
                title: l.tr(zh: "品种", en: "Species", de: "Art"),
                isComplete: selectedCatalog != nil || !trimmedSpecies.isEmpty
            ),
            PlantProfileReadinessItem(
                id: "place",
                title: l.tr(zh: "位置", en: "Place", de: "Standort"),
                isComplete: !trimmedRoomName.isEmpty || !trimmedLocation.isEmpty
            ),
            PlantProfileReadinessItem(
                id: "care",
                title: l.tr(zh: "照护", en: "Care", de: "Pflege"),
                isComplete: wateringInterval > 0 && fertilizingInterval > 0
            ),
            PlantProfileReadinessItem(
                id: "environment",
                title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"),
                isComplete: selectedCatalog != nil || windowDirection != .unknown || lightMeasurementLux > 0
            )
        ]
    }

    private var completedProfileReadinessCount: Int {
        profileReadinessItems.filter(\.isComplete).count
    }

    private var profileCompletionPercent: Int {
        guard !profileReadinessItems.isEmpty else { return 0 }
        return Int((Double(completedProfileReadinessCount) / Double(profileReadinessItems.count) * 100).rounded())
    }

    private var profileSetupTitle: String {
        if trimmedName.isEmpty {
            return l.tr(zh: "先给这株植物建个清晰档案", en: "Start a clear profile for this plant", de: "Lege ein klares Profil für diese Pflanze an")
        }
        if selectedCatalog == nil && trimmedSpecies.isEmpty {
            return l.tr(zh: "补齐品种，照护计划会更准", en: "Add species for a sharper care plan", de: "Art ergänzen für einen genaueren Pflegeplan")
        }
        if trimmedRoomName.isEmpty && trimmedLocation.isEmpty {
            return l.tr(zh: "加上位置，家里更容易找到它", en: "Add its place so the family can find it", de: "Ort ergänzen, damit alle sie finden")
        }
        return l.tr(zh: "档案可以保存，也可以继续补细节", en: "Ready to save, or keep refining details", de: "Bereit zum Speichern, Details können folgen")
    }

    private var profilePreviewName: String {
        trimmedName.isEmpty ? l.tr(zh: "新植物", en: "New plant", de: "Neue Pflanze") : trimmedName
    }

    private var profilePreviewSpecies: String {
        if let selectedCatalog {
            return selectedCatalog.localizedCommonName
        }
        if !trimmedSpecies.isEmpty {
            return trimmedSpecies
        }
        return l.tr(zh: "等待匹配品种", en: "Species to match", de: "Art noch offen")
    }

    private var profilePreviewPlace: String {
        if !trimmedRoomName.isEmpty, !trimmedLocation.isEmpty {
            return "\(trimmedRoomName) · \(trimmedLocation)"
        }
        if !trimmedRoomName.isEmpty {
            return trimmedRoomName
        }
        if !trimmedLocation.isEmpty {
            return trimmedLocation
        }
        return isIndoor
            ? l.tr(zh: "室内位置未设置", en: "Indoor place unset", de: "Innenstandort fehlt")
            : l.tr(zh: "户外位置未设置", en: "Outdoor place unset", de: "Außenstandort fehlt")
    }

    private var carePlanPreviewSummary: String {
        l.tr(
            zh: "浇水 \(wateringInterval) 天 · 施肥 \(fertilizingInterval) 天 · \(lightLevel.displayName)",
            en: "Water \(wateringInterval)d · fertilize \(fertilizingInterval)d · \(lightLevel.displayName)",
            de: "Gießen \(wateringInterval) T. · düngen \(fertilizingInterval) T. · \(lightLevel.displayName)"
        )
    }

    private var carePlanPreviewDetail: String {
        if let selectedCatalog {
            return l.tr(
                zh: "已使用资料库默认值：\(selectedCatalog.localizedCommonName)",
                en: "Using catalog defaults for \(selectedCatalog.localizedCommonName)",
                de: "Katalogwerte für \(selectedCatalog.localizedCommonName) aktiv"
            )
        }
        return l.tr(
            zh: "未匹配资料库时，会使用你填写的环境和周期生成本地计划。",
            en: "Without a catalog match, Ohana uses your environment and cadence to create a local plan.",
            de: "Ohne Katalogtreffer nutzt Ohana Umgebung und Rhythmus für den lokalen Plan."
        )
    }

    private var creationOutcomeItems: [PlantCreationOutcomeItem] {
        [
            PlantCreationOutcomeItem(
                id: "home",
                title: l.tr(zh: "首页植物档案", en: "Home plant card", de: "Pflanzenkarte zuhause"),
                detail: trimmedName.isEmpty
                    ? l.tr(zh: "输入名称后会生成首页卡片、位置分组和植物列表项。", en: "Add a name to create the home card, site group, and list row.", de: "Name ergänzen, um Karte, Standortgruppe und Listeneintrag zu erstellen.")
                    : l.tr(zh: "\(profilePreviewName) 会出现在 \(profilePreviewPlace)。", en: "\(profilePreviewName) will appear in \(profilePreviewPlace).", de: "\(profilePreviewName) erscheint in \(profilePreviewPlace)."),
                icon: "house.fill",
                tint: Color.goTeal,
                isReady: !trimmedName.isEmpty
            ),
            PlantCreationOutcomeItem(
                id: "care",
                title: l.tr(zh: "护理计划与提醒", en: "Care plan and alerts", de: "Pflegeplan und Hinweise"),
                detail: remindersEnabled
                    ? l.tr(zh: "\(carePlanPreviewSummary)，保存后会创建本地护理节奏。", en: "\(carePlanPreviewSummary); saving creates the local care rhythm.", de: "\(carePlanPreviewSummary); Speichern erstellt den lokalen Rhythmus.")
                    : l.tr(zh: "\(carePlanPreviewSummary)，提醒关闭时只保留计划。", en: "\(carePlanPreviewSummary); reminders are off, so only the plan is kept.", de: "\(carePlanPreviewSummary); Hinweise sind aus, nur der Plan bleibt."),
                icon: remindersEnabled ? "bell.badge.fill" : "bell.slash.fill",
                tint: remindersEnabled ? Color.goLime : Color.goYellow,
                isReady: wateringInterval > 0 && fertilizingInterval > 0
            ),
            PlantCreationOutcomeItem(
                id: "safety",
                title: l.tr(zh: "安全与成长记录", en: "Safety and growth log", de: "Sicherheit und Wachstum"),
                detail: creationSafetyAndGrowthDetail,
                icon: selectedCatalog == nil ? "photo.stack.fill" : "shield.checkered",
                tint: selectedCatalog == nil ? Color.goTeal : safetyOutcomeTint,
                isReady: selectedCatalog != nil || !trimmedSpecies.isEmpty
            )
        ]
    }

    private var creationSafetyAndGrowthDetail: String {
        guard let selectedCatalog else {
            return l.tr(
                zh: "匹配品种后会带入安全提示；保存后也能继续补照片和首次照护。",
                en: "A catalog match adds safety notes; after saving, add photos and the first care log.",
                de: "Ein Katalogtreffer ergänzt Sicherheit; nach dem Speichern Fotos und erste Pflege ergänzen."
            )
        }
        if selectedCatalog.isToxicToCats || selectedCatalog.isToxicToDogs || selectedCatalog.isToxicToChildren {
            return l.tr(
                zh: "\(selectedCatalog.localizedCommonName) 有误食风险，详情页会优先提示摆放安全。",
                en: "\(selectedCatalog.localizedCommonName) has ingestion risk; detail pages will prioritize placement safety.",
                de: "\(selectedCatalog.localizedCommonName) hat Verschluckrisiko; Details priorisieren Standort-Sicherheit."
            )
        }
        return l.tr(
            zh: "\(selectedCatalog.localizedCommonName) 已匹配，安全、光照和成长档案会更完整。",
            en: "\(selectedCatalog.localizedCommonName) is matched, improving safety, light, and growth context.",
            de: "\(selectedCatalog.localizedCommonName) ist zugeordnet und verbessert Sicherheit, Licht und Wachstum."
        )
    }

    private var safetyOutcomeTint: Color {
        guard let selectedCatalog else { return Color.goTeal }
        return selectedCatalog.isToxicToCats || selectedCatalog.isToxicToDogs || selectedCatalog.isToxicToChildren
            ? Color.goYellow
            : Color.goTeal
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

                profileSetupOverview
                    .padding(.horizontal, 20)

                creationOutcomePreview
                    .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    goFormField(l.tr(zh: "名称", en: "Name", de: "Name"), text: $name, placeholder: l.tr(zh: "我的绿萝", en: "My pothos", de: "Meine Efeutute"), identifier: "add-plant-name-input", focusField: .name)
                    goFormField(l.tr(zh: "品种", en: "Species", de: "Art"), text: $species, placeholder: l.tr(zh: "绿萝、多肉…", en: "Pothos, succulent...", de: "Efeutute, Sukkulente..."), identifier: "add-plant-species-input", focusField: .species)
                    catalogSearchSection
                    goFormField(l.tr(zh: "房间", en: "Room", de: "Raum"), text: $roomName, placeholder: l.tr(zh: "客厅、阳台…", en: "Living room, balcony...", de: "Wohnzimmer, Balkon..."), identifier: "add-plant-room-input", focusField: .room)
                    goFormField(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), text: $location, placeholder: l.tr(zh: "南窗边、书桌、花架…", en: "South window, desk, plant stand...", de: "Südfenster, Schreibtisch, Pflanzenregal..."), identifier: "add-plant-location-input", focusField: .location)
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
                    HStack(spacing: 8) {
                        Image(systemName: name.isEmpty ? "text.cursor" : (isSaving ? "hourglass" : "leaf.fill"))
                            .accessibilityHidden(true)
                        Text(name.isEmpty ? l.tr(zh: "请先输入名称", en: "Enter a name first", de: "Zuerst einen Namen eingeben") : (isSaving ? l.tr(zh: "正在添加…", en: "Adding...", de: "Wird hinzugefügt...") : l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen")))
                    }
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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            keyboardFocusSpacer
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                    focusedField = nil
                }
                .accessibilityIdentifier("add-plant-keyboard-done")
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

    private var profileSetupOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goTeal.opacity(0.16))
                        .frame(width: 58, height: 58)
                    Text(avatarEmoji)
                        .font(OhanaFont.adaptive(size: 30))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileSetupTitle)
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(profilePreviewName) · \(profilePreviewSpecies)")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(profilePreviewPlace)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(profileCompletionPercent)%")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text(l.tr(zh: "完成度", en: "ready", de: "bereit"))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                }
                .accessibilityElement(children: .combine)
            }

            ProgressView(value: Double(completedProfileReadinessCount), total: Double(max(profileReadinessItems.count, 1)))
                .tint(Color.goLime)
                .accessibilityLabel(l.tr(zh: "建档完成度", en: "Profile readiness", de: "Profilbereitschaft"))
                .accessibilityValue("\(profileCompletionPercent)%")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(profileReadinessItems) { item in
                    readinessPill(item)
                }
            }

            Divider()
                .overlay(Color.ohanaControlFill.opacity(0.55))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.clock") // a11y: allow decorative care-plan glyph; adjacent text gives the preview.
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 28, height: 28) // a11y: allow non-interactive care preview glyph; adjacent text gives the content.
                    .background(Color.goYellow.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "照护计划预览", en: "Care plan preview", de: "Pflegeplan-Vorschau"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(carePlanPreviewSummary)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(carePlanPreviewDetail)
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-profile-overview")
    }

    private var creationOutcomePreview: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill") // a11y: allow decorative outcome-preview glyph; heading names the section.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .frame(width: 32, height: 32) // a11y: allow non-interactive section glyph; heading text names the section.
                    .background(Color.goLime.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "保存后会生成这些入口", en: "After saving, Ohana prepares", de: "Nach dem Speichern entsteht"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "像成员档案一样，植物会进入首页、护理计划、图库和安全复查。",
                        en: "Like a member profile, the plant joins Home, care plans, gallery, and safety review.",
                        de: "Wie ein Mitgliedsprofil kommt die Pflanze in Home, Pflegeplan, Galerie und Sicherheitsprüfung."
                    ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
                ForEach(creationOutcomeItems) { item in
                    creationOutcomeRow(item)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-plant-creation-outcome-preview")
    }

    private func creationOutcomeRow(_ item: PlantCreationOutcomeItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon) // a11y: allow decorative outcome glyph; row text describes the generated entry.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34) // a11y: allow non-interactive outcome glyph; row text is the accessible content.
                .background(item.tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(item.detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: item.isReady ? "checkmark.circle.fill" : "circle")
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(item.isReady ? Color.goLime : Color.ohanaTertiaryText)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.detail)")
        .accessibilityIdentifier("add-plant-creation-outcome-\(item.id)")
    }

    private func readinessPill(_ item: PlantProfileReadinessItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(item.isComplete ? Color.goLime : Color.ohanaTertiaryText)
                .accessibilityHidden(true)
            Text(item.title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(item.isComplete ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaControlFill.opacity(item.isComplete ? 0.66 : 0.38), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.isComplete ? l.tr(zh: "已完成", en: "complete", de: "fertig") : l.tr(zh: "待补充", en: "missing", de: "fehlt"))")
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
                .focused($focusedField, equals: .catalogSearch)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.catalogSearch) }
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
                .focused($focusedField, equals: .potMaterial)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.potMaterial) }
                .accessibilityIdentifier("add-plant-pot-material-input")
            TextField(l.tr(zh: "土壤类型，如疏松排水型通用土", en: "Soil type, e.g. loose well-draining mix", de: "Erdtyp, z. B. lockere gut drainierende Erde"), text: $soilType) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .focused($focusedField, equals: .soil)
                .submitLabel(.done)
                .onSubmit { focusAfterSubmit(.soil) }
                .accessibilityIdentifier("add-plant-soil-input")
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
                .focused($focusedField, equals: .source)
                .submitLabel(.done)
                .onSubmit { focusAfterSubmit(.source) }
                .accessibilityIdentifier("add-plant-source-input")
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

    private func goFormField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        identifier: String,
        focusField: AddPlantFocusField
    ) -> some View {
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
                        .strokeBorder(
                            focusedField == focusField ? Color.goTeal.opacity(0.58) : Color.ohanaCardSurface.opacity(0.18),
                            lineWidth: focusedField == focusField ? 1.5 : 1
                        )
                )
                .focused($focusedField, equals: focusField)
                .submitLabel(focusField == .location ? .done : .next)
                .onSubmit { focusAfterSubmit(focusField) }
                .accessibilityIdentifier(identifier)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    @ViewBuilder
    private var keyboardFocusSpacer: some View {
        if focusedField != nil {
            Color.clear
                .frame(height: 74)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func focusAfterSubmit(_ field: AddPlantFocusField) {
        switch field {
        case .name:
            focusedField = .species
        case .species:
            focusedField = .catalogSearch
        case .catalogSearch:
            focusedField = .room
        case .room:
            focusedField = .location
        case .location, .soil, .source:
            focusedField = nil
        case .potMaterial:
            focusedField = .soil
        }
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
