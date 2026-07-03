//
//  PlantDetailEditSheet.swift
//  Ohana
//
//  Edit form for the plant detail route.
//

import SwiftData
import SwiftUI

private enum PlantEditFocusSection: String, CaseIterable, Identifiable {
    case all
    case identity
    case care
    case environment
    case potting
    case growth
    case safety
    case notes

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:
            "square.grid.2x2.fill"
        case .identity:
            "person.text.rectangle.fill"
        case .care:
            "calendar.badge.clock"
        case .environment:
            "sun.max.fill"
        case .potting:
            "shippingbox.fill"
        case .growth:
            "ruler.fill"
        case .safety:
            "shield.checkered"
        case .notes:
            "note.text"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alles")
        case .identity:
            l.tr(zh: "身份", en: "Identity", de: "Identität")
        case .care:
            l.tr(zh: "护理", en: "Care", de: "Pflege")
        case .environment:
            l.tr(zh: "环境", en: "Environment", de: "Umgebung")
        case .potting:
            l.tr(zh: "盆土", en: "Potting", de: "Topf")
        case .growth:
            l.tr(zh: "成长", en: "Growth", de: "Wachstum")
        case .safety:
            l.tr(zh: "安全", en: "Safety", de: "Sicherheit")
        case .notes:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }
}

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
    @State private var selectedEditFocus: PlantEditFocusSection = .all
    private var l: L10n { L10n(appLanguage) }

    private var commonCatalogEntries: [PlantCatalogEntry] {
        [
            "epipremnum-aureum",
            "monstera-deliciosa",
            "chlorophytum-comosum",
            "sansevieria-trifasciata",
            "zamioculcas-zamiifolia",
            "pilea-peperomioides"
        ].compactMap { PlantCatalog.entry(id: $0) }
    }

    private var commonRoomOptions: [String] {
        [
            l.tr(zh: "客厅", en: "Living room", de: "Wohnzimmer"),
            l.tr(zh: "阳台", en: "Balcony", de: "Balkon"),
            l.tr(zh: "卧室", en: "Bedroom", de: "Schlafzimmer"),
            l.tr(zh: "厨房", en: "Kitchen", de: "Küche"),
            l.tr(zh: "书房", en: "Study", de: "Arbeitszimmer"),
            l.tr(zh: "浴室", en: "Bathroom", de: "Bad"),
            l.tr(zh: "办公室", en: "Office", de: "Büro")
        ]
    }

    private var commonSpotOptions: [String] {
        [
            l.tr(zh: "南窗边", en: "South window", de: "Südfenster"),
            l.tr(zh: "东窗边", en: "East window", de: "Ostfenster"),
            l.tr(zh: "西窗边", en: "West window", de: "Westfenster"),
            l.tr(zh: "北窗边", en: "North window", de: "Nordfenster"),
            l.tr(zh: "窗台", en: "Window sill", de: "Fensterbank"),
            l.tr(zh: "书桌", en: "Desk", de: "Schreibtisch"),
            l.tr(zh: "花架", en: "Plant stand", de: "Pflanzenregal")
        ]
    }

    private var commonPotMaterialOptions: [String] {
        [
            l.tr(zh: "陶盆", en: "Terracotta", de: "Terrakotta"),
            l.tr(zh: "塑料盆", en: "Plastic", de: "Kunststoff"),
            l.tr(zh: "釉面陶瓷", en: "Glazed ceramic", de: "Glasierte Keramik"),
            l.tr(zh: "自吸水盆", en: "Self-watering", de: "Selbstbewässernd")
        ]
    }

    private var commonSoilOptions: [String] {
        [
            l.tr(zh: "疏松排水型通用土", en: "Loose all-purpose mix", de: "Lockere Universalerde"),
            l.tr(zh: "多肉/仙人掌土", en: "Succulent mix", de: "Sukkulentenerde"),
            l.tr(zh: "观叶植物土", en: "Foliage plant mix", de: "Grünpflanzenerde"),
            l.tr(zh: "树皮颗粒混合土", en: "Bark chunky mix", de: "Rindensubstrat")
        ]
    }

    private var commonSourceOptions: [String] {
        [
            l.tr(zh: "花市", en: "Plant market", de: "Pflanzenmarkt"),
            l.tr(zh: "花店", en: "Plant shop", de: "Pflanzengeschäft"),
            l.tr(zh: "朋友分株", en: "Friend's cutting", de: "Ableger von Freunden"),
            l.tr(zh: "网购", en: "Online order", de: "Online bestellt")
        ]
    }

    private struct PlantEditReadinessItem: Identifiable {
        let id: String
        let title: String
        let isComplete: Bool
    }

    private var selectedCatalogEntry: PlantCatalogEntry? {
        catalogSpeciesId.isEmpty ? nil : PlantCatalog.entry(id: catalogSpeciesId)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSpecies: String {
        species.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedRoomName: String {
        roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var profileReadinessItems: [PlantEditReadinessItem] {
        [
            PlantEditReadinessItem(
                id: "identity",
                title: l.tr(zh: "身份", en: "Identity", de: "Identität"),
                isComplete: !trimmedName.isEmpty && (selectedCatalogEntry != nil || !trimmedSpecies.isEmpty)
            ),
            PlantEditReadinessItem(
                id: "place",
                title: l.tr(zh: "位置", en: "Place", de: "Standort"),
                isComplete: !trimmedRoomName.isEmpty || !trimmedLocation.isEmpty
            ),
            PlantEditReadinessItem(
                id: "care",
                title: l.tr(zh: "计划", en: "Plan", de: "Plan"),
                isComplete: wateringInterval > 0 && fertilizingInterval > 0
            ),
            PlantEditReadinessItem(
                id: "environment",
                title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"),
                isComplete: windowDirection != .unknown || lastLightMeasurementLux > 0 || selectedCatalogEntry != nil
            ),
            PlantEditReadinessItem(
                id: "safety",
                title: l.tr(zh: "安全", en: "Safety", de: "Sicherheit"),
                isComplete: isIndoorSuitable || safetyRiskCount == 0
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

    private var safetyRiskCount: Int {
        [isToxicToCats, isToxicToDogs, isToxicToChildren].count(where: { $0 })
    }

    private var editOverviewTitle: String {
        if recalculationImpacts.isEmpty {
            return l.tr(zh: "档案已保持稳定", en: "Profile stays stable", de: "Profil bleibt stabil")
        }
        return l.tr(zh: "保存前先看影响", en: "Review save impact", de: "Auswirkung vor dem Speichern prüfen")
    }

    private var draftProfileName: String {
        trimmedName.isEmpty ? l.tr(zh: "未命名植物", en: "Unnamed plant", de: "Unbenannte Pflanze") : trimmedName
    }

    private var draftProfileSpecies: String {
        if let selectedCatalogEntry {
            return selectedCatalogEntry.localizedCommonName
        }
        if !trimmedSpecies.isEmpty {
            return trimmedSpecies
        }
        return l.tr(zh: "物种待补充", en: "Species missing", de: "Art fehlt")
    }

    private var draftPlaceSummary: String {
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
            ? l.tr(zh: "室内位置待补充", en: "Indoor place missing", de: "Innenstandort fehlt")
            : l.tr(zh: "户外位置待补充", en: "Outdoor place missing", de: "Außenstandort fehlt")
    }

    private var draftCareSummary: String {
        l.tr(
            zh: "浇水 \(wateringInterval) 天 · 施肥 \(fertilizingInterval) 天",
            en: "Water \(wateringInterval)d · fertilize \(fertilizingInterval)d",
            de: "Gießen \(wateringInterval) T. · düngen \(fertilizingInterval) T."
        )
    }

    private var draftEnvironmentSummary: String {
        let lightText = lastLightMeasurementLux > 0
            ? "\(lightLevel.displayName) · \(lastLightMeasurementLux) lux"
            : lightLevel.displayName
        return "\(isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "户外", en: "Outdoor", de: "Draußen")) · \(lightText)"
    }

    private var draftSafetySummary: String {
        if safetyRiskCount > 0 {
            return l.tr(zh: "\(safetyRiskCount) 项误食风险", en: "\(safetyRiskCount) ingestion risks", de: "\(safetyRiskCount) Verschluckrisiken")
        }
        if !isIndoorSuitable {
            return l.tr(zh: "不建议室内摆放", en: "Not ideal indoors", de: "Nicht ideal für drinnen")
        }
        return l.tr(zh: "家庭低风险", en: "Low household risk", de: "Geringes Haushaltsrisiko")
    }

    private var editFocusSummary: String {
        switch selectedEditFocus {
        case .all:
            l.tr(zh: "全部字段 · \(profileCompletionPercent)% 档案完整度", en: "All fields · \(profileCompletionPercent)% profile complete", de: "Alle Felder · \(profileCompletionPercent)% Profil")
        case .identity:
            "\(draftProfileName) · \(draftProfileSpecies)"
        case .care:
            draftCareSummary
        case .environment:
            draftEnvironmentSummary
        case .potting:
            pottingFocusStatus
        case .growth:
            growthFocusStatus
        case .safety:
            draftSafetySummary
        case .notes:
            notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? l.tr(zh: "暂无备注", en: "No notes yet", de: "Noch keine Notizen")
                : l.tr(zh: "已记录备注", en: "Notes saved in draft", de: "Notizen im Entwurf")
        }
    }

    private var pottingFocusStatus: String {
        var items: [String] = []
        if potDiameterCm > 0 {
            items.append(l.tr(zh: "\(Int(potDiameterCm)) cm 盆", en: "\(Int(potDiameterCm)) cm pot", de: "\(Int(potDiameterCm)) cm Topf"))
        }
        if !potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if isHydroponic {
            items.append(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"))
        }
        if isSucculent {
            items.append(l.tr(zh: "多肉", en: "Succulent", de: "Sukkulente"))
        }
        return items.isEmpty
            ? l.tr(zh: "盆土待补充", en: "Potting missing", de: "Topfdetails fehlen")
            : items.prefix(2).joined(separator: " · ")
    }

    private var growthFocusStatus: String {
        var items: [String] = []
        if hasAcquiredDate {
            items.append(l.tr(zh: "有购入日期", en: "Acquired date set", de: "Kaufdatum gesetzt"))
        }
        if !acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if currentHeightCm > 0 {
            items.append(l.tr(zh: "\(Int(currentHeightCm)) cm 高", en: "\(Int(currentHeightCm)) cm tall", de: "\(Int(currentHeightCm)) cm hoch"))
        }
        if currentSpreadCm > 0 {
            items.append(l.tr(zh: "\(Int(currentSpreadCm)) cm 冠幅", en: "\(Int(currentSpreadCm)) cm spread", de: "\(Int(currentSpreadCm)) cm breit"))
        }
        return items.isEmpty
            ? l.tr(zh: "成长线索待补充", en: "Growth details missing", de: "Wachstumsdetails fehlen")
            : items.prefix(2).joined(separator: " · ")
    }

    var body: some View {
        OhanaSheetWrapper(title: l.tr(zh: "编辑植物", en: "Edit plant", de: "Pflanze bearbeiten"), onDismiss: { dismiss() }) {
            VStack(spacing: 16) {
                editProfileOverview
                editFocusSwitcher
                focusedEditSections
                recalculationNoticeSection

                Button { save() } label: {
                    Text(isSaving ? l.tr(zh: "保存中…", en: "Saving...", de: "Speichern...") : l.tr(zh: "保存", en: "Save", de: "Speichern")).capsuleButton()
                }
                .padding(.top, 8)
                .disabled(isSaving)
                .accessibilityIdentifier("plant-edit-save-action")
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-edit-sheet")
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

    private var editFocusSwitcher: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "slider.horizontal.3") // a11y: allow decorative edit-focus glyph; section heading names the control.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .frame(width: 44, height: 44)
                    .background(Color.goLime.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "编辑重点", en: "Edit focus", de: "Bearbeitungsfokus"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(editFocusSummary)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlantEditFocusSection.allCases) { section in
                        editFocusButton(section)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("plant-edit-focus-switcher")
    }

    private func editFocusButton(_ section: PlantEditFocusSection) -> some View {
        let isSelected = selectedEditFocus == section
        let tint = editFocusTint(for: section)
        return Button {
            withAnimation(GoMotion.selection) {
                selectedEditFocus = section
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: section.icon) // a11y: allow decorative focus glyph; button text names the section.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : tint)
                    .accessibilityHidden(true)
                Text(section.title(l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(editFocusStatus(for: section))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.76) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 102, alignment: .leading)
            .frame(minHeight: 82, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? tint : Color.ohanaControlFill.opacity(0.52), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : tint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(section.title(l)), \(editFocusStatus(for: section))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("plant-edit-focus-\(section.rawValue)")
    }

    private func editFocusTint(for section: PlantEditFocusSection) -> Color {
        switch section {
        case .all:
            Color.goLime
        case .identity:
            Color.goTeal
        case .care:
            remindersEnabled ? Color.goLime : Color.goYellow
        case .environment:
            isNearClimateSource ? Color.goYellow : Color.goTeal
        case .potting:
            potHasDrainage ? Color.goTeal : Color.goYellow
        case .growth:
            Color.goLime
        case .safety:
            safetyRiskCount > 0 || !isIndoorSuitable ? Color.goYellow : Color.goLime
        case .notes:
            Color.goTeal
        }
    }

    private func editFocusStatus(for section: PlantEditFocusSection) -> String {
        switch section {
        case .all:
            "\(profileCompletionPercent)%"
        case .identity:
            selectedCatalogEntry == nil
                ? l.tr(zh: "待匹配", en: "Match", de: "Abgleich")
                : l.tr(zh: "已匹配", en: "Matched", de: "Verknüpft")
        case .care:
            remindersEnabled
                ? l.tr(zh: "提醒开", en: "Alerts on", de: "Hinweise an")
                : l.tr(zh: "提醒关", en: "Alerts off", de: "Hinweise aus")
        case .environment:
            lightLevel.displayName
        case .potting:
            potDiameterCm > 0 || !soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? l.tr(zh: "已记录", en: "Set", de: "Gesetzt")
                : l.tr(zh: "待补充", en: "Missing", de: "Fehlt")
        case .growth:
            currentHeightCm > 0 || currentSpreadCm > 0 || hasAcquiredDate
                ? l.tr(zh: "有线索", en: "Tracked", de: "Erfasst")
                : l.tr(zh: "待补充", en: "Missing", de: "Fehlt")
        case .safety:
            draftSafetySummary
        case .notes:
            notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? l.tr(zh: "空", en: "Empty", de: "Leer")
                : l.tr(zh: "已写", en: "Written", de: "Notiert")
        }
    }

    @ViewBuilder
    private var focusedEditSections: some View {
        switch selectedEditFocus {
        case .all:
            profileSection
            catalogSection
            cycleSection
            environmentSection
            potSection
            sourceAndSizeSection
            healthAndSafetySection
            notesSection
        case .identity:
            profileSection
            catalogSection
        case .care:
            cycleSection
        case .environment:
            environmentSection
        case .potting:
            potSection
        case .growth:
            sourceAndSizeSection
        case .safety:
            healthAndSafetySection
        case .notes:
            notesSection
        }
    }

    private var editProfileOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goTeal.opacity(0.16))
                        .frame(width: 58, height: 58)
                    Text(avatarEmoji.isEmpty ? plant.avatarEmoji : avatarEmoji)
                        .font(OhanaFont.adaptive(size: 30))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(editOverviewTitle)
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(draftProfileName) · \(draftProfileSpecies)")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(draftPlaceSummary)
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
                    Text(l.tr(zh: "档案", en: "profile", de: "Profil"))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                }
                .accessibilityElement(children: .combine)
            }

            ProgressView(value: Double(completedProfileReadinessCount), total: Double(max(profileReadinessItems.count, 1)))
                .tint(Color.goLime)
                .accessibilityLabel(l.tr(zh: "植物档案完整度", en: "Plant profile completeness", de: "Pflanzenprofil-Vollständigkeit"))
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

            VStack(alignment: .leading, spacing: 8) {
                editOverviewFact(icon: "calendar.badge.clock", title: l.tr(zh: "照护节奏", en: "Care rhythm", de: "Pflegerhythmus"), value: draftCareSummary, tint: Color.goYellow)
                editOverviewFact(icon: "sun.max.fill", title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"), value: draftEnvironmentSummary, tint: Color.goTeal)
                editOverviewFact(icon: "shield.checkered", title: l.tr(zh: "安全", en: "Safety", de: "Sicherheit"), value: draftSafetySummary, tint: safetyRiskCount > 0 ? Color.goYellow : Color.goLime)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("plant-edit-profile-overview")
    }

    private func readinessPill(_ item: PlantEditReadinessItem) -> some View {
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

    private func editOverviewFact(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28) // a11y: allow non-interactive overview glyph; adjacent text carries the fact.
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var profileSection: some View {
        VStack(spacing: 12) {
            formField(l.tr(zh: "名称", en: "Name", de: "Name"), text: $name, identifier: "plant-edit-name-input")
            commonCatalogChoiceSection
            formField(l.tr(zh: "物种名", en: "Species", de: "Art"), text: $species, identifier: "plant-edit-species-input")
            OhanaChoiceChipRow(
                title: l.tr(zh: "常用房间", en: "Common rooms", de: "Häufige Räume"),
                options: commonRoomOptions,
                selection: $roomNameRaw,
                identifierPrefix: "plant-edit-room-choice"
            )
            formField(l.tr(zh: "房间", en: "Room", de: "Raum"), text: $roomNameRaw, identifier: "plant-edit-room-input")
            OhanaChoiceChipRow(
                title: l.tr(zh: "常用位置", en: "Common spots", de: "Häufige Plätze"),
                options: commonSpotOptions,
                selection: $location,
                identifierPrefix: "plant-edit-location-choice"
            )
            formField(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), text: $location, identifier: "plant-edit-location-input")
            formField(l.tr(zh: "头像 Emoji", en: "Avatar emoji", de: "Avatar-Emoji"), text: $avatarEmoji)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var commonCatalogChoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l.tr(zh: "常见植物", en: "Common plants", de: "Häufige Pflanzen"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonCatalogEntries) { entry in
                        commonCatalogChoiceButton(entry)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
        }
        .accessibilityIdentifier("plant-edit-common-catalog")
    }

    private func commonCatalogChoiceButton(_ entry: PlantCatalogEntry) -> some View {
        let isSelected = catalogSpeciesId == entry.id
        return Button {
            withAnimation(GoMotion.selection) {
                catalogSpeciesId = entry.id
            }
            UISelectionFeedbackGenerator().selectionChanged()
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
            .frame(width: 104, alignment: .leading)
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
        .accessibilityIdentifier("plant-edit-common-catalog-\(entry.id)")
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
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见盆材质", en: "Common pot materials", de: "Häufige Topfmaterialien"),
                options: commonPotMaterialOptions,
                selection: $potMaterialRaw,
                identifierPrefix: "plant-edit-pot-material-choice"
            )
            formField(l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), text: $potMaterialRaw)
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见土壤", en: "Common soil", de: "Häufige Erde"),
                options: commonSoilOptions,
                selection: $soilTypeRaw,
                identifierPrefix: "plant-edit-soil-choice"
            )
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
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见来源", en: "Common sources", de: "Häufige Quellen"),
                options: commonSourceOptions,
                selection: $acquisitionSourceRaw,
                identifierPrefix: "plant-edit-source-choice"
            )
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

    @ViewBuilder
    private func formField(_ title: String, text: Binding<String>, identifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .medium))
                .foregroundStyle(Color.ohanaSecondaryText)
            if let identifier {
                TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .textFieldStyle(.plain)
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .accessibilityIdentifier(identifier)
            } else {
                TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .textFieldStyle(.plain)
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
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
