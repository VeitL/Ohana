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
    @State private var isCustomizingName = false
    @State private var species = ""
    @State private var roomName = ""
    @State private var location = ""
    @State private var avatarEmoji = "🌱"
    @State private var catalogQuery = ""
    @State private var selectedCatalogID = ""
    @State private var selectedCatalogGroup: PlantCatalogBrowsingGroup = .recommended
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var potDiameterCm = 0.0
    @State private var potMaterial = ""
    @State private var soilType = ""
    @State var isIndoor = true
    @State var windowDirection: PlantWindowDirection = .unknown
    @State var lightLevel: PlantLightLevel = .medium
    @State var lightMeasurementLux = 0
    @State var humidityPreference: PlantHumidityPreference = .standard
    @State var temperaturePreference: PlantTemperaturePreference = .standard
    @State var isNearClimateSource = false
    @State private var potHasDrainage = true
    @State private var hasAcquiredDate = false
    @State private var acquiredDate = Date()
    @State private var acquisitionSource = ""
    @State private var currentHeightCm = 0.0
    @State private var currentSpreadCm = 0.0
    @State var isHydroponic = false
    @State var isSucculent = false
    @State var healthStatus: PlantHealthStatus = .stable
    @State private var remindersEnabled = true
    @State private var isSaving = false
    @State private var showDuplicateAlert = false
    @State private var showingOptionalPlantDetails = false
    @State private var showingCustomRoomField = false
    @State private var showingCustomLocationField = false
    @State var duplicateAcknowledgementKey = ""
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

    var selectedCatalog: PlantCatalogEntry? {
        selectedCatalogID.isEmpty ? nil : PlantCatalog.entry(id: selectedCatalogID)
    }
    var l: L10n { L10n(appLanguage) }

    private var groupedCatalogEntries: [PlantCatalogEntry] {
        AddPlantCatalogPickerModel.entries(for: selectedCatalogGroup)
    }

    private var commonRoomOptions: [String] {
        AddPlantChoiceLibrary.roomOptions(l)
    }

    private var commonSpotOptions: [String] {
        AddPlantChoiceLibrary.spotOptions(l)
    }

    private var commonPotMaterialOptions: [String] {
        AddPlantChoiceLibrary.potMaterialOptions(l)
    }

    private var commonSoilOptions: [String] {
        AddPlantChoiceLibrary.soilOptions(l)
    }

    private var commonSourceOptions: [String] {
        AddPlantChoiceLibrary.sourceOptions(l)
    }

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

    private var usesCustomRoomEntry: Bool {
        !trimmedRoomName.isEmpty && !commonRoomOptions.contains(trimmedRoomName)
    }

    private var usesCustomLocationEntry: Bool {
        !trimmedLocation.isEmpty && !commonSpotOptions.contains(trimmedLocation)
    }

    private var catalogMatches: [PlantCatalogSearchResult] {
        PlantCatalog.searchResults(catalogQuery, limit: 8)
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
        return l.tr(zh: "品种可选", en: "Species optional", de: "Art optional")
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
            zh: "不知道品种也可以先用默认节奏，之后按记录调整。",
            en: "If the species is unknown, start with this simple cadence and adjust from later logs.",
            de: "Ist die Art unbekannt, starte mit diesem einfachen Rhythmus und passe ihn später an."
        )
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

    var duplicateCandidates: [PlantDuplicateCandidate] {
        PlantProfileUXPolicy.duplicateCandidates(
            draft: duplicateDraft,
            existingPlants: existingPlantSnapshots
        )
    }

    var currentDuplicateAcknowledgementKey: String {
        PlantProfileUXPolicy.duplicateAcknowledgementKey(for: duplicateDraft)
    }

    private var requiresDuplicateAcknowledgement: Bool {
        !duplicateCandidates.isEmpty && duplicateAcknowledgementKey != currentDuplicateAcknowledgementKey
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                addPlantSimpleHeader
                    .padding(.horizontal, 20)

                VStack(spacing: 14) {
                    plantSpeciesPickerSection
                    nameAndPlaceSection
                    duplicateWarningSection
                    essentialCareSection
                    optionalPlantDetailsSection
                }
                .padding(.horizontal, 20)

                Button {
                    savePlant()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: trimmedName.isEmpty ? "text.cursor" : (isSaving ? "hourglass" : "leaf.fill"))
                            .accessibilityHidden(true)
                        Text(trimmedName.isEmpty ? l.tr(zh: "请选择品种或填写名称", en: "Choose a species or enter a name", de: "Art wählen oder Namen eingeben") : (isSaving ? l.tr(zh: "正在添加…", en: "Adding...", de: "Wird hinzugefügt...") : l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen")))
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(trimmedName.isEmpty ? Color.ohanaTertiaryText : Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        trimmedName.isEmpty ? Color.ohanaControlFill.opacity(0.72) : Color.goLime,
                        in: Capsule()
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(trimmedName.isEmpty || isSaving)
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
        .onChange(of: roomName) { _, newValue in
            if commonRoomOptions.contains(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                showingCustomRoomField = false
                if focusedField == .room { focusedField = nil }
            }
        }
        .onChange(of: location) { _, newValue in
            if commonSpotOptions.contains(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                showingCustomLocationField = false
                if focusedField == .location { focusedField = nil }
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

    private var addPlantSimpleHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goTeal.opacity(0.16))
                    .frame(width: 54, height: 54)
                Text(avatarEmoji)
                    .font(OhanaFont.adaptive(size: 28))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                    .font(OhanaFont.adaptive(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(profilePreviewName) · \(profilePreviewSpecies)")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("add-plant-name-summary-value")
                Text(carePlanPreviewSummary)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-plant-simple-header")
    }

    private var plantSpeciesPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "选择品种", en: "Choose species", de: "Art wählen"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(l.tr(
                zh: "先选大类，再选品种。选中后会自动填写名称、浇水、施肥和基础环境。",
                en: "Pick a group, then a species. Ohana fills the name, watering, fertilizer, and basic care defaults.",
                de: "Wähle erst eine Gruppe, dann eine Art. Ohana füllt Name, Gießen, Düngen und Basiswerte."
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlantCatalogBrowsingGroup.allCases) { group in
                        catalogGroupButton(group)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)

            Text(selectedCatalogGroup.subtitle(l))
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                catalogSearchResultsList
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(groupedCatalogEntries) { entry in
                        commonPlantChoiceButton(entry)
                    }
                }
                .accessibilityElement(children: .contain)
            }

            catalogSearchField
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-species-picker")
    }

    private func catalogGroupButton(_ group: PlantCatalogBrowsingGroup) -> some View {
        let isSelected = selectedCatalogGroup == group
        return Button {
            selectedCatalogGroup = group
            catalogQuery = ""
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(group.title(l))
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(isSelected ? Color.goLime : Color.ohanaControlFill.opacity(0.62), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(group.title(l))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-catalog-group-\(group.rawValue)")
    }

    private func commonPlantChoiceButton(_ entry: PlantCatalogEntry) -> some View {
        let isSelected = selectedCatalogID == entry.id
        return Button {
            applyCatalog(entry)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.localizedCommonName)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(l.tr(
                    zh: "\(entry.defaultWateringDays)天浇水",
                    en: "Water \(entry.defaultWateringDays)d",
                    de: "\(entry.defaultWateringDays) T. gießen"
                ))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.goLime : Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-common-catalog-\(entry.id)")
    }

    private var nameAndPlaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "名称和位置", en: "Name and place", de: "Name und Ort"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            plantNameSummarySection

            OhanaChoiceChipRow(
                title: l.tr(zh: "房间", en: "Room", de: "Raum"),
                options: commonRoomOptions,
                selection: $roomName,
                identifierPrefix: "add-plant-room-choice"
            )

            if showingCustomRoomField || usesCustomRoomEntry {
                inlineFormField(
                    l.tr(zh: "自定义房间", en: "Custom room", de: "Eigener Raum"),
                    text: $roomName,
                    placeholder: l.tr(zh: "客厅、阳台…", en: "Living room, balcony...", de: "Wohnzimmer, Balkon..."),
                    identifier: "add-plant-room-input",
                    focusField: .room,
                    submitLabel: .next
                )
            } else {
                customInlineEntryButton(
                    title: l.tr(zh: "自定义房间", en: "Custom room", de: "Eigener Raum"),
                    identifier: "add-plant-room-custom-toggle"
                ) {
                    revealCustomRoomField()
                }
            }

            OhanaChoiceChipRow(
                title: l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"),
                options: commonSpotOptions,
                selection: $location,
                identifierPrefix: "add-plant-location-choice"
            )

            if showingCustomLocationField || usesCustomLocationEntry {
                inlineFormField(
                    l.tr(zh: "自定义位置", en: "Custom spot", de: "Eigener Standort"),
                    text: $location,
                    placeholder: l.tr(zh: "南窗边、书桌、花架…", en: "South window, desk, plant stand...", de: "Südfenster, Schreibtisch, Pflanzenregal..."),
                    identifier: "add-plant-location-input",
                    focusField: .location,
                    submitLabel: .done
                )
            } else {
                customInlineEntryButton(
                    title: l.tr(zh: "自定义位置", en: "Custom spot", de: "Eigener Standort"),
                    identifier: "add-plant-location-custom-toggle"
                ) {
                    revealCustomLocationField()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-name-place")
    }

    @ViewBuilder
    private var plantNameSummarySection: some View {
        if selectedCatalog != nil, !isCustomizingName {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(zh: "植物名字", en: "Plant name", de: "Pflanzenname"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)

                    Text(trimmedName.isEmpty ? (selectedCatalog?.localizedCommonName ?? "") : trimmedName)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .accessibilityIdentifier("add-plant-name-summary-secondary-value")
                }

                Spacer(minLength: 8)

                Button {
                    isCustomizingName = true
                    focusedField = .name
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"), systemImage: "pencil")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill.opacity(0.66), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "编辑植物名字", en: "Edit plant name", de: "Pflanzennamen bearbeiten"))
                .accessibilityIdentifier("add-plant-name-edit-action")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(Color.ohanaControlFill.opacity(0.44), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("add-plant-name-summary")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                inlineFormField(
                    l.tr(zh: "植物名字", en: "Plant name", de: "Pflanzenname"),
                    text: $name,
                    placeholder: selectedCatalog?.localizedCommonName ?? l.tr(zh: "我的绿萝", en: "My pothos", de: "Meine Efeutute"),
                    identifier: "add-plant-name-input",
                    focusField: .name,
                    submitLabel: .next
                )

                if let selectedCatalog {
                    Button {
                        name = selectedCatalog.localizedCommonName
                        isCustomizingName = false
                        focusedField = nil
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(
                            l.tr(zh: "使用品种名称", en: "Use species name", de: "Artnamen verwenden"),
                            systemImage: "leaf"
                        )
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .foregroundStyle(Color.goTeal)
                    .accessibilityIdentifier("add-plant-name-use-catalog-action")
                }
            }
        }
    }

    private var essentialCareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "自动护理计划", en: "Automatic care plan", de: "Automatischer Pflegeplan"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedCatalog == nil ? "sparkles" : "checkmark.seal.fill") // a11y: allow decorative care-plan glyph; adjacent text describes the generated plan.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(selectedCatalog == nil ? Color.goTeal : Color.goLime)
                    .frame(width: 44, height: 44)
                    .background((selectedCatalog == nil ? Color.goTeal : Color.goLime).opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(carePlanPreviewSummary)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(carePlanPreviewDetail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(l.tr(zh: "植物提醒", en: "Plant reminders", de: "Pflanzenerinnerungen"), isOn: $remindersEnabled)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-essential-care")
    }

    private var optionalPlantDetailsSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(GoMotion.quick) {
                    showingOptionalPlantDetails.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative optional-details glyph; button text labels the action.
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.goTeal.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "可选细节", en: "Optional details", de: "Optionale Details"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "调整品种备注、头像、照护周期、盆器、来源、光照和健康状态。",
                            en: "Adjust species notes, avatar, care cadence, pot, source, light, and health.",
                            de: "Artnotiz, Symbol, Pflegezyklus, Topf, Quelle, Licht und Zustand anpassen."
                        ))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down") // a11y: allow decorative disclosure glyph; button value exposes expanded state.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .rotationEffect(.degrees(showingOptionalPlantDetails ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("add-plant-optional-details-toggle")
            .accessibilityLabel(l.tr(zh: "可选细节", en: "Optional details", de: "Optionale Details"))
            .accessibilityValue(showingOptionalPlantDetails ? l.tr(zh: "已展开", en: "Expanded", de: "Geöffnet") : l.tr(zh: "已收起", en: "Collapsed", de: "Geschlossen"))

            if showingOptionalPlantDetails {
                VStack(spacing: 12) {
                    speciesOverrideSection
                    avatarPickerSection
                    careAdjustmentSection
                    environmentSection
                    potSection
                    sourceSection
                    healthSection
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("add-plant-optional-details-content")
            }
        }
        .accessibilityIdentifier("add-plant-optional-details")
    }

    private var speciesOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "品种备注", en: "Species note", de: "Artnotiz"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            inlineFormField(
                l.tr(zh: "显示品种", en: "Shown species", de: "Angezeigte Art"),
                text: $species,
                placeholder: l.tr(zh: "如果没有选到准确品种，可手动备注", en: "Add a note if the catalog match is not exact", de: "Notiz ergänzen, falls der Katalogtreffer nicht exakt ist"),
                identifier: "add-plant-species-input",
                focusField: .species,
                submitLabel: .next
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-species-override")
    }

    private var careAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "调整护理周期", en: "Adjust care cadence", de: "Pflegezyklus anpassen"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            Stepper(l.tr(zh: "浇水：每 \(wateringInterval) 天", en: "Water: every \(wateringInterval) days", de: "Gießen: alle \(wateringInterval) Tage"), value: $wateringInterval, in: 1 ... 90)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)

            Stepper(l.tr(zh: "施肥：每 \(fertilizingInterval) 天", en: "Fertilize: every \(fertilizingInterval) days", de: "Düngen: alle \(fertilizingInterval) Tage"), value: $fertilizingInterval, in: 1 ... 365)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goLime)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-care-adjustments")
    }

    private var avatarPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "植物图标", en: "Plant icon", de: "Pflanzensymbol"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

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
                    .accessibilityLabel(l.tr(zh: "选择植物图标 \(emoji)", en: "Choose plant icon \(emoji)", de: "Pflanzensymbol \(emoji) wählen"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-avatar-picker")
    }

    private var catalogSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass") // a11y: allow decorative search glyph; text field placeholder labels the search input.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .accessibilityHidden(true)
            TextField(l.tr(zh: "搜索绿萝、Monstera、吊兰…", en: "Search pothos, Monstera, spider plant...", de: "Efeutute, Monstera, Grünlilie suchen..."), text: $catalogQuery) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .catalogSearch)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.catalogSearch) }
                .accessibilityIdentifier("add-plant-catalog-search-input")

            if !catalogQuery.isEmpty {
                Button {
                    catalogQuery = ""
                    focusedField = nil
                } label: {
                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative clear-search glyph; button has an explicit accessibility label.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "清空搜索", en: "Clear search", de: "Suche löschen"))
                .accessibilityIdentifier("add-plant-catalog-search-clear")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, catalogQuery.isEmpty ? 14 : 2)
        .frame(minHeight: 48)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private var catalogSearchResultsList: some View {
        VStack(spacing: 8) {
            if catalogMatches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "没有找到匹配", en: "No match found", de: "Kein Treffer"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "可以直接填写名称保存；以后在详情里再补品种。",
                        en: "You can save with a custom name and add the species later from details.",
                        de: "Du kannst mit eigenem Namen speichern und die Art später ergänzen."
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func catalogMatchButton(_ result: PlantCatalogSearchResult) -> some View {
        let entry = result.entry
        return Button {
            applyCatalog(entry)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedCatalogID == entry.id ? "checkmark.circle.fill" : "leaf.circle")
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(selectedCatalogID == entry.id ? Color.goLime : Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.localizedCommonName)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(entry.latinName)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                    Text(l.tr(
                        zh: "浇水 \(entry.defaultWateringDays) 天 · 施肥 \(entry.defaultFertilizingDays) 天",
                        en: "Water \(entry.defaultWateringDays)d · fertilize \(entry.defaultFertilizingDays)d",
                        de: "Gießen \(entry.defaultWateringDays) T. · düngen \(entry.defaultFertilizingDays) T."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                catalogChip(
                    entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren
                        ? l.tr(zh: "误食风险", en: "Risk", de: "Risiko")
                        : l.tr(zh: "低风险", en: "Low risk", de: "Gering"),
                    foreground: entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren ? Color.arkInk : Color.ohanaPrimaryText,
                    background: entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren ? Color.goYellow : Color.ohanaControlFill.opacity(0.78)
                )
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
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见盆材质", en: "Common pot materials", de: "Häufige Topfmaterialien"),
                options: commonPotMaterialOptions,
                selection: $potMaterial,
                identifierPrefix: "add-plant-pot-material-choice"
            )
            TextField(l.tr(zh: "盆材质，如陶盆、塑料盆", en: "Pot material, e.g. terracotta or plastic", de: "Topfmaterial, z. B. Ton oder Kunststoff"), text: $potMaterial) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .focused($focusedField, equals: .potMaterial)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.potMaterial) }
                .accessibilityIdentifier("add-plant-pot-material-input")
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见土壤", en: "Common soil", de: "Häufige Erde"),
                options: commonSoilOptions,
                selection: $soilType,
                identifierPrefix: "add-plant-soil-choice"
            )
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
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见来源", en: "Common sources", de: "Häufige Quellen"),
                options: commonSourceOptions,
                selection: $acquisitionSource,
                identifierPrefix: "add-plant-source-choice"
            )
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

    private func inlineFormField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        identifier: String,
        focusField: AddPlantFocusField,
        submitLabel: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)

            TextField(placeholder, text: text) // ui-v4: allow existing form input; add-plant now keeps text fields off the primary path where choices exist.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(
                            focusedField == focusField ? Color.goTeal.opacity(0.58) : Color.ohanaCardSurface.opacity(0.18),
                            lineWidth: focusedField == focusField ? 1.5 : 1
                        )
                )
                .focused($focusedField, equals: focusField)
                .submitLabel(submitLabel)
                .onSubmit { focusAfterSubmit(focusField) }
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func customInlineEntryButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: "plus")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.goTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
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
            focusedField = .room
        case .species:
            focusedField = .room
        case .catalogSearch:
            focusedField = nil
        case .room:
            focusedField = .location
        case .location, .soil, .source:
            focusedField = nil
        case .potMaterial:
            focusedField = .soil
        }
    }

    private func revealCustomRoomField() {
        showingCustomRoomField = true
        focusedField = nil
        OhanaFrameScheduler.runAfterNextFrame {
            focusedField = .room
        }
    }

    private func revealCustomLocationField() {
        showingCustomLocationField = true
        focusedField = nil
        OhanaFrameScheduler.runAfterNextFrame {
            focusedField = .location
        }
    }

    private func applyCatalog(_ entry: PlantCatalogEntry) {
        let previousCatalogName = selectedCatalog?.localizedCommonName ?? ""
        let shouldUseCatalogName = trimmedName.isEmpty || (!previousCatalogName.isEmpty && trimmedName == previousCatalogName)
        let defaults = PlantProfileUXPolicy.catalogDefaults(for: entry)
        selectedCatalogID = entry.id
        catalogQuery = ""
        if shouldUseCatalogName {
            name = defaults.name
            isCustomizingName = false
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
        focusedField = nil
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
