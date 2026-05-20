//
//  UIGuidelinesView.swift
//  Ohana
//
//  Developer-only interactive UI guidelines console.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct UIGuidelinesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ohanaDesignSpecSelectionV4") private var storedSelectionV4 = DesignSpecSelectionV4.ohanaDefault.encodedString(pretty: false)
    @AppStorage("ohanaDesignSpecSelectionV3") private var storedSelectionV3 = ""

    @State private var selection = DesignSpecSelectionV4.ohanaDefault
    @State private var previewMode: DesignPreviewModeV4 = .dark
    @State private var step: DesignBuilderStepV4 = .background
    @State private var toast: String?
    @State private var showAudit = false
    @State private var showExport = false

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: previewMode)
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            consoleContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(palette.primaryText)
                        .frame(width: 32, height: 32)
                        .background(palette.controlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom nav icon press in developer console
            }
            ToolbarItem(placement: .topBarTrailing) {
                modeToggle
            }
        }
        .preferredColorScheme(previewMode == .dark ? .dark : .light)
        .onAppear {
            loadSelection()
        }
        .onChange(of: selection) { _, newValue in
            storedSelectionV4 = newValue.encodedString(pretty: false)
        }
    }

    private var consoleContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                DesignSpecSafePreviewCanvasV4(
                    selection: selection,
                    mode: previewMode,
                    step: step,
                    toast: $toast
                )

                DesignSpecStepRailV4(step: $step, selection: selection, mode: previewMode)

                DesignSpecControlsPanelV4(selection: $selection, step: $step, mode: previewMode)

                advancedToggle(
                    title: "设计检查 / Design Audit",
                    icon: "checkmark.shield.fill",
                    isExpanded: $showAudit
                )
                if showAudit {
                    DesignSpecAuditPanelV4(selection: selection, mode: previewMode)
                        .transition(.opacity)
                }

                advancedToggle(
                    title: "导出规范 / Export",
                    icon: "square.and.arrow.up.fill",
                    isExpanded: $showExport
                )
                if showExport {
                    exportPanel
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
    }

    private var pageBackground: some View {
        ZStack {
            palette.background
            if selection.background == "goGradient" {
                RadialGradient(
                    colors: [palette.accent.opacity(previewMode == .dark ? 0.32 : 0.20), .clear],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 460
                )
                RadialGradient(
                    colors: [palette.secondaryAccent.opacity(previewMode == .dark ? 0.20 : 0.13), .clear],
                    center: .bottomTrailing,
                    startRadius: 30,
                    endRadius: 420
                )
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(DesignPreviewModeV4.allCases) { mode in
                Button {
                    withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) { previewMode = mode }
                } label: {
                    Label(mode.zh, systemImage: mode.icon)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(previewMode == mode ? Color.arkInk : palette.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(previewMode == mode ? palette.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom mode toggle animation
            }
        }
        .padding(4)
        .overlay(Capsule().strokeBorder(palette.stroke, lineWidth: 1))
    }

    private func advancedToggle(title: String, icon: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(DesignSpecUIV4.typeFont(13, weight: .black, selection: selection))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(palette.secondaryText)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
            }
            .padding(13)
            .background(glass(cornerRadius: 20))
        }
        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom disclosure row animation
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Button {
                    copy(DesignSpecExporterV4.json(selection: selection, mode: previewMode), message: "已复制 V4 JSON")
                } label: {
                    Label("复制 JSON", systemImage: "curlybraces")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(buttonStyle(.secondary))

                Button {
                    copy(DesignSpecExporterV4.markdown(selection: selection, mode: previewMode), message: "已复制 Markdown")
                } label: {
                    Label("复制 MD", systemImage: "doc.on.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(buttonStyle(.secondary))

                Button {
                    withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) {
                        selection = .ohanaDefault
                        step = .background
                    }
                    toast = "已恢复默认"
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(buttonStyle(.icon))
            }

            if let toast {
                Text(toast)
                    .font(DesignSpecUIV4.typeFont(11, weight: .black, selection: selection))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(palette.accent, in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(13)
        .background(glass(cornerRadius: 22))
    }

    private func loadSelection() {
        if let decoded = DesignSpecSelectionV4.decode(from: storedSelectionV4) {
            selection = normalized(decoded)
            storedSelectionV4 = selection.encodedString(pretty: false)
            return
        }
        if let migrated = DesignSpecSelectionV4.fromLegacyJSONString(storedSelectionV3) {
            selection = normalized(migrated)
            storedSelectionV4 = selection.encodedString(pretty: false)
            return
        }
        selection = .ohanaDefault
        storedSelectionV4 = selection.encodedString(pretty: false)
    }

    private func normalized(_ value: DesignSpecSelectionV4) -> DesignSpecSelectionV4 {
        var normalized = value
        let allowedGlass = Set(DesignSpecOptionCatalogV4.glass.map(\.id))
        if !allowedGlass.contains(normalized.glass) {
            normalized.glass = "refractive"
        }
        if !allowedGlass.contains(normalized.sheetGlass) {
            normalized.sheetGlass = "refractive"
        }
        let allowedCards = Set(DesignSpecOptionCatalogV4.cards.map(\.id))
        if !allowedCards.contains(normalized.sheetCard) {
            normalized.sheetCard = "flat"
        }
        let allowedInputs = Set(DesignSpecOptionCatalogV4.inputs.map(\.id))
        if !allowedInputs.contains(normalized.sheetInput) {
            normalized.sheetInput = "flat"
        }
        let allowedButtons = Set(DesignSpecOptionCatalogV4.buttons.map(\.id))
        if !allowedButtons.contains(normalized.sheetButton) {
            normalized.sheetButton = "pill"
        }
        let allowedIcons = Set(DesignSpecOptionCatalogV4.icons.map(\.id))
        if !allowedIcons.contains(normalized.icon) {
            normalized.icon = "monochromePrimary"
        }
        let allowedSettingIcons = Set(DesignSpecOptionCatalogV4.settingIcons.map(\.id))
        if !allowedSettingIcons.contains(normalized.settingIcon) {
            normalized.settingIcon = "plainGlyph"
        }
        let allowedBackButtons = Set(DesignSpecOptionCatalogV4.pageBackButtons.map(\.id))
        if !allowedBackButtons.contains(normalized.pageBackButton) {
            normalized.pageBackButton = "floatingCircle"
        }
        let allowedCloseButtons = Set(DesignSpecOptionCatalogV4.pageCloseButtons.map(\.id))
        if !allowedCloseButtons.contains(normalized.pageCloseButton) {
            normalized.pageCloseButton = "iconOnly"
        }
        return normalized
    }

    private func copy(_ value: String, message: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #endif
        withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) { toast = message }
    }

    private func glass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial).opacity(DesignSpecUIV4.glassOpacity(selection)) // ui-v4: allow developer console glass shell
            shape.fill(Color.white.opacity(previewMode == .dark ? 0.06 : 0.22)) // ui-v4: allow developer console glass tint
            shape.fill(palette.accent.opacity(selection.glass == "clear" ? 0.035 : 0.065))
        }
        .overlay(shape.strokeBorder(palette.stroke, lineWidth: 1))
    }

    private func buttonStyle(_ kind: DesignSpecButtonKindV4) -> DesignSpecTokenButtonStyleV4 {
        DesignSpecTokenButtonStyleV4(kind: kind, palette: palette, selection: selection)
    }
}

#Preview {
    NavigationStack {
        UIGuidelinesView()
    }
}

private struct DesignSpecSafePreviewCanvasV4: View {
    let selection: DesignSpecSelectionV4
    let mode: DesignPreviewModeV4
    let step: DesignBuilderStepV4
    @Binding var toast: String?

    @State private var toggleOn = true
    @State private var selectedChip = "30D"
    @State private var fabOpen = false
    @State private var transitionOn = true
    @State private var rewardOn = false
    @Namespace private var controlNamespace

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step == .sheet {
                sheetRenderCard
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                normalRenderCard
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(space(12, 14, 17))
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(mode == .dark ? 0.18 : 0.08), radius: 14, y: 8) // ui-v4: allow preview canvas floating depth
        .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: step)
    }

    private var normalRenderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            renderTitle(
                zh: "普通 UI 渲染",
                en: "General UI renderer",
                value: "\(step.zh) · \(selection.card) · \(selection.button)"
            )

            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 7) {
                    navigationCompact
                    HStack(spacing: 8) {
                        Button("打卡 / Record") { play("按钮点击 / \(selection.tap)") }
                            .buttonStyle(buttonStyle(.primary))
                        Button("Overview") { play("Overview") }
                            .buttonStyle(buttonStyle(.secondary))
                        Button { play("Icon Button") } label: {
                            Image(systemName: icon("gearshape.fill"))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(buttonStyle(.icon))
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 7) {
                    badge("New")
                    togglePreview
                }
            }

            pageChromeAndSettingsPreview
            listRowPreview
            segmentPreview

            HStack(spacing: 7) {
                ForEach(["干粮", "湿粮", "零食"], id: \.self) { item in
                    Button {
                        withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) {
                            selectedChip = item
                        }
                        play("Chip / \(item)")
                    } label: {
                        chip(item, selected: selectedChip == item)
                    }
                    .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom compact chip selection animation
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: previewColumns, spacing: 8) {
                miniPanel("输入", "Input") {
                    inputMock("金额 / Amount", "$26.80", state: selection.inputState)
                }
                miniPanel("进度", "Progress") {
                    progressMock
                }
                miniPanel("图表", "Chart") {
                    miniChart(values: [0.28, 0.62, 0.45, 0.76, 0.58, 0.84, 0.70])
                }
                miniPanel("日历", "Calendar") {
                    calendarCompact
                }
                miniPanel("反馈", "Feedback") {
                    VStack(spacing: 7) {
                        feedbackToast
                        HStack(spacing: 7) {
                            rewardPreview
                            fabMiniButton
                        }
                    }
                }
                miniPanel("提醒", "Banner") {
                    bannerPreview
                }
            }
        }
        .padding(space(11, 13, 16))
        .background(cardFill)
    }

    private var sheetRenderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            renderTitle(
                zh: "弹窗系统渲染",
                en: "Sheet system renderer",
                value: "\(selection.sheetGlass) · \(selection.sheetCard) · \(selection.sheetInput) · \(selection.sheetButton)"
            )

            ZStack(alignment: .bottom) {
                sheetPreviewBackdrop
                sheetPreview
                    .padding(10)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))

            LazyVGrid(columns: previewColumns, spacing: 8) {
                sheetTokenCell("背景", "Background", selection.sheetGlass)
                sheetTokenCell("卡片", "Card", selection.sheetCard)
                sheetTokenCell("输入", "Input", selection.sheetInput)
                sheetTokenCell("按钮", "Button", selection.sheetButton)
                sheetTokenCell("关闭", "Chrome", selection.sheetChrome)
            }
        }
        .padding(space(11, 13, 16))
        .background(cardFill)
    }

    private var previewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    private func renderTitle(zh: String, en: String, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zh)
                    .font(font(17, .black))
                    .foregroundStyle(palette.primaryText)
                Text(en)
                    .font(font(10, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Text(value)
                .font(font(9, .black))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(palette.controlFill, in: Capsule())
        }
    }

    private var navigationCompact: some View {
        HStack(spacing: selection.navigation == "rail" ? 7 : 9) {
            if selection.navigation == "rail" {
                iconButton("house.fill", selected: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.navigation == "bottom" ? "GO Focus" : "今日设计")
                    .font(font(selection.navigation == "compact" ? 14 : 16, .black))
                    .foregroundStyle(palette.primaryText)
                Text("Nav · \(selection.navigation) · \(selection.type)")
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            iconButton("calendar", selected: selection.navigation != "compact")
            iconButton("person.crop.circle.fill", selected: false)
        }
        .padding(selection.navigation == "floating" ? 10 : 0)
        .background(selection.navigation == "floating" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selection.navigation == "floating" ? palette.stroke : .clear, lineWidth: 1))
    }

    private var pageChromeAndSettingsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                tokenCaption("页面 Chrome / Page Chrome", "\(selection.pageBackButton) · \(selection.pageCloseButton)")
                Spacer()
                pageBackControl
                pageCloseControl
            }

            HStack(spacing: 8) {
                settingsRowMock(icon: "person.2.badge.key.fill", title: "设备身份", subtitle: "Account")
                settingsRowMock(icon: "paintpalette.fill", title: "UI 规范", subtitle: "Design")
            }
        }
        .padding(10)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
    }

    private var calendarCompact: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                ForEach(Array([11, 12, 13, 14, 15].enumerated()), id: \.offset) { _, day in
                    dayCell(day, selected: day == 12, active: [11, 12, 15].contains(day))
                }
            }
            if selection.calendarLayout == "timeline" || selection.calendarLayout == "agendaHybrid" {
                agendaRow("20:00", "体重记录", "Weight", "scalemass.fill", Color.goTeal)
            }
        }
    }

    private func miniPanel<Content: View>(_ zh: String, _ en: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(zh)
                    .font(font(10, .black))
                    .foregroundStyle(palette.primaryText)
                Text(en)
                    .font(font(8, .bold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
            }
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(9)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
    }

    private var sheetPreviewBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [palette.accent.opacity(0.34), palette.secondaryAccent.opacity(0.26), palette.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text(index.isMultiple(of: 2) ? "OHANA SHEET 12345" : "弹窗透明度  输入  按钮")
                            .font(font(13, .black))
                            .foregroundStyle(palette.primaryText.opacity(mode == .dark ? 0.22 : 0.34))
                        Capsule()
                            .fill(index.isMultiple(of: 2) ? palette.accent.opacity(0.36) : palette.secondaryAccent.opacity(0.28))
                            .frame(height: 5)
                    }
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -4 : 4))
                    .offset(x: CGFloat(index - 2) * 14)
                }
            }
            .padding(18)
        }
        .frame(height: 300)
    }

    private func sheetTokenCell(_ zh: String, _ en: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(zh) / \(en)")
                    .font(font(10, .black))
                    .foregroundStyle(palette.primaryText)
                Text(value)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
    }

    private var fabMiniButton: some View {
        Button {
            withAnimation(motion) {
                fabOpen.toggle()
            }
            play("FAB / \(selection.fabMotion)")
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(palette.accentText)
                .frame(width: 34, height: 34)
                .background(palette.accent, in: Circle())
                .rotationEffect(.degrees(selection.fabMotion == "rotate" && fabOpen ? 45 : 0))
                .scaleEffect(selection.fabMotion == "pop" && fabOpen ? 1.10 : 1)
                .offset(y: selection.fabMotion == "float" && fabOpen ? -5 : 0)
        }
        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom FAB mini preview motion
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("安全预览")
                    .font(font(18, .black))
                    .foregroundStyle(palette.primaryText)
                Text("Safe live preview · no real data · all tokens applied")
                    .font(font(10, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Button {
                withAnimation(motion) {
                    fabOpen.toggle()
                }
                play("FAB / \(selection.fabMotion)")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(palette.accentText)
                    .frame(width: 44, height: 44)
                    .background(palette.accent, in: Circle())
                    .rotationEffect(.degrees(selection.fabMotion == "rotate" && fabOpen ? 45 : 0))
                    .scaleEffect(selection.fabMotion == "pop" && fabOpen ? 1.10 : 1)
                    .offset(y: selection.fabMotion == "float" && fabOpen ? -6 : 0)
                    .overlay(alignment: .topTrailing) {
                        if selection.fabMotion == "fan" && fabOpen {
                            Circle()
                                .fill(Color.goBlue)
                                .frame(width: 14, height: 14)
                                .offset(x: 8, y: -8)
                        }
                    }
            }
            .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom FAB motion preview
        }
    }

    private var navigationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            tokenCaption("导航 / Navigation", selection.navigation)
            HStack(spacing: selection.navigation == "rail" ? 7 : 9) {
                if selection.navigation == "rail" {
                    VStack(spacing: 7) {
                        iconButton("house.fill", selected: true)
                        iconButton("calendar", selected: false)
                        iconButton("gearshape.fill", selected: false)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.navigation == "bottom" ? "GO Focus" : "今日设计")
                        .font(font(selection.navigation == "compact" ? 14 : 16, .black))
                        .foregroundStyle(palette.primaryText)
                    Text("Current style · \(selection.navigation)")
                        .font(font(9, .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                iconButton("calendar", selected: selection.navigation != "compact")
                iconButton("person.crop.circle.fill", selected: false)
            }
            .padding(selection.navigation == "floating" ? 10 : 0)
            .background(selection.navigation == "floating" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selection.navigation == "floating" ? palette.stroke : .clear, lineWidth: 1))

            if selection.navigation == "bottom" {
                HStack {
                    navTab("house.fill", "Home", true)
                    navTab("calendar", "Plan", false)
                    navTab("chart.bar.fill", "Stats", false)
                    navTab("gearshape.fill", "Set", false)
                }
                .padding(7)
                .background(sheetFill)
            }
        }
        .padding(12)
        .background(cardFill)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            tokenCaption("卡片 / Card", "\(selection.card) · \(selection.glass) · \(selection.density)")
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日照顾")
                        .font(font(17, .black))
                        .foregroundStyle(palette.primaryText)
                    Text("Feeding · Water · Litter")
                        .font(font(10, .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                badge("New")
            }

            HStack(spacing: 8) {
                Button("打卡 / Record") { play("按钮点击 / \(selection.tap)") }
                    .buttonStyle(buttonStyle(.primary))
                Button("Overview") { play("Overview Sheet") }
                    .buttonStyle(buttonStyle(.secondary))
            }

            listRowPreview
        }
        .padding(space(11, 13, 16))
        .background(cardFill)
    }

    private var componentStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            tokenCaption("控件 / Controls", "chip \(selection.chip) · segment \(selection.segment) · toggle \(selection.toggle)")

            segmentPreview

            HStack(spacing: 7) {
                ForEach(["干粮", "湿粮", "零食"], id: \.self) { item in
                    Button {
                        withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) {
                            selectedChip = item
                        }
                        play("Chip / \(item)")
                    } label: {
                        chip(item, selected: selectedChip == item)
                    }
                    .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom chip selection animation
                }
                Spacer(minLength: 8)
                togglePreview
            }

            HStack(spacing: 9) {
                inputMock("金额 / Amount", "$26.80", state: selection.inputState)
                progressMock
            }
        }
        .padding(12)
        .background(cardFill)
    }

    private var chartStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            tokenCaption("图表 / Chart", "\(selection.chartLine) · \(selection.chartAxis)")
            miniChart(values: [0.28, 0.62, 0.45, 0.76, 0.58, 0.84, 0.70])
        }
        .padding(12)
        .background(cardFill)
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                tokenCaption("日历 / Calendar", "\(selection.calendarLayout) · \(selection.calendarDay) · \(selection.calendarEvent)")
                Spacer()
                chip(calendarLabel, selected: true)
            }

            if selection.calendarLayout == "timeline" {
                agendaRow("09:00", "主粮计划", "Food plan", "fork.knife", palette.accent)
                agendaRow("14:30", "换水", "Water change", "drop.fill", Color.goBlue)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array([11, 12, 13, 14, 15, 16, 17].enumerated()), id: \.offset) { _, day in
                        dayCell(day, selected: day == 12, active: [11, 12, 15].contains(day))
                    }
                }
                if selection.calendarLayout == "agendaHybrid" {
                    agendaRow("20:00", "体重记录", "Weight", "scalemass.fill", Color.goTeal)
                }
            }
        }
        .padding(12)
        .background(cardFill)
    }

    private var sheetPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                tokenCaption("弹窗 / Sheet", "\(selection.sheetGlass) · \(selection.sheetCard) · \(selection.sheetInput) · \(selection.sheetButton)")
                Spacer()
                closePreview
            }
            sheetContentBlock
            HStack(spacing: 8) {
                Button(sheetActionTitle) {
                    withAnimation(motion) {
                        rewardOn.toggle()
                    }
                    play("保存成功 / \(selection.transition)")
                }
                .buttonStyle(sheetButtonStyle(selection.sheet == "confirm" || selection.sheetChrome == "danger" ? .destructive : .primary))

                if selection.sheetChrome == "bottomCTA" {
                    Button("稍后 / Later") { play("Bottom CTA") }
                        .buttonStyle(sheetButtonStyle(.secondary))
                }
            }
        }
        .padding(selection.sheet == "minimal" ? 11 : 13)
        .background(sheetFill)
        .scaleEffect(transitionOn && selection.transition == "scale" ? 1 : 0.98)
        .opacity(transitionOn && selection.transition == "fade" ? 0.82 : 1)
        .offset(y: transitionOn && selection.transition == "slide" ? -4 : 0)
    }

    private var feedbackStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            tokenCaption("反馈与动效 / Feedback & Motion", "\(selection.toast) · \(selection.banner) · \(selection.motion) · \(selection.reward)")
            feedbackToast
            bannerPreview
            HStack(spacing: 9) {
                rewardPreview
                Button("播放 / Preview") {
                    withAnimation(motion) {
                        rewardOn.toggle()
                        transitionOn.toggle()
                    }
                    play("Motion / \(selection.motion)")
                }
                .buttonStyle(buttonStyle(.secondary))
            }
        }
        .padding(12)
        .background(cardFill)
    }

    private func inputMock(_ title: String, _ value: String, state: String, sheetStyle: Bool = false) -> some View {
        let tokens = sheetStyle ? sheetTokenSelection : selection
        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
            .font(font(9, .black))
            .foregroundStyle(state == "errorFirst" ? palette.danger : palette.secondaryText)
            HStack(spacing: 7) {
                Image(systemName: icon("keyboard.fill"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(state == "errorFirst" ? palette.danger : palette.accent)
                Text(value)
                    .font(font(12, .bold))
                    .foregroundStyle(palette.primaryText)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(DesignSpecUIV4.fieldFill(selection: tokens, palette: palette), in: RoundedRectangle(cornerRadius: DesignSpecUIV4.fieldRadius(tokens), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignSpecUIV4.fieldRadius(tokens), style: .continuous).strokeBorder(tokens.input == "flat" ? .clear : palette.stroke, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressMock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("进度 / Progress")
                .font(font(9, .black))
                .foregroundStyle(palette.secondaryText)
            Group {
                switch selection.progress {
                case "ring":
                    ZStack {
                        Circle().stroke(palette.stroke.opacity(0.45), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: 0.64)
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 42, height: 42)
                case "steps":
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index < 4 ? palette.accent : palette.stroke.opacity(0.55))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .frame(height: 42)
                case "slider":
                    Slider(value: .constant(0.64))
                        .tint(palette.accent)
                        .frame(height: 42)
                default:
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.stroke.opacity(0.45))
                            Capsule().fill(palette.accent).frame(width: proxy.size.width * 0.64)
                        }
                    }
                    .frame(height: 9)
                    .padding(.vertical, 16)
                }
            }
            Text("64%")
                .font(font(10, .black))
                .foregroundStyle(palette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayCell(_ day: Int, selected: Bool, active: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(font(10, selected ? .black : .bold))
            if active {
                calendarMarker(day)
            } else {
                Spacer().frame(height: 7)
            }
        }
        .foregroundStyle(selected ? palette.accent : palette.primaryText)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(dayFill(selected: selected, active: active), in: RoundedRectangle(cornerRadius: selection.calendarDay == "filledCircle" ? 999 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: selection.calendarDay == "filledCircle" ? 999 : 12, style: .continuous).strokeBorder(selected ? palette.accent : palette.stroke, lineWidth: selection.calendarDay == "minimalNumber" ? 0 : 1))
    }

    @ViewBuilder
    private func calendarMarker(_ day: Int) -> some View {
        switch selection.calendarEvent {
        case "bars":
            Capsule().fill(palette.accent).frame(width: 18, height: 3)
        case "icons":
                Image(systemName: icon(day.isMultiple(of: 2) ? "fork.knife" : "drop.fill"))
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(palette.accent)
        case "stack":
            Text("2")
                .font(font(7, .black))
                .foregroundStyle(palette.accentText)
                .padding(.horizontal, 5)
                .background(palette.accent, in: Capsule())
        default:
            HStack(spacing: 2) {
                Circle().fill(palette.accent).frame(width: 4, height: 4)
                Circle().fill(Color.goBlue).frame(width: 4, height: 4)
            }
        }
    }

    private func agendaRow(_ time: String, _ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            Text(time)
                .font(font(9, .black))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 38, alignment: .leading)
            Image(systemName: self.icon(icon))
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(font(11, .black))
                    .foregroundStyle(palette.primaryText)
                Text(subtitle)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
        .padding(9)
        .background(calendarAgendaFill(tint), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selection.calendarAgenda == "swipeRows" ? palette.accent.opacity(0.40) : .clear, lineWidth: 1))
        .overlay(alignment: .trailing) {
            if selection.calendarAgenda == "swipeRows" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "trash")
                }
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(palette.accent)
                .padding(.trailing, 7)
            }
        }
    }

    private func chip(_ title: String, selected: Bool) -> some View {
        let radius: CGFloat
        let fill: Color
        let stroke: Color
        let foreground: Color
        switch selection.chip {
        case "soft":
            radius = 12
            fill = selected ? palette.accent.opacity(0.22) : palette.secondaryAccent.opacity(0.12)
            stroke = .clear
            foreground = selected ? palette.accent : palette.primaryText
        case "outline":
            radius = 999
            fill = selected ? palette.accent.opacity(0.12) : .clear
            stroke = selected ? palette.accent : palette.stroke
            foreground = selected ? palette.accent : palette.primaryText
        case "tiny":
            radius = 8
            fill = selected ? palette.accent : palette.flatBlock
            stroke = .clear
            foreground = selected ? palette.accentText : palette.primaryText
        default:
            radius = 999
            fill = selected ? palette.accent : palette.controlFill
            stroke = selected ? .clear : palette.stroke
            foreground = selected ? palette.accentText : palette.primaryText
        }
        return Text(title)
            .font(font(10, .black))
            .foregroundStyle(foreground)
            .padding(.horizontal, selection.chip == "tiny" ? 8 : 10)
            .padding(.vertical, selection.chip == "tiny" ? 5 : 7)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: selection.chip == "outline" ? 1.2 : 1))
            .scaleEffect(selected ? 1 : 0.97)
            .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: selected)
    }

    private func badge(_ title: String) -> some View {
        Text(selection.badge == "dot" ? "" : (selection.badge == "number" ? "2" : title))
            .font(font(8, .black))
            .foregroundStyle(selection.badge == "outline" ? palette.accent : palette.accentText)
            .frame(width: selection.badge == "dot" ? 8 : nil, height: selection.badge == "dot" ? 8 : nil)
            .padding(.horizontal, selection.badge == "dot" ? 0 : 7)
            .padding(.vertical, selection.badge == "dot" ? 0 : 4)
            .background(selection.badge == "outline" ? .clear : palette.accent, in: Capsule())
            .overlay(Capsule().strokeBorder(selection.badge == "outline" ? palette.accent : .clear, lineWidth: 1))
    }

    private var background: some View {
        ZStack {
            palette.background
            if selection.background == "goGradient" {
                RadialGradient(colors: [palette.accent.opacity(mode == .dark ? 0.25 : 0.15), .clear], center: .topLeading, startRadius: 20, endRadius: 320)
            }
        }
    }

    private var cardFill: some View {
        let shape = RoundedRectangle(cornerRadius: DesignSpecUIV4.cardRadius(selection), style: .continuous)
        return ZStack {
            if selection.card == "glass" {
                shape.fill(.ultraThinMaterial).opacity(DesignSpecUIV4.glassOpacity(selection)) // ui-v4: allow card glass option preview
                shape.fill(palette.cardFill)
            } else if selection.card == "elevated" {
                shape.fill(palette.solidCard)
            } else if selection.card == "tinted" {
                shape.fill(LinearGradient(colors: [palette.accent.opacity(0.18), palette.cardFill], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                shape.fill(selection.card == "flat" ? palette.flatBlock : palette.solidCard)
            }
        }
        .overlay(shape.strokeBorder(selection.card == "flat" ? .clear : palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(selection.card == "elevated" ? 0.16 : 0), radius: 14, y: 7) // ui-v4: allow elevated card option preview
    }

    private var sheetCardFill: some View {
        let tokens = sheetTokenSelection
        let shape = RoundedRectangle(cornerRadius: DesignSpecUIV4.cardRadius(tokens), style: .continuous)
        return ZStack {
            if selection.sheetCard == "glass" {
                sheetGlassLayers(selection.sheetGlass, shape: shape)
                shape.fill(palette.cardFill.opacity(0.52))
            } else if selection.sheetCard == "elevated" {
                shape.fill(palette.solidCard)
            } else if selection.sheetCard == "tinted" {
                shape.fill(LinearGradient(colors: [palette.accent.opacity(0.18), palette.cardFill], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                shape.fill(selection.sheetCard == "flat" ? palette.flatBlock : palette.solidCard)
            }
        }
        .overlay(shape.strokeBorder(selection.sheetCard == "flat" ? .clear : palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(selection.sheetCard == "elevated" ? 0.14 : 0), radius: 12, y: 6) // ui-v4: allow sheet card style preview depth
    }

    private var sheetFill: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack {
            sheetGlassLayers(selection.sheetGlass, shape: shape)
            shape.fill(palette.accent.opacity(0.018))
        }
        .overlay(shape.strokeBorder(sheetGlassStroke(selection.sheetGlass), lineWidth: selection.sheetGlass == "edgePrism" ? 1.2 : 1))
    }

    @ViewBuilder
    private func sheetGlassLayers(_ id: String, shape: RoundedRectangle) -> some View {
        if id == "refractive" {
            shape.fill(.clear)
                .glassEffect(.regular.tint(palette.controlFill).interactive(false), in: shape)
            shape.fill(palette.controlFill)
            shape.fill(Color.white.opacity(mode == .dark ? 0.018 : 0.090)) // ui-v4: allow sheet control-glass tint
            LinearGradient(colors: [Color.white.opacity(mode == .dark ? 0.12 : 0.32), .clear], startPoint: .topLeading, endPoint: .bottomTrailing) // ui-v4: allow sheet glass sheen
                .mask(shape.strokeBorder(lineWidth: 1.2))
        } else if id == "nativeRegular" {
            shape.fill(.clear)
                .glassEffect(.regular.interactive(false), in: shape)
            LinearGradient(colors: [Color.white.opacity(mode == .dark ? 0.10 : 0.24), .clear], startPoint: .topLeading, endPoint: .bottomTrailing) // ui-v4: allow native sheet glass sheen
                .mask(shape.strokeBorder(lineWidth: 1.0))
        } else if id == "clear" {
            shape.fill(.clear)
                .glassEffect(.clear.interactive(false), in: shape)
            LinearGradient(colors: [Color.white.opacity(mode == .dark ? 0.07 : 0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing) // ui-v4: allow clear sheet glass sheen
                .mask(shape.strokeBorder(lineWidth: 0.9))
        } else if id == "edgePrism" {
            shape.fill(.clear)
                .glassEffect(.regular.tint(palette.accent.opacity(0.10)).interactive(false), in: shape)
            RadialGradient(colors: [palette.accent.opacity(mode == .dark ? 0.20 : 0.14), .clear], center: .topLeading, startRadius: 4, endRadius: 150)
            RadialGradient(colors: [palette.secondaryAccent.opacity(mode == .dark ? 0.15 : 0.10), .clear], center: .bottomTrailing, startRadius: 4, endRadius: 150)
            LinearGradient(colors: [Color.white.opacity(0.18), .clear, palette.accent.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) // ui-v4: allow prism sheet rim
                .mask(shape.strokeBorder(lineWidth: 1.35))
        } else {
            shape.fill(.ultraThinMaterial).opacity(0.42) // ui-v4: allow calendar widget sheet material
            shape.fill(Color(hex: "1A0738").opacity(mode == .dark ? 0.46 : 0.18))
            RadialGradient(colors: [Color(hex: "00E5FF").opacity(0.24), .clear], center: .topLeading, startRadius: 4, endRadius: 150)
            RadialGradient(colors: [Color(hex: "7C3DFF").opacity(0.18), .clear], center: .topTrailing, startRadius: 4, endRadius: 150)
            LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing) // ui-v4: allow widget sheet edge
                .mask(shape.strokeBorder(lineWidth: 1.1))
        }
    }

    private func sheetGlassStroke(_ id: String) -> Color {
        switch id {
        case "refractive": return palette.stroke
        case "nativeRegular": return Color.white.opacity(mode == .dark ? 0.24 : 0.38) // ui-v4: allow native sheet rim
        case "clear": return Color.white.opacity(mode == .dark ? 0.18 : 0.30) // ui-v4: allow clear sheet rim
        case "edgePrism": return palette.accent.opacity(mode == .dark ? 0.42 : 0.34)
        default: return Color.white.opacity(mode == .dark ? 0.26 : 0.38) // ui-v4: allow widget sheet rim
        }
    }

    private func dayFill(selected: Bool, active: Bool) -> Color {
        if selected { return palette.accent.opacity(selection.calendarDay == "filledCircle" ? 1 : 0.22) }
        if selection.calendarDay == "heatmap" { return palette.accent.opacity(active ? 0.22 : 0.07) }
        if selection.calendarDay == "minimalNumber" { return .clear }
        return palette.controlFill
    }

    private var calendarLabel: String {
        switch selection.calendarLayout {
        case "monthGrid": return "月历"
        case "weekStrip": return "周条"
        case "timeline": return "时间轴"
        default: return "混合"
        }
    }

    private func play(_ message: String) {
        DesignSpecUIV4.triggerHaptic(selection)
        withAnimation(motion) {
            toast = message
        }
    }

    private func buttonStyle(_ kind: DesignSpecButtonKindV4) -> DesignSpecTokenButtonStyleV4 {
        DesignSpecTokenButtonStyleV4(kind: kind, palette: palette, selection: selection)
    }

    private func sheetButtonStyle(_ kind: DesignSpecButtonKindV4) -> DesignSpecTokenButtonStyleV4 {
        DesignSpecTokenButtonStyleV4(kind: kind, palette: palette, selection: sheetTokenSelection)
    }

    private var sheetTokenSelection: DesignSpecSelectionV4 {
        var tokens = selection
        tokens.glass = selection.sheetGlass
        tokens.card = selection.sheetCard
        tokens.input = selection.sheetInput
        tokens.button = selection.sheetButton
        return tokens
    }

    private func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        DesignSpecUIV4.typeFont(size, weight: weight, selection: selection)
    }

    private func icon(_ name: String) -> String {
        DesignSpecUIV4.iconName(name, selection: selection)
    }

    private var motion: Animation {
        DesignSpecUIV4.motionAnimation(selection)
    }

    private func space(_ compact: CGFloat, _ balanced: CGFloat, _ airy: CGFloat) -> CGFloat {
        DesignSpecUIV4.density(compact, balanced, airy, selection: selection)
    }

    private func tokenCaption(_ title: String, _ value: String) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(font(12, .black))
                .foregroundStyle(palette.primaryText)
            Text(value)
                .font(font(9, .black))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    private func iconButton(_ name: String, selected: Bool) -> some View {
        Image(systemName: icon(name))
            .font(.system(size: 12, weight: DesignSpecUIV4.iconWeight(selection)))
            .foregroundStyle(selected ? palette.accent : palette.primaryText)
            .frame(width: 30, height: 30)
            .background(palette.controlFill, in: Circle())
            .overlay(Circle().strokeBorder(selected ? palette.accent.opacity(0.35) : palette.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private var pageBackControl: some View {
        switch selection.pageBackButton {
        case "systemChevron":
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(palette.primaryText)
                .frame(width: 34, height: 34)
        case "solidCircle":
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(palette.accentText)
                .frame(width: 34, height: 34)
                .background(palette.accent, in: Circle())
        case "textPill":
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("返回")
            }
            .font(font(10, .black))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(palette.controlFill, in: Capsule())
        default:
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(palette.primaryText)
                .frame(width: 34, height: 34)
                .background(palette.controlFill, in: Circle())
                .overlay(Circle().strokeBorder(palette.stroke, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var pageCloseControl: some View {
        switch selection.pageCloseButton {
        case "circle":
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(palette.primaryText)
                .frame(width: 34, height: 34)
                .background(palette.controlFill, in: Circle())
                .overlay(Circle().strokeBorder(palette.stroke, lineWidth: 1))
        case "pill":
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                Text("关闭")
            }
            .font(font(10, .black))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(palette.controlFill, in: Capsule())
        case "text":
            Text("关闭")
                .font(font(10, .black))
                .foregroundStyle(palette.primaryText)
                .frame(height: 34)
        default:
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(palette.primaryText)
                .frame(width: 34, height: 34)
        }
    }

    private func settingsRowMock(icon iconName: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            settingIconPreview(iconName, tint: palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(font(10, .black))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(font(8, .bold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(palette.secondaryText.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(selection.listRow == "plain" ? .clear : rowFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(selection.listRow == "outlined" ? palette.stroke : .clear, lineWidth: 1))
    }

    @ViewBuilder
    private func settingIconPreview(_ iconName: String, tint: Color) -> some View {
        let glyph = Image(systemName: icon(iconName))
            .font(.system(size: 12, weight: DesignSpecUIV4.iconWeight(selection)))
        switch selection.settingIcon {
        case "plainGlyph":
            glyph
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
        case "circleDisc":
            glyph
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(mode == .dark ? 0.16 : 0.10), in: Circle())
        case "flatBlock":
            glyph
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(palette.flatBlock, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        default:
            glyph
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(mode == .dark ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private func navTab(_ name: String, _ title: String, _ selected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon(name))
            Text(title)
                .font(font(8, .black))
        }
        .font(.system(size: 12, weight: DesignSpecUIV4.iconWeight(selection)))
        .foregroundStyle(selected ? palette.accent : palette.secondaryText)
        .frame(maxWidth: .infinity)
    }

    private var listRowPreview: some View {
        HStack(spacing: 9) {
            Image(systemName: icon("clock.fill"))
                .font(.system(size: 11, weight: DesignSpecUIV4.iconWeight(selection)))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)
                .background(palette.controlFill, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("最近记录")
                    .font(font(11, .black))
                    .foregroundStyle(palette.primaryText)
                Text("List row · \(selection.listRow)")
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            badge("Row")
        }
        .padding(selection.listRow == "dense" ? 7 : 9)
        .background(selection.listRow == "plain" ? .clear : palette.controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selection.listRow == "outlined" ? palette.stroke : .clear, lineWidth: 1))
    }

    private var rowFill: Color {
        switch selection.listRow {
        case "dense": return palette.flatBlock
        case "plain": return .clear
        default: return palette.controlFill
        }
    }

    private var segmentPreview: some View {
        HStack(spacing: selection.segment == "tabs" ? 0 : 6) {
            ForEach(["7D", "30D", "90D"], id: \.self) { item in
                Button {
                    withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) { selectedChip = item }
                    play("Segment / \(selection.segment)")
                } label: {
                    Text(item)
                        .font(font(10, .black))
                        .foregroundStyle(segmentForeground(selected: selectedChip == item))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedChip == item && selection.segment != "underline" {
                                segmentItemShape
                                    .fill(segmentItemFill(selected: true))
                                    .matchedGeometryEffect(id: "segmentSelection", in: controlNamespace)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if selection.segment == "underline" && selectedChip == item {
                                Capsule()
                                    .fill(palette.accent)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "segmentUnderline", in: controlNamespace)
                            }
                        }
                }
                .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom segmented control animation
            }
        }
        .padding(selection.segment == "capsule" || selection.segment == "buttons" ? 4 : 0)
        .background(selection.segment == "capsule" || selection.segment == "buttons" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: selection.segment == "buttons" ? 12 : 999, style: .continuous))
        .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: selectedChip)
    }

    private var segmentItemShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: selection.segment == "buttons" ? 10 : 999, style: .continuous)
    }

    private func segmentItemFill(selected: Bool) -> Color {
        guard selected else { return .clear }
        switch selection.segment {
        case "underline": return .clear
        case "tabs": return palette.accent.opacity(0.20)
        default: return palette.accent
        }
    }

    private func segmentForeground(selected: Bool) -> Color {
        guard selected else { return palette.primaryText }
        return selection.segment == "capsule" || selection.segment == "buttons" ? palette.accentText : palette.accent
    }

    private var togglePreview: some View {
        Button {
            withAnimation(DesignSpecUIV4.controlChangeAnimation(selection)) { toggleOn.toggle() }
            play("Toggle / \(selection.toggle)")
        } label: {
            Group {
                switch selection.toggle {
                case "lock":
                    Image(systemName: toggleOn ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(toggleOn ? palette.accent : Color.goYellow)
                        .frame(width: 34, height: 34)
                        .background(palette.controlFill, in: Circle())
                        .symbolEffect(.bounce, value: toggleOn)
                case "text":
                    HStack(spacing: 7) {
                        compactSwitch
                        Text(toggleOn ? "公开" : "隐私")
                            .font(font(10, .black))
                            .foregroundStyle(toggleOn ? palette.accent : palette.primaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(palette.controlFill, in: Capsule())
                case "row":
                    HStack(spacing: 6) {
                        compactSwitch
                        Text("开关")
                    }
                    .font(font(10, .black))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                default:
                    compactSwitch
                }
            }
        }
        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom toggle press and knob animation
        .animation(DesignSpecUIV4.controlChangeAnimation(selection), value: toggleOn)
    }

    private var compactSwitch: some View {
        let knobSize: CGFloat = 16
        let trackWidth: CGFloat = 42
        let trackHeight: CGFloat = 20
        return ZStack(alignment: toggleOn ? .trailing : .leading) {
            Capsule()
                .fill(toggleOn ? palette.accent.opacity(0.88) : palette.controlFill)
            Circle()
                .fill(toggleOn ? palette.accentText : palette.secondaryText.opacity(0.72))
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(mode == .dark ? 0.22 : 0.12), radius: 3, y: 1) // ui-v4: allow switch knob lift
                .padding(.horizontal, 2)
        }
        .frame(width: trackWidth, height: trackHeight)
        .overlay(Capsule().strokeBorder(toggleOn ? palette.accent.opacity(0.30) : palette.stroke, lineWidth: 1))
    }

    private func miniChart(values: [CGFloat]) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let points = values.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) / CGFloat(values.count - 1) * width, y: height - value * height + 4)
            }

            ZStack {
                if selection.chartAxis != "none" {
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(palette.stroke.opacity(selection.chartAxis == "strong" ? 0.95 : 0.55))
                                .frame(height: 0.7)
                            Spacer(minLength: 0)
                        }
                    }
                }

                if selection.chartLine == "bars" {
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(values, id: \.self) { value in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(palette.accent)
                                .frame(height: max(14, value * height))
                        }
                    }
                    .padding(.horizontal, 5)
                } else {
                    if selection.chartLine == "area" {
                        areaPath(points: points, size: proxy.size)
                            .fill(LinearGradient(colors: [palette.accent.opacity(0.34), palette.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    }
                    linePath(points: points)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: selection.chartLine == "thin" ? 2 : 3.2, lineCap: .round, lineJoin: .round, dash: selection.chartLine == "dash" ? [6, 5] : []))
                }
            }
        }
        .frame(height: 76)
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private var closePreview: some View {
        Group {
            if selection.sheetChrome == "pillClose" {
                Text("关闭")
                    .font(font(10, .black))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(palette.controlFill, in: Capsule())
            } else if selection.sheetChrome == "danger" {
                Image(systemName: "trash.fill")
                    .foregroundStyle(palette.danger)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: icon("xmark"))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 28, height: 28)
            }
        }
    }

    @ViewBuilder
    private var sheetContentBlock: some View {
        sheetBody
            .padding(selection.sheet == "minimal" ? 9 : 10)
            .background(sheetCardFill)
    }

    @ViewBuilder
    private var sheetBody: some View {
        switch selection.sheet {
        case "overview":
            miniChart(values: [0.45, 0.62, 0.40, 0.75, 0.68, 0.80, 0.58])
        case "confirm":
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(palette.danger)
                Text("确认删除 / Confirm")
                    .font(font(12, .black))
                    .foregroundStyle(palette.primaryText)
                Spacer()
            }
            .padding(10)
            .background(palette.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case "minimal":
            HStack(spacing: 8) {
                chip("50g", selected: true)
                chip("75g", selected: false)
            }
        default:
            inputMock("克数 / Grams", "50g", state: "clear", sheetStyle: true)
        }
    }

    private var sheetActionTitle: String {
        selection.sheet == "confirm" || selection.sheetChrome == "danger" ? "确认删除 / Delete" : "保存记录 / Save"
    }

    private var feedbackToast: some View {
        HStack(spacing: 8) {
            if selection.toast == "icon" || selection.toast == "glass" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(palette.accent)
            }
            Text(selection.toast == "silent" ? "Saved" : "已保存 / Saved")
                .font(font(selection.toast == "compact" ? 10 : 11, .black))
                .foregroundStyle(palette.primaryText)
            Spacer()
        }
        .padding(selection.toast == "compact" ? 8 : 10)
        .background(selection.toast == "glass" ? palette.cardFill : palette.controlFill, in: RoundedRectangle(cornerRadius: selection.toast == "compact" ? 12 : 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: selection.toast == "glass" ? 18 : 12, style: .continuous).strokeBorder(selection.toast == "glass" ? palette.stroke : .clear, lineWidth: 1))
    }

    private var bannerPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: selection.banner == "quiet" ? "bell.slash.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(selection.banner == "quiet" ? palette.secondaryText : palette.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("提醒 / Banner")
                    .font(font(11, .black))
                    .foregroundStyle(palette.primaryText)
                Text(selection.banner)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
        .padding(10)
        .background(bannerFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selection.banner == "top" ? palette.warning.opacity(0.35) : .clear, lineWidth: 1))
    }

    private var rewardPreview: some View {
        HStack(spacing: 7) {
            Image(systemName: rewardIcon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(rewardOn ? palette.accent : palette.secondaryText)
                .scaleEffect(rewardOn && selection.reward == "bouncy" ? 1.18 : 1)
                .rotationEffect(.degrees(rewardOn && selection.reward == "confetti" ? 12 : 0))
            Text("Reward")
                .font(font(10, .black))
                .foregroundStyle(palette.primaryText)
        }
        .padding(10)
        .background(palette.controlFill, in: Capsule())
    }

    private var rewardIcon: String {
        switch selection.reward {
        case "confetti": return "sparkles"
        case "quiet": return "checkmark"
        case "soundless": return "speaker.slash.fill"
        default: return "heart.fill"
        }
    }

    private var bannerFill: Color {
        switch selection.banner {
        case "quiet": return palette.controlFill
        case "card": return palette.warning.opacity(0.14)
        case "top": return palette.warning.opacity(0.10)
        default: return palette.accent.opacity(0.10)
        }
    }

    private func calendarAgendaFill(_ tint: Color) -> Color {
        switch selection.calendarAgenda {
        case "plainList": return .clear
        case "groupedCards": return tint.opacity(0.12)
        default: return palette.controlFill
        }
    }
}
