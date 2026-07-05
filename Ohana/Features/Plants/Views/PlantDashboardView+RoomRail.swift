//
//  PlantDashboardView+RoomRail.swift
//  Ohana
//
//  Right-edge room switcher for dense plant collections.
//

import SwiftUI

extension PlantDashboardView {
    @ViewBuilder
    var plantFloatingEdgeControls: some View {
        if showsPlantViewSwitcherRail || showsRoomEdgeRail {
            VStack(spacing: 10) {
                if showsPlantViewSwitcherRail {
                    plantViewSwitcherRail
                }

                if showsRoomEdgeRail {
                    roomEdgeRail
                }
            }
            .padding(.trailing, 4)
            .padding(.top, 132)
            .padding(.bottom, 112)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .zIndex(45)
        }
    }

    var plantViewSwitcherRail: some View {
        VStack(spacing: 8) {
            ForEach(PlantDashboardPlantsViewStyle.allCases) { style in
                plantViewSwitcherButton(style)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(roomEdgeRailBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-view-switcher-rail")
    }

    func plantViewSwitcherButton(_ style: PlantDashboardPlantsViewStyle) -> some View {
        let isSelected = selectedPlantsViewStyle == style
        return Button {
            selectPlantViewStyle(style)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: style.icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .frame(height: 14)
                    .accessibilityHidden(true)
                Text(style.shortTitle(l))
                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(style.title(l))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("plant-dashboard-view-\(style.rawValue)")
    }

    var roomEdgeRail: some View {
        VStack(spacing: 8) {
            roomEdgeRailButton(
                id: "all",
                title: l.tr(zh: "全部", en: "All", de: "Alle"),
                shortTitle: l.tr(zh: "全", en: "All", de: "Alle"),
                count: plants.count,
                isSelected: selectedLocation == nil,
                dueCount: dueTasks.count
            ) {
                selectRoomFromEdgeRail(nil)
            } batchCareAction: {
                openBatchCareSheet()
            }

            ForEach(roomCareSummaries.prefix(7)) { summary in
                roomEdgeRailButton(
                    id: summary.id,
                    title: summary.title,
                    shortTitle: roomEdgeRailShortTitle(summary.title),
                    count: summary.plantCount,
                    isSelected: selectedLocation == summary.id,
                    dueCount: summary.dueTaskCount
                ) {
                    selectRoomFromEdgeRail(selectedLocation == summary.id ? nil : summary.id)
                } batchCareAction: {
                    openBatchCareSheet(roomID: summary.id)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(roomEdgeRailBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-edge-rail")
    }

    @ViewBuilder
    var roomEdgeRailBackground: some View {
        if usesFullVisualEffects && !reduceTransparency {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular.tint(roomEdgeRailGlassTint).interactive(true), in: Capsule()) // ui-v4: allow Liquid Glass room rail matching home navigation
                .overlay(roomEdgeRailStroke)
                .shadow( // ui-v4: allow floating glass room rail depth above plant wallet cards
                    color: Color.arkInk.opacity(colorScheme == .dark ? 0.22 : 0.10),
                    radius: 18,
                    x: 0,
                    y: 10
                )
        } else {
            Capsule()
                .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.88 : 0.94))
                .overlay(roomEdgeRailStroke)
                .shadow( // ui-v4: allow reduced-mode plant room rail separation without Liquid Glass.
                    color: Color.arkInk.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
    }

    var roomEdgeRailStroke: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.ohanaPrimaryText.opacity(colorScheme == .dark ? 0.18 : 0.14),
                        Color.ohanaSecondaryText.opacity(colorScheme == .dark ? 0.18 : 0.10),
                        Color.ohanaGlassStroke.opacity(usesFullVisualEffects ? 0.20 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    var usesFullVisualEffects: Bool {
        workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects
    }

    var roomEdgeRailGlassTint: Color {
        if reduceTransparency {
            return Color.ohanaCardSurface.opacity(0.94)
        }
        return Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.34 : 0.42)
    }

    func roomEdgeRailButton(
        id: String,
        title: String,
        shortTitle: String,
        count: Int,
        isSelected: Bool,
        dueCount: Int,
        action: @escaping () -> Void,
        batchCareAction: (() -> Void)? = nil
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(shortTitle)
                    .font(OhanaFont.adaptive(size: shortTitle.count > 2 ? 9 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("\(count)")
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Circle())
            .overlay(alignment: .topTrailing) {
                if dueCount > 0 {
                    Circle()
                        .fill(Color.goYellow)
                        .frame(width: 9, height: 9) // a11y: allow decorative due dot inside the 44pt room rail button
                        .overlay {
                            Circle().strokeBorder(Color.ohanaCardSurface.opacity(0.8), lineWidth: 1)
                        }
                        .offset(x: -5, y: 5)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(roomEdgeRailAccessibilityLabel(title: title, count: count, dueCount: dueCount, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("plant-dashboard-room-edge-\(roomEdgeRailIdentifier(id))")
        .contextMenu {
            if dueCount > 0, let batchCareAction {
                Button {
                    batchCareAction()
                } label: {
                    Label(
                        id == "all"
                            ? l.tr(zh: "完成全部待照护", en: "Complete all due care", de: "Alle fällige Pflege erledigen")
                            : l.tr(zh: "照护这间", en: "Care for this room", de: "Diesen Raum pflegen"),
                        systemImage: "checkmark.circle.fill"
                    )
                }
            }
        }
    }

    func roomEdgeRailShortTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        if roomEdgeRailContainsCJK(trimmed) {
            return String(trimmed.prefix(1))
        }
        let words = trimmed
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)
        if words.count >= 2 {
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(trimmed.prefix(3)).uppercased()
    }

    func roomEdgeRailContainsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }

    func roomEdgeRailIdentifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    func roomEdgeRailAccessibilityLabel(
        title: String,
        count: Int,
        dueCount: Int,
        isSelected: Bool
    ) -> String {
        let state = isSelected ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt") : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        let due = dueCount == 0
            ? l.tr(zh: "无到期任务", en: "no due tasks", de: "keine fälligen Aufgaben")
            : l.tr(zh: "\(dueCount) 项到期", en: "\(dueCount) due", de: "\(dueCount) fällig")
        return l.tr(
            zh: "\(title)，\(count) 株植物，\(due)，\(state)",
            en: "\(title), \(count) plants, \(due), \(state)",
            de: "\(title), \(count) Pflanzen, \(due), \(state)"
        )
    }
}
