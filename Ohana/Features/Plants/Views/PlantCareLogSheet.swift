//
//  PlantCareLogSheet.swift
//  Ohana
//
//  Lightweight confirmation sheet for plant care and observation logs.
//

import PhotosUI
import SwiftUI

private struct PlantCareLogContextItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let tint: Color
}

private struct PlantCareLogImpactItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private struct PlantCareLogNoteSuggestion: Identifiable {
    let id: String
    let text: String
}

struct PlantCareLogSheet: View {
    let plant: Plant
    let onSave: (PlantCareType, String, PlantHealthStatus, Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @State private var selectedCareType: PlantCareType
    @State private var selectedHealthStatus: PlantHealthStatus
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isLoadingPhoto = false
    @State private var note = ""

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { careTint(for: selectedCareType) }
    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private let careTypes: [PlantCareType] = [
        .watering,
        .fertilizing,
        .pestCheck,
        .photo,
        .leafCleaning,
        .newLeaf,
        .yellowLeaf,
        .pestFound,
        .misting,
        .rotating,
        .pruning,
        .repotting,
        .customNote
    ]

    private var placementSummary: String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactSpot = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !exactSpot.isEmpty, room != exactSpot {
            return "\(room) · \(exactSpot)"
        }
        if !room.isEmpty { return room }
        if !exactSpot.isEmpty { return exactSpot }
        return l.tr(zh: "位置未设置", en: "Place unset", de: "Standort fehlt")
    }

    private var waterContextText: String {
        guard let days = plant.daysSinceWatered else {
            return l.tr(zh: "未记录", en: "No log", de: "Kein Eintrag")
        }
        return l.tr(zh: "\(days) 天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    private var fertilizerContextText: String {
        guard let days = plant.daysSinceFertilized else {
            return l.tr(zh: "未记录", en: "No log", de: "Kein Eintrag")
        }
        return l.tr(zh: "\(days) 天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    private var checkInContextItems: [PlantCareLogContextItem] {
        [
            PlantCareLogContextItem(
                id: "status",
                icon: healthSymbol(for: selectedHealthStatus),
                title: l.tr(zh: "状态", en: "Status", de: "Status"),
                value: selectedHealthStatus.displayName,
                tint: healthTint(for: selectedHealthStatus)
            ),
            PlantCareLogContextItem(
                id: "place",
                icon: "mappin.and.ellipse",
                title: l.tr(zh: "位置", en: "Place", de: "Ort"),
                value: placementSummary,
                tint: Color.goTeal
            ),
            PlantCareLogContextItem(
                id: "water",
                icon: "drop.fill",
                title: l.tr(zh: "上次浇水", en: "Last water", de: "Letztes Gießen"),
                value: waterContextText,
                tint: Color.goTeal
            ),
            PlantCareLogContextItem(
                id: "fertilizer",
                icon: "leaf.fill",
                title: l.tr(zh: "上次施肥", en: "Last feed", de: "Letztes Düngen"),
                value: fertilizerContextText,
                tint: Color.goLime
            )
        ]
    }

    private var saveImpactItems: [PlantCareLogImpactItem] {
        [
            PlantCareLogImpactItem(
                id: "timeline",
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "进入时间线", en: "Adds to timeline", de: "In die Zeitachse"),
                detail: selectedCareType.displayName(l: l),
                tint: tint
            ),
            PlantCareLogImpactItem(
                id: "health",
                icon: healthSymbol(for: selectedHealthStatus),
                title: l.tr(zh: "更新健康状态", en: "Updates health", de: "Aktualisiert Status"),
                detail: selectedHealthStatus.displayName,
                tint: healthTint(for: selectedHealthStatus)
            ),
            PlantCareLogImpactItem(
                id: "cadence",
                icon: selectedCareType == .watering ? "drop.fill" : "calendar.badge.clock",
                title: l.tr(zh: "影响护理节奏", en: "Shapes care rhythm", de: "Prägt Rhythmus"),
                detail: careLogImpactDetail,
                tint: tint
            ),
            PlantCareLogImpactItem(
                id: "photo",
                icon: selectedPhotoData == nil ? "photo.badge.plus" : "photo.fill",
                title: l.tr(zh: "成长图库", en: "Growth gallery", de: "Wachstumsgalerie"),
                detail: selectedPhotoData == nil
                    ? l.tr(zh: "无照片", en: "No photo", de: "Kein Foto")
                    : l.tr(zh: "会加入图库", en: "Added to gallery", de: "Kommt in Galerie"),
                tint: selectedPhotoData == nil ? Color.goYellow : Color.goTeal
            )
        ]
    }

    private var careLogImpactDetail: String {
        switch selectedCareType {
        case .watering:
            l.tr(zh: "重置浇水判断", en: "Resets water timing", de: "Setzt Gießrhythmus")
        case .fertilizing:
            l.tr(zh: "重置施肥判断", en: "Resets feed timing", de: "Setzt Düngeplan")
        case .pestCheck, .pestFound, .yellowLeaf:
            l.tr(zh: "强化健康复查", en: "Improves health review", de: "Stärkt Gesundheitscheck")
        case .photo, .newLeaf:
            l.tr(zh: "补充成长档案", en: "Builds growth record", de: "Ergänzt Wachstum")
        case .repotting:
            l.tr(zh: "影响盆土判断", en: "Affects potting context", de: "Beeinflusst Topfkontext")
        default:
            l.tr(zh: "沉淀日常护理", en: "Captures routine care", de: "Erfasst Routinepflege")
        }
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
        _selectedCareType = State(initialValue: initialCareType)
        _selectedHealthStatus = State(initialValue: currentHealthStatus)
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "记录植物护理", en: "Log plant care", de: "Pflanzenpflege erfassen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                header
                checkInContextCard
                saveImpactPreview
                careTypePicker
                healthStatusPicker
                photoAttachmentSection
                suggestedNotesSection
                noteSection
                saveButton
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-care-log-sheet")
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(from: item)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: careSymbol(for: selectedCareType)) // a11y: allow decorative sheet glyph; heading names the log.
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(careTypeHint(selectedCareType))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }

    private var checkInContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "本次 Check-in", en: "This check-in", de: "Dieser Check-in"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(checkInContextItems) { item in
                    contextMetric(item)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-log-context")
    }

    private func contextMetric(_ item: PlantCareLogContextItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.icon) // a11y: allow decorative context glyph; adjacent text carries the metric.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28) // a11y: allow non-interactive metric glyph; row text is accessible.
                .background(item.tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(item.value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.value)")
        .accessibilityIdentifier("plant-care-log-context-\(item.id)")
    }

    private var saveImpactPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath") // a11y: allow decorative save-impact glyph; heading names the section.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive impact glyph; adjacent text is accessible.
                    .background(tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "保存后会更新", en: "After saving", de: "Nach dem Speichern"))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "这条记录会同步到时间线、健康摘要、护理节奏和成长图库。",
                        en: "This log feeds the timeline, health summary, care rhythm, and growth gallery.",
                        de: "Dieser Eintrag fließt in Zeitachse, Status, Rhythmus und Galerie."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
                ForEach(saveImpactItems) { item in
                    saveImpactRow(item)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-log-save-impact")
    }

    private func saveImpactRow(_ item: PlantCareLogImpactItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon) // a11y: allow decorative impact glyph; row text describes the effect.
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30) // a11y: allow non-interactive impact glyph; adjacent text is accessible.
                .background(item.tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(item.title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 8)
            Text(item.detail)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.detail)")
        .accessibilityIdentifier("plant-care-log-impact-\(item.id)")
    }

    private var careTypePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "护理类型", en: "Care type", de: "Pflegetyp"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(careTypes) { type in
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
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var healthStatusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "记录后的状态", en: "Status after log", de: "Status nach Eintrag"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(PlantHealthStatus.allCases) { status in
                    chipButton(
                        title: status.displayName,
                        icon: healthSymbol(for: status),
                        tint: healthTint(for: status),
                        isSelected: selectedHealthStatus == status
                    ) {
                        selectedHealthStatus = status
                    }
                    .accessibilityIdentifier("plant-care-log-health-\(status.rawValue)")
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
                                .frame(width: 190, alignment: .leading)
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
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            onSave(selectedCareType, trimmedNote, selectedHealthStatus, selectedPhotoData)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative save glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "保存记录", en: "Save log", de: "Eintrag speichern"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoadingPhoto)
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
            Color.goLime
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

    private func healthTint(for status: PlantHealthStatus) -> Color {
        switch status {
        case .thriving:
            Color.goLime
        case .stable:
            Color.goTeal
        case .watching:
            Color.goYellow
        case .stressed:
            Color.goRed
        }
    }

    private func healthSymbol(for status: PlantHealthStatus) -> String {
        switch status {
        case .thriving:
            "leaf.circle.fill"
        case .stable:
            "checkmark.seal.fill"
        case .watching:
            "eye.fill"
        case .stressed:
            "exclamationmark.triangle.fill"
        }
    }
}
