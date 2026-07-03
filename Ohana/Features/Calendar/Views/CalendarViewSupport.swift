//
//  CalendarViewSupport.swift
//  Ohana
//
//  Support values and filter controls for CalendarView.
//

import Combine
import SwiftUI

enum CalendarViewMode: String, CaseIterable {
    case month = "月"
    case list = "列表"
}

@MainActor
final class CalendarVisibleDateCoordinator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var pendingDate: Date?
    private var updateTask: Task<Void, Never>?

    deinit {
        updateTask?.cancel()
    }

    func scheduleUpdate(to date: Date, apply: @escaping @MainActor (Date) -> Void) {
        let normalized = Calendar.current.startOfDay(for: date)
        if let pendingDate,
           Calendar.current.isDate(pendingDate, inSameDayAs: normalized) {
            return
        }
        pendingDate = normalized
        guard updateTask == nil else { return }

        updateTask = OhanaFrameScheduler.runAfterNextFrame { [weak self] in
            guard let self else { return }
            let date = pendingDate
            pendingDate = nil
            updateTask = nil
            guard let date else { return }
            apply(date)
        }
    }
}

@MainActor
final class CalendarTimelinePositionCoordinator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var pendingDateID: String?
    private var updateTask: Task<Void, Never>?

    deinit {
        updateTask?.cancel()
    }

    func scheduleUpdate(to dateID: String?, apply: @escaping @MainActor (String?) -> Void) {
        pendingDateID = dateID
        guard updateTask == nil else { return }

        updateTask = OhanaFrameScheduler.runAfterNextFrame { [weak self] in
            guard let self else { return }
            let dateID = pendingDateID
            pendingDateID = nil
            updateTask = nil
            apply(dateID)
        }
    }

    func cancel() {
        pendingDateID = nil
        updateTask?.cancel()
        updateTask = nil
    }
}

struct CalendarFilterSelection: Equatable {
    static let allPlantsToken = "__all_plants__"

    var petId: String
    var humanId: String
    var plantId: String

    static let all = CalendarFilterSelection(petId: "", humanId: "", plantId: "")
    static let allPlants = CalendarFilterSelection(petId: "", humanId: "", plantId: allPlantsToken)

    var selectedPetId: String? { petId.isEmpty ? nil : petId }
    var selectedHumanId: String? { humanId.isEmpty ? nil : humanId }
    var isAllPlantsSelected: Bool { plantId == Self.allPlantsToken }
    var selectedPlantId: String? { plantId.isEmpty || isAllPlantsSelected ? nil : plantId }
    var isPlantScopeSelected: Bool { isAllPlantsSelected || selectedPlantId != nil }
    var normalizedForUserFilterControls: CalendarFilterSelection {
        guard petId.isEmpty, humanId.isEmpty, !plantId.isEmpty, !isAllPlantsSelected else { return self }
        return .allPlants
    }

    var metricScope: String {
        if selectedPetId != nil { return "pet" }
        if selectedHumanId != nil { return "human" }
        if isAllPlantsSelected { return "plants" }
        if selectedPlantId != nil { return "plant" }
        return "all"
    }

    static func pet(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: id, humanId: "", plantId: "")
    }

    static func human(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: "", humanId: id, plantId: "")
    }

    static func plant(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: "", humanId: "", plantId: id)
    }
}

struct CalendarContentHandoffState: Equatable {
    var viewModeRaw: String
    var filter: CalendarFilterSelection
}

nonisolated enum CalendarEmbeddedContentMountPolicy {
    static let inactiveEmbeddedDataLoadDelayMilliseconds: UInt64 = 220
    static let visibleEmbeddedDataLoadDelayMilliseconds: UInt64 = 24
    static let activeEmbeddedDataLoadDelayMilliseconds: UInt64 = 120
    static let inactiveEmbeddedContentDelayMilliseconds: UInt64 = 220
    static let activeEmbeddedContentDelayMilliseconds: UInt64 = 96

    static func shouldRenderMainContent(
        hideToolbar: Bool,
        isEmbeddedPrepared: Bool,
        isEmbeddedVisible: Bool,
        isEmbeddedActive: Bool,
        isContentMounted: Bool
    ) -> Bool {
        guard hideToolbar else { return true }
        guard isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive else { return false }
        return isEmbeddedVisible || isEmbeddedActive || isContentMounted
    }

    static func shouldScheduleDeferredMount(
        hideToolbar: Bool,
        isEmbeddedPrepared: Bool,
        isEmbeddedVisible: Bool,
        isEmbeddedActive: Bool,
        isContentMounted: Bool
    ) -> Bool {
        guard hideToolbar else { return false }
        guard !isContentMounted else { return false }
        return isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    static func contentDelayMilliseconds(isEmbeddedActive: Bool) -> UInt64 {
        isEmbeddedActive ? activeEmbeddedContentDelayMilliseconds : inactiveEmbeddedContentDelayMilliseconds
    }

    static func routeDataLoadDelayMilliseconds(
        hideToolbar: Bool,
        isEmbeddedVisible: Bool,
        isEmbeddedActive: Bool
    ) -> UInt64 {
        guard hideToolbar else { return activeEmbeddedDataLoadDelayMilliseconds }
        if isEmbeddedVisible || isEmbeddedActive {
            return visibleEmbeddedDataLoadDelayMilliseconds
        }
        return isEmbeddedActive
            ? activeEmbeddedDataLoadDelayMilliseconds
            : inactiveEmbeddedDataLoadDelayMilliseconds
    }
}

struct CalendarEventDetailPresentation: Identifiable {
    let event: Event
    let occurrenceDate: Date
    let allowsEditing: Bool

    var id: String {
        "\(event.id.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))-\(allowsEditing)"
    }
}

/// 日历宠物筛选条：点击时只回传本地视觉选择，持久化由 `CalendarView` 下一帧处理。
struct CalendarPetChipFilterBar: View {
    let selection: CalendarFilterSelection
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let onSelect: (CalendarFilterSelection) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { false }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg: Color { Color.arkInk }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var selectedPetId: String? { selection.selectedPetId }
    private var selectedHumanId: String? { selection.selectedHumanId }
    private var isPlantScopeSelected: Bool { selection.isPlantScopeSelected }
    private var showsPlantsChip: Bool { !plants.isEmpty || isPlantScopeSelected }

    var body: some View {
        let l = L10n(AppLanguage.code)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(
                    label: l.tr(zh: "全部", en: "All", de: "Alle"),
                    systemImage: "square.grid.2x2.fill",
                    identifier: "calendar-filter-all",
                    isSelected: selectedPetId == nil && selectedHumanId == nil && !isPlantScopeSelected
                ) {
                    onSelect(.all)
                }
                if showsPlantsChip {
                    chipButton(
                        label: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                        systemImage: "leaf.fill",
                        identifier: "calendar-filter-plants",
                        isSelected: isPlantScopeSelected
                    ) {
                        onSelect(.allPlants)
                    }
                }
                ForEach(pets) { pet in
                    chipButton(
                        label: pet.name,
                        systemImage: pet.speciesSilhouetteSymbol,
                        identifier: "calendar-filter-pet-\(pet.name)",
                        isSelected: selectedPetId == pet.id.uuidString
                    ) {
                        onSelect(.pet(pet.id.uuidString))
                    }
                }
                ForEach(humans) { human in
                    chipButton(
                        label: human.name,
                        systemImage: "person.fill",
                        identifier: "calendar-filter-human-\(human.name)",
                        isSelected: selectedHumanId == human.id.uuidString
                    ) {
                        onSelect(.human(human.id.uuidString))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .accessibilityIdentifier("calendar-filter-chip-bar")
    }

    private func chipButton(
        label: String,
        systemImage: String,
        identifier: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(OhanaFont.subheadline(.bold))
                    .symbolRenderingMode(.monochrome)
                Text(label).font(OhanaFont.subheadline(.bold))
            }
            .foregroundStyle(chipForeground(isSelected: isSelected))
            .frame(minHeight: 44)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(chipBackground(isSelected: isSelected), in: Capsule())
            .shadow(color: isSelected && isMaterial ? chipAccent.opacity(0.25) : .clear, radius: 6, x: 0, y: 2) // ui-v4: allow legacy material calendar chip depth
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaSelectionMotion(isSelected: isSelected, scale: 1.018)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected
            ? L10n.current.tr(zh: "已选中", en: "Selected", de: "Ausgewählt")
            : L10n.current.tr(zh: "未选中", en: "Not selected", de: "Nicht ausgewählt"))
    }

    private func chipForeground(isSelected: Bool) -> Color {
        if isSelected { return chipSelFg }
        if isMaterial { return Color(hex: "8E8E93") }
        return Color.ohanaSecondaryText
    }

    private func chipBackground(isSelected: Bool) -> Color {
        if isSelected { return chipAccent }
        if isMaterial { return matSurface }
        return Color.ohanaControlFill
    }
}
