//
//  PlantBatchCareSheet.swift
//  Ohana
//
//  Value-snapshot batch care checklist for plant dashboard routes.
//

import SwiftData
import SwiftUI

struct PlantBatchCareSheet: View {
    let snapshot: PlantBatchCareSheetSnapshot
    let initialCareType: PlantCareType?
    let imageDataProvider: @Sendable (PersistentIdentifier) async -> Data?
    let onComplete: ([PlantBatchCareSelection]) -> Void
    let onOpenCareLog: (UUID, PlantCareType) -> Void
    let onDeferTask: (PlantBatchCareSheetTask) -> Void
    let onSkipTask: (PlantBatchCareSheetTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @State private var selectedCareType: PlantCareType?
    @State private var selectedTaskIDs: Set<String>

    init(
        snapshot: PlantBatchCareSheetSnapshot,
        initialCareType: PlantCareType? = nil,
        imageDataProvider: @escaping @Sendable (PersistentIdentifier) async -> Data?,
        onComplete: @escaping ([PlantBatchCareSelection]) -> Void,
        onOpenCareLog: @escaping (UUID, PlantCareType) -> Void,
        onDeferTask: @escaping (PlantBatchCareSheetTask) -> Void,
        onSkipTask: @escaping (PlantBatchCareSheetTask) -> Void
    ) {
        self.snapshot = snapshot
        self.initialCareType = initialCareType
        self.imageDataProvider = imageDataProvider
        self.onComplete = onComplete
        self.onOpenCareLog = onOpenCareLog
        self.onDeferTask = onDeferTask
        self.onSkipTask = onSkipTask
        _selectedCareType = State(initialValue: initialCareType)
        _selectedTaskIDs = State(initialValue: Set(snapshot.filterSnapshot(for: initialCareType).taskIDs))
    }

    private var l: L10n { L10n(appLanguage) }

    private var visibleSnapshot: PlantBatchCareSheetFilterSnapshot {
        snapshot.filterSnapshot(for: selectedCareType)
    }

    private var selectedTasks: [PlantBatchCareSheetTask] {
        snapshot.tasks.filter { selectedTaskIDs.contains($0.id) }
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "批量照护", en: "Batch care", de: "Sammelpflege"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                typeChips
                checklist
                bottomAction
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-batch-care-sheet")
        .onChange(of: snapshot.signature) { _, _ in
            selectedTaskIDs = Set(snapshot.filterSnapshot(for: selectedCareType).taskIDs)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checklist.checked") // a11y: allow decorative glyph; title and metrics name this sheet.
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                    Text(l.tr(
                        zh: "先勾选，再一次完成；需要细记的项目可进入详记。",
                        en: "Select items, complete once, or open details for richer logs.",
                        de: "Auswählen, gesammelt erledigen oder Details erfassen."
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                metricPill(
                    icon: "leaf.fill",
                    value: "\(Set(snapshot.tasks.map(\.plantID)).count)",
                    label: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                    tint: Color.goTeal
                )
                metricPill(
                    icon: "checkmark.circle.fill",
                    value: "\(selectedTasks.count)",
                    label: l.tr(zh: "已选", en: "Selected", de: "Gewählt"),
                    tint: Color.goPrimary
                )
                metricPill(
                    icon: "calendar.badge.exclamationmark",
                    value: "\(snapshot.tasks.count)",
                    label: l.tr(zh: "任务", en: "Tasks", de: "Aufgaben"),
                    tint: Color.goYellow
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    title: l.tr(zh: "全部 \(snapshot.allFilter.count)", en: "All \(snapshot.allFilter.count)", de: "Alle \(snapshot.allFilter.count)"),
                    icon: "checklist",
                    isSelected: selectedCareType == nil,
                    tint: Color.goPrimary
                ) {
                    selectCareType(nil)
                }

                ForEach(snapshot.careTypeFilters) { item in
                    chip(
                        title: "\(item.careType?.displayName(l: l) ?? "") \(item.count)",
                        icon: item.careType.map(careSymbol(for:)) ?? "checklist",
                        isSelected: selectedCareType == item.careType,
                        tint: item.careType.map(careTint(for:)) ?? Color.goPrimary
                    ) {
                        selectCareType(item.careType)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityIdentifier("plant-batch-care-type-chips")
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visibleSnapshot.count == 0 {
                emptyState
            } else {
                ForEach(visibleSnapshot.roomSections) { section in
                    roomSection(section.room, tasks: section.tasks)
                }
            }
        }
    }

    private var bottomAction: some View {
        Button {
            let selections = selectedTasks.map(\.selection)
            guard !selections.isEmpty else { return }
            onComplete(selections)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative glyph; button label names action.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .accessibilityHidden(true)
                Text(primaryButtonTitle)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(selectedTasks.isEmpty ? Color.ohanaSecondaryText : Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(selectedTasks.isEmpty ? Color.ohanaControlFill.opacity(0.72) : Color.goPrimary, in: Capsule())
        }
        .disabled(selectedTasks.isEmpty)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-batch-care-complete-selected")
    }

    private var primaryButtonTitle: String {
        if selectedTasks.isEmpty {
            return l.tr(zh: "选择照护项目", en: "Select care items", de: "Aufgaben auswählen")
        }
        if let selectedCareType, selectedTasks.allSatisfy({ $0.careType == selectedCareType }) {
            let name = selectedCareType.displayName(l: l)
            return l.tr(zh: "完成 \(selectedTasks.count) 项\(name)", en: "Complete \(selectedTasks.count) \(name)", de: "\(selectedTasks.count) \(name) erledigen")
        }
        return l.tr(zh: "完成 \(selectedTasks.count) 项照护", en: "Complete \(selectedTasks.count) care tasks", de: "\(selectedTasks.count) Aufgaben erledigen")
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative glyph; text explains state.
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "没有匹配的照护", en: "No matching care", de: "Keine passenden Aufgaben"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "换一个类型，或回到全部查看。", en: "Choose another type or return to all.", de: "Anderen Typ wählen oder alle anzeigen."))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func roomSection(_ room: String, tasks: [PlantBatchCareSheetTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(room)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(l.tr(zh: "\(tasks.count) 项", en: "\(tasks.count) tasks", de: "\(tasks.count) Aufgaben"))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func taskRow(_ task: PlantBatchCareSheetTask) -> some View {
        let isSelected = selectedTaskIDs.contains(task.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    toggle(task)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(OhanaFont.adaptive(size: 22, weight: .black))
                        .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isSelected ? l.tr(zh: "取消选择\(task.plantName)", en: "Deselect \(task.plantName)", de: "\(task.plantName) abwählen") : l.tr(zh: "选择\(task.plantName)", en: "Select \(task.plantName)", de: "\(task.plantName) auswählen"))

                taskAvatar(for: task)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(task.plantName) · \(task.careType.displayName(l: l))")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(task.subtitle) · \(task.dueText)")
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 6)
            }

            HStack(spacing: 8) {
                rowActionButton(
                    symbol: "clock.arrow.circlepath",
                    title: l.tr(zh: "延后", en: "Defer", de: "Später"),
                    label: l.tr(zh: "延后\(task.plantName)", en: "Defer \(task.plantName)", de: "\(task.plantName) verschieben"),
                    identifier: "plant-batch-care-defer-\(task.id)"
                ) {
                    onDeferTask(task)
                    dismiss()
                }

                rowActionButton(
                    symbol: "forward.end.fill",
                    title: l.tr(zh: "跳过", en: "Skip", de: "Überspringen"),
                    label: l.tr(zh: "跳过\(task.plantName)", en: "Skip \(task.plantName)", de: "\(task.plantName) überspringen"),
                    identifier: "plant-batch-care-skip-\(task.id)"
                ) {
                    onSkipTask(task)
                    dismiss()
                }

                rowActionButton(
                    symbol: "square.and.pencil",
                    title: l.tr(zh: "详记", en: "Detail", de: "Details"),
                    label: l.tr(zh: "详记\(task.plantName)", en: "Detailed log for \(task.plantName)", de: "Details für \(task.plantName)"),
                    identifier: "plant-batch-care-detail-\(task.id)"
                ) {
                    onOpenCareLog(task.plantID, task.careType)
                    dismiss()
                }
            }
        }
        .padding(8)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func taskAvatar(for task: PlantBatchCareSheetTask) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if task.avatarSignature.isEmpty {
                    taskAvatarPlaceholder(for: task)
                } else {
                    AsyncDecodedImageView(
                        cacheID: "plant-batch-care-\(task.plantID.uuidString)-avatar",
                        sourceSignature: task.avatarSignature,
                        maxPixel: 96,
                        asyncDataProvider: { await imageDataProvider(task.plantModelID) }
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        taskAvatarPlaceholder(for: task)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            Image(systemName: careSymbol(for: task.careType))
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 18, height: 18) // a11y: allow decorative badge inside non-interactive avatar.
                .background(careTint(for: task.careType), in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.ohanaCardSurface, lineWidth: 1.5)
                }
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private func taskAvatarPlaceholder(for task: PlantBatchCareSheetTask) -> some View {
        let tint = taskTint(for: task)
        return ZStack {
            tint.opacity(0.16)
            Image(systemName: "leaf.fill") // a11y: allow decorative avatar placeholder.
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }

    private func chip(
        title: String,
        icon: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(isSelected ? tint : Color.ohanaControlFill.opacity(0.72), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func rowActionButton(symbol: String, title: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(Color.ohanaCardSurface.opacity(0.74), in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func metricPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func selectCareType(_ type: PlantCareType?) {
        selectedCareType = type
        selectedTaskIDs = Set(snapshot.filterSnapshot(for: type).taskIDs)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggle(_ task: PlantBatchCareSheetTask) {
        if selectedTaskIDs.contains(task.id) {
            selectedTaskIDs.remove(task.id)
        } else {
            selectedTaskIDs.insert(task.id)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func taskTint(for task: PlantBatchCareSheetTask) -> Color {
        let hex = task.tintHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return hex.isEmpty ? Color.goTeal : Color(hex: hex)
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .repotting: "arrow.triangle.2.circlepath"
        case .pruning: "scissors"
        case .misting: "humidity.fill"
        case .rotating: "rotate.3d"
        case .leafCleaning: "sparkles"
        case .pestCheck, .pestFound: "ladybug.fill"
        case .photo: "camera.fill"
        case .newLeaf: "leaf.circle.fill"
        case .yellowLeaf: "exclamationmark.triangle.fill"
        case .customNote: "note.text"
        }
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting: Color.goTeal
        case .fertilizing, .newLeaf, .leafCleaning: Color.goYellow
        case .pestCheck, .pestFound, .yellowLeaf: Color.goOrange
        case .repotting, .pruning, .rotating, .photo, .customNote: Color.goPrimary
        }
    }
}
