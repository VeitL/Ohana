import SwiftUI
import UIKit

enum HumanDeletionPresentationOutcome: Equatable {
    case deleted
    case failed(message: String)
}

enum HumanDeletionPresentationCopy {
    static func failureMessage(
        for result: MemberDeletionCommandResult? = nil,
        l: L10n
    ) -> String {
        if result?.persistenceErrorDescription?.localizedCaseInsensitiveContains("pending shop purchase") == true {
            return l.tr(
                zh: "请先结算或退款待处理的商店购买，再删除这位成员。",
                en: "Settle or refund the pending shop purchase before deleting this member.",
                de: "Schließe den ausstehenden Shop-Kauf ab oder erstatte ihn, bevor du dieses Mitglied löschst.",
                es: "Completa o reembolsa la compra pendiente antes de eliminar a este miembro.",
                pt: "Conclua ou reembolse a compra pendente antes de excluir este membro.",
                fr: "Finalisez ou remboursez l’achat en attente avant de supprimer ce membre.",
                ja: "保留中のショップ購入を完了または返金してから、このメンバーを削除してください。",
                ko: "대기 중인 상점 구매를 완료하거나 환불한 후 이 구성원을 삭제해 주세요.",
                it: "Completa o rimborsa l’acquisto in sospeso prima di eliminare questo membro."
            )
        }
        return l.tr(
            zh: "成员没有被删除。数据仍然保留，请稍后重试。",
            en: "The member was not deleted. Their data is still intact. Try again.",
            de: "Das Mitglied wurde nicht gelöscht. Die Daten sind weiterhin vorhanden. Bitte erneut versuchen.",
            es: "El miembro no se eliminó. Sus datos siguen intactos. Inténtalo de nuevo.",
            pt: "O membro não foi excluído. Os dados continuam intactos. Tente novamente.",
            fr: "Le membre n’a pas été supprimé. Ses données sont intactes. Réessayez.",
            ja: "メンバーは削除されませんでした。データは保持されています。もう一度お試しください。",
            ko: "구성원이 삭제되지 않았습니다. 데이터는 그대로 유지됩니다. 다시 시도해 주세요.",
            it: "Il membro non è stato eliminato. I dati sono ancora intatti. Riprova."
        )
    }
}

enum HumanBasicInfoPresentedSheet: String, Identifiable {
    case editor
    case avatarPreview

    var id: String { rawValue }
}

func localizedHumanAgeYears(_ years: Int, l: L10n) -> String {
    l.tr(
        zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.",
        es: "\(years) años", pt: "\(years) anos", fr: "\(years) ans",
        ja: "\(years)歳", ko: "\(years)세", it: "\(years) anni"
    )
}

struct HumanBasicInfoAvatarImage: View {
    let data: Data?
    let fallbackEmoji: String
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 2))
            AsyncDecodedImageView(data: data) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: max(0, size - 8), height: max(0, size - 8), alignment: .center)
                    .clipShape(Circle())
            } placeholder: {
                Text(fallbackEmoji.isEmpty ? "👤" : fallbackEmoji)
                    .font(OhanaFont.metric(size: size * 0.48))
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }
}

struct HumanBasicInfoIdentityHero: View {
    let human: Human
    let onAvatarTap: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ProfileIdentityHero(
            name: human.name,
            subtitle: l.tr(
                zh: "家庭成员资料", en: "Household profile", de: "Haushaltsprofil",
                es: "Perfil del hogar", pt: "Perfil da família", fr: "Profil du foyer",
                ja: "家族プロフィール", ko: "가족 프로필", it: "Profilo familiare"
            ),
            themeColorHex: human.safeThemeColorHex,
            fallbackColor: Color.goPrimary,
            statusTitle: human.hasPassedAway
                ? l.tr(zh: "纪念模式", en: "Memorial", de: "Gedenken")
                : nil,
            avatarAccessibilityLabel: l.tr(
                zh: "\(human.name) 的头像", en: "Avatar for \(human.name)", de: "Avatar von \(human.name)",
                es: "Avatar de \(human.name)", pt: "Avatar de \(human.name)", fr: "Avatar de \(human.name)",
                ja: "\(human.name)のアバター", ko: "\(human.name)님의 아바타", it: "Avatar di \(human.name)"
            ),
            nameAccessibilityIdentifier: "human-basic-info-name-readback",
            onAvatarTap: onAvatarTap
        ) {
            HumanBasicInfoAvatarImage(
                data: human.avatarImageData,
                fallbackEmoji: human.avatarEmoji,
                accent: Color(hex: human.safeThemeColorHex),
                size: 88
            )
        } badges: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { profileBadges }
                VStack(spacing: 8) { profileBadges }
            }
        }
    }

    @ViewBuilder
    private var profileBadges: some View {
        ProfileBadge(
            title: HumanProfileOptions.localizedRoleTitle(human.role, l: l),
            systemImage: "person.badge.key.fill"
        )
        if let birthday = human.birthday {
            ProfileBadge(title: ageText(for: birthday), systemImage: "birthday.cake.fill")
        }
        if !human.mbti.isEmpty {
            ProfileBadge(title: human.mbti.uppercased(), systemImage: nil)
        }
    }

    private func ageText(for birthday: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return years > 0
            ? localizedHumanAgeYears(years, l: l)
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }
}

struct HumanBasicInfoReadContentView: View {
    let human: Human
    let profileCompletionResolutions: Set<MemberProfileCompletionCategory>
    let canEditProfile: Bool
    let onEdit: () -> Void
    let onMarkPassedAway: (Date) -> Void
    let onUndoPassedAway: () -> Void
    let onDelete: (@escaping (HumanDeletionPresentationOutcome) -> Void) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 24) {
            memorialStatus
            ProfileCompletionCard(
                snapshot: MemberProfileCompletenessPolicy.human(
                    human,
                    explicitlyResolvedCategories: profileCompletionResolutions
                ),
                onContinue: canEditProfile ? onEdit : nil
            )
            coreProfileSection
            bodySection
            householdSection
            privacySection
            themeSection
            notesSection
            HumanLifecycleDangerZone(
                human: human,
                onMarkPassedAway: onMarkPassedAway,
                onUndoPassedAway: onUndoPassedAway,
                onDelete: onDelete
            )
        }
    }

    @ViewBuilder
    private var memorialStatus: some View {
        if human.hasPassedAway {
            ProfileStatusBanner(
                title: l.tr(zh: "已进入纪念状态", en: "Memorial profile", de: "Gedenkprofil"),
                detail: human.passedAwayDate.map {
                    l.tr(
                        zh: "纪念日期：\($0.formatted(.dateTime.year().month().day()))",
                        en: "Memorial date: \($0.formatted(.dateTime.year().month().day()))",
                        de: "Gedenkdatum: \($0.formatted(.dateTime.year().month().day()))",
                        es: "Fecha conmemorativa: \($0.formatted(.dateTime.year().month().day()))",
                        pt: "Data memorial: \($0.formatted(.dateTime.year().month().day()))",
                        fr: "Date commémorative : \($0.formatted(.dateTime.year().month().day()))",
                        ja: "メモリアル日：\($0.formatted(.dateTime.year().month().day()))",
                        ko: "추모일: \($0.formatted(.dateTime.year().month().day()))",
                        it: "Data commemorativa: \($0.formatted(.dateTime.year().month().day()))"
                    )
                },
                systemImage: "heart.fill",
                tint: Color.purple
            )
        }
    }

    private var coreProfileSection: some View {
        infoSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
            infoRow(label: l.tr(zh: "名字", en: "Name", de: "Name"), value: human.name)
            infoRow(
                label: l.tr(
                    zh: "家庭角色", en: "Household role", de: "Rolle im Haushalt",
                    es: "Rol en el hogar", pt: "Papel na família", fr: "Rôle dans le foyer",
                    ja: "家族での役割", ko: "가족 역할", it: "Ruolo familiare"
                ),
                value: HumanProfileOptions.localizedRoleTitle(human.role, l: l)
            )
            infoRow(
                label: l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"),
                value: localizedGenderTitle(for: human.genderRaw)
            )
            if let birthday = human.birthday {
                infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: birthday.formatted(.dateTime.year().month().day()))
                infoRow(label: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: Human.westernZodiacDisplay(for: birthday, l: l))
            } else {
                infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: localizedEmptyValue)
            }
        }
    }

    private var bodySection: some View {
        infoSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
            if hasBodyDetails {
                if !human.bloodType.isEmpty {
                    infoRow(label: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), value: human.bloodType)
                }
                if human.heightCm > 0, human.heightCm.isFinite {
                    infoRow(label: l.tr(zh: "身高", en: "Height", de: "Größe"), value: String(format: "%.0f cm", human.heightCm))
                }
                if !human.mbti.isEmpty {
                    infoRow(label: "MBTI", value: human.mbti.uppercased())
                }
            } else {
                emptySectionRow
            }
        }
    }

    private var householdSection: some View {
        infoSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
            infoRow(
                label: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"),
                value: human.nationality.isEmpty
                    ? localizedEmptyValue
                    : PetBreedDatabase.localizedRegionName(human.nationality, l: l)
            )
            infoRow(
                label: l.tr(zh: "现居地", en: "Residence", de: "Wohnort"),
                value: human.city.isEmpty
                    ? localizedEmptyValue
                    : MemberResidenceValue(storedValue: human.city).localized(l: l)
            )
            infoRow(label: l.tr(zh: "加入时间", en: "Joined", de: "Beigetreten"), value: human.createdAt.formatted(.dateTime.year().month().day()))
            infoRow(
                label: l.tr(zh: "相处天数", en: "Days Together", de: "Gemeinsame Tage"),
                value: l.tr(
                    zh: "\(daysTogether) 天", en: "\(daysTogether) days", de: "\(daysTogether) Tage",
                    es: "\(daysTogether) días", pt: "\(daysTogether) dias", fr: "\(daysTogether) jours",
                    ja: "\(daysTogether)日", ko: "\(daysTogether)일", it: "\(daysTogether) giorni"
                )
            )
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        if HumanLocalPrivacyPolicy.isEnabled {
            infoSection(title: l.tr(zh: "隐私", en: "Privacy", de: "Datenschutz"), icon: "lock.shield.fill", iconColor: Color.goYellow) {
                infoRow(label: l.tr(zh: "隐私项目", en: "Private Fields", de: "Private Felder"), value: privacySummary)
            }
        }
    }

    private var themeSection: some View {
        infoSection(title: l.tr(zh: "主题色", en: "Theme Color", de: "Designfarbe"), icon: "paintpalette.fill", iconColor: Color(hex: human.safeThemeColorHex)) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: OhanaRadius.icon)
                    .fill(Color(hex: human.safeThemeColorHex))
                    .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text("#\(human.safeThemeColorHex.uppercased())")
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .monospaced)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
            }
        }
    }

    private var notesSection: some View {
        infoSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
            if !displayNotes.isEmpty {
                Text(displayNotes)
                    .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptySectionRow
            }
        }
    }

    private var emptySectionRow: some View {
        ProfileEmptySectionRow(
            title: l.tr(zh: "尚未填写", en: "Not added yet", de: "Noch nicht ausgefüllt"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            onEdit: canEditProfile ? onEdit : nil
        )
    }

    private func infoSection(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ProfileInfoSection(title: title, systemImage: icon, tint: iconColor, content: content)
    }

    private func infoRow(label: String, value: String) -> some View {
        ProfileInfoRow(label: label, value: value)
    }

    private var daysTogether: Int {
        max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
    }

    private var hasBodyDetails: Bool {
        !human.bloodType.isEmpty ||
            (human.heightCm > 0 && human.heightCm.isFinite) ||
            !human.mbti.isEmpty
    }

    private var privacySummary: String {
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(localizedPrivateFieldTitle)
        return titles.isEmpty
            ? l.tr(zh: "全部公开", en: "All visible", de: "Alles sichtbar")
            : titles.joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    private var displayNotes: String {
        HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
    }

    private var localizedEmptyValue: String {
        l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? localizedEmptyValue : title
    }

    private func localizedPrivateFieldTitle(_ field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            l.tr(zh: "身体与健康记录", en: "Body & health records", de: "Körper- und Gesundheitsdaten")
        case .workout:
            l.tr(zh: "运动", en: "Workouts", de: "Training")
        case .medication:
            l.tr(zh: "吃药提醒", en: "Medication", de: "Medikamente")
        case .wishlist:
            l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermögen & Wünsche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }
}
