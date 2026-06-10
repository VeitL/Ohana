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

struct CalendarFilterSelection: Equatable {
    var petId: String
    var humanId: String

    static let all = CalendarFilterSelection(petId: "", humanId: "")

    var selectedPetId: String? { petId.isEmpty ? nil : petId }
    var selectedHumanId: String? { humanId.isEmpty ? nil : humanId }

    static func pet(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: id, humanId: "")
    }

    static func human(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: "", humanId: id)
    }
}

struct CalendarContentHandoffState: Equatable {
    var viewModeRaw: String
    var filter: CalendarFilterSelection
}

/// 日历宠物筛选条：点击时只回传本地视觉选择，持久化由 `CalendarView` 下一帧处理。
struct CalendarPetChipFilterBar: View {
    let selection: CalendarFilterSelection
    let pets: [Pet]
    let humans: [Human]
    let onSelect: (CalendarFilterSelection) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { false }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg: Color { Color.arkInk }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var selectedPetId: String? { selection.selectedPetId }
    private var selectedHumanId: String? { selection.selectedHumanId }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "全部", systemImage: "square.grid.2x2.fill", isSelected: selectedPetId == nil && selectedHumanId == nil) {
                    onSelect(.all)
                }
                ForEach(pets) { pet in
                    chipButton(label: pet.name, systemImage: pet.speciesSilhouetteSymbol, isSelected: selectedPetId == pet.id.uuidString) {
                        onSelect(.pet(pet.id.uuidString))
                    }
                }
                ForEach(humans) { human in
                    chipButton(label: human.name, systemImage: "person.fill", isSelected: selectedHumanId == human.id.uuidString) {
                        onSelect(.human(human.id.uuidString))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
    }

    private func chipButton(label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(OhanaFont.subheadline(.bold))
                    .symbolRenderingMode(.monochrome)
                Text(label).font(OhanaFont.subheadline(.bold))
            }
            .foregroundStyle(chipForeground(isSelected: isSelected))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(chipBackground(isSelected: isSelected), in: Capsule())
            .shadow(color: isSelected && isMaterial ? chipAccent.opacity(0.25) : .clear, radius: 6, x: 0, y: 2) // ui-v4: allow legacy material calendar chip depth
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaSelectionMotion(isSelected: isSelected, scale: 1.018)
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
