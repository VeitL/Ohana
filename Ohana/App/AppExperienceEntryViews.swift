//
//  AppExperienceEntryViews.swift
//  Ohana
//

import SwiftUI

struct AppExperienceIntroductionBanner: View {
    let appLanguage: String
    let onDismiss: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "leaf.fill") // a11y: allow decorative mode glyph is hidden below
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 38, height: 38) // a11y: allow non-interactive decorative glyph
                .background(Color.goPrimary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(
                    zh: "认识佛系模式",
                    en: "Meet Zen mode",
                    de: "Zen-Modus kennenlernen",
                    es: "Conoce el modo zen",
                    pt: "Conheça o modo zen",
                    fr: "Découvrir le mode Zen",
                    ja: "佛系モードについて",
                    ko: "마음 편한 모드 알아보기",
                    it: "Scopri la modalità Zen"
                ))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "只保留首页打卡、连续日历与 Oasis；可随时在设置中切换。",
                    en: "Keep only Home check-ins, the streak calendar, and Oasis. Switch anytime in Settings.",
                    de: "Nur Home-Check-ins, Serienkalender und Oasis. Jederzeit in den Einstellungen wechselbar.",
                    es: "Solo conserva los check-ins de Inicio, el calendario de rachas y Oasis. Cambia cuando quieras en Ajustes.",
                    pt: "Mantém apenas os check-ins do Início, o calendário de sequências e o Oásis. Mude quando quiser nos Ajustes.",
                    fr: "Conservez seulement les check-ins de l’accueil, le calendrier des séries et Oasis. Changez de mode à tout moment dans les réglages.",
                    ja: "ホームのチェックイン、連続カレンダー、Oasisだけのシンプルなモードです。設定からいつでも切り替えられます。",
                    ko: "홈 체크인, 연속 기록 캘린더와 Oasis만 남겨요. 설정에서 언제든지 바꿀 수 있어요.",
                    it: "Mantiene solo i check-in della Home, il calendario delle serie e Oasi. Puoi cambiare in qualsiasi momento dalle Impostazioni."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark") // a11y: allow parent Button supplies the localized dismiss label
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 36, height: 36) // a11y: allow parent Button owns the padded hit target
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(
                zh: "关闭介绍",
                en: "Dismiss introduction",
                de: "Einführung schließen",
                es: "Cerrar introducción",
                pt: "Fechar introdução",
                fr: "Fermer la présentation",
                ja: "紹介を閉じる",
                ko: "소개 닫기",
                it: "Chiudi introduzione"
            ))
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
        .accessibilityIdentifier("zen-introduction-banner")
    }
}

struct AppExperienceSelectionView: View {
    let appLanguage: String
    let onSelect: (AppExperienceMode) -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 9) {
                            Image(systemName: "leaf.fill") // a11y: allow decorative mode glyph is hidden below
                                .font(OhanaFont.adaptive(size: 34, weight: .black))
                                .foregroundStyle(Color.arkInk)
                                .frame(width: 82, height: 82)
                                .background(Color.goPrimary, in: Circle())
                                .accessibilityHidden(true)

                            Text(l.tr(
                                zh: "你想怎样使用 Ohana？",
                                en: "How would you like to use Ohana?",
                                de: "Wie möchtest du Ohana nutzen?",
                                es: "¿Cómo quieres usar Ohana?",
                                pt: "Como você quer usar o Ohana?",
                                fr: "Comment souhaitez-vous utiliser Ohana ?",
                                ja: "Ohanaをどのように使いますか？",
                                ko: "Ohana를 어떻게 사용할까요?",
                                it: "Come vuoi usare Ohana?"
                            ))
                            .font(OhanaFont.title(.black))
                            .foregroundStyle(Color.goCardWhite.opacity(0.94))
                            .multilineTextAlignment(.center)

                            Text(l.tr(
                                zh: "之后随时可以在设置中切换，成员和记录不会丢失。",
                                en: "You can switch in Settings anytime. Members and records stay intact.",
                                de: "Du kannst später jederzeit wechseln. Mitglieder und Verläufe bleiben erhalten.",
                                es: "Puedes cambiar en Ajustes cuando quieras. Los miembros y registros se conservarán.",
                                pt: "Você pode mudar nos Ajustes quando quiser. Membros e registros serão mantidos.",
                                fr: "Vous pourrez changer à tout moment dans les réglages. Les membres et les données seront conservés.",
                                ja: "後から設定でいつでも切り替えられます。メンバーと記録はそのまま残ります。",
                                ko: "나중에 설정에서 언제든지 바꿀 수 있어요. 구성원과 기록은 그대로 유지돼요.",
                                it: "Puoi cambiare in qualsiasi momento dalle Impostazioni. Membri e registri resteranno intatti."
                            ))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.goCardWhite.opacity(0.66))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            ForEach(AppExperienceMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 430)
                    .background(
                        Color.goCardWhite.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                            .strokeBorder(Color.goCardWhite.opacity(0.14), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("app-experience-selection")
    }

    private func modeButton(_ mode: AppExperienceMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode == .zen ? "leaf.fill" : "square.grid.2x2.fill")
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 46, height: 46)
                    .background(mode == .zen ? Color.goPrimary : Color.goBlue, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title(l))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.94))
                    Text(mode.subtitle(l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.goCardWhite.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right") // a11y: allow decorative chevron is hidden below
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.goCardWhite.opacity(0.54))
                    .accessibilityHidden(true)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(Color.goCardWhite.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.13), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("app-experience-\(mode.rawValue)")
    }
}

struct ZenOwnerSelectionView: View {
    let appLanguage: String
    let humans: [AppExperienceHumanChoice]
    let onSelect: (UUID) -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ownerGateShell {
            Image(systemName: "person.crop.circle.badge.checkmark") // a11y: allow decorative owner glyph is hidden below
                .font(OhanaFont.adaptive(size: 36, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)

            Text(l.tr(
                zh: "谁是你？",
                en: "Which person is you?",
                de: "Welche Person bist du?",
                es: "¿Quién eres?",
                pt: "Quem é você?",
                fr: "Quel profil est le vôtre ?",
                ja: "どのプロフィールがあなたですか？",
                ko: "어느 프로필이 본인인가요?",
                it: "Qual è il tuo profilo?"
            ))
                .font(OhanaFont.title(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            Text(l.tr(
                zh: "佛系模式会在你打开 App 时自动为这位成员打卡。",
                en: "Zen mode automatically checks in this person when you open the app.",
                de: "Der Zen-Modus checkt diese Person beim Öffnen der App automatisch ein.",
                es: "El modo zen registra automáticamente el check-in de esta persona cuando abres la app.",
                pt: "O modo zen faz o check-in automático dessa pessoa quando você abre o app.",
                fr: "Le mode Zen enregistre automatiquement cette personne quand vous ouvrez l’app.",
                ja: "佛系モードでは、Appを開くとこのメンバーを自動でチェックインします。",
                ko: "마음 편한 모드에서는 앱을 열 때 이 구성원을 자동으로 체크인해요.",
                it: "La modalità Zen effettua automaticamente il check-in di questa persona quando apri l’app."
            ))
            .font(OhanaFont.body(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(humans) { human in
                    Button {
                        onSelect(human.id)
                    } label: {
                        HStack(spacing: 12) {
                            Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                                .font(OhanaFont.adaptive(size: 28))
                                .frame(width: 44, height: 44)
                                .background(Color.ohanaControlFill, in: Circle())
                                .accessibilityHidden(true)
                            Text(human.name)
                                .font(OhanaFont.headline(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Spacer()
                            Image(systemName: "chevron.right") // a11y: allow decorative chevron is hidden below
                                .foregroundStyle(Color.ohanaTertiaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("zen-owner-\(human.id.uuidString)")
                }
            }
        }
        .accessibilityIdentifier("zen-owner-selection")
    }
}

struct ZenOwnerResolutionView: View {
    let appLanguage: String

    var body: some View {
        ownerGateShell {
            ProgressView()
                .tint(Color.goPrimary)
                .accessibilityLabel(L10n(appLanguage).tr(
                    zh: "正在确认本人",
                    en: "Confirming your profile",
                    de: "Dein Profil wird bestätigt",
                    es: "Confirmando tu perfil",
                    pt: "Confirmando seu perfil",
                    fr: "Confirmation de votre profil",
                    ja: "プロフィールを確認中",
                    ko: "본인 프로필 확인 중",
                    it: "Conferma del profilo"
                ))
        }
    }
}

struct ZenOwnerUnavailableView: View {
    let appLanguage: String
    let onOpenSettings: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ownerGateShell {
            Image(systemName: "person.crop.circle.badge.exclamationmark") // a11y: allow decorative unavailable-state glyph is hidden below
                .font(OhanaFont.adaptive(size: 36, weight: .black))
                .foregroundStyle(Color.goOrange)
                .accessibilityHidden(true)
            Text(l.tr(
                zh: "需要一位在世成员",
                en: "A living person is needed",
                de: "Eine lebende Person wird benötigt",
                es: "Se necesita una persona viva",
                pt: "É necessária uma pessoa viva",
                fr: "Une personne vivante est nécessaire",
                ja: "存命中のメンバーが必要です",
                ko: "생존 구성원이 필요해요",
                it: "Serve una persona vivente"
            ))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)
            Text(l.tr(
                zh: "自动打卡和提醒已经停止。请在普通模式中建立成员，或在设置中切换模式。",
                en: "Automatic check-ins and reminders are stopped. Add a person in Standard mode or switch modes in Settings.",
                de: "Automatische Check-ins und Erinnerungen sind gestoppt. Lege im Standardmodus eine Person an oder wechsle in den Einstellungen.",
                es: "Los check-ins automáticos y recordatorios están detenidos. Añade una persona en el modo Estándar o cambia de modo en Ajustes.",
                pt: "Os check-ins automáticos e lembretes foram interrompidos. Adicione uma pessoa no modo Padrão ou mude de modo nos Ajustes.",
                fr: "Les check-ins automatiques et les rappels sont arrêtés. Ajoutez une personne en mode Standard ou changez de mode dans les réglages.",
                ja: "自動チェックインとリマインダーを停止しました。通常モードでメンバーを追加するか、設定からモードを切り替えてください。",
                ko: "자동 체크인과 알림을 중지했어요. 일반 모드에서 구성원을 추가하거나 설정에서 모드를 바꾸세요.",
                it: "I check-in automatici e i promemoria sono stati interrotti. Aggiungi una persona in modalità Standard o cambia modalità nelle Impostazioni."
            ))
            .font(OhanaFont.body(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: onOpenSettings) {
                Label(l.tr(
                    zh: "打开设置",
                    en: "Open Settings",
                    de: "Einstellungen öffnen",
                    es: "Abrir Ajustes",
                    pt: "Abrir Ajustes",
                    fr: "Ouvrir les réglages",
                    ja: "設定を開く",
                    ko: "설정 열기",
                    it: "Apri Impostazioni"
                ), systemImage: "gearshape.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("zen-owner-open-settings")
        }
        .accessibilityIdentifier("zen-owner-unavailable")
    }
}

private func ownerGateShell(
    @ViewBuilder content: () -> some View
) -> some View {
    let gateContent = content()
    return ZStack {
        OhanaStaticAppBackground()
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    gateContent
                }
                .padding(24)
                .frame(maxWidth: 430)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
