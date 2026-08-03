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
                        Label(l.tr(zh: "关闭", en: "Close", de: "Schließen",
                            es: "Cerrar",
                            pt: "Fechar",
                            fr: "Fermer",
                            ja: "閉じる",
                            ko: "닫기",
                            it: "Chiudi"), systemImage: "xmark")
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
                        de: "Ohana Personal ist jetzt freigeschaltet.",
                        es: "Ohana Personal ya está desbloqueado.",
                        pt: "Ohana Personal foi desbloqueado.",
                        fr: "Ohana Personal est maintenant débloqué.",
                        ja: "Ohana Personalが利用可能になりました。",
                        ko: "Ohana Personal이 잠금 해제되었습니다.",
                        it: "Ohana Personal è ora sbloccato."
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
                ? l.tr(zh: "Ohana Personal 已启用", en: "Ohana Personal is active", de: "Ohana Personal ist aktiv",
                    es: "Ohana Personal está activo",
                    pt: "Ohana Personal está ativo",
                    fr: "Ohana Personal est actif",
                    ja: "Ohana Personalは有効です",
                    ko: "Ohana Personal이 활성화되었습니다",
                    it: "Ohana Personal è attivo")
                : l.tr(zh: "免费够用，需要更多时再升级", en: "Free for the essentials. Upgrade when you need more.", de: "Kostenlos für das Wesentliche. Upgrade, wenn du mehr brauchst.",
                    es: "Free cubre lo esencial. Mejora cuando necesites más.",
                    pt: "Free cobre o essencial. Faça upgrade quando precisar de mais.",
                    fr: "Free couvre l’essentiel. Passez à la version supérieure si nécessaire.",
                    ja: "基本機能はFreeで。必要になったらアップグレード。",
                    ko: "필수 기능은 Free로. 더 필요할 때 업그레이드하세요.",
                    it: "Free copre l’essenziale. Passa al livello superiore quando serve."))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)

            Text(l.tr(
                zh: "Free 没有广告，也不会锁住你的记录。Personal 为更多活跃成员与进阶本地工具而生。",
                en: "Free has no ads and never locks your records. Personal adds room to grow and advanced local tools.",
                de: "Free ist werbefrei und sperrt keine Einträge. Personal bietet mehr Platz und fortgeschrittene lokale Werkzeuge.",
                es: "Free no tiene anuncios y nunca bloquea tus registros. Ohana Personal ofrece más espacio para crecer y herramientas locales avanzadas.",
                pt: "Free não tem anúncios e nunca bloqueia seus registros. Ohana Personal oferece mais espaço para crescer e ferramentas locais avançadas.",
                fr: "Free est sans publicité et ne bloque jamais vos données. Ohana Personal offre plus de capacité et des outils locaux avancés.",
                ja: "Freeには広告がなく、記録がロックされることもありません。Ohana Personalでは利用枠が広がり、高度なローカルツールを使えます。",
                ko: "Free에는 광고가 없으며 기록을 잠그지 않습니다. Ohana Personal은 더 넉넉한 이용 한도와 고급 로컬 도구를 제공합니다.",
                it: "Free è senza pubblicità e non blocca mai i tuoi dati. Ohana Personal offre più spazio per crescere e strumenti locali avanzati."
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
                        de: "Unbegrenzte Anzahlen und alle Personal-Funktionen sind verfügbar.",
                        es: "Las cantidades son ilimitadas y todas las funciones de Ohana Personal están disponibles.",
                        pt: "As quantidades são ilimitadas e todos os recursos do Ohana Personal estão disponíveis.",
                        fr: "Les quantités sont illimitées et toutes les fonctionnalités Ohana Personal sont disponibles.",
                        ja: "利用数は無制限で、Ohana Personalのすべての機能を利用できます。",
                        ko: "이용 수는 무제한이며 Ohana Personal의 모든 기능을 사용할 수 있습니다.",
                        it: "Le quantità sono illimitate e tutte le funzioni Ohana Personal sono disponibili."
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
            return l.tr(zh: "Ohana Personal 年度方案", en: "Ohana Personal Yearly", de: "Ohana Personal jährlich",
                es: "Ohana Personal anual",
                pt: "Ohana Personal anual",
                fr: "Ohana Personal annuel",
                ja: "Ohana Personal 年額",
                ko: "Ohana Personal 연간",
                it: "Ohana Personal annuale")
        }
        if commerce.activePersonalPurchaseChoices.contains(.monthly) {
            return l.tr(zh: "Ohana Personal 月度方案", en: "Ohana Personal Monthly", de: "Ohana Personal monatlich",
                es: "Ohana Personal mensual",
                pt: "Ohana Personal mensal",
                fr: "Ohana Personal mensuel",
                ja: "Ohana Personal 月額",
                ko: "Ohana Personal 월간",
                it: "Ohana Personal mensile")
        }
        return "Ohana Personal"
    }

    private var legacySupporterMessage: String {
        l.tr(
            zh: "你之前购买的 Supporter Pack 已自动升级为 Ohana Personal Lifetime，无需再次付费。",
            en: "Your previous Supporter Pack purchase has been upgraded to Ohana Personal Lifetime at no extra cost.",
            de: "Dein früherer Supporter-Pack-Kauf wurde ohne Aufpreis auf Ohana Personal Lifetime erweitert.",
            es: "Tu compra anterior de Supporter Pack se ha actualizado a Ohana Personal Lifetime sin coste adicional.",
            pt: "Sua compra anterior do Supporter Pack foi atualizada para Ohana Personal Lifetime sem custo adicional.",
            fr: "Votre ancien achat de Supporter Pack a été converti en Ohana Personal Lifetime sans frais supplémentaires.",
            ja: "以前購入したSupporter Packは、追加料金なしでOhana Personal Lifetimeにアップグレードされました。",
            ko: "이전에 구매한 Supporter Pack이 추가 비용 없이 Ohana Personal Lifetime으로 업그레이드되었습니다.",
            it: "Il tuo precedente acquisto di Supporter Pack è stato aggiornato a Ohana Personal Lifetime senza costi aggiuntivi."
        )
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "Free 与 Personal", en: "Free and Personal", de: "Free und Personal",
                es: "Free y Personal",
                pt: "Free e Personal",
                fr: "Free et Personal",
                ja: "FreeとPersonal",
                ko: "Free와 Personal",
                it: "Free e Personal"))
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
                subtitle: l.tr(
                    zh: "每天轻松记录 · 永久免费",
                    en: "Easy everyday records · Free forever",
                    de: "Täglich leicht festhalten · Dauerhaft kostenlos",
                    es: "Registros diarios sencillos · Gratis para siempre",
                    pt: "Registros diários simples · Grátis para sempre",
                    fr: "Noter le quotidien simplement · Gratuit pour toujours",
                    ja: "毎日を気軽に記録 · ずっと無料",
                    ko: "매일 가볍게 기록 · 평생 무료",
                    it: "Registri quotidiani semplici · Gratis per sempre"
                ),
                symbol: "checkmark.shield.fill",
                tint: Color.goTeal
            )
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "person.2.fill",
                text: l.tr(
                    zh: "1 只活跃宠物、2 位活跃 Human、5 株活跃植物",
                    en: "1 active pet, 2 active Humans, and 5 active plants",
                    de: "1 aktives Tier, 2 aktive Menschen und 5 aktive Pflanzen",
                    es: "1 mascota activa, 2 Human activos y 5 plantas activas",
                    pt: "1 animal ativo, 2 Human ativos e 5 plantas ativas",
                    fr: "1 animal actif, 2 Human actifs et 5 plantes actives",
                    ja: "アクティブなペット1匹、Human 2人、植物5株",
                    ko: "활성 반려동물 1마리, Human 2명, 식물 5개",
                    it: "1 animale attivo, 2 Human attivi e 5 piante attive"
                ),
                tint: Color.goTeal
            )
            featureRow(
                symbol: "calendar.badge.clock",
                text: l.tr(
                    zh: "3 个普通活跃计划；健康关键提醒不限数量",
                    en: "3 active everyday plans; health-critical reminders are unlimited",
                    de: "3 aktive Alltagspläne; gesundheitlich wichtige Erinnerungen sind unbegrenzt",
                    es: "3 planes cotidianos activos; los recordatorios críticos de salud no tienen límite",
                    pt: "3 planos ativos do dia a dia; lembretes críticos de saúde são ilimitados",
                    fr: "3 plans courants actifs ; les rappels de santé essentiels sont illimités",
                    ja: "通常のアクティブなプランは3件まで。健康上重要なリマインダーは無制限",
                    ko: "일반 활성 플랜 3개, 건강상 중요한 미리 알림은 무제한",
                    it: "3 piani quotidiani attivi; i promemoria sanitari essenziali sono illimitati"
                ),
                tint: Color.goTeal
            )
            featureRow(
                symbol: "lock.open.fill",
                text: l.tr(
                    zh: "全部历史、现有数据、核心照护记录与导出始终可用",
                    en: "All history, existing data, core care records, and exports stay available",
                    de: "Verlauf, vorhandene Daten, zentrale Pflegeeinträge und Exporte bleiben verfügbar",
                    es: "Todo el historial, los datos existentes, los registros de cuidados esenciales y las exportaciones siguen disponibles",
                    pt: "Todo o histórico, os dados existentes, os registros essenciais de cuidados e as exportações continuam disponíveis",
                    fr: "Tout l’historique, les données existantes, les soins essentiels et les exportations restent disponibles",
                    ja: "すべての履歴、既存データ、基本のケア記録、エクスポートは引き続き利用できます",
                    ko: "전체 기록, 기존 데이터, 핵심 돌봄 기록 및 내보내기는 계속 이용할 수 있습니다",
                    it: "Tutta la cronologia, i dati esistenti, le cure essenziali e le esportazioni restano disponibili"
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
                subtitle: l.tr(
                    zh: "看懂长期变化 · 更多本地工具",
                    en: "Understand long-term change · More local tools",
                    de: "Langfristige Veränderungen verstehen · Mehr lokale Werkzeuge",
                    es: "Entiende los cambios a largo plazo · Más herramientas locales",
                    pt: "Entenda mudanças de longo prazo · Mais ferramentas locais",
                    fr: "Comprendre les évolutions · Plus d’outils locaux",
                    ja: "長期の変化を理解 · 充実したローカル機能",
                    ko: "장기 변화를 이해 · 더 많은 로컬 도구",
                    it: "Comprendi i cambiamenti nel tempo · Più strumenti locali"
                ),
                symbol: "sparkles",
                tint: Color.goPrimary
            )
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "infinity",
                text: l.tr(
                    zh: "活跃宠物、Human、植物与计划不限数量",
                    en: "Unlimited active pets, Humans, plants, and plans",
                    de: "Unbegrenzt aktive Tiere, Menschen, Pflanzen und Pläne",
                    es: "Mascotas activas, Human, plantas y planes sin límite",
                    pt: "Animais ativos, Human, plantas e planos sem limite",
                    fr: "Animaux actifs, Human, plantes et plans sans limite",
                    ja: "アクティブなペット、Human、植物、プランが無制限",
                    ko: "활성 반려동물, Human, 식물 및 플랜 무제한",
                    it: "Animali attivi, Human, piante e piani senza limiti"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "chart.xyaxis.line",
                text: l.tr(
                    zh: "90 天与全部时间的进阶趋势分析",
                    en: "Advanced 90-day and all-time trend analysis",
                    de: "Erweiterte Trendanalysen über 90 Tage und den gesamten Zeitraum",
                    es: "Análisis avanzados de tendencias de 90 días y de todo el historial",
                    pt: "Análises avançadas de tendências de 90 dias e de todo o histórico",
                    fr: "Analyses avancées des tendances sur 90 jours et sur tout l’historique",
                    ja: "90日間と全期間の高度な傾向分析",
                    ko: "90일 및 전체 기간 고급 추세 분석",
                    it: "Analisi avanzate delle tendenze a 90 giorni e dell’intero storico"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "doc.richtext.fill",
                text: l.tr(
                    zh: "兽医 PDF 摘要",
                    en: "Vet PDF summaries",
                    de: "Tierarzt-Zusammenfassungen als PDF",
                    es: "Resúmenes veterinarios en PDF",
                    pt: "Resumos veterinários em PDF",
                    fr: "Résumés vétérinaires en PDF",
                    ja: "獣医向けPDF要約",
                    ko: "수의사용 PDF 요약",
                    it: "Riepiloghi veterinari in PDF"
                ),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "doc.viewfinder",
                text: l.tr(zh: "本机化验单扫描与逐项复核；原图与 OCR 不上传、不长期保存", en: "On-device lab report scanning and item-by-item review; source images and OCR aren’t uploaded or retained", de: "Laborberichte auf dem Gerät scannen und einzeln prüfen; Quellbilder und OCR werden weder hochgeladen noch gespeichert",
                    es: "Escaneo local de informes de laboratorio y revisión elemento por elemento; las imágenes originales y el OCR no se suben ni se conservan", pt: "Digitalização local de laudos laboratoriais e revisão item a item; imagens originais e OCR não são enviados nem mantidos", fr: "Numérisation locale des analyses et vérification élément par élément ; les images sources et l’OCR ne sont ni envoyés ni conservés",
                    ja: "端末上で検査報告書をスキャンし、項目ごとに確認。元画像とOCRはアップロードも長期保存もされません", ko: "기기 내 검사 보고서 스캔 및 항목별 검토; 원본 이미지와 OCR은 업로드하거나 장기 보관하지 않음", it: "Scansione locale dei referti di laboratorio e revisione voce per voce; immagini originali e OCR non vengono caricati né conservati"),
                tint: Color.goPrimary
            )
            featureRow(
                symbol: "paintpalette.fill",
                text: l.tr(
                    zh: "全部 Founding Supporter 外观权益",
                    en: "Every Founding Supporter appearance extra",
                    de: "Alle Design-Extras für Founding Supporter",
                    es: "Todos los extras visuales de Founding Supporter",
                    pt: "Todos os extras visuais de Founding Supporter",
                    fr: "Tous les extras visuels Founding Supporter",
                    ja: "Founding Supporterのすべての外観特典",
                    ko: "Founding Supporter의 모든 디자인 혜택",
                    it: "Tutti gli extra estetici Founding Supporter"
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
}

private extension PersonalPlanView {
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
                        l.tr(zh: "管理订阅", en: "Manage subscription", de: "Abonnement verwalten",
                            es: "Gestionar suscripción",
                            pt: "Gerenciar assinatura",
                            fr: "Gérer l’abonnement",
                            ja: "サブスクリプションを管理",
                            ko: "구독 관리",
                            it: "Gestisci abbonamento"),
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
                    de: "Auf Lifetime upgraden",
                    es: "Actualizar a Lifetime",
                    pt: "Fazer upgrade para Lifetime",
                    fr: "Passer à Lifetime",
                    ja: "Lifetimeにアップグレード",
                    ko: "Lifetime으로 업그레이드",
                    it: "Passa a Lifetime"
                ))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "Lifetime 是可选的一次性购买。购买后 Apple 不会自动取消你现有的月度或年度订阅，请在订阅管理中确认续订状态。",
                    en: "Lifetime is an optional one-time purchase. Apple does not automatically cancel your existing monthly or yearly subscription; review its renewal in subscription management.",
                    de: "Lifetime ist ein optionaler Einmalkauf. Apple kündigt dein bestehendes Monats- oder Jahresabo nicht automatisch; prüfe die Verlängerung in der Aboverwaltung.",
                    es: "Lifetime es una compra única opcional. Apple no cancela automáticamente tu suscripción mensual o anual actual; comprueba su renovación en la gestión de suscripciones.",
                    pt: "Lifetime é uma compra única opcional. A Apple não cancela automaticamente sua assinatura mensal ou anual atual; confira a renovação no gerenciamento de assinaturas.",
                    fr: "Lifetime est un achat unique facultatif. Apple n’annule pas automatiquement votre abonnement mensuel ou annuel actuel ; vérifiez son renouvellement dans la gestion des abonnements.",
                    ja: "Lifetimeは任意の買い切り購入です。Appleが現在の月額または年額サブスクリプションを自動的に解約することはありません。サブスクリプション管理で更新状況を確認してください。",
                    ko: "Lifetime은 선택 가능한 일회성 구매입니다. Apple은 기존 월간 또는 연간 구독을 자동으로 취소하지 않으니 구독 관리에서 갱신 상태를 확인하세요.",
                    it: "Lifetime è un acquisto una tantum facoltativo. Apple non annulla automaticamente l’abbonamento mensile o annuale esistente; verificane il rinnovo nella gestione abbonamenti."
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

                purchaseChoiceCard(.lifetime)
                purchaseActionButton

                if let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(
                        l.tr(zh: "管理现有订阅", en: "Manage existing subscription", de: "Bestehendes Abo verwalten",
                            es: "Gestionar suscripción actual",
                            pt: "Gerenciar assinatura atual",
                            fr: "Gérer l’abonnement actuel",
                            ja: "現在のサブスクリプションを管理",
                            ko: "기존 구독 관리",
                            it: "Gestisci abbonamento esistente"),
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
                        de: "Ohana prüft deinen Personal-Plan im App Store. Bis zum Abschluss wird kein erneuter Kauf angeboten.",
                        es: "Ohana está comprobando tu plan Ohana Personal con App Store. No se ofrecerá otra compra hasta que termine la verificación.",
                        pt: "Ohana está verificando seu plano Ohana Personal com a App Store. Nenhuma nova compra será oferecida até o fim da verificação.",
                        fr: "Ohana vérifie votre formule Ohana Personal auprès de l’App Store. Aucun nouvel achat ne sera proposé avant la fin de la vérification.",
                        ja: "OhanaがApp StoreでOhana Personalプランを確認しています。確認が完了するまで、再購入は案内されません。",
                        ko: "Ohana가 App Store에서 Ohana Personal 플랜을 확인하고 있습니다. 확인이 끝날 때까지 재구매가 제공되지 않습니다.",
                        it: "Ohana sta verificando il tuo piano Ohana Personal con l’App Store. Non verrà proposto un nuovo acquisto finché la verifica non sarà completata."
                    ),
                    symbol: "checkmark.shield.fill",
                    tint: Color.goTeal
                )
                restoreButton
            }
            .accessibilityIdentifier("personal-plan-verifying-entitlement")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(zh: "选择方案", en: "Choose a plan", de: "Plan auswählen",
                    es: "Elegir un plan",
                    pt: "Escolher um plano",
                    fr: "Choisir une formule",
                    ja: "プランを選択",
                    ko: "플랜 선택",
                    it: "Scegli un piano"))
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
                            de: "Dieser Plan ist im App Store vorübergehend nicht verfügbar. Free bleibt normal nutzbar.",
                            es: "Este plan no está disponible temporalmente en App Store. Free sigue funcionando con normalidad.",
                            pt: "Este plano está temporariamente indisponível na App Store. Free continua funcionando normalmente.",
                            fr: "Cette formule est temporairement indisponible sur l’App Store. Free reste pleinement utilisable.",
                            ja: "このプランは現在App Storeで一時的に利用できません。Freeは引き続き通常どおり使えます。",
                            ko: "이 플랜은 현재 App Store에서 일시적으로 사용할 수 없습니다. Free는 계속 정상적으로 이용할 수 있습니다.",
                            it: "Questo piano è temporaneamente non disponibile sull’App Store. Free continua a funzionare normalmente."
                        ),
                        symbol: "wifi.exclamationmark",
                        tint: Color.goOrange
                    )
                    Button {
                        reloadPersonalProducts()
                    } label: {
                        Label(
                            l.tr(zh: "重试获取方案", en: "Retry plans", de: "Pläne erneut laden",
                                es: "Volver a cargar los planes",
                                pt: "Carregar planos novamente",
                                fr: "Recharger les formules",
                                ja: "プランを再読み込み",
                                ko: "플랜 다시 불러오기",
                                it: "Ricarica i piani"),
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
                            Text(l.tr(zh: "推荐", en: "Recommended", de: "Empfohlen",
                                es: "Recomendado",
                                pt: "Recomendado",
                                fr: "Recommandé",
                                ja: "おすすめ",
                                ko: "추천",
                                it: "Consigliato"))
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
            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt",
                es: "Seleccionado",
                pt: "Selecionado",
                fr: "Sélectionné",
                ja: "選択中",
                ko: "선택됨",
                it: "Selezionato")
            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt",
                es: "No seleccionado",
                pt: "Não selecionado",
                fr: "Non sélectionné",
                ja: "未選択",
                ko: "선택되지 않음",
                it: "Non selezionato"))
        .accessibilityIdentifier("personal-plan-choice-\(choice.rawValue)")
    }

    private func purchaseChoiceAccessibilityLabel(_ choice: PersonalPurchaseChoice) -> String {
        var components = [choiceTitle(choice)]
        if choice == .yearly {
            components.append(l.tr(zh: "推荐", en: "Recommended", de: "Empfohlen",
                es: "Recomendado",
                pt: "Recomendado",
                fr: "Recommandé",
                ja: "おすすめ",
                ko: "추천",
                it: "Consigliato"))
        }
        components.append(choicePrice(choice))
        components.append(choiceDetail(choice))
        return components.joined(separator: ", ")
    }

    private func choiceTitle(_ choice: PersonalPurchaseChoice) -> String {
        switch choice {
        case .monthly:
            l.tr(zh: "月度", en: "Monthly", de: "Monatlich",
                es: "Mensual",
                pt: "Mensal",
                fr: "Mensuel",
                ja: "月額",
                ko: "월간",
                it: "Mensile")
        case .yearly:
            l.tr(zh: "年度", en: "Yearly", de: "Jährlich",
                es: "Anual",
                pt: "Anual",
                fr: "Annuel",
                ja: "年額",
                ko: "연간",
                it: "Annuale")
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
                de: "Monatliche Verlängerung; jederzeit im Apple Account kündbar",
                es: "Se renueva mensualmente; cancela cuando quieras en tu cuenta de Apple",
                pt: "Renovação mensal; cancele quando quiser na sua Conta Apple",
                fr: "Renouvellement mensuel ; annulez à tout moment dans votre compte Apple",
                ja: "毎月自動更新。Apple Accountでいつでも解約できます",
                ko: "매월 자동 갱신되며 Apple 계정에서 언제든지 취소할 수 있습니다",
                it: "Rinnovo mensile; annulla in qualsiasi momento nel tuo Apple Account"
            )
        case .yearly:
            if commerce.isEligibleForIntroOffer(for: .yearly) {
                l.tr(
                    zh: "可免费试用 14 天，之后按年续订",
                    en: "14-day free trial, then yearly renewal",
                    de: "14 Tage kostenlos, danach jährliche Verlängerung",
                    es: "14 días de prueba gratis; después, renovación anual",
                    pt: "Teste grátis por 14 dias; depois, renovação anual",
                    fr: "Essai gratuit de 14 jours, puis renouvellement annuel",
                    ja: "14日間無料、その後は年額で更新",
                    ko: "14일 무료 체험 후 연간 갱신",
                    it: "Prova gratuita di 14 giorni, poi rinnovo annuale"
                )
            } else {
                l.tr(
                    zh: "按年自动续订，可随时在 Apple 账号中取消",
                    en: "Renews yearly; cancel anytime in your Apple Account",
                    de: "Jährliche Verlängerung; jederzeit im Apple Account kündbar",
                    es: "Se renueva anualmente; cancela cuando quieras en tu cuenta de Apple",
                    pt: "Renovação anual; cancele quando quiser na sua Conta Apple",
                    fr: "Renouvellement annuel ; annulez à tout moment dans votre compte Apple",
                    ja: "毎年自動更新。Apple Accountでいつでも解約できます",
                    ko: "매년 자동 갱신되며 Apple 계정에서 언제든지 취소할 수 있습니다",
                    it: "Rinnovo annuale; annulla in qualsiasi momento nel tuo Apple Account"
                )
            }
        case .lifetime:
            l.tr(
                zh: "一次购买，永久解锁当前 Personal 功能",
                en: "One purchase for permanent access to current Personal features",
                de: "Ein Kauf für dauerhaften Zugriff auf aktuelle Personal-Funktionen",
                es: "Una compra para acceder permanentemente a las funciones actuales de Ohana Personal",
                pt: "Uma compra para acesso permanente aos recursos atuais do Ohana Personal",
                fr: "Un achat pour un accès permanent aux fonctionnalités Ohana Personal actuelles",
                ja: "1回の購入で、現在のOhana Personal機能を永続的に利用できます",
                ko: "한 번 구매하면 현재 Ohana Personal 기능을 영구적으로 이용할 수 있습니다",
                it: "Un solo acquisto per accedere permanentemente alle attuali funzioni Ohana Personal"
            )
        }
    }

    private func choicePrice(_ choice: PersonalPurchaseChoice) -> String {
        guard let price = commerce.displayPrice(for: choice) else {
            return commerce.isLoadingProduct
                ? l.tr(zh: "载入中", en: "Loading", de: "Laden",
                    es: "Cargando",
                    pt: "Carregando",
                    fr: "Chargement",
                    ja: "読み込み中",
                    ko: "불러오는 중",
                    it: "Caricamento")
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

    // MARK: - Purchase State and Personal Extras
    private var purchaseButtonTitle: String {
        if commerce.isPurchasePending {
            return l.tr(zh: "等待 App Store 批准", en: "Awaiting App Store approval", de: "Warten auf App-Store-Freigabe",
                es: "Esperando la aprobación del App Store",
                pt: "Aguardando aprovação da App Store",
                fr: "En attente de l’approbation de l’App Store",
                ja: "App Storeの承認待ち",
                ko: "App Store 승인 대기 중",
                it: "In attesa dell’approvazione dell’App Store")
        }
        if commerce.isLoadingProduct {
            return l.tr(zh: "正在获取价格", en: "Loading prices", de: "Preise werden geladen",
                es: "Cargando precio",
                pt: "Carregando preço",
                fr: "Chargement du prix",
                ja: "価格を取得中",
                ko: "가격 불러오는 중",
                it: "Caricamento prezzo")
        }
        guard let selectedChoice else {
            return l.tr(zh: "请先选择一个方案", en: "Choose a plan to continue", de: "Wähle zuerst einen Plan",
                es: "Elige un plan para continuar",
                pt: "Escolha um plano para continuar",
                fr: "Choisissez une formule pour continuer",
                ja: "続けるにはプランを選択してください",
                ko: "계속하려면 플랜을 선택하세요",
                it: "Scegli un piano per continuare")
        }
        guard let price = commerce.displayPrice(for: selectedChoice) else {
            return l.tr(zh: "App Store 暂不可用", en: "App Store unavailable", de: "App Store nicht verfügbar",
                es: "App Store no disponible",
                pt: "App Store indisponível",
                fr: "App Store indisponible",
                ja: "App Storeを利用できません",
                ko: "App Store를 사용할 수 없음",
                it: "App Store non disponibile")
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
                    Text(l.tr(zh: "正在恢复…", en: "Restoring…", de: "Wiederherstellung…",
                        es: "Restaurando…",
                        pt: "Restaurando…",
                        fr: "Restauration…",
                        ja: "復元中…",
                        ko: "복원 중…",
                        it: "Ripristino…"))
                }
            } else {
                Text(l.tr(zh: "恢复购买", en: "Restore purchases", de: "Käufe wiederherstellen",
                    es: "Restaurar compras",
                    pt: "Restaurar compras",
                    fr: "Restaurer les achats",
                    ja: "購入を復元",
                    ko: "구매 복원",
                    it: "Ripristina acquisti"))
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
            Text(l.tr(zh: "Personal 外观权益", en: "Personal appearance extras", de: "Design-Extras in Personal",
                es: "Extras visuales de Personal",
                pt: "Extras visuais do Personal",
                fr: "Bonus visuels de Personal",
                ja: "Personalの外観特典",
                ko: "Personal 디자인 혜택",
                it: "Extra estetici di Personal"))
                .font(OhanaFont.body(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.top, 16)
                .padding(.bottom, 7)
            featureRow(
                symbol: "photo.on.rectangle.angled",
                text: l.tr(zh: "流光绿洲、午夜群岛与霓虹网格背景", en: "Oasis Glow, Midnight Isles, and Neon Grid backgrounds", de: "Oasenleuchten-, Mitternachtsinseln- und Neonraster-Hintergründe",
                    es: "Fondos Resplandor del oasis, Islas de Medianoche y Cuadrícula Neón",
                    pt: "Fundos Brilho do oásis, Ilhas da Meia-noite e Grade Neon",
                    fr: "Arrière-plans Lueur de l’oasis, Îles de minuit et Grille néon",
                    ja: "オアシスの輝き、真夜中の島々、ネオングリッドの背景",
                    ko: "오아시스 글로우, 한밤의 섬, 네온 그리드 배경",
                    it: "Sfondi Bagliore dell’oasi, Isole di mezzanotte e Griglia neon"),
                tint: Color.goPrimary
            )
            .padding(.vertical, 8)
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "app.badge.fill",
                text: l.tr(zh: "霓虹笑脸 App 图标", en: "Neon Smile app icon", de: "Neon-Smile-App-Symbol",
                    es: "Icono de la app Sonrisa Neón",
                    pt: "Ícone do app Sorriso Neon",
                    fr: "Icône de l’app Sourire néon",
                    ja: "ネオンスマイルのAppアイコン",
                    ko: "네온 스마일 앱 아이콘",
                    it: "Icona app Sorriso neon"),
                tint: Color.goPrimary
            )
            .padding(.vertical, 8)
            Divider().overlay(Color.ohanaDivider)
            featureRow(
                symbol: "rectangle.portrait.on.rectangle.portrait.fill",
                text: l.tr(zh: "Founding Ohana 周报海报与支持者标记", en: "Founding Ohana weekly poster and supporter mark", de: "Founding-Ohana-Wochenposter und Unterstützer-Markierung",
                    es: "Póster semanal Founding Ohana y distintivo de apoyo",
                    pt: "Pôster semanal Founding Ohana e marca de apoiador",
                    fr: "Affiche hebdomadaire Founding Ohana et badge de soutien",
                    ja: "Founding Ohana週間レポートポスターとサポーターマーク",
                    ko: "Founding Ohana 주간 리포트 포스터 및 서포터 표시",
                    it: "Poster settimanale Founding Ohana e contrassegno sostenitore"),
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
                    Text(l.tr(zh: "霓虹笑脸", en: "Neon Smile", de: "Neon Smile",
                        es: "Sonrisa Neón",
                        pt: "Sorriso Neon",
                        fr: "Sourire néon",
                        ja: "ネオンスマイル",
                        ko: "네온 스마일",
                        it: "Sorriso neon"))
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
                            ? l.tr(zh: "使用中", en: "In use", de: "Aktiv",
                                es: "En uso",
                                pt: "Em uso",
                                fr: "En cours d’utilisation",
                                ja: "使用中",
                                ko: "사용 중",
                                it: "In uso")
                            : l.tr(zh: "使用", en: "Use", de: "Nutzen",
                                es: "Usar",
                                pt: "Usar",
                                fr: "Utiliser",
                                ja: "使用する",
                                ko: "사용",
                                it: "Usa"))
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
            return l.tr(zh: "已由 Ohana Personal 解锁", en: "Unlocked by Ohana Personal", de: "Durch Ohana Personal freigeschaltet",
                es: "Desbloqueado con Ohana Personal",
                pt: "Desbloqueado pelo Ohana Personal",
                fr: "Débloqué grâce à Ohana Personal",
                ja: "Ohana Personalでアンロック済み",
                ko: "Ohana Personal로 잠금 해제됨",
                it: "Sbloccato con Ohana Personal")
        }
        if hasCoconutIconOwnership {
            return l.tr(zh: "已使用椰子获得，继续永久可用", en: "Already earned with coconuts and remains available", de: "Bereits mit Kokosnüssen verdient und weiter verfügbar",
                es: "Ya se obtuvo con cocos y seguirá disponible para siempre",
                pt: "Já foi obtido com cocos e continuará disponível para sempre",
                fr: "Déjà obtenu avec des noix de coco et disponible définitivement",
                ja: "ココナッツで入手済みのため、今後もずっと利用可能",
                ko: "코코넛으로 이미 획득했으며 계속 영구 사용 가능",
                it: "Già ottenuto con le noci di cocco e disponibile per sempre")
        }
        return l.tr(zh: "Personal 可立即解锁，也可在椰子商店赚取", en: "Unlock it with Personal, or earn it in the Coconut Shop", de: "Mit Personal freischalten oder im Kokosnuss-Shop verdienen",
            es: "Desbloquéalo con Personal o consíguelo en la Tienda de Cocos",
            pt: "Desbloqueie com o Personal ou ganhe na Loja de Cocos",
            fr: "Débloquez-le avec Personal ou obtenez-le dans la Boutique Coco",
            ja: "Personalですぐにアンロックするか、ココナッツショップで獲得",
            ko: "Personal로 바로 잠금 해제하거나 코코넛 상점에서 획득",
            it: "Sbloccalo con Personal oppure ottienilo nel Negozio delle noci di cocco")
    }

    private var purchaseFootnote: some View {
        VStack(spacing: 8) {
            Text(l.tr(
                zh: "月度与年度方案会自动续订，除非在当前周期结束前至少 24 小时于 Apple 账号中取消。Lifetime 为一次性购买。付款由 Apple 处理。",
                en: "Monthly and yearly plans renew automatically unless cancelled in your Apple Account at least 24 hours before the current period ends. Lifetime is a one-time purchase. Apple processes payment.",
                de: "Monats- und Jahrespläne verlängern sich automatisch, sofern sie nicht mindestens 24 Stunden vor Ablauf im Apple Account gekündigt werden. Lifetime ist ein Einmalkauf. Apple verarbeitet die Zahlung.",
                es: "Los planes mensuales y anuales se renuevan automáticamente, salvo que se cancelen en tu cuenta de Apple al menos 24 horas antes de que finalice el periodo actual. Lifetime es una compra única. Apple procesa el pago.",
                pt: "Os planos mensais e anuais são renovados automaticamente, a menos que sejam cancelados na sua Conta Apple pelo menos 24 horas antes do fim do período atual. Lifetime é uma compra única. O pagamento é processado pela Apple.",
                fr: "Les formules mensuelles et annuelles se renouvellent automatiquement, sauf annulation dans votre compte Apple au moins 24 heures avant la fin de la période en cours. Lifetime est un achat unique. Le paiement est traité par Apple.",
                ja: "月額および年額プランは、現在の期間が終了する24時間以上前にApple Accountで解約しない限り自動更新されます。Lifetimeは買い切りです。支払いはAppleが処理します。",
                ko: "월간 및 연간 요금제는 현재 이용 기간이 끝나기 최소 24시간 전에 Apple 계정에서 취소하지 않으면 자동 갱신됩니다. Lifetime은 일회성 구매이며 결제는 Apple에서 처리합니다.",
                it: "I piani mensili e annuali si rinnovano automaticamente, salvo annullamento nell’Apple Account almeno 24 ore prima della fine del periodo corrente. Lifetime è un acquisto una tantum. Il pagamento è gestito da Apple."
            ))
            .font(OhanaFont.caption2())
            .foregroundStyle(Color.ohanaTertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text(l.tr(
                zh: "Lifetime 仅包含当前平台的本地 Personal 功能，不包含未来的 Family 在线服务或 Care+。",
                en: "Lifetime covers local Personal features on this platform; future Family online services and Care+ are not included.",
                de: "Lifetime umfasst lokale Personal-Funktionen auf dieser Plattform; künftige Family-Onlinedienste und Care+ sind nicht enthalten.",
                es: "Lifetime cubre las funciones locales de Ohana Personal en esta plataforma; no incluye futuros servicios en línea de Family ni Care+.",
                pt: "Lifetime cobre os recursos locais do Ohana Personal nesta plataforma; futuros serviços online do Family e o Care+ não estão incluídos.",
                fr: "Lifetime couvre les fonctionnalités locales Ohana Personal sur cette plateforme ; les futurs services en ligne Family et Care+ ne sont pas inclus.",
                ja: "Lifetimeには、このプラットフォームのローカルなOhana Personal機能のみが含まれます。将来のFamilyオンラインサービスやCare+は含まれません。",
                ko: "Lifetime에는 이 플랫폼의 로컬 Ohana Personal 기능만 포함되며 향후 Family 온라인 서비스와 Care+는 포함되지 않습니다.",
                it: "Lifetime include le funzionalità locali Ohana Personal su questa piattaforma; i futuri servizi online Family e Care+ non sono inclusi."
            ))
            .font(OhanaFont.caption2())
            .foregroundStyle(Color.ohanaTertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Link(
                    l.tr(zh: "隐私政策", en: "Privacy Policy", de: "Datenschutz",
                        es: "Política de privacidad",
                        pt: "Política de Privacidade",
                        fr: "Politique de confidentialité",
                        ja: "プライバシーポリシー",
                        ko: "개인정보 처리방침",
                        it: "Informativa sulla privacy"),
                    destination: OhanaPublicLinks.privacyPolicy
                )
                if let standardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link(
                        l.tr(zh: "使用条款", en: "Terms of Use", de: "Nutzungsbedingungen",
                            es: "Términos de uso",
                            pt: "Termos de Uso",
                            fr: "Conditions d’utilisation",
                            ja: "利用規約",
                            ko: "이용 약관",
                            it: "Termini di utilizzo"),
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
                    de: "Ohana Personal ist freigeschaltet. Danke für deine Unterstützung.",
                    es: "Ohana Personal está desbloqueado. Gracias por tu apoyo.",
                    pt: "Ohana Personal foi desbloqueado. Obrigado pelo apoio.",
                    fr: "Ohana Personal est débloqué. Merci pour votre soutien.",
                    ja: "Ohana Personalをアンロックしました。ご支援ありがとうございます。",
                    ko: "Ohana Personal이 잠금 해제되었습니다. 응원해 주셔서 감사합니다.",
                    it: "Ohana Personal è sbloccato. Grazie per il supporto."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .pending:
                purchaseStatusMessage = l.tr(
                    zh: "购买正在等待批准，完成后会自动解锁。",
                    en: "The purchase is awaiting approval and will unlock automatically when completed.",
                    de: "Der Kauf wartet auf Freigabe und wird danach automatisch aktiviert.",
                    es: "La compra está pendiente de aprobación y se desbloqueará automáticamente cuando se complete.",
                    pt: "A compra está aguardando aprovação e será desbloqueada automaticamente quando for concluída.",
                    fr: "L’achat attend une approbation et se débloquera automatiquement une fois terminé.",
                    ja: "購入は承認待ちです。完了すると自動的にアンロックされます。",
                    ko: "구매 승인 대기 중이며 완료되면 자동으로 잠금 해제됩니다.",
                    it: "L’acquisto è in attesa di approvazione e si sbloccherà automaticamente al termine."
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
                        de: "Ohana Personal wurde wiederhergestellt.",
                        es: "Ohana Personal se ha restaurado.",
                        pt: "Ohana Personal foi restaurado.",
                        fr: "Ohana Personal a été restauré.",
                        ja: "Ohana Personalを復元しました。",
                        ko: "Ohana Personal을 복원했습니다.",
                        it: "Ohana Personal è stato ripristinato."
                    )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .noPurchases:
                if commerce.isPurchasePending {
                    purchaseStatusMessage = l.tr(
                        zh: "购买正在等待批准，完成后会自动解锁。",
                        en: "The purchase is awaiting approval and will unlock automatically when completed.",
                        de: "Der Kauf wartet auf Freigabe und wird danach automatisch aktiviert.",
                        es: "La compra está pendiente de aprobación y se desbloqueará automáticamente cuando se complete.",
                        pt: "A compra está aguardando aprovação e será desbloqueada automaticamente quando for concluída.",
                        fr: "L’achat attend une approbation et se débloquera automatiquement une fois terminé.",
                        ja: "購入は承認待ちです。完了すると自動的にアンロックされます。",
                        ko: "구매 승인 대기 중이며 완료되면 자동으로 잠금 해제됩니다.",
                        it: "L’acquisto è in attesa di approvazione e si sbloccherà automaticamente al termine."
                    )
                } else {
                    purchaseStatusMessage = l.tr(
                        zh: "当前 Apple 账号没有可恢复的 Personal 或 Supporter Pack 购买。",
                        en: "The current Apple Account has no Personal or Supporter Pack purchase to restore.",
                        de: "Für den aktuellen Apple Account gibt es keinen Personal- oder Supporter-Pack-Kauf zum Wiederherstellen.",
                        es: "La cuenta de Apple actual no tiene ninguna compra de Personal o Supporter Pack que se pueda restaurar.",
                        pt: "A Conta Apple atual não tem nenhuma compra do Personal ou Supporter Pack para restaurar.",
                        fr: "Le compte Apple actuel ne possède aucun achat Personal ou Supporter Pack à restaurer.",
                        ja: "現在のApple Accountには、復元できるPersonalまたはSupporter Packの購入がありません。",
                        ko: "현재 Apple 계정에 복원할 수 있는 Personal 또는 Supporter Pack 구매 내역이 없습니다.",
                        it: "L’Apple Account attuale non ha acquisti Personal o Supporter Pack da ripristinare."
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
