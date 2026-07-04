//
//  OhanaUISpecShowcaseView.swift
//  Ohana
//
//  Developer-only UI specification showcase.
//

import SwiftUI

struct OhanaUISpecShowcaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var selectedTab: OhanaUISpecShowcaseTab = .foundations
    @State private var sampleToggle = true
    @State private var sampleStepperValue = 7
    @State private var sampleDate = Date()
    @State private var sampleLeadDays = 1
    @State private var sampleSegment = "plan"
    @State private var sampleText = ""

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var cardFill: Color {
        reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface
    }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    tabPicker
                    selectedContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by explicit close label
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(primaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close"))
                .accessibilityIdentifier("ui-spec-showcase-close-action")
            }
        }
        .accessibilityIdentifier("ui-spec-showcase")
    }

    private var header: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "paintpalette.fill") // a11y: allow decorative icon covered by adjacent heading
                        .font(OhanaFont.adaptive(size: 22, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(l.tr(zh: "Ohana UI 规范", en: "Ohana UI Specification"))
                            .font(OhanaFont.title(.black))
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "展示 token、组件、页面契约和验收门槛。规范正文见 docs/design/ohana-ui-spec.md。",
                            en: "A showcase for tokens, components, page contracts, and validation gates. See docs/design/ohana-ui-spec.md."
                        ))
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    specPill(l.tr(zh: "JSON 决定 token", en: "JSON owns tokens"), tint: Color.goPrimary)
                    specPill(l.tr(zh: "成熟模块优先", en: "Mature module first"), tint: Color.goTeal)
                }
            }
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OhanaUISpecShowcaseTab.allCases) { tab in
                    Button {
                        withAnimation(GoMotion.selection) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title(l))
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(selectedTab == tab ? Color.ohanaPrimaryActionText : secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 78)
                            .frame(minHeight: 44)
                            .background(
                                selectedTab == tab ? Color.goPrimary : Color.ohanaControlFill,
                                in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("ui-spec-showcase-tab-\(tab.rawValue)")
                }
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .foundations:
            foundationsContent
        case .components:
            componentsContent
        case .patterns:
            patternsContent
        case .validation:
            validationContent
        }
    }

    private var foundationsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                l.tr(zh: "基础系统", en: "Foundations"),
                subtitle: l.tr(zh: "颜色、字体、表面和密度必须来自现有 token。", en: "Color, type, surface, and density come from existing tokens.")
            )
            swatchGrid
            typographySamples
            surfaceSamples
        }
    }

    private var componentsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                l.tr(zh: "核心组件", en: "Core Components"),
                subtitle: l.tr(zh: "按钮、卡片、设置行、图表和短弹窗的最小标准。", en: "Minimum standards for buttons, cards, settings rows, charts, and short popups.")
            )
            actionSamples
            settingsRowSample
            controlRowSamples
            inputSamples
            miniChartSample
            shortPopupSample
            componentReferenceCard
        }
    }

    private var patternsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                l.tr(zh: "页面契约", en: "Page Contracts"),
                subtitle: l.tr(zh: "新页面先声明参照面，再做差异。", en: "New screens declare a reference surface before diverging.")
            )
            contractCard(
                icon: "fork.knife",
                title: l.tr(zh: "高频护理详情", en: "High-frequency care detail"),
                reference: "QuickFeedDetailSheet.swift",
                notes: [
                    l.tr(zh: "快速记录卡片必须靠上。", en: "Quick record card stays high on the page."),
                    l.tr(zh: "习性、建议、历史、提醒管理同页闭环。", en: "Habit, advice, history, and reminder management stay in one loop.")
                ],
                tint: Color.goPrimary
            )
            contractCard(
                icon: "rectangle.3.group.fill",
                title: l.tr(zh: "快捷操作二级菜单", en: "Quick action secondary menu"),
                reference: "FocusHomeRouteSheetModifier.swift",
                notes: [
                    l.tr(zh: "首卡是最常用动作。", en: "The first card is the common action."),
                    l.tr(zh: "不要先铺一个大背景卡再弹记录框。", en: "Do not show a large background card before the record popup.")
                ],
                tint: Color.goTeal
            )
            contractCard(
                icon: "sparkles.rectangle.stack.fill",
                title: l.tr(zh: "空间卡片动效", en: "Spatial card motion"),
                reference: "OhanaMotionScene",
                notes: [
                    l.tr(zh: "动画读取冻结快照。", en: "Animation reads frozen snapshots."),
                    l.tr(zh: "视觉可点时就应响应下一次点击。", en: "A visually available target must respond to the next tap.")
                ],
                tint: Color.goYellow
            )
        }
    }

    private var validationContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                l.tr(zh: "验收门槛", en: "Validation Gates"),
                subtitle: l.tr(zh: "完成 UI 前必须能说清楚测了什么。", en: "Before UI is done, state exactly what was validated.")
            )
            checklistCard
            commandCard
            antiPatternCard
        }
    }

    private var swatchGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(colorSwatches) { swatch in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .fill(swatch.color)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                        )
                    Text(swatch.title)
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(primaryText)
                    Text(swatch.detail)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }
        }
    }

    private var typographySamples: some View {
        specCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionMiniTitle(l.tr(zh: "字体层级", en: "Type Scale"), icon: "textformat.size")
                Text(l.tr(zh: "页面标题使用 OhanaFont.title", en: "Page title uses OhanaFont.title"))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
                Text(l.tr(zh: "卡片标题使用 headline/body，保持短句和可扫描。", en: "Card headings use headline/body, staying short and scannable."))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "辅助说明使用 footnote/caption，不承担主要操作说明。", en: "Hints use footnote/caption and do not carry the main workflow."))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var surfaceSamples: some View {
        specCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionMiniTitle(l.tr(zh: "表面纪律", en: "Surface Discipline"), icon: "square.stack.3d.up.fill")
                HStack(spacing: 10) {
                    surfaceBlock(
                        title: l.tr(zh: "卡片", en: "Card"),
                        subtitle: "ohanaCardSurface",
                        fill: Color.ohanaCardSurface
                    )
                    surfaceBlock(
                        title: l.tr(zh: "控件", en: "Control"),
                        subtitle: "ohanaControlFill",
                        fill: Color.ohanaControlFill
                    )
                }
                Text(l.tr(
                    zh: "业务表面默认用实色 token，玻璃和阴影只给少数明确场景。",
                    en: "Business surfaces default to solid tokens; glass and shadows are reserved for explicit cases."
                ))
                .font(OhanaFont.footnote(.semibold))
                .foregroundStyle(secondaryText)
            }
        }
    }

    private var actionSamples: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "按钮", en: "Buttons"), icon: "hand.tap.fill")
                Button {
                    sampleToggle.toggle()
                } label: {
                    Label(
                        l.tr(zh: "主要操作", en: "Primary action"),
                        systemImage: sampleToggle ? "checkmark.circle.fill" : "plus.circle.fill"
                    )
                    .font(OhanaFont.body(.bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("ui-spec-showcase-primary-action")

                HStack(spacing: 10) {
                    Button {
                        sampleToggle.toggle()
                    } label: {
                        Label(l.tr(zh: "次要", en: "Secondary"), systemImage: "slider.horizontal.3")
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        sampleToggle.toggle()
                    } label: {
                        Image(systemName: "bell.fill") // a11y: allow decorative icon covered by explicit reminder label
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.ohanaControlFill, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "提醒样例", en: "Reminder sample"))
                }
            }
        }
    }

    private var settingsRowSample: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "设置行", en: "Settings Row"), icon: "gearshape.fill")
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush.pointed.fill") // a11y: allow decorative icon covered by adjacent setting label
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 32, height: 32) // a11y: allow decorative non-interactive settings glyph
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "UI 规范展示", en: "UI Specification Showcase"))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(primaryText)
                        Text(l.tr(zh: "调试模块内的只读页面", en: "Read-only page inside Debug"))
                            .font(OhanaFont.footnote())
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by adjacent setting label
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                        .foregroundStyle(tertiaryText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var controlRowSamples: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "控制行", en: "Control Rows"), icon: "switch.2")
                specToggleRow
                specStepperRow
                specDatePickerRow
                specMenuPickerRow
                specSegmentedPickerRow
            }
        }
        .accessibilityIdentifier("ui-spec-showcase-control-rows")
    }

    private var specToggleRow: some View {
        Toggle(isOn: $sampleToggle) {
            specControlLabel(
                title: l.tr(zh: "开关按钮", en: "Toggle"),
                value: sampleToggle ? l.tr(zh: "开启", en: "On") : l.tr(zh: "关闭", en: "Off"),
                footnote: l.tr(zh: "开关行使用 Toggle + tint + 扁平控制块。", en: "Toggle rows use Toggle, tint, and a flat control block.")
            )
        }
        .tint(Color.goTeal)
        .frame(minHeight: 58)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityIdentifier("ui-spec-showcase-toggle-row")
    }

    private var specStepperRow: some View {
        Stepper(value: $sampleStepperValue, in: 1 ... 60) {
            specControlLabel(
                title: l.tr(zh: "数字步进器", en: "Stepper"),
                value: l.tr(zh: "每 \(sampleStepperValue) 天", en: "Every \(sampleStepperValue)d"),
                footnote: l.tr(zh: "周期、库存阈值、数量用步进器，避免自由输入误差。", en: "Use steppers for cadence, stock thresholds, and bounded quantities.")
            )
        }
        .tint(Color.goTeal)
        .frame(minHeight: 58)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityIdentifier("ui-spec-showcase-stepper-row")
    }

    private var specDatePickerRow: some View {
        DatePicker(selection: $sampleDate, displayedComponents: [.date]) {
            specControlLabel(
                title: l.tr(zh: "日期选择栏", en: "Date picker row"),
                value: sampleDate.formatted(date: .abbreviated, time: .omitted),
                footnote: l.tr(zh: "日期选择必须显示当前值和用途，不只放一个系统控件。", en: "Date rows show the current value and purpose, not only the system control.")
            )
        }
        .tint(Color.goTeal)
        .frame(minHeight: 58)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityIdentifier("ui-spec-showcase-date-row")
    }

    private var specMenuPickerRow: some View {
        Picker(selection: $sampleLeadDays) {
            ForEach([0, 1, 2, 7], id: \.self) { day in
                Text(leadTitle(day)).tag(day)
            }
        } label: {
            specControlLabel(
                title: l.tr(zh: "菜单选择", en: "Menu picker"),
                value: leadTitle(sampleLeadDays),
                footnote: l.tr(zh: "长列表、低频选择用菜单；当前值必须外显。", en: "Use a menu for long or low-frequency choices; expose the current value.")
            )
        }
        .pickerStyle(.menu)
        .tint(Color.goTeal)
        .frame(minHeight: 58)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityIdentifier("ui-spec-showcase-menu-picker-row")
    }

    private var specSegmentedPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            specControlLabel(
                title: l.tr(zh: "分段选择", en: "Segmented picker"),
                value: segmentTitle(sampleSegment),
                footnote: l.tr(zh: "2-4 个高频互斥选项用分段，不用一排自造胶囊。", en: "Use segmented controls for 2-4 frequent exclusive options.")
            )

            Picker(selection: $sampleSegment) {
                ForEach(["overview", "plan", "history"], id: \.self) { value in
                    Text(segmentTitle(value)).tag(value)
                }
            } label: {
                Text(l.tr(zh: "分段选择", en: "Segmented picker"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .tint(Color.goTeal)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityIdentifier("ui-spec-showcase-segmented-picker-row")
    }

    private var inputSamples: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "输入与表单", en: "Inputs And Forms"), icon: "square.and.pencil")
                OhanaTextField(
                    placeholder: l.tr(zh: "植物名称", en: "Plant name"),
                    text: $sampleText,
                    style: .boxed
                )
                .accessibilityIdentifier("ui-spec-showcase-boxed-text-field")

                OhanaTextField(
                    placeholder: l.tr(zh: "搜索或筛选", en: "Search or filter"),
                    text: $sampleText,
                    style: .compactCapsule
                )
                .accessibilityIdentifier("ui-spec-showcase-compact-text-field")

                Text(l.tr(
                    zh: "输入框优先用 OhanaTextField；不要在页面内临时拼 TextField 背景、边框和 focus 态。",
                    en: "Prefer OhanaTextField; do not hand-roll TextField backgrounds, borders, and focus states in screens."
                ))
                .font(OhanaFont.footnote(.semibold))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var miniChartSample: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "图表", en: "Charts"), icon: "chart.xyaxis.line")
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(chartValues.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                            .fill(index == chartValues.count - 1 ? Color.goPrimary : Color.goTeal.opacity(0.68))
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(value))
                    }
                }
                .frame(height: 86)
                .padding(12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                Text(l.tr(zh: "图表回答护理问题；密集数据先聚合成值快照。", en: "Charts answer care questions; dense data is aggregated into value snapshots first."))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var componentReferenceCard: some View {
        specCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionMiniTitle(l.tr(zh: "生成代码时照抄这些入口", en: "Copy These Entry Points"), icon: "curlybraces")
                codeLine("OhanaTextField(placeholder:text:style:)")
                codeLine("Toggle { specControlLabel(...) }.tint(Color.goTeal)")
                codeLine("DatePicker(selection:displayedComponents:) { specControlLabel(...) }")
                codeLine("Picker(...).pickerStyle(.segmented)")
                codeLine(".buttonStyle(ScaleButtonStyle())")
                codeLine(".feedFlatBlockSurface(cornerRadius: OhanaRadius.control)")
                codeLine("OhanaMinimalBarChart(points:tint:progress:showsLabels:maxBarHeight:)")
            }
        }
        .accessibilityIdentifier("ui-spec-showcase-component-reference")
    }

    private var shortPopupSample: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "短弹窗", en: "Short Popup"), icon: "rectangle.bottomthird.inset.filled")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Capsule()
                            .fill(Color.ohanaDivider.opacity(0.8))
                            .frame(width: 48, height: 5)
                        Spacer()
                        Image(systemName: "xmark") // a11y: allow decorative sample close glyph
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(secondaryText)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    Text(l.tr(zh: "快速记录", en: "Quick Record"))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(primaryText)
                    Text(l.tr(zh: "一个表面、一个主按钮；不在背后再铺大卡片。", en: "One surface, one primary button; no extra background card behind it."))
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(l.tr(zh: "保存", en: "Save"))
                        .font(OhanaFont.body(.bold))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .padding(16)
                .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.inlinePopup, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.inlinePopup, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                )
            }
        }
    }

    private var checklistCard: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "Strict Smoothness Matrix", en: "Strict Smoothness Matrix"), icon: "checkmark.shield.fill")
                ForEach(validationItems, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative status icon covered by adjacent text
                            .font(OhanaFont.adaptive(size: 14, weight: .bold))
                            .foregroundStyle(Color.goTeal)
                            .accessibilityHidden(true)
                        Text(item)
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var commandCard: some View {
        specCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionMiniTitle(l.tr(zh: "最小校验", en: "Minimum Checks"), icon: "terminal.fill")
                codeLine("scripts/audit-ui-v4.sh --changed")
                codeLine("scripts/audit-accessibility.sh --changed")
                codeLine("scripts/dev-check-changed.sh")
            }
        }
    }

    private var antiPatternCard: some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionMiniTitle(l.tr(zh: "禁止漂移", en: "No Style Drift"), icon: "exclamationmark.triangle.fill")
                ForEach(antiPatterns, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                            .fill(Color.goRed.opacity(0.82))
                            .frame(width: 7, height: 7) // a11y: allow decorative non-interactive bullet
                            .padding(.top, 6)
                        Text(item)
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func contractCard(icon: String, title: String, reference: String, notes: [String], tint: Color) -> some View {
        specCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon) // a11y: allow decorative contract icon covered by adjacent title
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive contract glyph
                        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(primaryText)
                        Text(reference)
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                }

                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6) // a11y: allow decorative non-interactive bullet
                            .padding(.top, 7)
                        Text(note)
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func specCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(primaryText)
            Text(subtitle)
                .font(OhanaFont.footnote(.semibold))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private func sectionMiniTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon) // a11y: allow decorative section icon covered by adjacent title
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(primaryText)
        }
    }

    private func specPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private func surfaceBlock(title: String, subtitle: String, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .fill(fill)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                )
            Text(title)
                .font(OhanaFont.footnote(.bold))
                .foregroundStyle(primaryText)
            Text(subtitle)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func codeLine(_ value: String) -> some View {
        Text(value)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .accessibilityLabel(value)
    }

    private func specControlLabel(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(footnote)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func leadTitle(_ days: Int) -> String {
        switch days {
        case 0:
            l.tr(zh: "当天", en: "Same day")
        case 1:
            l.tr(zh: "提前 1 天", en: "1 day before")
        case 2:
            l.tr(zh: "提前 2 天", en: "2 days before")
        default:
            l.tr(zh: "提前 \(days) 天", en: "\(days)d before")
        }
    }

    private func segmentTitle(_ value: String) -> String {
        switch value {
        case "overview":
            l.tr(zh: "概览", en: "Overview")
        case "plan":
            l.tr(zh: "计划", en: "Plan")
        default:
            l.tr(zh: "历史", en: "History")
        }
    }

    private var colorSwatches: [OhanaUISpecSwatch] {
        [
            OhanaUISpecSwatch(
                title: l.tr(zh: "主行动", en: "Primary"),
                detail: l.tr(zh: "全局 CTA、选中、确认", en: "CTA, selection, confirm"),
                color: Color.goPrimary
            ),
            OhanaUISpecSwatch(
                title: l.tr(zh: "成功/辅助", en: "Success/Support"),
                detail: l.tr(zh: "完成、辅助强调", en: "Completion, support"),
                color: Color.goTeal
            ),
            OhanaUISpecSwatch(
                title: l.tr(zh: "提醒", en: "Warning"),
                detail: l.tr(zh: "提醒、库存、注意", en: "Reminder, stock, caution"),
                color: Color.goYellow
            ),
            OhanaUISpecSwatch(
                title: l.tr(zh: "危险", en: "Danger"),
                detail: l.tr(zh: "删除、失败、阻断", en: "Delete, failure, blocker"),
                color: Color.goRed
            )
        ]
    }

    private var chartValues: [Int] { [32, 48, 38, 66, 44, 74, 58] }

    private var validationItems: [String] {
        [
            l.tr(zh: "Finger-first frame：先给视觉反馈。", en: "Finger-first frame: visual feedback comes first."),
            l.tr(zh: "动画读取冻结快照，不读数据库。", en: "Animation reads frozen snapshots, not the database."),
            l.tr(zh: "重活延后、可取消、可批处理。", en: "Heavy work is deferred, cancellable, or batched."),
            l.tr(zh: "Safe area、hit testing、Dynamic Type 已检查。", en: "Safe area, hit testing, and Dynamic Type are checked.")
        ]
    }

    private var antiPatterns: [String] {
        [
            l.tr(zh: "从外部网页风格直接生成 app 页面。", en: "Generating app pages directly from external web styles."),
            l.tr(zh: "简单信息也套多层卡片。", en: "Wrapping simple information in nested cards."),
            l.tr(zh: "动画期间阻塞下一次有效点击。", en: "Blocking the next valid tap during animation."),
            l.tr(zh: "在可复用卡片、弹窗或动效里做宽查询。", en: "Broad queries inside reusable cards, popups, or motion scenes.")
        ]
    }
}

private enum OhanaUISpecShowcaseTab: String, CaseIterable, Identifiable {
    case foundations
    case components
    case patterns
    case validation

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .foundations:
            l.tr(zh: "基础", en: "Basics")
        case .components:
            l.tr(zh: "组件", en: "Components")
        case .patterns:
            l.tr(zh: "契约", en: "Contracts")
        case .validation:
            l.tr(zh: "验收", en: "Gates")
        }
    }
}

private struct OhanaUISpecSwatch: Identifiable {
    let title: String
    let detail: String
    let color: Color

    var id: String { title }
}

#Preview {
    NavigationStack {
        OhanaUISpecShowcaseView()
    }
}
