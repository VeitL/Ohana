//
//  DesignSpecControlsV4.swift
//  Ohana
//

import SwiftUI

struct DesignSpecStepRailV4: View {
    @Binding var step: DesignBuilderStepV4
    let selection: DesignSpecSelectionV4
    let mode: DesignPreviewModeV4

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: mode)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(DesignBuilderStepV4.allCases) { item in
                    Button {
                        withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) { step = item }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.zh)
                                Text(item.en)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .opacity(0.70)
                            }
                        }
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(step == item ? Color.arkInk : palette.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(step == item ? palette.accent : palette.controlFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(step == item ? Color.clear : palette.stroke, lineWidth: 1))
                        .scaleEffect(step == item ? 1 : 0.98)
                        .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: step)
                    }
                    .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom selected-chip press animation
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

struct DesignSpecControlsPanelV4: View {
    @Binding var selection: DesignSpecSelectionV4
    @Binding var step: DesignBuilderStepV4
    let mode: DesignPreviewModeV4

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            switch step {
            case .background:
                optionRow("背景 / Background", keyPath: \.background, options: DesignSpecOptionCatalogV4.backgrounds)
                optionRow("主色 / Accent", keyPath: \.accent, options: DesignSpecOptionCatalogV4.accents)
            case .card:
                optionRow("卡片 / Card", keyPath: \.card, options: DesignSpecOptionCatalogV4.cards)
                optionRow("密度 / Density", keyPath: \.density, options: DesignSpecOptionCatalogV4.densities)
            case .button:
                optionRow("按钮 / Button", keyPath: \.button, options: DesignSpecOptionCatalogV4.buttons)
                optionRow("点击反馈 / Tap", keyPath: \.tap, options: DesignSpecOptionCatalogV4.taps)
            case .input:
                optionRow("输入框 / Input", keyPath: \.input, options: DesignSpecOptionCatalogV4.inputs)
                optionRow("状态 / State", keyPath: \.inputState, options: DesignSpecOptionCatalogV4.inputStates)
                optionRow("开关 / Toggle", keyPath: \.toggle, options: DesignSpecOptionCatalogV4.toggles)
            case .controls:
                optionRow("选择标签 / Chip", keyPath: \.chip, options: DesignSpecOptionCatalogV4.chips)
                optionRow("分段 / Segment", keyPath: \.segment, options: DesignSpecOptionCatalogV4.segments)
                optionRow("进度 / Progress", keyPath: \.progress, options: DesignSpecOptionCatalogV4.progresses)
            case .text:
                optionRow("字体 / Type", keyPath: \.type, options: DesignSpecOptionCatalogV4.types)
                optionRow("Icon / Icon", keyPath: \.icon, options: DesignSpecOptionCatalogV4.icons)
            case .navigation:
                optionRow("导航 / Nav", keyPath: \.navigation, options: DesignSpecOptionCatalogV4.navigation)
                optionRow("设置图标 / Setting Icon", keyPath: \.settingIcon, options: DesignSpecOptionCatalogV4.settingIcons)
                optionRow("返回 / Back", keyPath: \.pageBackButton, options: DesignSpecOptionCatalogV4.pageBackButtons)
                optionRow("关闭 / Close", keyPath: \.pageCloseButton, options: DesignSpecOptionCatalogV4.pageCloseButtons)
                optionRow("列表 / Row", keyPath: \.listRow, options: DesignSpecOptionCatalogV4.listRows)
                optionRow("角标 / Badge", keyPath: \.badge, options: DesignSpecOptionCatalogV4.badges)
            case .sheet:
                optionRow("布局 / Layout", keyPath: \.sheet, options: DesignSpecOptionCatalogV4.sheets, showsDescription: false)
                optionRow("背景 / Background", keyPath: \.sheetGlass, options: DesignSpecOptionCatalogV4.glass, showsDescription: false)
                optionRow("卡片 / Card", keyPath: \.sheetCard, options: DesignSpecOptionCatalogV4.cards, showsDescription: false)
                optionRow("输入 / Input", keyPath: \.sheetInput, options: DesignSpecOptionCatalogV4.inputs, showsDescription: false)
                optionRow("按钮 / Button", keyPath: \.sheetButton, options: DesignSpecOptionCatalogV4.buttons, showsDescription: false)
                optionRow("关闭 / Chrome", keyPath: \.sheetChrome, options: DesignSpecOptionCatalogV4.sheetChrome, showsDescription: false)
            case .chart:
                optionRow("趋势 / Line", keyPath: \.chartLine, options: DesignSpecOptionCatalogV4.chartLines)
                optionRow("坐标 / Axis", keyPath: \.chartAxis, options: DesignSpecOptionCatalogV4.chartAxes)
            case .calendar:
                optionRow("结构 / Layout", keyPath: \.calendarLayout, options: DesignSpecOptionCatalogV4.calendarLayouts)
                optionRow("日期格 / Day Cell", keyPath: \.calendarDay, options: DesignSpecOptionCatalogV4.calendarDays)
                optionRow("事件标记 / Event Marker", keyPath: \.calendarEvent, options: DesignSpecOptionCatalogV4.calendarEvents)
                optionRow("日程列表 / Agenda", keyPath: \.calendarAgenda, options: DesignSpecOptionCatalogV4.calendarAgenda)
            case .feedback:
                optionRow("Toast / Toast", keyPath: \.toast, options: DesignSpecOptionCatalogV4.toasts)
                optionRow("Banner / Banner", keyPath: \.banner, options: DesignSpecOptionCatalogV4.banners)
                optionRow("触感 / Haptic", keyPath: \.haptic, options: DesignSpecOptionCatalogV4.haptics)
            case .motion:
                optionRow("动效 / Motion", keyPath: \.motion, options: DesignSpecOptionCatalogV4.motions)
                optionRow("FAB / FAB", keyPath: \.fabMotion, options: DesignSpecOptionCatalogV4.fabMotions)
                optionRow("转场 / Transition", keyPath: \.transition, options: DesignSpecOptionCatalogV4.transitions)
                optionRow("奖励 / Reward", keyPath: \.reward, options: DesignSpecOptionCatalogV4.rewards)
            }
        }
        .padding(13)
        .background(glass(cornerRadius: 22))
    }

    private func optionRow(_ title: String, keyPath: WritableKeyPath<DesignSpecSelectionV4, String>, options: [DesignSpecOptionV4], showsDescription: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(DesignSpecUIV4.typeFont(12, weight: .black, selection: selection))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text(valueTitle(selection[keyPath: keyPath], in: options))
                    .font(DesignSpecUIV4.typeFont(10, weight: .black, selection: selection))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(options) { option in
                        Button {
                            withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) {
                                selection[keyPath: keyPath] = option.id
                            }
                        } label: {
                            optionChip(option, selected: selection[keyPath: keyPath] == option.id)
                        }
                        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom token-chip press animation
                    }
                }
            }

            if showsDescription, let selected = options.first(where: { $0.id == selection[keyPath: keyPath] }) {
                Text("\(selected.zhDescription) / \(selected.enDescription)")
                    .font(DesignSpecUIV4.typeFont(10, weight: .bold, selection: selection))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func optionChip(_ option: DesignSpecOptionV4, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: option.icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(selected ? Color.arkInk : palette.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(option.zh)
                Text(option.en)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .opacity(0.68)
            }
            if option.recommended {
                Image(systemName: "star.fill")
                    .font(.system(size: 7, weight: .black))
            }
        }
        .font(DesignSpecUIV4.typeFont(11, weight: .black, selection: selection))
        .foregroundStyle(selected ? Color.arkInk : palette.primaryText)
        .frame(minWidth: 112, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? option.tint : palette.controlFill, in: RoundedRectangle(cornerRadius: DesignSpecUIV4.innerRadius(selection), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSpecUIV4.innerRadius(selection), style: .continuous).strokeBorder(selected ? Color.clear : palette.stroke, lineWidth: 1))
        .scaleEffect(selected ? 1 : 0.98)
        .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: selected)
    }

    private func valueTitle(_ id: String, in options: [DesignSpecOptionV4]) -> String {
        options.first(where: { $0.id == id }).map { "\($0.zh) / \($0.en)" } ?? id
    }

    private func glass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial).opacity(DesignSpecUIV4.glassOpacity(selection)) // ui-v4: allow developer console glass shell
            shape.fill(Color.white.opacity(mode == .dark ? 0.06 : 0.22)) // ui-v4: allow glass shell tint
            shape.fill(palette.accent.opacity(selection.glass == "clear" ? 0.035 : 0.065))
        }
        .overlay(shape.strokeBorder(palette.stroke, lineWidth: 1))
    }
}

struct DesignSpecAuditPanelV4: View {
    let selection: DesignSpecSelectionV4
    let mode: DesignPreviewModeV4

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: mode)
    }

    var body: some View {
        let results = DesignSpecAuditEngineV4.results(for: selection)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("设计检查 / Design Audit", systemImage: "checkmark.shield.fill")
                    .font(DesignSpecUIV4.typeFont(13, weight: .black, selection: selection))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("\(results.filter { $0.status == .pass }.count)/\(results.count)")
                    .font(DesignSpecUIV4.typeFont(11, weight: .black, selection: selection))
                    .foregroundStyle(palette.accent)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(results) { result in
                    auditCell(result)
                }
            }
        }
        .padding(13)
        .background(glass(cornerRadius: 22))
    }

    private func auditCell(_ result: DesignSpecAuditResultV4) -> some View {
        let tint = tint(for: result.status)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(tint)
                Spacer()
                Text(result.status.rawValue.uppercased())
                    .font(DesignSpecUIV4.typeFont(8, weight: .black, selection: selection))
                    .foregroundStyle(tint)
            }
            Text(result.titleZh)
                .font(DesignSpecUIV4.typeFont(11, weight: .black, selection: selection))
                .foregroundStyle(palette.primaryText)
            Text(result.detailZh)
                .font(DesignSpecUIV4.typeFont(9, weight: .bold, selection: selection))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: DesignSpecUIV4.innerRadius(selection), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSpecUIV4.innerRadius(selection), style: .continuous).strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }

    private func tint(for status: DesignSpecAuditResultV4.Status) -> Color {
        switch status {
        case .pass: return Color.goTeal
        case .warning: return Color.goYellow
        case .fail: return Color.goRed
        }
    }

    private func glass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial).opacity(DesignSpecUIV4.glassOpacity(selection)) // ui-v4: allow developer console glass shell
            shape.fill(Color.white.opacity(mode == .dark ? 0.06 : 0.22)) // ui-v4: allow glass shell tint
        }
        .overlay(shape.strokeBorder(palette.stroke, lineWidth: 1))
    }
}
