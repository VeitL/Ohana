import SwiftUI

struct GrowthUnlockRulesSheet: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color {
        Color(hex: status.step.tintHex)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        GrowthUnlockLoopCard(
                            currentLevel: status.currentLevel,
                            appLanguage: appLanguage
                        )
                        GrowthUnlockStageExplorer(
                            currentLevel: status.currentLevel,
                            appLanguage: appLanguage,
                            initialStageID: status.step.id
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .accessibilityIdentifier("growth-unlock-rules-sheet")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(
                    zh: "椰子树成长图鉴",
                    en: "Coconut Tree Atlas",
                    de: "Kokosbaum-Atlas",
                    es: "Atlas del cocotero",
                    pt: "Atlas do coqueiro",
                    fr: "Atlas du cocotier",
                    ja: "ココナッツツリー図鑑",
                    ko: "코코넛 나무 도감",
                    it: "Atlante dell’albero di cocco"
                ))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "点一级，看看会长出什么",
                    en: "Tap a level to see what grows",
                    de: "Tippe eine Stufe an und entdecke mehr",
                    es: "Toca un nivel para ver qué crece",
                    pt: "Toque em um nível para ver o que cresce",
                    fr: "Touchez un niveau pour voir ce qui pousse",
                    ja: "レベルをタップして成長を確認",
                    ko: "레벨을 탭해 무엇이 자라는지 확인하세요",
                    it: "Tocca un livello e scopri cosa cresce"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(
                zh: "关闭",
                en: "Close",
                de: "Schließen",
                es: "Cerrar",
                pt: "Fechar",
                fr: "Fermer",
                ja: "閉じる",
                ko: "닫기",
                it: "Chiudi"
            ))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

struct GrowthUnlockRuleInfoButton: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onTap: () -> Void

    var body: some View {
        Button {
            OhanaFeedback.light()
            onTap()
        } label: {
            Image(systemName: "info.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch appLanguage {
        case "en":
            "Show unlock rules for \(status.step.title(language: appLanguage))"
        case "de":
            "Freischaltregeln fuer \(status.step.title(language: appLanguage)) anzeigen"
        default:
            "查看\(status.step.title(language: appLanguage))解锁规则"
        }
    }
}

struct GrowthUnlockProgressCard: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let appLanguage: String
    var isCompact = false

    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    private var nextStep: GrowthUnlockStep? {
        GrowthUnlockPolicy.nextLockedStep(currentLevel: currentLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            HStack(spacing: 10) {
                Image(systemName: currentStep.icon)
                    .font(OhanaFont.adaptive(size: isCompact ? 15 : 17, weight: .black))
                    .foregroundStyle(Color(hex: currentStep.tintHex))
                    .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38) // a11y: allow decorative growth-stage glyph; surrounding card text owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(zh: "生命之树 Lv.\(currentLevel)", en: "Life Tree Lv.\(currentLevel)", de: "Lebensbaum Lv.\(currentLevel)"))
                        .font(isCompact ? OhanaFont.callout(.black) : OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(currentStep.title(language: appLanguage))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color(hex: currentStep.tintHex))
                }

                Spacer(minLength: 8)

                if let nextStep {
                    Text("Lv.\(nextStep.requiredLevel)")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color(hex: nextStep.tintHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.ohanaControlFill, in: Capsule())
                } else {
                    Image(systemName: "checkmark.seal.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ProgressView(value: min(1, max(0, progressToNextLevel)))
                    .tint(Color.goPrimary)
                    .background(Color.ohanaControlFill, in: Capsule())
                    .clipShape(Capsule())

                Text(nextText)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isCompact ? 13 : 16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous))
    }

    private var nextText: String {
        guard let nextStep else {
            return localized(
                zh: "全部成长功能已开放，后续成长只保留奖励和长期目标。",
                en: "All growth features are open; future growth keeps rewards and long-term goals.",
                de: "Alle Wachstumsfunktionen sind offen; weiteres Wachstum bleibt Belohnung und Langzeitziel."
            )
        }
        return localized(
            zh: "下一阶段：\(nextStep.title(language: appLanguage))，Lv.\(nextStep.requiredLevel) 解锁。",
            en: "Next: \(nextStep.title(language: appLanguage)), unlocks at Lv.\(nextStep.requiredLevel).",
            de: "Weiter: \(nextStep.title(language: appLanguage)), ab Lv.\(nextStep.requiredLevel)."
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}

struct GrowthUnlockRoadmapView: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let appLanguage: String
    var onClose: (() -> Void)?

    @Environment(AppServices.self) private var appServices
    @AppStorage(PlantLockedPreviewPolicy.onboardingHasPlantsKey) private var onboardingHasPlants = false
    @State private var appearHandoffTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }
    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    private var showsPlantLockedPreview: Bool {
        _ = onboardingHasPlants
        return PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: currentLevel)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        GrowthUnlockLoopCard(
                            currentLevel: currentLevel,
                            appLanguage: appLanguage
                        )
                        GrowthUnlockProgressCard(
                            currentLevel: currentLevel,
                            progressToNextLevel: progressToNextLevel,
                            appLanguage: appLanguage
                        )
                        if showsPlantLockedPreview {
                            PlantLockedPreviewCard(
                                currentLevel: currentLevel,
                                currentEnergy: appServices.oasisTree.totalEnergy,
                                appLanguage: appLanguage
                            )
                        }
                        GrowthUnlockStageExplorer(
                            currentLevel: currentLevel,
                            appLanguage: appLanguage
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            appearHandoffTask?.cancel()
            appearHandoffTask = OhanaFrameScheduler.runAfterNextFrame {
                appServices.onboardingJourney.markRoadmapPromptSeen()
                AppPerformanceMonitor.shared.record("growth_roadmap_opened", valueMS: 0)
                appearHandoffTask = nil
            }
        }
        .onDisappear {
            appearHandoffTask?.cancel()
            appearHandoffTask = nil
        }
        .accessibilityIdentifier("growth-unlock-roadmap-screen")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(
                    zh: "椰子树成长路线",
                    en: "Coconut Tree Roadmap",
                    de: "Kokosbaum-Roadmap",
                    es: "Ruta del cocotero",
                    pt: "Rota do coqueiro",
                    fr: "Parcours du cocotier",
                    ja: "ココナッツツリーの成長ルート",
                    ko: "코코넛 나무 성장 경로",
                    it: "Percorso dell’albero di cocco"
                ))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("Lv.\(currentLevel) · \(currentStep.title(language: appLanguage))")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goPrimary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(
                    zh: "关闭",
                    en: "Close",
                    de: "Schließen",
                    es: "Cerrar",
                    pt: "Fechar",
                    fr: "Fermer",
                    ja: "閉じる",
                    ko: "닫기",
                    it: "Chiudi"
                ))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}
