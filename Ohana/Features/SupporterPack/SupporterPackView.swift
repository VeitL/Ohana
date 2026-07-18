import Foundation
import SwiftData
import SwiftUI

/// Free/Personal comparison and StoreKit purchase surface.
struct PersonalPlanView: View {
    let prompt: PersonalUpgradePrompt?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(AppServices.self) private var appServices
    @AppStorage(AppIconCatalog.selectedIconKey) private var selectedAppIcon = AppIconCatalog.defaultItemId

    @State private var selectedChoice: PersonalPurchaseChoice?
    @State private var hasCoconutIconOwnership = false
    @State private var isApplyingIcon = false
    @State private var iconErrorMessage: String?
    @State private var purchaseStatusMessage: String?

    init(prompt: PersonalUpgradePrompt? = nil) {
        self.prompt = prompt
    }

    private var l: L10n { L10n(appLanguage) }
    private var commerce: CommerceEntitlementService { appServices.commerce }

    private var canUseNeonSmileIcon: Bool {
        SupporterPackAccessPolicy.canUseNeonSmileIcon(
            hasSupporterPack: commerce.hasPersonalEntitlement,
            hasCoconutOwnership: hasCoconutIconOwnership
        )
    }

    private var hasVerifiedSubscriptionEntitlement: Bool {
        commerce.entitlementStatus == .ownedVerified &&
            !commerce.activePersonalPurchaseChoices.isDisjoint(with: [.monthly, .yearly])
    }

    private var shouldWaitForEntitlementVerification: Bool {
        commerce.hasPersonalEntitlement ||
            commerce.entitlementStatus == .checking ||
            commerce.entitlementStatus == .temporarilyUnknown
    }

    private var neonSmileDescriptor: AppIconShopDescriptor? {
        AppIconCatalog.descriptor(forItemId: SupporterPackAccessPolicy.neonSmileIconItemID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let prompt {
                            upgradeReasonCard(prompt)
                            if commerce.hasPersonalEntitlement {
                                activePlanCard
                            } else {
                                purchaseSection
                            }
                            purchaseFootnote
                        } else {
                            hero
                            if commerce.hasPersonalEntitlement {
                                activePlanCard
                            }
                            comparisonSection
                            purchaseSection
                            personalExtras
                            neonSmileCard
                            purchaseFootnote
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Ohana Personal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
                    }
                    .accessibilityIdentifier("personal-plan-close-action")
                }
            }
        }
        .accessibilityIdentifier("personal-plan-screen")
        .task {
            if prompt == nil {
                refreshCoconutIconOwnership()
            }
            guard PersonalPurchaseChoice.allCases.allSatisfy({ commerce.displayPrice(for: $0) == nil }),
                  !commerce.isLoadingProduct
            else { return }
            await commerce.reloadPersonalProducts()
        }
        .onChange(of: commerce.hasPersonalEntitlement) { _, isOwned in
            if isOwned {
                selectedChoice = nil
                purchaseStatusMessage = commerce.hasLegacySupporterPackEntitlement
                    ? legacySupporterMessage
                    : l.tr(
                        zh: "Ohana Personal 已解锁。",
                        en: "Ohana Personal is now unlocked.",
                        de: "Ohana Personal ist jetzt freigeschaltet."
                    )
            } else if commerce.entitlementStatus == .notOwnedVerified {
                purchaseStatusMessage = nil
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.16))
                    .frame(width: 88, height: 88)
                Image(systemName: commerce.hasPersonalEntitlement ? "checkmark.seal.fill" : "sparkles")
                    .font(OhanaFont.adaptive(size: 38, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
            }

            Text(commerce.hasPersonalEntitlement
                ? l.tr(zh: "Ohana Personal 已启用", en: "Ohana Personal is active", de: "Ohana Personal ist aktiv")
                : l.tr(zh: "免费够用，需要更多时再升级", en: "Free for the essentials. Upgrade when you need more.", de: "Kostenlos für das Wesentliche. Upgrade, wenn du mehr brauchst."))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)

            Text(l.tr(
                zh: "Free 没有广告，也不会锁住你的记录。Personal 为更多活跃成员与进阶本地工具而生。",
                en: "Free has no ads and never locks your records. Personal adds room to grow and advanced local tools.",
                de: "Free ist werbefrei und sperrt keine Einträge. Personal bietet mehr Platz und fortgeschrittene lokale Werkzeuge."
            ))
            .font(OhanaFont.body(.medium))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func upgradeReasonCard(_ prompt: PersonalUpgradePrompt) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.16))
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkles") // a11y: allow decorative sparkle glyph is hidden by the chained modifier below
                    .font(OhanaFont.adaptive(size: 28, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
            }

            Text(prompt.title(l))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)

            Text(prompt.detail(l))
                .font(OhanaFont.body(.medium))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("personal-plan-upgrade-reason")
    }

    private var activePlanCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill").accessibilityHidden(true)
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.goTeal)
            VStack(alignment: .leading, spacing: 4) {
                Text(activePlanTitle)
                    .font(OhanaFont.body(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(commerce.hasLegacySupporterPackEntitlement
                    ? legacySupporterMessage
                    : l.tr(
                        zh: "无限数量与全部 Personal 功能已可使用。",
                        en: "Unlimited counts and every Personal feature are available.",
                        de: "Unbegrenzte Anzahlen und alle Personal-Funktionen sind verfügbar."
                    ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.goTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("personal-plan-active-status")
    }

    private var activePlanTitle: String {
        if commerce.hasLegacySupporterPackEntitlement || commerce.activePersonalPurchaseChoices.contains(.lifetime) {
            return "Ohana Personal Lifetime"
        }
        if commerce.activePersonalPurchaseChoices.contains(.yearly) {
            return l.tr(zh: "Ohana Personal 年度方案", en: "Ohana Personal Yearly", de: "Ohana Personal jährlich")
        }
        if commerce.activePersonalPurchaseChoices.contains(.monthly) {
            return l.tr(zh: "Ohana Personal 月度方案", en: "Ohana Personal Monthly", de: "Ohana Personal monatlich")
        }
        return "Ohana Personal"
    }

    private var legacySupporterMessage: String {
        l.tr(
            zh: "你之前购买的 Supporter Pack 已自动升级为 Ohana Personal Lifetime，无需再次付费。",
            en: "Your previous Supporter Pack purchase has been upgraded to Ohana Personal Lifetime at no extra cost.",
            de: "Dein früherer Supporter-Pack-Kauf wurde ohne Aufpreis auf Ohana Personal Lifetime erweitert."
        )
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "Free 与 Personal", en: "Free and Personal", de: "Free und Personal"))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)

            freePlanCard
            personalPlanCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            planHeader(
                title: "Free",
                subtitle: l.tr(zh: "永久免费 · 无广告", en: "Free forever · No ads", de: "Dauerhaft kostenlos · Werbefrei"),
                symbol: "checkmark.shield.fill",
                tint: Color.goTeal
            )
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "person.2.fill",
                text: l.tr(
                    zh: "1 只活跃宠物、2 位活跃 Human、5 株活跃植物",
                    en: "1 active pet, 2 active Humans, and 5 active plants",
                    de: "1 aktives Tier, 2 aktive Menschen und 5 aktive Pflanzen"
                ),
                tint: Color.goTeal
            )
            featureRow(
                symbol: "calendar.badge.clock",
                text: l.tr(
                    zh: "3 个普通活跃计划；健康关键提醒不限数量",
                    en: "3 active everyday plans; health-critical reminders are unlimited",
                    de: "3 aktive Alltagspläne; gesundheitlich wichtige Erinnerungen sind unbegrenzt"
                ),
                tint: Color.goTeal
            )
            featureRow(
                symbol: "lock.open.fill",
                text: l.tr(
                    zh: "全部历史、现有数据、核心照护记录与导出始终可用",
                    en: "All history, existing data, core care records, and exports stay available",
                    de: "Verlauf, vorhandene Daten, zentrale Pflegeeinträge und Exporte bleiben verfügbar"
                ),
                tint: Color.goTeal
            )
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityIdentifier("personal-plan-free-card")
    }

    private var personalPlanCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            planHeader(
                title: "Ohana Personal",
                subtitle: l.tr(zh: "按月、按年或 Lifetime", en: "Monthly, yearly, or Lifetime", de: "Monatlich, jährlich oder Lifetime"),
                symbol: "sparkles",
                tint: Color.goPrimary
            )
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "infinity",
                text: l.tr(
                    zh: "活跃宠物、Human、植物与计划不限数量",
                    en: "Unlimited active pets, Humans, plants, and plans",
                    de: "Unbegrenzt aktive Tiere, Menschen, Pflanzen und Pläne"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "chart.xyaxis.line",
                text: l.tr(
                    zh: "90 天与全部时间的进阶趋势分析",
                    en: "Advanced 90-day and all-time trend analysis",
                    de: "Erweiterte Trendanalysen über 90 Tage und den gesamten Zeitraum"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "doc.richtext.fill",
                text: l.tr(
                    zh: "兽医 PDF 摘要",
                    en: "Vet PDF summaries",
                    de: "Tierarzt-Zusammenfassungen als PDF"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "paintpalette.fill",
                text: l.tr(
                    zh: "全部 Founding Supporter 外观权益",
                    en: "Every Founding Supporter appearance extra",
                    de: "Alle Design-Extras für Founding Supporter"
                ),
                tint: Color.goPrimary
            )
        }
        .padding(16)
        .background(Color.goPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .stroke(Color.goPrimary.opacity(0.34), lineWidth: 1)
        }
        .accessibilityIdentifier("personal-plan-personal-card")
    }

    private func planHeader(title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.body(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func featureRow(symbol: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(OhanaFont.footnote(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 22) // a11y: allow decorative glyph; this row is not interactive
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if commerce.activePersonalPurchaseChoices.contains(.lifetime) {
            VStack(spacing: 12) {
                if let purchaseStatusMessage {
                    statusMessage(purchaseStatusMessage, symbol: "info.circle.fill", tint: Color.goTeal)
                }
                if !commerce.activePersonalPurchaseChoices.isDisjoint(with: [.monthly, .yearly]),
                   let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(
                        l.tr(zh: "管理订阅", en: "Manage subscription", de: "Abonnement verwalten"),
                        destination: subscriptionsURL
                    )
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.goTeal)
                    .accessibilityIdentifier("personal-plan-manage-subscription-action")
                }
                restoreButton
            }
        } else if hasVerifiedSubscriptionEntitlement {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(
                    zh: "升级为 Lifetime",
                    en: "Upgrade to Lifetime",
                    de: "Auf Lifetime upgraden"
                ))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "Lifetime 是可选的一次性购买。购买后 Apple 不会自动取消你现有的月度或年度订阅，请在订阅管理中确认续订状态。",
                    en: "Lifetime is an optional one-time purchase. Apple does not automatically cancel your existing monthly or yearly subscription; review its renewal in subscription management.",
                    de: "Lifetime ist ein optionaler Einmalkauf. Apple kündigt dein bestehendes Monats- oder Jahresabo nicht automatisch; prüfe die Verlängerung in der Aboverwaltung."
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

                purchaseChoiceCard(.lifetime)
                purchaseActionButton

                if let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(
                        l.tr(zh: "管理现有订阅", en: "Manage existing subscription", de: "Bestehendes Abo verwalten"),
                        destination: subscriptionsURL
                    )
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.goTeal)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("personal-plan-manage-subscription-action")
                }
                restoreButton
            }
            .accessibilityIdentifier("personal-plan-lifetime-upgrade")
        } else if shouldWaitForEntitlementVerification {
            VStack(spacing: 12) {
                statusMessage(
                    l.tr(
                        zh: "正在向 App Store 核对你的 Personal 方案。核对完成前不会推荐重复购买。",
                        en: "Ohana is checking your Personal plan with the App Store. No repeat purchase will be offered until verification finishes.",
                        de: "Ohana prüft deinen Personal-Plan im App Store. Bis zum Abschluss wird kein erneuter Kauf angeboten."
                    ),
                    symbol: "checkmark.shield.fill",
                    tint: Color.goTeal
                )
                restoreButton
            }
            .accessibilityIdentifier("personal-plan-verifying-entitlement")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(zh: "选择方案", en: "Choose a plan", de: "Plan auswählen"))
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)

                ForEach(PersonalPurchaseChoice.allCases, id: \.self) { choice in
                    purchaseChoiceCard(choice)
                }

                purchaseActionButton

                if let selectedChoice,
                   commerce.displayPrice(for: selectedChoice) == nil,
                   !commerce.isLoadingProduct {
                    statusMessage(
                        l.tr(
                            zh: "暂时无法从 App Store 获取这个方案。Free 仍可正常使用。",
                            en: "This plan is temporarily unavailable from the App Store. Free still works normally.",
                            de: "Dieser Plan ist im App Store vorübergehend nicht verfügbar. Free bleibt normal nutzbar."
                        ),
                        symbol: "wifi.exclamationmark",
                        tint: Color.goOrange
                    )
                    Button {
                        reloadPersonalProducts()
                    } label: {
                        Label(
                            l.tr(zh: "重试获取方案", en: "Retry plans", de: "Pläne erneut laden"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(commerce.isPurchasing || commerce.isPurchasePending || commerce.isRestoring)
                    .accessibilityIdentifier("personal-plan-reload-products-action")
                }

                restoreButton

                if let purchaseStatusMessage {
                    statusMessage(purchaseStatusMessage, symbol: "info.circle.fill", tint: Color.goTeal)
                }
                if let error = commerce.lastErrorMessage, !error.isEmpty {
                    statusMessage(error, symbol: "exclamationmark.triangle.fill", tint: Color.goOrange)
                }
            }
        }
    }

    private var purchaseActionButton: some View {
        Button {
            purchaseSelectedPlan()
        } label: {
            HStack(spacing: 8) {
                if commerce.isPurchasing || commerce.isLoadingProduct {
                    ProgressView()
                        .tint(Color.arkInk)
                } else if commerce.isPurchasePending {
                    Image(systemName: "clock.fill").accessibilityHidden(true)
                } else {
                    Image(systemName: selectedChoice == .lifetime ? "checkmark.seal.fill" : "sparkles")
                        .accessibilityHidden(true)
                }
                Text(purchaseButtonTitle)
                    .font(OhanaFont.body(.black))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .disabled(
            commerce.isPurchasing ||
                commerce.isPurchasePending ||
                commerce.isRestoring ||
                commerce.isLoadingProduct ||
                selectedPersonalPrice == nil
        )
        .accessibilityIdentifier("personal-plan-purchase-action")
    }

    private func purchaseChoiceCard(_ choice: PersonalPurchaseChoice) -> some View {
        Button {
            selectedChoice = choice
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedChoice == choice ? "checkmark.circle.fill" : "circle")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(selectedChoice == choice ? Color.goPrimary : Color.ohanaTertiaryText)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(choiceTitle(choice))
                            .font(OhanaFont.body(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        if choice == .yearly {
                            Text(l.tr(zh: "推荐", en: "Recommended", de: "Empfohlen"))
                                .font(OhanaFont.caption2(.bold))
                                .foregroundStyle(Color.arkInk)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.goPrimary, in: Capsule())
                        }
                    }
                    Text(choiceDetail(choice))
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text(choicePrice(choice))
                    .font(OhanaFont.body(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(15)
            .contentShape(Rectangle())
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .stroke(selectedChoice == choice ? Color.goPrimary : Color.ohanaDivider, lineWidth: selectedChoice == choice ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(purchaseChoiceAccessibilityLabel(choice))
        .accessibilityValue(selectedChoice == choice
            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt"))
        .accessibilityIdentifier("personal-plan-choice-\(choice.rawValue)")
    }

    private func purchaseChoiceAccessibilityLabel(_ choice: PersonalPurchaseChoice) -> String {
        var components = [choiceTitle(choice)]
        if choice == .yearly {
            components.append(l.tr(zh: "推荐", en: "Recommended", de: "Empfohlen"))
        }
        components.append(choicePrice(choice))
        components.append(choiceDetail(choice))
        return components.joined(separator: ", ")
    }

    private func choiceTitle(_ choice: PersonalPurchaseChoice) -> String {
        switch choice {
        case .monthly:
            l.tr(zh: "月度", en: "Monthly", de: "Monatlich")
        case .yearly:
            l.tr(zh: "年度", en: "Yearly", de: "Jährlich")
        case .lifetime:
            "Lifetime"
        }
    }

    private func choiceDetail(_ choice: PersonalPurchaseChoice) -> String {
        switch choice {
        case .monthly:
            l.tr(
                zh: "按月自动续订，可随时在 Apple 账号中取消",
                en: "Renews monthly; cancel anytime in your Apple Account",
                de: "Monatliche Verlängerung; jederzeit im Apple Account kündbar"
            )
        case .yearly:
            if commerce.isEligibleForIntroOffer(for: .yearly) {
                l.tr(
                    zh: "可免费试用 14 天，之后按年续订",
                    en: "14-day free trial, then yearly renewal",
                    de: "14 Tage kostenlos, danach jährliche Verlängerung"
                )
            } else {
                l.tr(
                    zh: "按年自动续订，可随时在 Apple 账号中取消",
                    en: "Renews yearly; cancel anytime in your Apple Account",
                    de: "Jährliche Verlängerung; jederzeit im Apple Account kündbar"
                )
            }
        case .lifetime:
            l.tr(
                zh: "一次购买，永久解锁当前 Personal 功能",
                en: "One purchase for permanent access to current Personal features",
                de: "Ein Kauf für dauerhaften Zugriff auf aktuelle Personal-Funktionen"
            )
        }
    }

    private func choicePrice(_ choice: PersonalPurchaseChoice) -> String {
        guard let price = commerce.displayPrice(for: choice) else {
            return commerce.isLoadingProduct
                ? l.tr(zh: "载入中", en: "Loading", de: "Laden")
                : "—"
        }
        switch choice {
        case .monthly:
            return l.tr(
                zh: "\(price)／月",
                en: "\(price)/month",
                de: "\(price)/Monat",
                es: "\(price)/mes",
                pt: "\(price)/mês",
                fr: "\(price)/mois",
                ja: "月額\(price)",
                ko: "월 \(price)",
                it: "\(price)/mese"
            )
        case .yearly:
            return l.tr(
                zh: "\(price)／年",
                en: "\(price)/year",
                de: "\(price)/Jahr",
                es: "\(price)/año",
                pt: "\(price)/ano",
                fr: "\(price)/an",
                ja: "年額\(price)",
                ko: "연 \(price)",
                it: "\(price)/anno"
            )
        case .lifetime:
            return price
        }
    }
}

// MARK: - Purchase State and Personal Extras

private extension PersonalPlanView {

    private var purchaseButtonTitle: String {
        if commerce.isPurchasePending {
            return l.tr(zh: "等待 App Store 批准", en: "Awaiting App Store approval", de: "Warten auf App-Store-Freigabe")
        }
        if commerce.isLoadingProduct {
            return l.tr(zh: "正在获取价格", en: "Loading prices", de: "Preise werden geladen")
        }
        guard let selectedChoice else {
            return l.tr(zh: "请先选择一个方案", en: "Choose a plan to continue", de: "Wähle zuerst einen Plan")
        }
        guard let price = commerce.displayPrice(for: selectedChoice) else {
            return l.tr(zh: "App Store 暂不可用", en: "App Store unavailable", de: "App Store nicht verfügbar")
        }
        switch selectedChoice {
        case .monthly:
            return l.tr(
                zh: "选择月度方案 · \(price)",
                en: "Choose Monthly · \(price)",
                de: "Monatlich wählen · \(price)",
                es: "Elegir plan mensual · \(price)",
                pt: "Escolher plano mensal · \(price)",
                fr: "Choisir l’offre mensuelle · \(price)",
                ja: "月額プランを選択 · \(price)",
                ko: "월간 요금제 선택 · \(price)",
                it: "Scegli il piano mensile · \(price)"
            )
        case .yearly:
            return l.tr(
                zh: "选择年度方案 · \(price)",
                en: "Choose Yearly · \(price)",
                de: "Jährlich wählen · \(price)",
                es: "Elegir plan anual · \(price)",
                pt: "Escolher plano anual · \(price)",
                fr: "Choisir l’offre annuelle · \(price)",
                ja: "年額プランを選択 · \(price)",
                ko: "연간 요금제 선택 · \(price)",
                it: "Scegli il piano annuale · \(price)"
            )
        case .lifetime:
            return l.tr(
                zh: "买断 Lifetime · \(price)",
                en: "Buy Lifetime · \(price)",
                de: "Lifetime kaufen · \(price)",
                es: "Comprar Lifetime · \(price)",
                pt: "Comprar Lifetime · \(price)",
                fr: "Acheter Lifetime · \(price)",
                ja: "Lifetimeを購入 · \(price)",
                ko: "Lifetime 구매 · \(price)",
                it: "Acquista Lifetime · \(price)"
            )
        }
    }

    private var selectedPersonalPrice: String? {
        guard let selectedChoice else { return nil }
        return commerce.displayPrice(for: selectedChoice)
    }

    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            if commerce.isRestoring {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(l.tr(zh: "正在恢复…", en: "Restoring…", de: "Wiederherstellung…"))
                }
            } else {
                Text(l.tr(zh: "恢复购买", en: "Restore purchases", de: "Käufe wiederherstellen"))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.goTeal)
        .frame(maxWidth: .infinity)
        .disabled(commerce.isPurchasing || commerce.isRestoring)
        .accessibilityIdentifier("personal-plan-restore-action")
    }

    private var personalExtras: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l.tr(zh: "Personal 外观权益", en: "Personal appearance extras", de: "Design-Extras in Personal"))
                .font(OhanaFont.body(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.top, 16)
                .padding(.bottom, 7)
            featureRow(
                symbol: "photo.on.rectangle.angled",
                text: l.tr(zh: "流光绿洲、午夜群岛与霓虹网格背景", en: "Oasis Glow, Midnight Isles, and Neon Grid backgrounds", de: "Oasenleuchten-, Mitternachtsinseln- und Neonraster-Hintergründe"),
                tint: Color.goPrimary
            )
            .padding(.vertical, 8)
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "app.badge.fill",
                text: l.tr(zh: "霓虹笑脸 App 图标", en: "Neon Smile app icon", de: "Neon-Smile-App-Symbol"),
                tint: Color.goPrimary
            )
            .padding(.vertical, 8)
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "rectangle.portrait.on.rectangle.portrait.fill",
                text: l.tr(zh: "Founding Ohana 周报海报与支持者标记", en: "Founding Ohana weekly poster and supporter mark", de: "Founding-Ohana-Wochenposter und Unterstützer-Markierung"),
                tint: Color.goPrimary
            )
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityIdentifier("personal-plan-appearance-extras")
    }

    @ViewBuilder
    private var neonSmileCard: some View {
        if let descriptor = neonSmileDescriptor {
            HStack(spacing: 14) {
                AppIconArtwork(descriptor: descriptor)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "霓虹笑脸", en: "Neon Smile", de: "Neon Smile"))
                        .font(OhanaFont.body(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(neonSmileAccessDetail)
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)

                Button {
                    applyNeonSmileIcon(descriptor)
                } label: {
                    if isApplyingIcon {
                        ProgressView()
                            .tint(Color.goPrimary)
                    } else {
                        Text(selectedAppIcon == descriptor.itemId
                            ? l.tr(zh: "使用中", en: "In use", de: "Aktiv")
                            : l.tr(zh: "使用", en: "Use", de: "Nutzen"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.goPrimary)
                .disabled(
                    !canUseNeonSmileIcon ||
                        !appServices.appIcons.supportsAlternateIcons ||
                        isApplyingIcon ||
                        selectedAppIcon == descriptor.itemId
                )
                .accessibilityIdentifier("personal-plan-neon-icon-action")
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))

            if let iconErrorMessage {
                statusMessage(iconErrorMessage, symbol: "exclamationmark.triangle.fill", tint: Color.goOrange)
            }
        }
    }

    private var neonSmileAccessDetail: String {
        if commerce.hasPersonalEntitlement {
            return l.tr(zh: "已由 Ohana Personal 解锁", en: "Unlocked by Ohana Personal", de: "Durch Ohana Personal freigeschaltet")
        }
        if hasCoconutIconOwnership {
            return l.tr(zh: "已使用椰子获得，继续永久可用", en: "Already earned with coconuts and remains available", de: "Bereits mit Kokosnüssen verdient und weiter verfügbar")
        }
        return l.tr(zh: "Personal 可立即解锁，也可在椰子商店赚取", en: "Unlock it with Personal, or earn it in the Coconut Shop", de: "Mit Personal freischalten oder im Kokosnuss-Shop verdienen")
    }

    private var purchaseFootnote: some View {
        VStack(spacing: 8) {
            Text(l.tr(
                zh: "月度与年度方案会自动续订，除非在当前周期结束前至少 24 小时于 Apple 账号中取消。Lifetime 为一次性购买。付款由 Apple 处理。",
                en: "Monthly and yearly plans renew automatically unless cancelled in your Apple Account at least 24 hours before the current period ends. Lifetime is a one-time purchase. Apple processes payment.",
                de: "Monats- und Jahrespläne verlängern sich automatisch, sofern sie nicht mindestens 24 Stunden vor Ablauf im Apple Account gekündigt werden. Lifetime ist ein Einmalkauf. Apple verarbeitet die Zahlung."
            ))
            .font(OhanaFont.caption2())
            .foregroundStyle(Color.ohanaTertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text(l.tr(
                zh: "Lifetime 仅包含当前平台的本地 Personal 功能，不包含未来的 Family 在线服务或 Care+。",
                en: "Lifetime covers local Personal features on this platform; future Family online services and Care+ are not included.",
                de: "Lifetime umfasst lokale Personal-Funktionen auf dieser Plattform; künftige Family-Onlinedienste und Care+ sind nicht enthalten."
            ))
            .font(OhanaFont.caption2())
            .foregroundStyle(Color.ohanaTertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Link(
                    l.tr(zh: "隐私政策", en: "Privacy Policy", de: "Datenschutz"),
                    destination: OhanaPublicLinks.privacyPolicy
                )
                if let standardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link(
                        l.tr(zh: "使用条款", en: "Terms of Use", de: "Nutzungsbedingungen"),
                        destination: standardEULAURL
                    )
                }
            }
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(Color.goTeal)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("personal-plan-purchase-terms")
    }

    private func statusMessage(_ message: String, symbol: String, tint: Color) -> some View {
        Label(message, systemImage: symbol)
            .font(OhanaFont.footnote())
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func purchaseSelectedPlan() {
        guard let choice = selectedChoice else { return }
        purchaseStatusMessage = nil
        iconErrorMessage = nil
        Task { @MainActor in
            let outcome = await commerce.purchasePersonal(choice)
            switch outcome {
            case .purchased:
                purchaseStatusMessage = l.tr(
                    zh: "Ohana Personal 已解锁。谢谢你的支持。",
                    en: "Ohana Personal is unlocked. Thank you for your support.",
                    de: "Ohana Personal ist freigeschaltet. Danke für deine Unterstützung."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .pending:
                purchaseStatusMessage = l.tr(
                    zh: "购买正在等待批准，完成后会自动解锁。",
                    en: "The purchase is awaiting approval and will unlock automatically when completed.",
                    de: "Der Kauf wartet auf Freigabe und wird danach automatisch aktiviert."
                )
            case .cancelled:
                break
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func restorePurchases() {
        purchaseStatusMessage = nil
        iconErrorMessage = nil
        Task { @MainActor in
            let outcome = await commerce.restorePurchases()
            switch outcome {
            case .restored:
                purchaseStatusMessage = commerce.hasLegacySupporterPackEntitlement
                    ? legacySupporterMessage
                    : l.tr(
                        zh: "Ohana Personal 已恢复。",
                        en: "Ohana Personal restored.",
                        de: "Ohana Personal wurde wiederhergestellt."
                    )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .noPurchases:
                if commerce.isPurchasePending {
                    purchaseStatusMessage = l.tr(
                        zh: "购买正在等待批准，完成后会自动解锁。",
                        en: "The purchase is awaiting approval and will unlock automatically when completed.",
                        de: "Der Kauf wartet auf Freigabe und wird danach automatisch aktiviert."
                    )
                } else {
                    purchaseStatusMessage = l.tr(
                        zh: "当前 Apple 账号没有可恢复的 Personal 或 Supporter Pack 购买。",
                        en: "The current Apple Account has no Personal or Supporter Pack purchase to restore.",
                        de: "Für den aktuellen Apple Account gibt es keinen Personal- oder Supporter-Pack-Kauf zum Wiederherstellen."
                    )
                }
            case .failed:
                break
            }
        }
    }

    private func reloadPersonalProducts() {
        purchaseStatusMessage = nil
        iconErrorMessage = nil
        Task { @MainActor in
            await commerce.reloadPersonalProducts()
        }
    }

    private func refreshCoconutIconOwnership() {
        do {
            let hasRecord = try ShopPurchaseRecordStore.isOwned(
                itemID: SupporterPackAccessPolicy.neonSmileIconItemID,
                context: modelContext
            )
            let legacyIDs = ShopPurchaseRecordStore.legacyPurchasedItemIDs(
                raw: UserDefaults.standard.string(
                    forKey: SupporterPackCatalog.supporterIconLegacyOwnershipKey
                ) ?? ""
            )
            hasCoconutIconOwnership = hasRecord || legacyIDs.contains(SupporterPackAccessPolicy.neonSmileIconItemID)
        } catch {
            // StoreKit entitlement remains independently usable. A failed
            // local ownership read never grants the icon or blocks this screen.
            hasCoconutIconOwnership = false
        }
    }

    private func applyNeonSmileIcon(_ descriptor: AppIconShopDescriptor) {
        guard canUseNeonSmileIcon, appServices.appIcons.supportsAlternateIcons else { return }
        isApplyingIcon = true
        iconErrorMessage = nil
        appServices.appIcons.setIcon(descriptor) { result in
            isApplyingIcon = false
            switch result {
            case .success:
                selectedAppIcon = descriptor.itemId
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case let .failure(error):
                iconErrorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

/// Compatibility wrapper for the existing background-picker and other routes.
/// Every legacy entry now opens the Personal comparison, not the retired
/// cosmetic-only Supporter Pack offer.
struct SupporterPackView: View {
    var body: some View {
        PersonalPlanView()
    }
}
