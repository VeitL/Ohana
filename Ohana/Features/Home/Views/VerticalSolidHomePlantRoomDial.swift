//
//  VerticalSolidHomePlantRoomDial.swift
//  Ohana
//
//  Room selector and scroll state used by the Home plants surface.
//

import Foundation
import SwiftUI

enum VerticalSolidHomePlantRoomDialLayout {
    static let width: CGFloat = 68
    static let collapsedHeight: CGFloat = 44
    static let expandedHeight: CGFloat = 220
    static let viewSwitcherHeight: CGFloat = 44
    static let controlGap: CGFloat = 10
}

struct VerticalSolidHomePlantRoomDialOption: Identifiable, Equatable {
    let id: String
    let roomID: String?
    let title: String
    let shortTitle: String
    let count: Int
    let dueCount: Int
}

struct VerticalSolidHomePlantRoomDialWheelItem: Identifiable {
    let id: Int
    let cycle: Int
    let option: VerticalSolidHomePlantRoomDialOption
}

struct VerticalSolidHomePlantRoomDial: View {
    let options: [VerticalSolidHomePlantRoomDialOption]
    let selectedRoomID: String?
    let localization: L10n
    let reduceMotion: Bool
    let onSelect: (String?) -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isExpanded = false
    @State private var scrollID: Int?

    private var l: L10n { localization }

    private var currentOption: VerticalSolidHomePlantRoomDialOption {
        options.first(where: { $0.roomID == selectedRoomID }) ?? options[0]
    }

    private var usesDialMotion: Bool {
        workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects && !reduceMotion
    }

    var body: some View {
        Group {
            if isExpanded {
                wheel
            } else {
                collapsedButton
            }
        }
        .frame(
            width: VerticalSolidHomePlantRoomDialLayout.width,
            height: isExpanded
                ? VerticalSolidHomePlantRoomDialLayout.expandedHeight
                : VerticalSolidHomePlantRoomDialLayout.collapsedHeight
        )
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-room-edge-rail")
        .onChange(of: selectedRoomID) { _, roomID in
            guard isExpanded else { return }
            recenter(roomID: roomID)
        }
        .onChange(of: options) { _, _ in
            guard isExpanded else { return }
            recenter(roomID: selectedRoomID)
        }
        .onDisappear {
            isExpanded = false
            scrollID = nil
        }
    }

    private var collapsedButton: some View {
        let option = currentOption
        return Button {
            expand()
        } label: {
            label(option, isFocused: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(option, isSelected: true))
        .accessibilityHint(l.tr(
            zh: "轻点展开房间滚轮，上下轻扫切换",
            en: "Tap to expand the room dial, then swipe vertically",
            de: "Tippen, um das Raumrad zu öffnen, dann vertikal streichen"
        ))
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
        .accessibilityIdentifier("home-plants-room-edge-collapsed")
    }

    private var wheel: some View {
        let items = wheelItems
        return ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    wheelButton(item, isFocused: item.id == scrollID)
                        .id(item.id)
                        .scrollTransition(.interactive(timingCurve: .easeInOut), axis: .vertical) { content, phase in
                            let distance = min(CGFloat(abs(phase.value)), 1)
                            let scale: CGFloat = usesDialMotion ? 1 - distance * 0.14 : 1
                            let opacity: Double = max(0.38, 1 - Double(distance) * 0.62)
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
        .scrollPosition(id: $scrollID, anchor: .center)
        .scrollTargetBehavior(.viewAligned(anchor: .center))
        .frame(
            width: VerticalSolidHomePlantRoomDialLayout.width,
            height: VerticalSolidHomePlantRoomDialLayout.expandedHeight
        )
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
            if scrollID == nil {
                scrollID = middleID(for: selectedRoomID)
            }
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .idle else { return }
            settle(items: items)
        }
        .accessibilityLabel(l.tr(
            zh: "房间滚轮",
            en: "Room dial",
            de: "Raumrad"
        ))
        .accessibilityAction(.escape) {
            collapse()
        }
    }

    private var wheelItems: [VerticalSolidHomePlantRoomDialWheelItem] {
        guard !options.isEmpty else { return [] }
        return (0 ..< 13).flatMap { cycle in
            options.indices.map { optionIndex in
                VerticalSolidHomePlantRoomDialWheelItem(
                    id: cycle * options.count + optionIndex,
                    cycle: cycle,
                    option: options[optionIndex]
                )
            }
        }
    }

    private func wheelButton(
        _ item: VerticalSolidHomePlantRoomDialWheelItem,
        isFocused: Bool
    ) -> some View {
        Button {
            commit(item.option)
            collapse()
        } label: {
            label(item.option, isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(item.option, isSelected: isFocused))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityIdentifier("home-plants-room-edge-\(identifier(item.option.id))-\(item.cycle)")
        .accessibilityHidden(item.cycle != 6)
    }

    private func label(
        _ option: VerticalSolidHomePlantRoomDialOption,
        isFocused: Bool
    ) -> some View {
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
                    .frame(width: 7, height: 7) // a11y: allow decorative due dot inside the 44pt dial target.
                    .offset(x: -7, y: 6)
                    .accessibilityHidden(true)
            }
        }
    }

    private func expand() {
        scrollID = middleID(for: selectedRoomID)
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isExpanded = true
        }
        OhanaFeedback.light()
    }

    private func collapse() {
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isExpanded = false
        }
    }

    private func settle(items: [VerticalSolidHomePlantRoomDialWheelItem]) {
        guard
            let scrollID,
            let item = items.first(where: { $0.id == scrollID })
        else { return }

        commit(item.option)
        recenter(roomID: item.option.roomID)
    }

    private func commit(_ option: VerticalSolidHomePlantRoomDialOption) {
        guard selectedRoomID != option.roomID else { return }
        onSelect(option.roomID)
    }

    private func recenter(roomID: String?) {
        let centeredID = middleID(for: roomID)
        guard scrollID != centeredID else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollID = centeredID
        }
    }

    private func middleID(for roomID: String?) -> Int {
        let optionIndex = options.firstIndex(where: { $0.roomID == roomID }) ?? 0
        return 6 * options.count + optionIndex
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard
            !options.isEmpty,
            let currentIndex = options.firstIndex(where: { $0.roomID == selectedRoomID })
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
        commit(options[nextIndex])
    }

    private func accessibilityLabel(
        _ option: VerticalSolidHomePlantRoomDialOption,
        isSelected: Bool
    ) -> String {
        let state = isSelected
            ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
            : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        let due = option.dueCount == 0
            ? l.tr(zh: "无到期任务", en: "no due tasks", de: "keine fälligen Aufgaben")
            : l.tr(zh: "\(option.dueCount) 项到期", en: "\(option.dueCount) due", de: "\(option.dueCount) fällig")
        return l.tr(
            zh: "\(option.title)，\(option.count) 株植物，\(due)，\(state)",
            en: "\(option.title), \(option.count) plants, \(due), \(state)",
            de: "\(option.title), \(option.count) Pflanzen, \(due), \(state)"
        )
    }

    static func shortTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        if trimmed.unicodeScalars.contains(where: { (0x4E00 ... 0x9FFF).contains(Int($0.value)) }) {
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

    private func identifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

final class VerticalSolidHomePlantDeckScrollOffsetTracker {
    var offsetY: CGFloat = 0
}
