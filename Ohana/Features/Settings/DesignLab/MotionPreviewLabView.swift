//
//  MotionPreviewLabView.swift
//  Ohana
//
//  System-level motion preview for choosing Ohana's restrained premium motion.
//

import SwiftUI

struct MotionPreviewLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var selectedSystem: MotionPreviewSystem = .capsule
    @State private var selectedChartSystem: MotionPreviewSystem = .flow
    @State private var selectedAccent: MotionPreviewAccent = .primary
    @State private var counter = 9709
    @State private var secondaryCounter = 11
    @State private var numberPulse = false
    @State private var floatingDelta: Int?
    @State private var deltaToken = 0
    @State private var progress = 0.62
    @State private var progressPulse = false
    @State private var chartVariant = 0
    @State private var chartReveal = true
    @State private var selectedContext = 0
    @State private var sheetVisible = false
    @State private var sheetContentVisible = false
    @State private var standaloneContentVisible = true
    @State private var triggerToken = 0

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color { selectedAccent.color }
    private var chartSystem: MotionPreviewSystem { selectedChartSystem }
    private var recipeSummary: String {
        l.tr(
            zh: "当前选择：全局 \(selectedSystem.shortName(l))；Chart 使用 \(selectedChartSystem.shortName(l))，线条慢慢延长。",
            en: "Current pick: global \(selectedSystem.shortName(l)); charts use \(selectedChartSystem.shortName(l)) with a slow line draw.",
            de: "Aktuelle Wahl: global \(selectedSystem.shortName(l)); Charts nutzen \(selectedChartSystem.shortName(l)) mit langsamem Linienaufbau."
        )
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    systemSelector
                    accentSelector
                    actionRail
                    motionSpecMatrix
                    numberScenario
                    progressScenario
                    chartScenario
                    contextScenario
                    sheetOpenScenario
                    sheetContentScenario
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.tr(zh: "Motion System 预览", en: "Motion System Preview", de: "Motion-System-Vorschau"))
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "3 套完整系统，每套分别定义数字、进度、chart、切换、sheet 打开、sheet 内容加载。",
                    en: "Three complete systems. Each defines numbers, progress, charts, switching, sheet opening, and sheet content loading.",
                    de: "Drei komplette Systeme fuer Zahlen, Fortschritt, Charts, Wechsel, Sheet-Oeffnung und Sheet-Inhaltsladen."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schliessen"))
        }
    }

    private var systemSelector: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "基础 Motion System", en: "Base Motion System", de: "Basis-Motion-System"),
            subtitle: recipeSummary
        ) {
            VStack(spacing: 10) {
                ForEach(MotionPreviewSystem.allCases) { system in
                    Button {
                        OhanaFeedback.selection()
                        withAnimation(system.animation(.switching, reduceMotion: reduceMotion)) {
                            selectedSystem = system
                            triggerToken += 1
                        }
                        replaySheetContent()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: system.icon)
                                .font(OhanaFont.adaptive(size: 15, weight: .black))
                                .foregroundStyle(selectedSystem == system ? Color.ohanaPrimaryActionText : Color.ohanaFunctionalIcon)
                                .frame(width: 34, height: 34) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                                .background(selectedSystem == system ? accent : Color.ohanaControlFill, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(system.title(l))
                                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                    Text(system.badge(l))
                                        .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(selectedSystem == system ? Color.ohanaPrimaryActionText : accent)
                                        .padding(.horizontal, 7)
                                        .frame(height: 20)
                                        .background(selectedSystem == system ? accent : accent.opacity(0.13), in: Capsule())
                                }
                                Text(system.summary(l))
                                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: selectedSystem == system ? "checkmark.circle.fill" : "circle")
                                .font(OhanaFont.adaptive(size: 18, weight: .bold))
                                .foregroundStyle(selectedSystem == system ? accent : Color.ohanaTertiaryText)
                        }
                        .padding(10)
                        .background(selectedSystem == system ? accent.opacity(0.14) : Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                                .strokeBorder(selectedSystem == system ? accent.opacity(0.52) : Color.ohanaGlassStroke.opacity(0.68), lineWidth: 1)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var accentSelector: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "5 个原色", en: "Five Base Colors", de: "Fuenf Grundfarben"),
            subtitle: l.tr(zh: "只影响本页预览，不修改全局主题。", en: "This only affects the preview page, not the global theme.", de: "Gilt nur fuer diese Vorschau, nicht fuer das globale Theme.")
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(MotionPreviewAccent.allCases) { item in
                    Button {
                        OhanaFeedback.selection()
                        withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
                            selectedAccent = item
                            triggerToken += 1
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Circle()
                                .fill(item.color)
                                .frame(width: selectedAccent == item ? 34 : 28, height: selectedAccent == item ? 34 : 28)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.ohanaPrimaryText.opacity(selectedAccent == item ? 0.86 : 0), lineWidth: 2)
                                }
                                .shadow(color: item.color.opacity(selectedAccent == item ? 0.32 : 0.10), radius: selectedAccent == item ? 12 : 5, x: 0, y: 5) // ui-v4: allow palette preview glow

                            Text(item.title(l))
                                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(selectedAccent == item ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(selectedAccent == item ? item.color.opacity(0.14) : Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                .strokeBorder(selectedAccent == item ? item.color.opacity(0.58) : Color.ohanaGlassStroke.opacity(0.65), lineWidth: 1)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var actionRail: some View {
        HStack(spacing: 9) {
            previewCommand(title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "play.fill") {
                playAll()
            }
            previewCommand(title: l.tr(zh: "数字", en: "Number", de: "Zahl"), icon: "number") {
                triggerNumber()
            }
            previewCommand(title: l.tr(zh: "进度", en: "Progress", de: "Fortschritt"), icon: "chart.bar.fill") {
                triggerProgress()
            }
            previewCommand(title: l.tr(zh: "Sheet", en: "Sheet", de: "Sheet"), icon: "rectangle.bottomthird.inset.filled") {
                toggleSheet()
            }
        }
    }

    private func previewCommand(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(accent, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            .shadow(color: accent.opacity(0.22), radius: 12, x: 0, y: 7) // ui-v4: allow primary command depth in motion preview
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var motionSpecMatrix: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "当前 Ohana 配方的 6 项设计", en: "Six Designs in the Current Ohana Recipe", de: "Sechs Designs im aktuellen Ohana-Rezept"),
            subtitle: l.tr(zh: "基础系统使用 Capsule；Chart 单独使用 Flow 的慢线条 reveal。", en: "The base system uses Capsule; charts use Flow's slow line reveal.", de: "Das Basissystem nutzt Capsule; Charts nutzen Flows langsames Linien-Reveal.")
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(MotionPreviewCategory.allCases) { category in
                    let categorySystem = system(for: category)
                    let spec = categorySystem.spec(for: category, l)
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: category.icon)
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .background(accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(category.title(l))
                                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(categorySystem.shortName(l))
                                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .padding(.horizontal, 5)
                                    .frame(height: 16)
                                    .background(accent, in: Capsule())
                            }
                            Text(spec)
                                .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
            }
        }
    }

    private var numberScenario: some View {
        MotionScenarioPanel(
            category: .number,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerNumber
        ) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(l.tr(zh: "椰子数", en: "Coconut balance", de: "Kokos-Konto"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "circle.hexagongrid.fill") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                        Text("\(counter)")
                            .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .ohanaNumericMotion(counter)
                    }
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(accent, in: Capsule())
                    .scaleEffect(numberPulse ? selectedSystem.numberScale : 1)
                    .overlay(alignment: .topTrailing) {
                        if let floatingDelta {
                            Text("+\(floatingDelta)")
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                                .offset(x: 8, y: selectedSystem.numberDeltaOffset)
                                .transition(selectedSystem.numberDeltaTransition)
                        }
                    }
                    .animation(selectedSystem.animation(.number, reduceMotion: reduceMotion), value: numberPulse)
                    .animation(selectedSystem.animation(.number, reduceMotion: reduceMotion), value: counter)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(l.tr(zh: "Today Focus", en: "Today Focus", de: "Today Focus"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text("\(secondaryCounter)")
                        .font(OhanaFont.adaptive(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .ohanaNumericMotion(secondaryCounter)
                        .scaleEffect(numberPulse ? selectedSystem.secondaryNumberScale : 1)
                }
            }
        }
    }

    private var progressScenario: some View {
        MotionScenarioPanel(
            category: .progress,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerProgress
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "能量注入", en: "Energy injection", de: "Energie"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .ohanaNumericMotion(progress)
                        .scaleEffect(progressPulse ? selectedSystem.progressLabelScale : 1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.ohanaControlFill)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(16, geo.size.width * progress))
                            .overlay(alignment: .trailing) {
                                Circle()
                                    .fill(Color.ohanaPrimaryActionText.opacity(selectedSystem.progressCapOpacity))
                                    .frame(width: 9, height: 9) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                                    .padding(.trailing, 4)
                                    .scaleEffect(progressPulse ? selectedSystem.progressCapScale : 1)
                            }
                    }
                }
                .frame(height: 18)
                .animation(selectedSystem.animation(.progress, reduceMotion: reduceMotion), value: progress)

                HStack(spacing: 8) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        Capsule()
                            .fill(index < Int(progress * 5.0) ? accent : Color.ohanaControlFill)
                            .frame(height: 8)
                            .animation(selectedSystem.animation(.progress, reduceMotion: reduceMotion).delay(selectedSystem.progressStagger * Double(index)), value: progress)
                    }
                }
            }
        }
    }

    private var chartScenario: some View {
        MotionScenarioPanel(
            category: .chart,
            system: chartSystem,
            accent: accent,
            localization: l,
            action: triggerChart
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "周趋势", en: "Weekly trend", de: "Wochentrend"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(chartSystem.chartLabel(l))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(accent.opacity(0.14), in: Capsule())
                }

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .fill(Color.ohanaControlFill.opacity(0.54))
                    MotionPreviewChartArea(points: chartPoints)
                        .fill(accent.opacity(0.16))
                        .scaleEffect(x: 1, y: chartReveal ? 1 : chartSystem.chartAreaStartScale, anchor: .bottom)
                        .opacity(chartReveal ? 1 : 0)
                    MotionPreviewChartLine(points: chartPoints)
                        .trim(from: 0, to: chartReveal ? 1 : 0)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    ForEach(chartPoints.indices, id: \.self) { index in
                        MotionPreviewChartDot(
                            point: chartPoints[index],
                            index: index,
                            count: chartPoints.count,
                            accent: accent,
                            visible: chartReveal,
                            system: chartSystem
                        )
                    }
                }
                .frame(height: 136)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .animation(chartSystem.animation(.chart, reduceMotion: reduceMotion), value: chartReveal)
            }
        }
    }

    private var contextScenario: some View {
        MotionScenarioPanel(
            category: .switching,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerContextSwitch
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(MotionPreviewContext.fixtures.indices, id: \.self) { index in
                        let item = MotionPreviewContext.fixtures[index]
                        Button {
                            guard selectedContext != index else { return }
                            withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
                                selectedContext = index
                                triggerToken += 1
                            }
                            OhanaFeedback.selection()
                        } label: {
                            Text(item.name)
                                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(selectedContext == index ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(selectedContext == index ? accent : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                let context = MotionPreviewContext.fixtures[selectedContext]
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "日历快照", en: "Calendar snapshot", de: "Kalender-Snapshot"))
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            Text(context.name)
                                .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        Spacer()
                        Text("\(context.items.count)")
                            .font(OhanaFont.adaptive(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                            .ohanaNumericMotion(context.items.count)
                    }

                    ForEach(context.items.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(index == 0 ? accent : context.tint)
                                .frame(width: 8, height: 8) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            Text(context.items[index].text(l))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Spacer()
                            Text(index == 0 ? l.tr(zh: "优先", en: "First", de: "Zuerst") : l.tr(zh: "已排程", en: "Ready", de: "Bereit"))
                                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(index == 0 ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(index == 0 ? accent : Color.ohanaControlFill, in: Capsule())
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Color.ohanaControlFill.opacity(0.64), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.ohanaCardSurfaceElevated.opacity(0.58), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                .id(selectedContext)
                .transition(selectedSystem.switchTransition)
                .ohanaContextHandoff(triggerToken, direction: .neutral, initialScale: selectedSystem.switchInitialScale)
            }
        }
    }

    private var sheetOpenScenario: some View {
        MotionScenarioPanel(
            category: .sheetOpen,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: toggleSheet
        ) {
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(l.tr(
                        zh: "这里专门看 sheet 外壳打开/关闭：位移、缩放、透明度、遮罩节奏。",
                        en: "This isolates sheet shell open/close: offset, scale, opacity, and scrim rhythm.",
                        de: "Isoliert die Sheet-Huelle: Versatz, Skalierung, Deckkraft und Scrim-Rhythmus."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        toggleSheet()
                    } label: {
                        Label(sheetVisible ? l.tr(zh: "关闭 Sheet", en: "Close Sheet", de: "Sheet schliessen") : l.tr(zh: "打开 Sheet", en: "Open Sheet", de: "Sheet oeffnen"), systemImage: "rectangle.bottomthird.inset.filled")
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.bottom, sheetVisible ? 160 : 0)

                if sheetVisible {
                    MotionPreviewSheetShell(
                        system: selectedSystem,
                        accent: accent,
                        localization: l,
                        contentVisible: sheetContentVisible,
                        onClose: toggleSheet,
                        onConfirm: {
                            triggerNumber()
                            toggleSheet()
                        }
                    )
                    .transition(selectedSystem.sheetTransition)
                }
            }
            .frame(minHeight: 264, alignment: .top)
            .animation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion), value: sheetVisible)
        }
    }

    private var sheetContentScenario: some View {
        MotionScenarioPanel(
            category: .sheetContent,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: replaySheetContent
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "内容加载节奏", en: "Content loading rhythm", de: "Inhalts-Laderhythmus"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(selectedSystem.contentLabel(l))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(accent.opacity(0.14), in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(MotionPreviewLoadingRow.fixtures.indices, id: \.self) { index in
                        MotionPreviewContentLoadingRow(
                            row: MotionPreviewLoadingRow.fixtures[index],
                            index: index,
                            visible: standaloneContentVisible,
                            accent: accent,
                            system: selectedSystem,
                            localization: l
                        )
                    }
                }
            }
        }
    }

    private var chartPoints: [CGFloat] {
        MotionPreviewChartFixtures.points[chartVariant % MotionPreviewChartFixtures.points.count]
    }

    private func system(for category: MotionPreviewCategory) -> MotionPreviewSystem {
        category == .chart ? selectedChartSystem : selectedSystem
    }

    private func playAll() {
        triggerNumber()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            triggerProgress()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            triggerChart()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            triggerContextSwitch()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            replaySheetContent()
        }
    }

    private func triggerNumber() {
        let token = deltaToken + 1
        deltaToken = token
        floatingDelta = selectedSystem == .signal ? 18 : 12
        OhanaFeedback.light()
        withAnimation(selectedSystem.animation(.number, reduceMotion: reduceMotion)) {
            numberPulse = true
            counter += floatingDelta ?? 0
            secondaryCounter += 1
            triggerToken += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.numberSettleDelay) {
            guard deltaToken == token else { return }
            withAnimation(selectedSystem.animation(.number, reduceMotion: reduceMotion)) {
                numberPulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.numberDeltaLife) {
            guard deltaToken == token else { return }
            withAnimation(GoMotion.quick) {
                floatingDelta = nil
            }
        }
    }

    private func triggerProgress() {
        let next = progress > 0.84 ? 0.36 : min(0.94, progress + selectedSystem.progressStep)
        withAnimation(selectedSystem.animation(.progress, reduceMotion: reduceMotion)) {
            progressPulse = true
            progress = next
            triggerToken += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.progressPulseLife) {
            withAnimation(selectedSystem.animation(.progress, reduceMotion: reduceMotion)) {
                progressPulse = false
            }
        }
        OhanaFeedback.selection()
    }

    private func triggerChart() {
        chartVariant = (chartVariant + 1) % MotionPreviewChartFixtures.points.count
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            chartReveal = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(chartSystem.animation(.chart, reduceMotion: reduceMotion)) {
                chartReveal = true
                triggerToken += 1
            }
        }
        OhanaFeedback.selection()
    }

    private func triggerContextSwitch() {
        withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
            selectedContext = (selectedContext + 1) % MotionPreviewContext.fixtures.count
            triggerToken += 1
        }
        OhanaFeedback.selection()
    }

    private func toggleSheet() {
        if sheetVisible {
            withAnimation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion)) {
                sheetVisible = false
                sheetContentVisible = false
            }
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sheetContentVisible = false
        }
        withAnimation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion)) {
            sheetVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.sheetContentStartDelay) {
            withAnimation(selectedSystem.animation(.sheetContent, reduceMotion: reduceMotion)) {
                sheetContentVisible = true
            }
        }
        OhanaFeedback.soft()
    }

    private func replaySheetContent() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            standaloneContentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(selectedSystem.animation(.sheetContent, reduceMotion: reduceMotion)) {
                standaloneContentVisible = true
                triggerToken += 1
            }
        }
    }
}
