//
//  ProfileDetailComponents.swift
//  Ohana
//
//  Shared, read-first profile presentation for Human, Pet, and Plant.
//

import SwiftUI

@MainActor
struct ProfileDetailScaffold<Hero: View, Content: View>: View {
    let title: String
    let closeTitle: String
    let editTitle: String
    let showsEditAction: Bool
    let showsSavedFeedback: Bool
    let savedFeedbackTitle: String
    let closeAccessibilityIdentifier: String
    let editAccessibilityIdentifier: String
    let onClose: (() -> Void)?
    let onEdit: (() -> Void)?
    @ViewBuilder let hero: () -> Hero
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        closeTitle: String,
        editTitle: String,
        showsEditAction: Bool,
        showsSavedFeedback: Bool,
        savedFeedbackTitle: String,
        closeAccessibilityIdentifier: String = "profile-detail-close-action",
        editAccessibilityIdentifier: String = "profile-detail-edit-action",
        onClose: (() -> Void)?,
        onEdit: (() -> Void)?,
        @ViewBuilder hero: @escaping () -> Hero,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.closeTitle = closeTitle
        self.editTitle = editTitle
        self.showsEditAction = showsEditAction
        self.showsSavedFeedback = showsSavedFeedback
        self.savedFeedbackTitle = savedFeedbackTitle
        self.closeAccessibilityIdentifier = closeAccessibilityIdentifier
        self.editAccessibilityIdentifier = editAccessibilityIdentifier
        self.onClose = onClose
        self.onEdit = onEdit
        self.hero = hero
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    hero()
                    content()
                    Spacer(minLength: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }

            if showsSavedFeedback {
                ProfileSavedFeedback(title: savedFeedbackTitle)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.ohanaCardSurfaceElevated, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closeTitle, action: onClose)
                        .accessibilityIdentifier(closeAccessibilityIdentifier)
                }
            }

            if showsEditAction, let onEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        OhanaFeedback.light()
                        onEdit()
                    } label: {
                        Text(editTitle)
                    }
                    .font(OhanaFont.callout(.bold))
                    .accessibilityIdentifier(editAccessibilityIdentifier)
                }
            }
        }
    }
}

@MainActor
struct ProfileIdentityHero<Avatar: View, Badges: View>: View {
    let name: String
    let subtitle: String
    let themeColorHex: String
    let fallbackColor: Color
    let statusTitle: String?
    let avatarAccessibilityLabel: String
    let nameAccessibilityIdentifier: String
    let onAvatarTap: (() -> Void)?
    @ViewBuilder let avatar: () -> Avatar
    @ViewBuilder let badges: () -> Badges

    init(
        name: String,
        subtitle: String,
        themeColorHex: String,
        fallbackColor: Color,
        statusTitle: String?,
        avatarAccessibilityLabel: String,
        nameAccessibilityIdentifier: String = "profile-identity-name",
        onAvatarTap: (() -> Void)?,
        @ViewBuilder avatar: @escaping () -> Avatar,
        @ViewBuilder badges: @escaping () -> Badges
    ) {
        self.name = name
        self.subtitle = subtitle
        self.themeColorHex = themeColorHex
        self.fallbackColor = fallbackColor
        self.statusTitle = statusTitle
        self.avatarAccessibilityLabel = avatarAccessibilityLabel
        self.nameAccessibilityIdentifier = nameAccessibilityIdentifier
        self.onAvatarTap = onAvatarTap
        self.avatar = avatar
        self.badges = badges
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    var body: some View {
        ZStack {
            WalletMemberHeroBackground(
                themeColorHex: themeColorHex,
                fallbackColor: fallbackColor,
                reducesEffects: workloadPolicy.shouldReduceWork()
            )

            LinearGradient(
                colors: [Color.arkInk.opacity(0.04), Color.arkInk.opacity(0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                avatarControl

                VStack(spacing: 5) {
                    Text(name)
                        .font(OhanaFont.title(.black))
                        .foregroundStyle(Color.goCardWhite)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .accessibilityIdentifier(nameAccessibilityIdentifier)

                    Text(subtitle)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.goCardWhite.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                badges()

                if let statusTitle {
                    Label(statusTitle, systemImage: "info.circle.fill")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goCardWhite)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 32)
                        .background(Color.arkInk.opacity(0.22), in: Capsule())
                        .accessibilityIdentifier("profile-identity-status")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 230)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .strokeBorder(Color.goCardWhite.opacity(0.22), lineWidth: 1)
        }
        .animation(reduceMotion ? GoMotion.reduced : GoMotion.page, value: statusTitle)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var avatarControl: some View {
        if let onAvatarTap {
            Button(action: onAvatarTap) {
                avatar()
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(avatarAccessibilityLabel)
            .accessibilityHint(L10n.current.tr(
                zh: "打开头像预览",
                en: "Open avatar preview",
                de: "Avatarvorschau öffnen"
            ))
            .accessibilityIdentifier("profile-identity-avatar-preview-action")
        } else {
            avatar()
                .accessibilityLabel(avatarAccessibilityLabel)
        }
    }
}

@MainActor
struct ProfileBadge: View {
    let title: String
    let systemImage: String?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
        }
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(Color.goCardWhite)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Color.goCardWhite.opacity(0.16), in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.goCardWhite.opacity(0.22), lineWidth: 1)
        }
    }
}

@MainActor
struct ProfileInfoSection<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .symbolRenderingMode(.hierarchical)
                .tint(tint)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@MainActor
struct ProfileInfoRow: View {
    let label: String
    let value: String
    var valueTint: Color = Color.ohanaPrimaryText
    var accessibilityIdentifier: String? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            LabeledContent {
                valueText(alignment: .trailing, textAlignment: .trailing)
            } label: {
                labelText
            }

            VStack(alignment: .leading, spacing: 4) {
                labelText
                valueText(alignment: .leading, textAlignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.38)
        }
        .accessibilityElement(children: .combine)
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }

    private var labelText: some View {
        Text(label)
            .font(OhanaFont.subheadline(.medium))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func valueText(alignment: Alignment, textAlignment: TextAlignment) -> some View {
        Text(value)
            .font(OhanaFont.subheadline(.semibold))
            .foregroundStyle(valueTint)
            .multilineTextAlignment(textAlignment)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

@MainActor
struct ProfileEmptySectionRow: View {
    let title: String
    let editTitle: String
    let onEdit: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                emptyLabel
                Spacer(minLength: 8)
                editButton
            }
            VStack(alignment: .leading, spacing: 10) {
                emptyLabel
                editButton
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    private var emptyLabel: some View {
        Label(title, systemImage: "plus.circle")
            .font(OhanaFont.subheadline(.medium))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    @ViewBuilder
    private var editButton: some View {
        if let onEdit {
            Button(editTitle, action: onEdit)
                .font(OhanaFont.subheadline(.bold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

@MainActor
struct ProfileStatusBanner: View {
    let title: String
    let detail: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(OhanaFont.footnote(.medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct ProfileCompletionCard: View {
    let snapshot: MemberProfileCompletionSnapshot
    let onContinue: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showsCompletionExplanation = false

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color {
        snapshot.reachesProfileThreshold ? Color.goTeal : Color.goPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(
                        zh: "资料完成度", en: "Profile completion", de: "Profilfortschritt",
                        es: "Perfil completado", pt: "Perfil concluído", fr: "Profil complété",
                        ja: "プロフィール完成度", ko: "프로필 완성도", it: "Completamento profilo"
                    ))
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)

                    Text(l.tr(
                        zh: "已完成 \(snapshot.completedCategoryCount)/\(snapshot.totalCategoryCount)",
                        en: "\(snapshot.completedCategoryCount) of \(snapshot.totalCategoryCount) complete",
                        de: "\(snapshot.completedCategoryCount) von \(snapshot.totalCategoryCount) vollständig",
                        es: "\(snapshot.completedCategoryCount) de \(snapshot.totalCategoryCount) completadas",
                        pt: "\(snapshot.completedCategoryCount) de \(snapshot.totalCategoryCount) concluídas",
                        fr: "\(snapshot.completedCategoryCount) sur \(snapshot.totalCategoryCount) terminées",
                        ja: "\(snapshot.totalCategoryCount)項目中\(snapshot.completedCategoryCount)項目完了",
                        ko: "\(snapshot.totalCategoryCount)개 중 \(snapshot.completedCategoryCount)개 완료",
                        it: "\(snapshot.completedCategoryCount) di \(snapshot.totalCategoryCount) completate"
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer(minLength: 8)

                Text("\(snapshot.completionPercent)%")
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityHidden(true)
            }

            ProgressView(value: Double(snapshot.completionPercent), total: 100)
                .tint(tint)

            if snapshot.missingCategories.isEmpty {
                Label(
                    l.tr(
                        zh: "四类资料都已完善", en: "All four categories are complete", de: "Alle vier Bereiche sind vollständig",
                        es: "Las cuatro categorías están completas", pt: "As quatro categorias estão completas", fr: "Les quatre catégories sont complètes",
                        ja: "4つの項目がすべて完了", ko: "네 가지 항목을 모두 완료했어요", it: "Tutte e quattro le categorie sono complete"
                    ),
                    systemImage: "checkmark.seal.fill"
                )
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.goTeal)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(
                        zh: "还可完善", en: "Still to add", de: "Noch offen",
                        es: "Aún por añadir", pt: "Ainda falta", fr: "Encore à compléter",
                        ja: "未完了", ko: "아직 필요한 항목", it: "Da completare"
                    ))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)

                    Text(snapshot.missingCategories.map { $0.localizedTitle(l) }.joined(separator: " · "))
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            DisclosureGroup(isExpanded: $showsCompletionExplanation) {
                Text(l.tr(
                    zh: "已填写，或已明确确认暂不清楚、不适用、暂不填写与不愿透露的类别，都会计入完成度。",
                    en: "A category counts when filled in or explicitly marked unknown, not applicable, skipped for now, or private.",
                    de: "Ein Bereich zählt, wenn er ausgefüllt oder ausdrücklich als unbekannt, nicht zutreffend, vorerst übersprungen oder privat markiert ist.",
                    es: "Una categoría cuenta si está rellenada o se marca como desconocida, no aplicable, pendiente o privada.",
                    pt: "Uma categoria conta quando preenchida ou marcada como desconhecida, não aplicável, adiada ou privada.",
                    fr: "Une catégorie compte si elle est remplie ou indiquée comme inconnue, non applicable, reportée ou privée.",
                    ja: "入力済み、または不明・該当なし・後で・非公開を明確に選んだ項目が完成度に含まれます。",
                    ko: "입력했거나 모름, 해당 없음, 나중에 입력, 비공개를 명확히 선택한 항목은 완성도에 포함됩니다.",
                    it: "Una categoria conta se compilata o indicata come sconosciuta, non applicabile, rimandata o privata."
                ))
                .font(OhanaFont.caption())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            } label: {
                Text(l.tr(
                    zh: "完成度如何计算？", en: "How is this calculated?", de: "Wie wird das berechnet?",
                    es: "¿Cómo se calcula?", pt: "Como é calculado?", fr: "Comment est-ce calculé ?",
                    ja: "完成度の計算方法", ko: "완성도 계산 방법", it: "Come viene calcolato?"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
            .tint(tint)
            .accessibilityIdentifier("profile-completion-explanation")

            if let onContinue, !snapshot.missingCategories.isEmpty {
                Button {
                    OhanaFeedback.light()
                    onContinue()
                } label: {
                    Label(
                        l.tr(
                            zh: "继续完善", en: "Continue", de: "Weiter vervollständigen",
                            es: "Continuar", pt: "Continuar", fr: "Continuer",
                            ja: "続きを入力", ko: "계속 작성", it: "Continua"
                        ),
                        systemImage: "arrow.up.right"
                    )
                    .font(OhanaFont.callout(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.control))
                .tint(tint)
                .accessibilityIdentifier("profile-completion-continue-action")
            }
        }
        .padding(16)
        .background(
            reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l.tr(
            zh: "资料完成度 \(snapshot.completionPercent)%，已完成 \(snapshot.completedCategoryCount) 项，共 \(snapshot.totalCategoryCount) 项",
            en: "Profile \(snapshot.completionPercent) percent complete, \(snapshot.completedCategoryCount) of \(snapshot.totalCategoryCount) categories",
            de: "Profil zu \(snapshot.completionPercent) Prozent vollständig, \(snapshot.completedCategoryCount) von \(snapshot.totalCategoryCount) Bereichen",
            es: "Perfil completado al \(snapshot.completionPercent) por ciento, \(snapshot.completedCategoryCount) de \(snapshot.totalCategoryCount) categorías",
            pt: "Perfil \(snapshot.completionPercent) por cento concluído, \(snapshot.completedCategoryCount) de \(snapshot.totalCategoryCount) categorias",
            fr: "Profil complété à \(snapshot.completionPercent) pour cent, \(snapshot.completedCategoryCount) catégories sur \(snapshot.totalCategoryCount)",
            ja: "プロフィール完成度\(snapshot.completionPercent)パーセント、\(snapshot.totalCategoryCount)項目中\(snapshot.completedCategoryCount)項目完了",
            ko: "프로필 \(snapshot.completionPercent)퍼센트 완료, \(snapshot.totalCategoryCount)개 중 \(snapshot.completedCategoryCount)개 완료",
            it: "Profilo completato al \(snapshot.completionPercent) per cento, \(snapshot.completedCategoryCount) categorie su \(snapshot.totalCategoryCount)"
        ))
        .accessibilityIdentifier("profile-completion-card")
    }
}

@MainActor
struct ProfileSavedFeedback: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            .shadow(color: Color.arkInk.opacity(0.14), radius: 14, y: 6) // ui-v4: allow transient overlay depth
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("profile-saved-feedback")
    }
}

@MainActor
struct ProfileAvatarPreviewSheet: View {
    let name: String
    let imageData: Data
    let closeTitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.arkInk.ignoresSafeArea()
                AsyncDecodedImageView(data: imageData) { image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(name)
                } placeholder: {
                    ProgressView()
                        .tint(Color.goCardWhite)
                }
                .padding(20)
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("profile-avatar-preview-screen")
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
