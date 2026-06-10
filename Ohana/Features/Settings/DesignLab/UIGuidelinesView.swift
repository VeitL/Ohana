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
                    Image(systemName: "chevron.left") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(palette.primaryText)
                        .frame(width: 32, height: 32) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
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

                NavigationLink {
                    GrowthUnlockFlowTestView()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tree.fill") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .background(palette.controlFill, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("成长解锁流程 / Growth Unlock")
                                .font(DesignSpecUIV4.typeFont(13, weight: .black, selection: selection))
                                .foregroundStyle(palette.primaryText)
                            Text("新手引导、树等级、功能锁测试")
                                .font(DesignSpecUIV4.typeFont(10, weight: .bold, selection: selection))
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(minHeight: 44)
                    .padding(13)
                    .background(glass(cornerRadius: OhanaRadius.input))
                }
                .buttonStyle(ScaleButtonStyle()) // ui-v4: developer flow test entry

                DesignSpecControlsPanelV4(selection: $selection, step: $step, mode: previewMode)

                advancedToggle(
                    title: "设计检查 / Design Audit",
                    icon: "checkmark.shield.fill",
                    isExpanded: $showAudit
                )
                if showAudit {
                    DesignSpecAuditPanelV4(selection: selection, mode: previewMode)
                }

                advancedToggle(
                    title: "导出规范 / Export",
                    icon: "square.and.arrow.up.fill",
                    isExpanded: $showExport
                )
                if showExport {
                    exportPanel
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
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
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
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(DesignSpecUIV4.typeFont(13, weight: .black, selection: selection))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Image(systemName: "chevron.down") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .foregroundStyle(palette.secondaryText)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
            }
            .padding(13)
            .background(glass(cornerRadius: OhanaRadius.input))
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
                    Image(systemName: "arrow.counterclockwise") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .frame(width: 22, height: 22) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
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
        .background(glass(cornerRadius: OhanaRadius.cardSoft))
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
