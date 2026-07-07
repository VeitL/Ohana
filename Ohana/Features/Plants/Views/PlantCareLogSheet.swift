//
//  PlantCareLogSheet.swift
//  Ohana
//
//  Lightweight confirmation sheet for plant care and observation logs.
//

import PhotosUI
import SwiftUI

private struct PlantCareLogNoteSuggestion: Identifiable {
    let id: String
    let text: String
}

private struct PlantCareLogCompactNotice: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .plantCareLogFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityElement(children: .combine)
    }
}

private struct PlantCareLogPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private extension View {
    func plantCareLogFlatBlockSurface(cornerRadius: CGFloat) -> some View {
        background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PlantCareLogSheet: View {
    let plant: Plant
    let onSave: (PlantCareType, String, PlantHealthStatus, Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedCareCategory: PlantCareCategory
    @State private var selectedCareType: PlantCareType
    @State private var selectedHealthStatus: PlantHealthStatus
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isLoadingPhoto = false
    @State private var showsAdvancedOptions = false
    @State private var note = ""

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { careTint(for: selectedCareType) }
    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var visibleCareTypes: [PlantCareType] {
        selectedCareCategory.careTypes
    }

    private var suggestedNotes: [PlantCareLogNoteSuggestion] {
        switch selectedCareType {
        case .watering:
            [
                PlantCareLogNoteSuggestion(id: "soil-dry", text: l.tr(zh: "表土已干，浇透到盆底出水。", en: "Top soil was dry; watered until drainage.", de: "Obererde trocken; gegossen bis Ablauf.")),
                PlantCareLogNoteSuggestion(id: "soil-wet", text: l.tr(zh: "土仍偏湿，只少量补水。", en: "Soil still damp; light top-up only.", de: "Erde noch feucht; nur leicht ergänzt.")),
                PlantCareLogNoteSuggestion(id: "leaf-response", text: l.tr(zh: "叶片轻微软垂，浇水后观察恢复。", en: "Leaves slightly drooped; recheck after watering.", de: "Blätter leicht schlaff; nach Gießen prüfen."))
            ]
        case .fertilizing:
            [
                PlantCareLogNoteSuggestion(id: "diluted", text: l.tr(zh: "使用稀释肥，避开叶片和新伤口。", en: "Used diluted fertilizer; avoided leaves and wounds.", de: "Verdünnt gedüngt; Blätter/Wunden gemieden.")),
                PlantCareLogNoteSuggestion(id: "skip-stress", text: l.tr(zh: "状态不稳，暂缓施肥。", en: "Plant looks unstable; skipped fertilizer.", de: "Instabiler Zustand; Düngen pausiert."))
            ]
        case .pestCheck:
            [
                PlantCareLogNoteSuggestion(id: "leaf-clear", text: l.tr(zh: "叶背、茎节和土面未见虫害。", en: "Leaf undersides, nodes, and soil looked clear.", de: "Blattunterseiten, Knoten und Erde unauffällig.")),
                PlantCareLogNoteSuggestion(id: "sticky-trace", text: l.tr(zh: "发现粘液/小黑点，继续隔离观察。", en: "Sticky marks or black specks found; keep isolated.", de: "Klebrige Stellen/schwarze Punkte; isoliert lassen."))
            ]
        case .yellowLeaf:
            [
                PlantCareLogNoteSuggestion(id: "lower-leaf", text: l.tr(zh: "底部老叶变黄，数量少。", en: "A few lower older leaves yellowed.", de: "Einige ältere untere Blätter gelb.")),
                PlantCareLogNoteSuggestion(id: "spread", text: l.tr(zh: "黄叶范围扩大，需要复查浇水和光照。", en: "Yellowing spread; recheck water and light.", de: "Gelbfärbung breitet sich aus; Wasser/Licht prüfen."))
            ]
        case .pestFound:
            [
                PlantCareLogNoteSuggestion(id: "isolated", text: l.tr(zh: "已隔离，擦拭叶片并拍照记录。", en: "Isolated, wiped leaves, and documented with photo.", de: "Isoliert, Blätter abgewischt, Foto dokumentiert.")),
                PlantCareLogNoteSuggestion(id: "treatment", text: l.tr(zh: "处理后 3 天复查叶背和新芽。", en: "Recheck leaf undersides and new growth in 3 days.", de: "In 3 Tagen Blattunterseiten/Neutriebe prüfen."))
            ]
        case .photo, .newLeaf:
            [
                PlantCareLogNoteSuggestion(id: "new-growth", text: l.tr(zh: "新叶展开，颜色正常。", en: "New leaf unfurled with normal color.", de: "Neues Blatt entfaltet, Farbe normal.")),
                PlantCareLogNoteSuggestion(id: "growth-angle", text: l.tr(zh: "同角度拍照，方便比较成长。", en: "Captured same angle for growth comparison.", de: "Gleicher Winkel für Wachstumsvergleich."))
            ]
        case .repotting:
            [
                PlantCareLogNoteSuggestion(id: "root-check", text: l.tr(zh: "检查根系，去除枯根后换盆。", en: "Checked roots and removed dead roots before repotting.", de: "Wurzeln geprüft, tote entfernt und umgetopft.")),
                PlantCareLogNoteSuggestion(id: "aftercare", text: l.tr(zh: "换盆后暂缓施肥，观察一周。", en: "After repotting, hold fertilizer and watch for a week.", de: "Nach Umtopfen Dünger pausieren, eine Woche beobachten."))
            ]
        default:
            [
                PlantCareLogNoteSuggestion(id: "routine", text: l.tr(zh: "状态稳定，按计划护理。", en: "Stable; continued routine care.", de: "Stabil; Routinepflege fortgesetzt.")),
                PlantCareLogNoteSuggestion(id: "watch", text: l.tr(zh: "需要继续观察叶片、土壤和光照。", en: "Keep watching leaves, soil, and light.", de: "Blätter, Erde und Licht weiter beobachten."))
            ]
        }
    }

    init(
        plant: Plant,
        initialCareType: PlantCareType,
        currentHealthStatus: PlantHealthStatus,
        onSave: @escaping (PlantCareType, String, PlantHealthStatus, Data?) -> Void
    ) {
        self.plant = plant
        self.onSave = onSave
        _selectedCareCategory = State(initialValue: initialCareType.careCategory)
        _selectedCareType = State(initialValue: initialCareType)
        _selectedHealthStatus = State(initialValue: currentHealthStatus)
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "记录植物护理", en: "Log plant care", de: "Pflanzenpflege erfassen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                plantCareSheetHero
                careTypePicker
                compactSaveNotice
                advancedOptionsToggle
                if showsAdvancedOptions {
                    advancedOptionsSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                saveButton
            }
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("plant-care-log-sheet")
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(from: item)
        }
        .onChange(of: selectedCareType) { _, type in
            selectedCareCategory = type.careCategory
        }
    }

    private var plantCareSheetHero: some View {
        HStack(spacing: 12) {
            Image(systemName: careSymbol(for: selectedCareType)) // a11y: allow decorative sheet glyph; heading names the log.
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 44, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "记录护理", en: "Log care", de: "Pflege erfassen"))
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(plant.name) · \(selectedCareType.displayName(l: l))")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-log-hero")
    }

    private var compactSaveNotice: some View {
        PlantCareLogCompactNotice(
            icon: "clock.arrow.circlepath",
            text: careTypeHint(selectedCareType),
            tint: tint
        )
        .accessibilityIdentifier("plant-care-log-summary")
    }

    private var careTypePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "护理类型", en: "Care type", de: "Pflegetyp"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlantCareCategory.allCases) { category in
                        categoryChip(category)
                            .accessibilityIdentifier("plant-care-log-category-\(category.rawValue)")
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(visibleCareTypes) { type in
                    chipButton(
                        title: type.displayName(l: l),
                        icon: careSymbol(for: type),
                        tint: careTint(for: type),
                        isSelected: selectedCareType == type
                    ) {
                        selectedCareType = type
                    }
                    .accessibilityIdentifier("plant-care-log-type-\(type.rawValue)")
                }
            }
        }
        .padding(14)
        .plantCareLogFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("plant-care-log-type-picker")
    }

    private func categoryChip(_ category: PlantCareCategory) -> some View {
        let isSelected = selectedCareCategory == category
        return Button {
            selectedCareCategory = category
            if !category.contains(selectedCareType) {
                selectedCareType = category.defaultCareType
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(category.shortTitle(l: l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(minWidth: 86)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .background(
                isSelected ? category.tint : Color.ohanaControlFill.opacity(0.72),
                in: Capsule()
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var advancedOptionsToggle: some View {
        Button {
            withAnimation(GoMotion.feedback) {
                showsAdvancedOptions.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3") // a11y: allow decorative options glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28) // a11y: allow visual glyph frame; button text names the action.
                    .accessibilityHidden(true)
                Text(l.tr(zh: "更多记录选项", en: "More log options", de: "Mehr Eintragsoptionen"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 8)
                Text(advancedSummaryText)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.down") // a11y: allow decorative disclosure glyph; button value exposes expanded state.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .rotationEffect(.degrees(showsAdvancedOptions ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 12)
            .plantCareLogFlatBlockSurface(cornerRadius: OhanaRadius.control)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: showsAdvancedOptions ? "收起更多记录选项" : "展开更多记录选项", en: showsAdvancedOptions ? "Collapse more log options" : "Expand more log options", de: showsAdvancedOptions ? "Mehr Optionen einklappen" : "Mehr Optionen ausklappen"))
        .accessibilityValue(showsAdvancedOptions ? l.tr(zh: "已展开", en: "Expanded", de: "Geöffnet") : l.tr(zh: "已收起", en: "Collapsed", de: "Geschlossen"))
        .accessibilityIdentifier("plant-care-log-advanced-toggle")
    }

    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            photoAttachmentSection
            suggestedNotesSection
            noteSection
        }
        .padding(14)
        .plantCareLogFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-log-advanced-options")
    }

    private var advancedSummaryText: String {
        var parts: [String] = []
        if selectedPhotoData != nil {
            parts.append(l.tr(zh: "有照片", en: "Photo", de: "Foto"))
        }
        if !trimmedNote.isEmpty {
            parts.append(l.tr(zh: "有备注", en: "Note", de: "Notiz"))
        }
        return parts.isEmpty ? l.tr(zh: "可选", en: "Optional", de: "Optional") : parts.joined(separator: " · ")
    }

    private var suggestedNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "建议备注", en: "Suggested notes", de: "Notizvorschläge"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedNotes) { suggestion in
                        Button {
                            appendSuggestedNote(suggestion.text)
                        } label: {
                            Text(suggestion.text)
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 168, idealWidth: 220, maxWidth: 260, alignment: .leading)
                                .frame(minHeight: 54, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.ohanaControlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(l.tr(zh: "加入备注：\(suggestion.text)", en: "Add note: \(suggestion.text)", de: "Notiz hinzufügen: \(suggestion.text)"))
                        .accessibilityIdentifier("plant-care-log-note-suggestion-\(suggestion.id)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
        }
        .accessibilityIdentifier("plant-care-log-suggested-notes")
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "备注", en: "Note", de: "Notiz"))
            GoDraftTextEditor(
                l.tr(zh: "例如：土还湿、叶背正常、发现黄叶位置...", en: "Example: soil still wet, leaf undersides clear, yellow leaf location...", de: "Beispiel: Erde noch feucht, Blattunterseiten sauber, Ort gelber Blätter..."),
                text: $note,
                minHeight: 88
            )
            .padding(10)
            .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .accessibilityIdentifier("plant-care-log-note")
        }
    }

    private var photoAttachmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "照片", en: "Photo", de: "Foto"))

            if let photoData = selectedPhotoData {
                VStack(alignment: .leading, spacing: 10) {
                    AsyncDecodedImageView(data: photoData) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                            .fill(Color.ohanaControlFill.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 132)
                    }
                    .accessibilityIdentifier("plant-care-log-photo-preview")

                    HStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            photoActionLabel(
                                title: l.tr(zh: "更换照片", en: "Replace photo", de: "Foto ersetzen"),
                                icon: "photo.on.rectangle.angled"
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-care-log-photo-replace")

                        Button {
                            selectedPhotoItem = nil
                            selectedPhotoData = nil
                        } label: {
                            photoActionLabel(
                                title: l.tr(zh: "移除", en: "Remove", de: "Entfernen"),
                                icon: "xmark.circle.fill"
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("plant-care-log-photo-remove")
                    }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: isLoadingPhoto ? "hourglass" : "photo.badge.plus") // a11y: allow decorative picker glyph; label names the action.
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .accessibilityHidden(true)
                        Text(isLoadingPhoto ? l.tr(zh: "正在读取照片", en: "Loading photo", de: "Foto wird geladen") : l.tr(zh: "添加一张照片", en: "Add a photo", de: "Foto hinzufügen"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                            .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isLoadingPhoto)
                .accessibilityIdentifier("plant-care-log-photo-picker")
            }
        }
    }

    private var saveButton: some View {
        PlantCareLogPrimaryButton(
            title: l.tr(zh: "保存记录", en: "Save log", de: "Eintrag speichern"),
            icon: "checkmark.circle.fill",
            tint: tint
        ) {
            onSave(selectedCareType, trimmedNote, selectedHealthStatus, selectedPhotoData)
            dismiss()
        }
        .disabled(isLoadingPhoto)
        .opacity(isLoadingPhoto ? 0.62 : 1)
        .accessibilityIdentifier("plant-care-log-save")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
    }

    private func chipButton(
        title: String,
        icon: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon) // a11y: allow decorative chip glyph; chip text names the option.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .background(
                isSelected ? tint : Color.ohanaControlFill.opacity(0.72),
                in: Capsule()
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func appendSuggestedNote(_ text: String) {
        let existing = trimmedNote
        if existing.isEmpty {
            note = text
        } else if !existing.contains(text) {
            note = "\(existing)\n\(text)"
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func photoActionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative photo action glyph; text names the action.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 40)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            isLoadingPhoto = false
            return
        }
        isLoadingPhoto = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                selectedPhotoData = data
                if data != nil {
                    selectedCareType = .photo
                }
                isLoadingPhoto = false
            }
        }
    }

    private func careTypeHint(_ type: PlantCareType) -> String {
        switch type {
        case .watering:
            l.tr(zh: "记录浇水后会更新浇水节奏和下一次护理计划。", en: "Watering updates the water rhythm and next care plan.", de: "Gießen aktualisiert Rhythmus und nächste Pflege.")
        case .fertilizing:
            l.tr(zh: "记录施肥后会更新施肥节奏。状态紧张时建议谨慎。", en: "Fertilizing updates the fertilizer rhythm. Use caution when stressed.", de: "Düngen aktualisiert den Rhythmus. Bei Stress vorsichtig sein.")
        case .pestCheck:
            l.tr(zh: "记录叶背、土面和新芽的复查结果。", en: "Log checks for leaf undersides, soil surface, and new growth.", de: "Blattunterseiten, Erdoberfläche und Neutriebe prüfen.")
        case .leafCleaning:
            l.tr(zh: "记录清洁叶片，帮助成长档案保留日常护理。", en: "Log leaf cleaning so the diary keeps routine care.", de: "Blattpflege für das Wachstumstagebuch erfassen.")
        case .newLeaf:
            l.tr(zh: "记录新叶或生长迹象。", en: "Log new leaves or growth signs.", de: "Neue Blätter oder Wachstum erfassen.")
        case .yellowLeaf:
            l.tr(zh: "记录黄叶位置和数量，便于后续复查。", en: "Log yellow-leaf location and count for follow-up.", de: "Ort und Anzahl gelber Blätter für Checks erfassen.")
        case .pestFound:
            l.tr(zh: "记录虫害发现和处理动作。", en: "Log pest findings and treatment steps.", de: "Schädlinge und Maßnahmen erfassen.")
        case .misting:
            l.tr(zh: "记录喷雾或湿度护理。", en: "Log misting or humidity care.", de: "Besprühen oder Feuchtepflege erfassen.")
        case .rotating:
            l.tr(zh: "记录转盆，帮助光照更均匀。", en: "Log pot rotation for more even light.", de: "Topfdrehung für gleichmäßigeres Licht erfassen.")
        case .pruning:
            l.tr(zh: "记录修剪、摘除枯叶或整理枝叶。", en: "Log pruning, dry leaf removal, or cleanup.", de: "Schnitt, trockene Blätter oder Pflege erfassen.")
        case .repotting:
            l.tr(zh: "记录换盆，会影响后续盆土和护理判断。", en: "Repotting affects future potting and care reasoning.", de: "Umtopfen beeinflusst spätere Pflegeentscheidungen.")
        case .photo:
            l.tr(zh: "附上一张照片，补齐成长照片档案。", en: "Attach a photo to complete the growth journal.", de: "Foto anhängen und Wachstumstagebuch ergänzen.")
        case .customNote:
            l.tr(zh: "记录一个普通观察备注。", en: "Log a general observation note.", de: "Eine allgemeine Beobachtung erfassen.")
        }
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }
}
