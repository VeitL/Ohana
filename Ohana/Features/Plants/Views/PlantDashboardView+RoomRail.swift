//
//  PlantDashboardView+RoomRail.swift
//  Ohana
//
//  Right-edge room switcher for dense plant collections.
//

import SwiftUI

extension PlantDashboardView {
    private struct RoomEdgeRailOption {
        let id: String
        let roomID: String?
        let title: String
        let shortTitle: String
        let count: Int
        let dueCount: Int
    }

    private struct RoomEdgeRailWheelItem: Identifiable {
        let id: Int
        let cycle: Int
        let optionIndex: Int
        let option: RoomEdgeRailOption
    }

    @ViewBuilder
    var plantFloatingEdgeControls: some View {
        if showsPlantViewSwitcherRail || showsRoomEdgeRail {
            ZStack(alignment: .trailing) {
                if showsPlantViewSwitcherRail {
                    plantViewSwitcherRail
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if showsRoomEdgeRail {
                    roomEdgeRail
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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
        Picker(
            l.tr(zh: "植物视图", en: "Plant view", de: "Pflanzenansicht"),
            selection: Binding(
                get: { selectedPlantsViewStyle },
                set: { selectPlantViewStyle($0) }
            )
        ) {
            ForEach(PlantDashboardPlantsViewStyle.allCases) { style in
                Label(style.title(l), systemImage: style.icon)
                    .labelStyle(.iconOnly)
                    .tag(style)
                    .accessibilityIdentifier("plant-dashboard-view-\(style.rawValue)")
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 88, height: 44)
        .accessibilityIdentifier("plant-dashboard-view-switcher-rail")
    }

    var roomEdgeRail: some View {
        Group {
            if isRoomEdgeRailExpanded {
                roomEdgeRailWheel
            } else {
                roomEdgeRailCollapsedButton
            }
        }
        .frame(width: 68)
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-edge-rail")
        .onDisappear {
            isRoomEdgeRailExpanded = false
            roomEdgeRailScrollID = nil
        }
    }

    private var roomEdgeRailCollapsedButton: some View {
        let option = roomEdgeRailCurrentOption
        return Button {
            expandRoomEdgeRail()
        } label: {
            roomEdgeRailLabel(option, isFocused: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(roomEdgeRailAccessibilityLabel(
            title: option.title,
            count: option.count,
            dueCount: option.dueCount,
            isSelected: true
        ))
        .accessibilityHint(l.tr(
            zh: "轻点展开房间滚轮，上下轻扫切换",
            en: "Tap to expand the room dial, then swipe vertically",
            de: "Tippen, um das Raumrad zu öffnen, dann vertikal streichen"
        ))
        .accessibilityAdjustableAction { direction in
            adjustRoomEdgeRailSelection(direction)
        }
        .accessibilityIdentifier("plant-dashboard-room-edge-collapsed")
        .contextMenu {
            roomEdgeRailBatchCareAction(option)
        }
    }

    private var roomEdgeRailWheel: some View {
        let options = roomEdgeRailOptions
        let items = roomEdgeRailWheelItems(options: options)
        let usesDialMotion = usesFullVisualEffects && !reduceMotion

        return ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    roomEdgeRailButton(item, isFocused: item.id == roomEdgeRailScrollID)
                        .id(item.id)
                        .scrollTransition(.interactive(timingCurve: .easeInOut), axis: .vertical) { content, phase in
                            let distance = CGFloat(abs(phase.value))
                            let scale: CGFloat = usesDialMotion ? 1 - distance * 0.14 : 1
                            let opacity: Double = 1 - Double(distance) * 0.62
                            let horizontalOffset: CGFloat = usesDialMotion ? distance * 7 : 0
                            return content
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .offset(x: horizontalOffset)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.vertical, 88, for: .scrollContent)
        .scrollPosition(id: $roomEdgeRailScrollID, anchor: .center)
        .scrollTargetBehavior(.viewAligned(anchor: .center))
        .frame(width: 68, height: 220)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear {
            if roomEdgeRailScrollID == nil {
                roomEdgeRailScrollID = roomEdgeRailMiddleID(for: selectedLocation, options: options)
            }
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .idle else { return }
            settleRoomEdgeRail(items: items, options: options)
        }
        .accessibilityLabel(l.tr(
            zh: "房间滚轮",
            en: "Room dial",
            de: "Raumrad"
        ))
        .accessibilityAction(.escape) {
            collapseRoomEdgeRail()
        }
    }

    var usesFullVisualEffects: Bool {
        workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects
    }

    private var roomEdgeRailOptions: [RoomEdgeRailOption] {
        var options = [RoomEdgeRailOption(
            id: "all",
            roomID: nil,
            title: l.tr(zh: "全部", en: "All", de: "Alle"),
            shortTitle: l.tr(zh: "全部", en: "ALL", de: "ALLE"),
            count: plants.count,
            dueCount: dueTasks.count
        )]
        options.append(contentsOf: roomCareSummaries.map { summary in
            RoomEdgeRailOption(
                id: summary.id,
                roomID: summary.id,
                title: summary.title,
                shortTitle: roomEdgeRailShortTitle(summary.title),
                count: summary.plantCount,
                dueCount: summary.dueTaskCount
            )
        })
        return options
    }

    private var roomEdgeRailCurrentOption: RoomEdgeRailOption {
        roomEdgeRailOptions.first(where: { $0.roomID == selectedLocation }) ?? roomEdgeRailOptions[0]
    }

    private func roomEdgeRailWheelItems(options: [RoomEdgeRailOption]) -> [RoomEdgeRailWheelItem] {
        guard !options.isEmpty else { return [] }
        return (0 ..< 13).flatMap { cycle in
            options.indices.map { optionIndex in
                RoomEdgeRailWheelItem(
                    id: cycle * options.count + optionIndex,
                    cycle: cycle,
                    optionIndex: optionIndex,
                    option: options[optionIndex]
                )
            }
        }
    }

    private func roomEdgeRailButton(_ item: RoomEdgeRailWheelItem, isFocused: Bool) -> some View {
        Button {
            commitRoomEdgeRailOption(item.option)
            collapseRoomEdgeRail()
        } label: {
            roomEdgeRailLabel(item.option, isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(roomEdgeRailAccessibilityLabel(
            title: item.option.title,
            count: item.option.count,
            dueCount: item.option.dueCount,
            isSelected: isFocused
        ))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityIdentifier("plant-dashboard-room-edge-\(roomEdgeRailIdentifier(item.option.id))-\(item.cycle)")
        .accessibilityHidden(item.cycle != 6)
        .contextMenu {
            roomEdgeRailBatchCareAction(item.option)
        }
    }

    private func roomEdgeRailLabel(_ option: RoomEdgeRailOption, isFocused: Bool) -> some View {
        VStack(spacing: 1) {
            Text(option.shortTitle)
                .font(OhanaFont.adaptive(size: option.shortTitle.count > 2 ? 9 : 12, weight: .black, design: .rounded))
                .foregroundStyle(isFocused ? Color.goPrimary : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text("\(option.count)")
                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(isFocused ? Color.goPrimary.opacity(0.72) : Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(width: 64, height: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(Color.goPrimary)
                .frame(width: 2, height: 24) // a11y: allow decorative selected-room indicator inside the 44pt dial target.
                .opacity(isFocused ? 1 : 0)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if option.dueCount > 0 {
                Circle()
                    .fill(Color.goYellow)
                    .frame(width: 7, height: 7) // a11y: allow decorative due dot inside the 44pt room dial target.
                    .offset(x: -7, y: 6)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func roomEdgeRailBatchCareAction(_ option: RoomEdgeRailOption) -> some View {
        if option.dueCount > 0 {
            Button {
                if let roomID = option.roomID {
                    openBatchCareSheet(roomID: roomID)
                } else {
                    openBatchCareSheet()
                }
            } label: {
                Label(
                    option.roomID == nil
                        ? l.tr(zh: "完成全部待照护", en: "Complete all due care", de: "Alle fällige Pflege erledigen")
                        : l.tr(zh: "照护这间", en: "Care for this room", de: "Diesen Raum pflegen"),
                    systemImage: "checkmark.circle.fill"
                )
            }
        }
    }

    private func expandRoomEdgeRail() {
        let options = roomEdgeRailOptions
        roomEdgeRailScrollID = roomEdgeRailMiddleID(for: selectedLocation, options: options)
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isRoomEdgeRailExpanded = true
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func collapseRoomEdgeRail() {
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isRoomEdgeRailExpanded = false
        }
    }

    private func settleRoomEdgeRail(
        items: [RoomEdgeRailWheelItem],
        options: [RoomEdgeRailOption]
    ) {
        guard
            let scrollID = roomEdgeRailScrollID,
            let item = items.first(where: { $0.id == scrollID })
        else { return }

        commitRoomEdgeRailOption(item.option)
        let centeredID = roomEdgeRailMiddleID(for: item.option.roomID, options: options)
        if scrollID != centeredID {
            roomEdgeRailScrollID = centeredID
        }
    }

    private func commitRoomEdgeRailOption(_ option: RoomEdgeRailOption) {
        guard selectedLocation != option.roomID else { return }
        selectRoomFromEdgeRail(option.roomID)
    }

    private func roomEdgeRailMiddleID(
        for roomID: String?,
        options: [RoomEdgeRailOption]
    ) -> Int {
        let optionIndex = options.firstIndex(where: { $0.roomID == roomID }) ?? 0
        return 6 * options.count + optionIndex
    }

    private func adjustRoomEdgeRailSelection(_ direction: AccessibilityAdjustmentDirection) {
        let options = roomEdgeRailOptions
        guard
            !options.isEmpty,
            let currentIndex = options.firstIndex(where: { $0.roomID == selectedLocation })
        else { return }

        let delta: Int
        switch direction {
        case .increment:
            delta = 1
        case .decrement:
            delta = -1
        @unknown default:
            return
        }

        let nextIndex = (currentIndex + delta + options.count) % options.count
        commitRoomEdgeRailOption(options[nextIndex])
    }

    func selectRoomFromEdgeRail(_ location: String?) {
        withAnimation(GoMotion.quick) {
            selectedLocation = location
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectPlantViewStyle(_ style: PlantDashboardPlantsViewStyle) {
        guard selectedPlantsViewStyle != style else { return }
        collapseExpandedPlantIfNeeded()
        withAnimation(GoMotion.quick) {
            selectedPlantsViewStyle = style
            if style == .list {
                selectedLocation = nil
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func roomEdgeRailShortTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        if roomEdgeRailContainsCJK(trimmed) {
            return String(trimmed.prefix(2))
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
