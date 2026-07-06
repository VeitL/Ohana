//
//  PlantBatchQuickRecordSheet.swift
//  Ohana
//
//  Multi-select quick logging for plant care actions.
//

import SwiftData
import SwiftUI

struct PlantBatchQuickRecordSheet: View {
    let plants: [Plant]
    let initialCareType: PlantCareType?
    let imageDataProvider: @Sendable (PersistentIdentifier) async -> Data?
    let onRecord: ([PlantBatchCareSelection]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedCareType: PlantCareType
    @State private var selectedPlantIDs: Set<UUID> = []

    init(
        plants: [Plant],
        initialCareType: PlantCareType? = nil,
        imageDataProvider: @escaping @Sendable (PersistentIdentifier) async -> Data?,
        onRecord: @escaping ([PlantBatchCareSelection]) -> Void
    ) {
        self.plants = plants
        self.initialCareType = initialCareType
        self.imageDataProvider = imageDataProvider
        self.onRecord = onRecord
        _selectedCareType = State(initialValue: initialCareType ?? .watering)
    }

    private var l: L10n { L10n(appLanguage) }
    private var activePlants: [Plant] { plants.sorted { $0.name < $1.name } }
    private var selectedCount: Int { selectedPlantIDs.count }
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "多选快速记录", en: "Multi-select log", de: "Mehrfach erfassen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                typeSelector
                selectionToolbar
                plantGrid
                recordButton
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-batch-quick-record-sheet")
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: careSymbol(for: selectedCareType))
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(careTint(for: selectedCareType))
                .frame(width: 44, height: 44)
                .background(careTint(for: selectedCareType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedCareType.displayName(l: l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(l.tr(
                    zh: selectedCount == 0 ? "先选择要记录的植物" : "将为 \(selectedCount) 株植物写入同一条护理事实",
                    en: selectedCount == 0 ? "Select plants to log" : "Will write one care fact for \(selectedCount) plants",
                    de: selectedCount == 0 ? "Pflanzen auswählen" : "Schreibt eine Pflegeaktion für \(selectedCount) Pflanzen"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "护理类型", en: "Care type", de: "Pflegetyp"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCareTypes) { type in
                        Button {
                            withAnimation(GoMotion.feedback) {
                                selectedCareType = type
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(type.displayName(l: l), systemImage: careSymbol(for: type))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(selectedCareType == type ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    selectedCareType == type ? careTint(for: type) : Color.ohanaControlFill,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-batch-quick-type-\(type.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(GoMotion.quick) {
                    selectedPlantIDs = Set(activePlants.map(\.id))
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Label(l.tr(zh: "全选", en: "Select all", de: "Alle wählen"), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.goPrimary.opacity(0.11), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-batch-quick-select-all")

            Button {
                withAnimation(GoMotion.quick) {
                    selectedPlantIDs.removeAll()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Label(l.tr(zh: "清空", en: "Clear", de: "Leeren"), systemImage: "xmark.circle.fill")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-batch-quick-clear")
        }
    }

    private var plantGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(activePlants, id: \.id) { plant in
                Button {
                    toggle(plant.id)
                } label: {
                    plantCard(plant)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-batch-quick-plant-\(plant.id.uuidString)")
            }
        }
    }

    private func plantCard(_ plant: Plant) -> some View {
        let isSelected = selectedPlantIDs.contains(plant.id)
        return HStack(spacing: 10) {
            FeatureHubAvatar(
                imageCacheID: "plant-batch-quick-\(plant.id.uuidString)",
                imageSignature: plant.avatarThumbnailSignature,
                plantModelID: plant.persistentModelID,
                emoji: "",
                fallback: String(plant.name.prefix(1)),
                tint: Color(hex: plant.themeColorHex)
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(plant.name)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(plant.roomName.isEmpty ? l.tr(zh: "未分组", en: "No room", de: "Kein Raum") : plant.roomName)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(isSelected ? careTint(for: selectedCareType) : Color.ohanaTertiaryText)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(
            isSelected ? careTint(for: selectedCareType).opacity(0.13) : Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(isSelected ? careTint(for: selectedCareType).opacity(0.42) : Color.ohanaCardStroke, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var recordButton: some View {
        Button {
            record()
        } label: {
            Label(recordTitle, systemImage: "checkmark.circle.fill")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(careTint(for: selectedCareType), in: Capsule())
                .opacity(selectedCount == 0 ? 0.45 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(selectedCount == 0)
        .accessibilityIdentifier("plant-batch-quick-record-action")
    }

    private var recordTitle: String {
        l.tr(
            zh: selectedCount == 0 ? "选择植物后记录" : "记录 \(selectedCount) 株 · \(selectedCareType.displayName(l: l))",
            en: selectedCount == 0 ? "Select plants to log" : "Log \(selectedCount) · \(selectedCareType.displayName(l: l))",
            de: selectedCount == 0 ? "Pflanzen auswählen" : "\(selectedCount) erfassen · \(selectedCareType.displayName(l: l))"
        )
    }

    private var quickCareTypes: [PlantCareType] {
        [
            .watering, .fertilizing, .misting, .pruning,
            .leafCleaning, .rotating, .pestCheck, .repotting,
            .newLeaf, .yellowLeaf, .pestFound, .customNote
        ]
    }

    private func toggle(_ id: UUID) {
        withAnimation(GoMotion.quick) {
            if selectedPlantIDs.contains(id) {
                selectedPlantIDs.remove(id)
            } else {
                selectedPlantIDs.insert(id)
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func record() {
        let selections = selectedPlantIDs.map {
            PlantBatchCareSelection(plantID: $0, careType: selectedCareType)
        }
        guard !selections.isEmpty else { return }
        onRecord(selections)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
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
        case .repotting, .rotating, .customNote: Color.goPrimary
        case .pruning: Color.goOrange
        case .pestCheck, .yellowLeaf, .pestFound: Color.goRed
        case .photo: Color.goPurple
        }
    }
}
