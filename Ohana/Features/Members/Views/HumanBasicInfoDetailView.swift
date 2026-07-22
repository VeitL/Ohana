//
//  HumanBasicInfoDetailView.swift
//  Ohana
//

import SwiftData
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

private func localizedHumanAgeYears(_ years: Int, l: L10n) -> String {
    l.tr(
        zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.",
        es: "\(years) años", pt: "\(years) anos", fr: "\(years) ans",
        ja: "\(years)歳", ko: "\(years)세", it: "\(years) anni"
    )
}

struct HumanBasicInfoDetailContentView: View {
    let human: Human
    var startsEditing = false
    var onSave: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private enum PresentedSheet: String, Identifiable {
        case editor
        case avatarPreview

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var canEditProfile: Bool {
        HumanProfileEditPolicy.canEdit(hasPassedAway: human.hasPassedAway)
    }
    private var l: L10n { L10n(appLanguage) }

    @State private var didApplyInitialEditing = false
    @State private var isDeleting = false
    @State private var personalUpgradePrompt: PersonalUpgradePrompt?
    @State private var presentedSheet: PresentedSheet?
    @State private var showingDiscardConfirmation = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var showsSavedFeedback = false
    @State private var savedFeedbackTask: Task<Void, Never>?
    @State private var profileCompletionResolutions: Set<MemberProfileCompletionCategory> = []

    @State private var eName = ""
    @State private var eAvatarImageData: Data? = nil
    @State private var eAvatarEmoji = ""
    @State private var eRole = "owner"
    @State private var eGender = ""
    @State private var eHasBirthday = false
    @State private var eBirthday = Date()
    @State private var eBloodType = ""
    @State private var eHeightText = ""
    @State private var eMBTI = ""
    @State private var eNationality = ""
    @State private var eCity = ""
    @State private var eThemeColorHex = ""
    @State private var eNotes = ""
    @State private var ePrivateWeight = false
    @State private var ePrivateWorkout = false
    @State private var ePrivateMedication = false
    @State private var ePrivateWishlist = false
    @State private var ePrivateExpense = false
    @State private var ePrivateNote = false

    private let themePresets = ["F97316", "EC4899", "A855F7", "EF4444", "14B8A6", "FACC15", "8B5CF6", "64748B", "B45309", "DB2777"]
    private let bloodTypeOptions = ["", "A", "B", "AB", "O"]
    private let mbtiOptions = ["", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]
    private let genderOptions = HumanProfileOptions.genderOptions

    var body: some View {
        ProfileDetailScaffold(
            title: l.tr(zh: "基础资料", en: "Profile", de: "Profil"),
            closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            showsEditAction: canEditProfile,
            showsSavedFeedback: showsSavedFeedback,
            savedFeedbackTitle: l.tr(zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert"),
            closeAccessibilityIdentifier: "human-basic-info-close-action",
            editAccessibilityIdentifier: "human-basic-info-edit-action",
            onClose: onClose,
            onEdit: presentEditor
        ) {
            avatarSection
        } content: {
            readContent
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway, presentedSheet == .editor {
                presentedSheet = nil
            }
        }
        .onAppear {
            guard startsEditing,
                  !didApplyInitialEditing,
                  canEditProfile else {
                return
            }
            didApplyInitialEditing = true
            presentEditor()
        }
        .task(id: human.id) {
            profileCompletionResolutions = MemberProfileCompletenessReadService
                .explicitlyResolvedCategories(
                    kind: .human,
                    subjectID: human.id,
                    context: modelContext
                )
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .editor:
                humanEditorSheet
            case .avatarPreview:
                if let imageData = human.avatarImageData {
                    ProfileAvatarPreviewSheet(
                        name: human.name,
                        imageData: imageData,
                        closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen")
                    )
                }
            }
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
                .ohanaSheetPagePresentation()
        }
        .onDisappear {
            savedFeedbackTask?.cancel()
        }
        .accessibilityIdentifier("human-basic-info-screen")
    }
}

private extension HumanBasicInfoDetailContentView {
    private var humanEditorSheet: some View {
        NavigationStack {
            editContent
                .navigationTitle(l.tr(zh: "编辑资料", en: "Edit profile", de: "Profil bearbeiten"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), action: cancelEditor)
                            .disabled(isSaving)
                            .accessibilityIdentifier("human-basic-info-cancel-edit-action")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: saveChanges) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                            }
                        }
                        .disabled(!canSaveHumanDraft)
                        .accessibilityIdentifier("human-basic-info-save-action")
                    }
                }
        }
        .interactiveDismissDisabled(hasHumanDraftChanges || isSaving)
        .confirmationDialog(
            l.tr(zh: "放弃未保存的修改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?"),
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(l.tr(zh: "放弃修改", en: "Discard changes", de: "Änderungen verwerfen"), role: .destructive) {
                presentedSheet = nil
            }
            .accessibilityIdentifier("human-basic-info-discard-changes-action")
            Button(l.tr(zh: "继续编辑", en: "Keep editing", de: "Weiter bearbeiten"), role: .cancel) {}
        }
        .alert(
            l.tr(zh: "无法保存资料", en: "Could not save profile", de: "Profil konnte nicht gespeichert werden"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .accessibilityIdentifier("human-basic-info-editor")
    }

    private func presentEditor() {
        guard canEditProfile else { return }
        loadEditState()
        presentedSheet = .editor
    }

    private func cancelEditor() {
        guard hasHumanDraftChanges else {
            presentedSheet = nil
            return
        }
        showingDiscardConfirmation = true
    }

    private var canSaveHumanDraft: Bool {
        !isSaving && !eName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasHumanDraftChanges
    }

    private var hasHumanDraftChanges: Bool {
        eName != human.name ||
            eAvatarImageData != human.avatarImageData ||
            eAvatarEmoji != human.avatarEmoji ||
            eRole != HumanProfileOptions.normalizedRole(human.role) ||
            eGender != (HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? "") ||
            eHasBirthday != (human.birthday != nil) ||
            (eHasBirthday && human.birthday.map { eBirthday != $0 } == true) ||
            eBloodType != human.bloodType ||
            eHeightText != originalHeightText ||
            eMBTI != human.mbti ||
            eNationality != human.nationality ||
            eCity != human.city ||
            eThemeColorHex.uppercased() != human.safeThemeColorHex.uppercased() ||
            eNotes != displayNotes ||
            editedPrivateFieldsRaw != human.privateFields
    }

    private var originalHeightText: String {
        human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
    }

    private func presentSavedFeedback() {
        savedFeedbackTask?.cancel()
        withAnimation(GoMotion.feedback) {
            showsSavedFeedback = true
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: l.tr(
                zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert",
                es: "Perfil actualizado", pt: "Perfil atualizado", fr: "Profil mis à jour",
                ja: "プロフィールを更新しました", ko: "프로필이 업데이트됨", it: "Profilo aggiornato"
            )
        )
        savedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.feedback) {
                showsSavedFeedback = false
            }
        }
    }

    private var avatarSection: some View {
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
            onAvatarTap: human.avatarImageData == nil ? nil : { presentedSheet = .avatarPreview }
        ) {
            humanAvatarImage(
                data: human.avatarImageData,
                fallbackEmoji: human.avatarEmoji,
                accent: Color(hex: human.safeThemeColorHex),
                size: 88
            )
        } badges: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { humanProfileBadges }
                VStack(spacing: 8) { humanProfileBadges }
            }
        }
    }

    @ViewBuilder
    private var humanProfileBadges: some View {
        ProfileBadge(title: localizedRoleText(for: human.role), systemImage: "person.badge.key.fill")
        if let birthday = human.birthday {
            ProfileBadge(title: humanAgeText(for: birthday), systemImage: "birthday.cake.fill")
        }
        if !human.mbti.isEmpty {
            ProfileBadge(title: human.mbti.uppercased(), systemImage: nil)
        }
    }

    private func humanAvatarImage(data: Data?, fallbackEmoji: String, accent: Color, size: CGFloat) -> some View {
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

    private func humanAgeText(for birthday: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return years > 0
            ? localizedHumanAgeYears(years, l: l)
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }

    private var readContent: some View {
        VStack(spacing: 24) {
            humanMemorialStatus
            humanProfileCompletionCard
            humanCoreProfileSection
            humanBodySection
            humanHouseholdSection
            humanPrivacySection
            humanThemeSection
            humanNotesSection
            humanLifecycleDangerZone
        }
    }

    private var humanProfileCompletionCard: some View {
        ProfileCompletionCard(
            snapshot: MemberProfileCompletenessPolicy.human(
                human,
                explicitlyResolvedCategories: profileCompletionResolutions
            ),
            onContinue: canEditProfile
                ? { presentEditor() }
                : nil
        )
    }

    @ViewBuilder
    private var humanMemorialStatus: some View {
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

    private var humanCoreProfileSection: some View {
        infoSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
            infoRow(label: l.tr(zh: "名字", en: "Name", de: "Name"), value: human.name)
            infoRow(
                label: l.tr(
                    zh: "家庭角色", en: "Household role", de: "Rolle im Haushalt",
                    es: "Rol en el hogar", pt: "Papel na família", fr: "Rôle dans le foyer",
                    ja: "家族での役割", ko: "가족 역할", it: "Ruolo familiare"
                ),
                value: localizedRoleText(for: human.role)
            )
            infoRow(label: l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"), value: localizedGenderTitle(for: human.genderRaw))
            if let birthday = human.birthday {
                infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: birthday.formatted(.dateTime.year().month().day()))
                infoRow(label: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: Human.westernZodiacDisplay(for: birthday, l: l))
            } else {
                infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: localizedEmptyValue)
            }
        }
    }

    private var humanBodySection: some View {
        infoSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
            if hasHumanBodyDetails {
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
                humanEmptySectionRow
            }
        }
    }

    private var humanHouseholdSection: some View {
        infoSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
            infoRow(label: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), value: human.nationality.isEmpty ? localizedEmptyValue : human.nationality)
            infoRow(label: l.tr(zh: "现居地", en: "Residence", de: "Wohnort"), value: human.city.isEmpty ? localizedEmptyValue : human.city)
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
    private var humanPrivacySection: some View {
        if HumanLocalPrivacyPolicy.isEnabled {
            infoSection(title: l.tr(zh: "隐私", en: "Privacy", de: "Datenschutz"), icon: "lock.shield.fill", iconColor: Color.goYellow) {
                infoRow(label: l.tr(zh: "隐私项目", en: "Private Fields", de: "Private Felder"), value: privacySummary)
            }
        }
    }

    private var humanThemeSection: some View {
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

    private var humanNotesSection: some View {
        infoSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
            if !displayNotes.isEmpty {
                Text(displayNotes)
                    .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                humanEmptySectionRow
            }
        }
    }

    private var humanEmptySectionRow: some View {
        ProfileEmptySectionRow(
            title: l.tr(zh: "尚未填写", en: "Not added yet", de: "Noch nicht ausgefüllt"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            onEdit: canEditProfile ? { presentEditor() } : nil
        )
    }

    private var editContent: some View {
        Form {
            Section {
                EditableProfileAvatarPicker(
                    avatarImageData: $eAvatarImageData,
                    fallbackEmoji: eAvatarEmoji.isEmpty ? "👤" : eAvatarEmoji,
                    accentColor: Color(hex: eThemeColorHex),
                    cropSpecies: "",
                    silhouetteSystemName: "person.fill"
                )
            } header: {
                Label(l.tr(zh: "头像", en: "Avatar", de: "Avatar"), systemImage: "person.crop.circle")
            }

            editSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
                editField(
                    l.tr(zh: "名字", en: "Name", de: "Name"),
                    text: $eName,
                    accessibilityIdentifier: "human-basic-info-name-input"
                )
                Divider().opacity(0.1)
                editField(
                    l.tr(zh: "头像 Emoji", en: "Avatar Emoji", de: "Avatar-Emoji"),
                    text: $eAvatarEmoji,
                    accessibilityIdentifier: "human-basic-info-avatar-emoji-input"
                )
                Divider().opacity(0.1)
                HStack {
                    editLabel(l.tr(
                        zh: "家庭角色", en: "Household role", de: "Rolle im Haushalt",
                        es: "Rol en el hogar", pt: "Papel na família", fr: "Rôle dans le foyer",
                        ja: "家族での役割", ko: "가족 역할", it: "Ruolo familiare"
                    ))
                    Spacer()
                    Picker("", selection: $eRole) {
                        Text(localizedRoleText(for: "owner")).tag("owner")
                        Text(localizedRoleText(for: "member")).tag("member")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                HStack {
                    editLabel(l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"))
                    Spacer()
                    Picker("", selection: $eGender) {
                        ForEach(genderOptions, id: \.key) { option in
                            Text(localizedGenderTitle(for: option.key)).tag(option.key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180, alignment: .trailing)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel(l.tr(zh: "设置生日", en: "Set Birthday", de: "Geburtstag festlegen"))
                }
                .tint(Color.goPrimary)
                .accessibilityIdentifier("human-basic-info-birthday-toggle")
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                        .accessibilityLabel(l.tr(
                            zh: "生日", en: "Birthday", de: "Geburtstag",
                            es: "Cumpleaños", pt: "Aniversário", fr: "Anniversaire",
                            ja: "誕生日", ko: "생일", it: "Compleanno"
                        ))
                        .accessibilityIdentifier("human-basic-info-birthday-picker")
                }
            }

            editSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
                optionChipGrid(title: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), selection: $eBloodType, options: bloodTypeOptions, accent: Color.goRed)
                Divider().opacity(0.1)
                heightStepperRow
                Divider().opacity(0.1)
                optionChipGrid(title: "MBTI", selection: $eMBTI, options: mbtiOptions, accent: Color.goOrange)
            }

            editSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
                optionPickerRow(l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), selection: $eNationality, options: countryOptions)
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "现居地", en: "Residence", de: "Wohnort"), selection: $eCity, options: residenceCityOptions)
            }

            if HumanLocalPrivacyPolicy.isEnabled {
                editSection(title: l.tr(zh: "隐私设置", en: "Privacy Settings", de: "Datenschutzeinstellungen"), icon: "lock.shield.fill", iconColor: Color.goYellow) {
                    privacyToggle(l.tr(zh: "体重记录", en: "Weight Records", de: "Gewichtsverlauf"), isOn: $ePrivateWeight)
                    privacyToggle(l.tr(zh: "运动记录", en: "Workout Records", de: "Trainingseinträge"), isOn: $ePrivateWorkout)
                    privacyToggle(l.tr(zh: "吃药提醒", en: "Medication Reminders", de: "Medikamentenerinnerungen"), isOn: $ePrivateMedication)
                    privacyToggle(l.tr(zh: "备注", en: "Notes", de: "Notizen"), isOn: $ePrivateNote)
                    privacyToggle(l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermögen & Wünsche"), isOn: $ePrivateWishlist)
                    privacyToggle(l.tr(zh: "花费记录", en: "Expense Records", de: "Ausgabeneinträge"), isOn: $ePrivateExpense)
                }
            }

            editSection(title: l.tr(zh: "主题色", en: "Theme Color", de: "Designfarbe"), icon: "paintpalette.fill", iconColor: Color(hex: eThemeColorHex)) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                    ForEach(themePresets, id: \.self) { hex in
                        let isSelected = eThemeColorHex.uppercased() == hex.uppercased()
                        Button { eThemeColorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                if isSelected {
                                    Circle().strokeBorder(Color.ohanaPrimaryText, lineWidth: 2.5)
                                    Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(l.tr(
                            zh: "主题色 #\(hex)", en: "Theme color #\(hex)", de: "Designfarbe #\(hex)",
                            es: "Color de acento #\(hex)", pt: "Cor de destaque #\(hex)", fr: "Couleur d’accent #\(hex)",
                            ja: "テーマカラー #\(hex)", ko: "테마 색상 #\(hex)", it: "Colore tema #\(hex)"
                        ))
                        .accessibilityValue(isSelected ? l.tr(
                            zh: "已选择", en: "Selected", de: "Ausgewählt",
                            es: "Seleccionado", pt: "Selecionado", fr: "Sélectionné",
                            ja: "選択中", ko: "선택됨", it: "Selezionato"
                        ) : "")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }

            editSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
                ZStack(alignment: .topLeading) {
                    if eNotes.isEmpty {
                        Text(l.tr(
                            zh: "添加想记住的事情（可选）", en: "Add something worth remembering (optional)", de: "Etwas Erinnernswertes hinzufügen (optional)",
                            es: "Añade algo que quieras recordar (opcional)", pt: "Adicione algo que queira lembrar (opcional)", fr: "Ajoutez quelque chose à retenir (facultatif)",
                            ja: "覚えておきたいことを追加（任意）", ko: "기억하고 싶은 내용을 추가하세요(선택 사항)", it: "Aggiungi qualcosa da ricordare (facoltativo)"
                        ))
                        .font(OhanaFont.body())
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                    }
                    TextEditor(text: $eNotes)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .accessibilityLabel(l.tr(
                            zh: "备注", en: "Notes", de: "Notizen",
                            es: "Notas", pt: "Notas", fr: "Notes",
                            ja: "メモ", ko: "메모", it: "Note"
                        ))
                        .accessibilityIdentifier("human-basic-info-notes-input")
                }
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(OhanaAppBackground())
        .scrollDismissesKeyboard(.interactively)
    }
}

private extension HumanBasicInfoDetailContentView {
    private var humanLifecycleDangerZone: some View {
        HumanLifecycleDangerZone(
            human: human,
            onMarkPassedAway: markHumanPassedAway,
            onUndoPassedAway: undoHumanPassedAway,
            onDelete: deleteHumanAndReturnHome
        )
    }

    private func infoSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        ProfileInfoSection(title: title, systemImage: icon, tint: iconColor, content: content)
    }

    private func editSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
        } header: {
            Label(title, systemImage: icon)
                .foregroundStyle(iconColor)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        ProfileInfoRow(label: label, value: value)
    }

    private func editLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func editField(
        _ title: String,
        text: Binding<String>,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        HStack {
            editLabel(title)
            if let accessibilityIdentifier {
                editTextField(title, text: text)
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                editTextField(title, text: text)
            }
        }
    }

    private func editTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .multilineTextAlignment(.trailing)
    }

    private var countryOptions: [String] {
        var options = [""] + PetBreedDatabase.countries
        if !eNationality.isEmpty, !options.contains(eNationality) {
            options.insert(eNationality, at: 1)
        }
        return options
    }

    private var residenceCityOptions: [String] {
        let base = eNationality.isEmpty
            ? [""]
            : [""] + PetBreedDatabase.cities(for: eNationality)
        var options = base
        if !eCity.isEmpty, !options.contains(eCity) {
            options.insert(eCity, at: 1)
        }
        return options
    }

    private var heightValue: Double {
        Double(eHeightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private var heightStepperRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                editLabel(l.tr(zh: "身高", en: "Height", de: "Größe"))
                Spacer()
                Text(heightValue > 0 ? "\(Int(heightValue)) cm" : localizedEmptyValue)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
            }
            HStack(spacing: 8) {
                ForEach(["", "160", "165", "170", "175", "180"], id: \.self) { option in
                    Button {
                        eHeightText = option
                    } label: {
                        Text(option.isEmpty ? localizedEmptyValue : "\(option)")
                            .font(OhanaFont.adaptive(size: 12, weight: heightOptionSelected(option) ? .black : .semibold, design: .rounded))
                            .foregroundStyle(heightOptionSelected(option) ? Color.arkInk : .primary.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(heightOptionSelected(option) ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            Stepper(
                value: Binding(
                    get: { Int(heightValue > 0 ? heightValue : 170) },
                    set: { eHeightText = "\($0)" }
                ),
                in: 80 ... 230,
                step: 1
            ) {
                Text(l.tr(zh: "微调 80-230 cm", en: "Fine tune 80-230 cm", de: "Feinabstimmung 80-230 cm"))
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func heightOptionSelected(_ option: String) -> Bool {
        guard let optionValue = Int(option) else {
            return eHeightText.isEmpty
        }
        return Int(heightValue) == optionValue
    }

    private func optionPickerRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            editLabel(title)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(localizedOptionTitle(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
    }

    private func optionChipGrid(title: String, selection: Binding<String>, options: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            editLabel(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = (selection.wrappedValue.isEmpty && option.isEmpty) || selection.wrappedValue.uppercased() == option
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(localizedOptionTitle(option))
                            .font(OhanaFont.adaptive(size: 12, weight: selected ? .black : .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(selected ? Color.arkInk : .primary.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selected ? accent : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func privacyToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            editLabel(title)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color.goYellow)
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var daysTogether: Int {
        max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
    }

    private var hasHumanBodyDetails: Bool {
        !human.bloodType.isEmpty ||
            (human.heightCm > 0 && human.heightCm.isFinite) ||
            !human.mbti.isEmpty
    }

    private var privacySummary: String {
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(localizedPrivateFieldTitle)
        return titles.isEmpty ? l.tr(zh: "全部公开", en: "All visible", de: "Alles sichtbar") : titles.joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    private var displayNotes: String {
        visibleNoteParts.joined(separator: "｜")
    }

    private var visibleNoteParts: [String] {
        HumanProfileOptions.visibleNoteParts(from: human.notes)
    }

    private var preservedMetadataParts: [String] {
        human.notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.hasPrefix("关系:") }
    }

    private func loadEditState() {
        eName = human.name
        eAvatarImageData = human.avatarImageData
        eAvatarEmoji = human.avatarEmoji
        eRole = HumanProfileOptions.normalizedRole(human.role)
        eGender = HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
        eBirthday = human.birthday ?? Date()
        eHasBirthday = human.birthday != nil
        eBloodType = human.bloodType
        eHeightText = human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
        eMBTI = human.mbti
        eNationality = human.nationality
        eCity = human.city
        eThemeColorHex = human.safeThemeColorHex
        eNotes = displayNotes
        ePrivateWeight = human.privateFields.contains(HumanPrivateField.weight.rawValue)
        ePrivateWorkout = human.privateFields.contains(HumanPrivateField.workout.rawValue)
        ePrivateMedication = human.privateFields.contains(HumanPrivateField.medication.rawValue)
        ePrivateWishlist = human.privateFields.contains(HumanPrivateField.wishlist.rawValue)
        ePrivateExpense = human.privateFields.contains(HumanPrivateField.expense.rawValue)
        ePrivateNote = human.privateFields.contains(HumanPrivateField.note.rawValue)
    }

    private func saveChanges() {
        guard canSaveHumanDraft else { return }
        let input = HumanProfileCommandInput(
            name: eName,
            avatarImageData: eAvatarImageData,
            avatarEmoji: eAvatarEmoji,
            role: eRole,
            gender: eGender,
            birthday: eHasBirthday ? eBirthday : nil,
            bloodType: eBloodType,
            heightText: eHeightText,
            mbti: eMBTI,
            nationality: eNationality,
            city: eCity,
            themeHex: eThemeColorHex,
            notes: eNotes,
            preservedNoteParts: preservedMetadataParts,
            shouldShowOnHome: true,
            privateFieldsRaw: HumanLocalPrivacyPolicy.isEnabled ? editedPrivateFieldsRaw : nil
        )
        isSaving = true
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "humanBasicInfo.profile"
            )
            guard result.didPersist else {
                isSaving = false
                saveErrorMessage = l.tr(
                    zh: "资料没有保存，请稍后再试。",
                    en: "Your changes were not saved. Try again.",
                    de: "Die Änderungen wurden nicht gespeichert. Bitte erneut versuchen."
                )
                OhanaFeedback.error()
                return
            }
            isSaving = false
            presentedSheet = nil
            OhanaFeedback.success()
            presentSavedFeedback()
            onSave?()
        }
    }

    private var editedPrivateFieldsRaw: Set<String> {
        var fields = Set<String>()
        if ePrivateWeight { fields.insert(HumanPrivateField.weight.rawValue) }
        if ePrivateWorkout { fields.insert(HumanPrivateField.workout.rawValue) }
        if ePrivateMedication { fields.insert(HumanPrivateField.medication.rawValue) }
        if ePrivateWishlist { fields.insert(HumanPrivateField.wishlist.rawValue) }
        if ePrivateExpense { fields.insert(HumanPrivateField.expense.rawValue) }
        if ePrivateNote { fields.insert(HumanPrivateField.note.rawValue) }
        return fields
    }

    private var localizedEmptyValue: String {
        l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
    }

    private func localizedOptionTitle(_ option: String) -> String {
        option.isEmpty ? localizedEmptyValue : option
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? localizedEmptyValue : title
    }

    private func localizedPrivateFieldTitle(_ field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
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

    private func deleteHumanAndReturnHome(
        completion: @escaping (HumanDeletionPresentationOutcome) -> Void
    ) {
        guard !isDeleting else {
            completion(.failed(message: HumanDeletionPresentationCopy.failureMessage(l: l)))
            return
        }
        isDeleting = true

        let target = human
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: target.id, kind: EntityKind.human.rawValue)

        OhanaFeedback.medium()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                target,
                activeHumanID: activeHumanID,
                note: "humanBasicInfo.delete"
            )
            guard result.didPersist else {
                isDeleting = false
                OhanaFeedback.error()
                completion(.failed(message: HumanDeletionPresentationCopy.failureMessage(for: result, l: l)))
                return
            }
            if case .pending = result.attachmentCleanup {
                appServices.islandToasts.show(l.tr(
                    zh: "成员已删除，但其本地备注附件未能完全清理。请联系支持。",
                    en: "The member was deleted, but local note attachments could not be fully removed. Contact support.",
                    de: "Das Mitglied wurde gelöscht, aber lokale Notizanhänge konnten nicht vollständig entfernt werden. Kontaktiere den Support."
                ))
            }
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
            isDeleting = false
            OhanaFeedback.success()
            completion(.deleted)
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                dismiss()
            }
        }
    }

    private func markHumanPassedAway(date: Date) {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: date,
                note: "humanBasicInfo.passed.mark"
            )
            guard result.didPersist else {
                appServices.islandToasts.show(l.tr(
                    zh: "离世状态没有更新，请稍后重试。",
                    en: "The memorial status was not updated. Try again.",
                    de: "Der Gedenkstatus wurde nicht aktualisiert. Bitte erneut versuchen.",
                    es: "El estado conmemorativo no se actualizó. Inténtalo de nuevo.",
                    pt: "O estado memorial não foi atualizado. Tente novamente.",
                    fr: "Le statut commémoratif n’a pas été mis à jour. Réessayez.",
                    ja: "メモリアル状態を更新できませんでした。もう一度お試しください。",
                    ko: "추모 상태가 업데이트되지 않았습니다. 다시 시도해 주세요.",
                    it: "Lo stato commemorativo non è stato aggiornato. Riprova."
                ))
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.success()
        }
    }

    private func undoHumanPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.undo"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "humanBasicInfo.passed.undo"
            )
            if let denial = result.personalDenial {
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            guard result.didPersist else {
                appServices.islandToasts.show(l.tr(
                    zh: "离世状态没有更新，请稍后重试。",
                    en: "The memorial status was not updated. Try again.",
                    de: "Der Gedenkstatus wurde nicht aktualisiert. Bitte erneut versuchen.",
                    es: "El estado conmemorativo no se actualizó. Inténtalo de nuevo.",
                    pt: "O estado memorial não foi atualizado. Tente novamente.",
                    fr: "Le statut commémoratif n’a pas été mis à jour. Réessayez.",
                    ja: "メモリアル状態を更新できませんでした。もう一度お試しください。",
                    ko: "추모 상태가 업데이트되지 않았습니다. 다시 시도해 주세요.",
                    it: "Lo stato commemorativo non è stato aggiornato. Riprova."
                ))
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.success()
        }
    }
}

struct HumanLifecycleDangerZone: View {
    let human: Human
    let onMarkPassedAway: (Date) -> Void
    let onUndoPassedAway: () -> Void
    let onDelete: (@escaping (HumanDeletionPresentationOutcome) -> Void) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var passedDate = Date()
    @State private var showingPassedAlert = false
    @State private var showingUndoPassedAlert = false
    @State private var showingDeleteSheet = false
    @State private var isExpanded = false
    @State private var isDeleteInProgress = false
    @State private var deleteErrorMessage: String?
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if human.hasPassedAway {
                    passedAwaySummary
                    lifecycleButton(
                        title: l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"),
                        icon: "arrow.uturn.backward",
                        color: Color.goYellow,
                        identifier: "human-memorial-undo-action"
                    ) {
                        showingUndoPassedAlert = true
                    }
                } else {
                    DatePicker(l.tr(zh: "离世日期", en: "Date of Passing", de: "Sterbedatum"), selection: $passedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                    lifecycleButton(
                        title: l.tr(
                            zh: "标记 \(human.name) 已离世", en: "Mark \(human.name) as passed away", de: "\(human.name) als verstorben markieren",
                            es: "Marcar a \(human.name) como fallecido", pt: "Marcar \(human.name) como falecido", fr: "Indiquer le décès de \(human.name)",
                            ja: "\(human.name)を逝去として記録", ko: "\(human.name)님을 별세로 표시", it: "Segna \(human.name) come deceduto"
                        ),
                        icon: "rainbow",
                        color: Color.goPurple,
                        identifier: "human-memorial-mark-action"
                    ) {
                        showingPassedAlert = true
                    }
                }

                lifecycleButton(
                    title: l.tr(
                        zh: "彻底删除 \(human.name)", en: "Permanently delete \(human.name)", de: "\(human.name) endgültig löschen",
                        es: "Eliminar permanentemente a \(human.name)", pt: "Excluir \(human.name) permanentemente", fr: "Supprimer définitivement \(human.name)",
                        ja: "\(human.name)を完全に削除", ko: "\(human.name)님 영구 삭제", it: "Elimina definitivamente \(human.name)"
                    ),
                    icon: "trash.fill",
                    color: Color.goRed,
                    identifier: "human-danger-delete-action"
                ) {
                    showingDeleteSheet = true
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "archivebox.fill") // a11y: allow decorative icon; the disclosure label supplies the full meaning
                    .foregroundStyle(Color.goRed.opacity(0.72))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(
                        zh: "生命与数据管理", en: "Life & data management", de: "Lebens- und Datenverwaltung",
                        es: "Vida y gestión de datos", pt: "Vida e gestão de dados", fr: "Vie et gestion des données",
                        ja: "ライフイベントとデータ管理", ko: "생애 및 데이터 관리", it: "Vita e gestione dei dati"
                    ))
                    .font(OhanaFont.callout(.bold))
                    Text(l.tr(
                        zh: "离世状态与永久删除", en: "Memorial status and permanent deletion", de: "Gedenkstatus und endgültiges Löschen",
                        es: "Estado conmemorativo y eliminación permanente", pt: "Estado memorial e exclusão permanente", fr: "Statut commémoratif et suppression définitive",
                        ja: "メモリアル状態と完全削除", ko: "추모 상태 및 영구 삭제", it: "Stato commemorativo ed eliminazione definitiva"
                    ))
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
        .tint(Color.goRed)
        .accessibilityIdentifier("human-lifecycle-management-disclosure")
        .onAppear {
            passedDate = human.passedAwayDate ?? Date()
        }
        .onChange(of: human.passedAwayDate) { _, date in
            passedDate = date ?? Date()
        }
        .alert(l.tr(zh: "确认标记离世", en: "Confirm Passing Mark", de: "Verstorben-Markierung bestätigen"), isPresented: $showingPassedAlert) {
            Button(l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), role: .destructive) {
                onMarkPassedAway(passedDate)
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将标记 \(human.name) 为离世，并让未来安排退出活跃提醒。原有数据会保留，此操作可撤销。",
                en: "\(human.name) will be marked as passed away, and future schedules will leave active reminders. Existing data is kept, and this can be undone.",
                de: "\(human.name) wird als verstorben markiert, und zukünftige Termine verlassen aktive Erinnerungen. Bestehende Daten bleiben erhalten und dies kann rückgängig gemacht werden.",
                es: "\(human.name) se marcará como fallecido y las futuras citas saldrán de los recordatorios activos. Los datos existentes se conservarán y podrás deshacerlo.",
                pt: "\(human.name) será marcado como falecido e os agendamentos futuros sairão dos lembretes ativos. Os dados existentes serão mantidos e isso poderá ser desfeito.",
                fr: "Le décès de \(human.name) sera enregistré et les échéances futures quitteront les rappels actifs. Les données existantes seront conservées et cette action pourra être annulée.",
                ja: "\(human.name)を逝去として記録し、今後の予定を有効なリマインダーから外します。既存のデータは保持され、元に戻せます。",
                ko: "\(human.name)님을 별세로 표시하고 이후 일정은 활성 알림에서 제외합니다. 기존 데이터는 유지되며 되돌릴 수 있습니다.",
                it: "\(human.name) verrà segnato come deceduto e gli appuntamenti futuri usciranno dai promemoria attivi. I dati esistenti saranno conservati e l’azione potrà essere annullata."
            ))
        }
        .alert(l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"), isPresented: $showingUndoPassedAlert) {
            Button(l.tr(zh: "撤销", en: "Undo", de: "Zurücknehmen"), role: .destructive) {
                onUndoPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将清除 \(human.name) 的离世记录，恢复为在世状态。",
                en: "\(human.name)'s passing record will be cleared and restored to active status.",
                de: "Der Verstorben-Eintrag von \(human.name) wird gelöscht und der aktive Status wiederhergestellt.",
                es: "Se borrará el registro de fallecimiento de \(human.name) y se restaurará su estado activo.",
                pt: "O registro de falecimento de \(human.name) será removido e o status ativo será restaurado.",
                fr: "L’enregistrement du décès de \(human.name) sera effacé et son statut actif sera rétabli.",
                ja: "\(human.name)の逝去記録を消去し、アクティブな状態に戻します。",
                ko: "\(human.name)님의 별세 기록을 지우고 활성 상태로 복원합니다.",
                it: "La registrazione del decesso di \(human.name) verrà rimossa e lo stato attivo ripristinato."
            ))
        }
        .sheet(isPresented: $showingDeleteSheet) {
            HumanDeleteConfirmationSheet(
                humanName: human.name,
                isDeleting: isDeleteInProgress,
                onCancel: { showingDeleteSheet = false },
                onDelete: beginDeletion
            )
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .alert(
            l.tr(
                zh: "无法删除成员", en: "Could not delete member", de: "Mitglied konnte nicht gelöscht werden",
                es: "No se pudo eliminar al miembro", pt: "Não foi possível excluir o membro", fr: "Impossible de supprimer le membre",
                ja: "メンバーを削除できませんでした", ko: "구성원을 삭제할 수 없음", it: "Impossibile eliminare il membro"
            ),
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button(l.confirm, role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func beginDeletion() {
        guard !isDeleteInProgress else { return }
        isDeleteInProgress = true
        onDelete { outcome in
            isDeleteInProgress = false
            switch outcome {
            case .deleted:
                showingDeleteSheet = false
            case let .failed(message):
                deleteErrorMessage = message
            }
        }
    }

    private var passedAwaySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = human.passedAwayDate {
                Text(l.tr(
                    zh: "离世日期：\(date.formatted(.dateTime.year().month().day()))",
                    en: "Date of passing: \(date.formatted(.dateTime.year().month().day()))",
                    de: "Sterbedatum: \(date.formatted(.dateTime.year().month().day()))",
                    es: "Fecha de fallecimiento: \(date.formatted(.dateTime.year().month().day()))",
                    pt: "Data de falecimento: \(date.formatted(.dateTime.year().month().day()))",
                    fr: "Date du décès : \(date.formatted(.dateTime.year().month().day()))",
                    ja: "逝去日：\(date.formatted(.dateTime.year().month().day()))",
                    ko: "별세일: \(date.formatted(.dateTime.year().month().day()))",
                    it: "Data del decesso: \(date.formatted(.dateTime.year().month().day()))"
                ))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
            }
            Text(l.tr(
                zh: "相伴 \(human.daysTogetherAtPassing) 天 · \(human.ageAtPassingText)",
                en: "Together for \(human.daysTogetherAtPassing) days · \(localizedAgeAtPassing)",
                de: "\(human.daysTogetherAtPassing) Tage zusammen · \(localizedAgeAtPassing)",
                es: "\(human.daysTogetherAtPassing) días juntos · \(localizedAgeAtPassing)",
                pt: "\(human.daysTogetherAtPassing) dias juntos · \(localizedAgeAtPassing)",
                fr: "\(human.daysTogetherAtPassing) jours ensemble · \(localizedAgeAtPassing)",
                ja: "一緒に過ごした\(human.daysTogetherAtPassing)日 · \(localizedAgeAtPassing)",
                ko: "함께한 \(human.daysTogetherAtPassing)일 · \(localizedAgeAtPassing)",
                it: "\(human.daysTogetherAtPassing) giorni insieme · \(localizedAgeAtPassing)"
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.goPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            .strokeBorder(Color.goPurple.opacity(0.22), lineWidth: 1))
        .accessibilityIdentifier("human-memorial-passed-date")
    }

    private func lifecycleButton(
        title: String,
        icon: String,
        color: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon) // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(color.opacity(0.26), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var localizedAgeAtPassing: String {
        guard let birthday = human.birthday,
              let passed = human.passedAwayDate else {
            return l.tr(zh: "未知年龄", en: "Unknown age", de: "Unbekanntes Alter")
        }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: passed).year ?? 0
        return years > 0
            ? localizedHumanAgeYears(years, l: l)
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }
}

private struct HumanDeleteConfirmationSheet: View {
    let humanName: String
    let isDeleting: Bool
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool
    private var l: L10n { L10n(appLanguage) }

    private var canDelete: Bool {
        !isDeleting && ConfirmationNameMatcher.matches(confirmName, expectedName: humanName)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(
                            zh: "删除成员 \(humanName)", en: "Delete member \(humanName)", de: "Mitglied \(humanName) löschen",
                            es: "Eliminar a \(humanName)", pt: "Excluir \(humanName)", fr: "Supprimer \(humanName)",
                            ja: "\(humanName)を削除", ko: "\(humanName)님 삭제", it: "Elimina \(humanName)"
                        ))
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "输入名字后才能继续", en: "Enter the name to continue", de: "Namen eingeben, um fortzufahren"))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: cancelAfterResigningKeyboard) {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("human-delete-confirm-close")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "这会永久删除成员资料及所有关联的本地数据，包括健康、用药、任务、椰子账本、活动记录与备注附件。无法撤销。",
                        en: "This permanently deletes the member profile and all related local data, including health, medication, tasks, coconut ledgers, activity history, and note attachments. It cannot be undone.",
                        de: "Dies löscht das Mitgliederprofil und alle zugehörigen lokalen Daten dauerhaft, einschließlich Gesundheit, Medikamente, Aufgaben, Kokosnuss-Konten, Aktivitäten und Notizanhänge. Dies kann nicht rückgängig gemacht werden.",
                        es: "Esto elimina permanentemente el perfil y todos los datos locales relacionados, incluidos salud, medicación, tareas, registros de cocos, actividad y archivos adjuntos. No se puede deshacer.",
                        pt: "Isso exclui permanentemente o perfil e todos os dados locais relacionados, incluindo saúde, medicação, tarefas, registros de cocos, atividades e anexos. Não é possível desfazer.",
                        fr: "Cette action supprime définitivement le profil et toutes les données locales associées, notamment santé, médicaments, tâches, registres de noix de coco, activités et pièces jointes. Elle est irréversible.",
                        ja: "メンバーのプロフィールと、健康・服薬・タスク・ココナッツ台帳・活動履歴・メモの添付ファイルを含む関連ローカルデータを完全に削除します。元に戻せません。",
                        ko: "구성원 프로필과 건강, 복약, 작업, 코코넛 원장, 활동 기록, 메모 첨부 파일을 포함한 모든 관련 로컬 데이터를 영구 삭제합니다. 되돌릴 수 없습니다.",
                        it: "Questa azione elimina definitivamente il profilo e tutti i dati locali correlati, inclusi salute, farmaci, attività, registri delle noci di cocco, cronologia e allegati delle note. Non può essere annullata."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text(l.tr(
                        zh: "请输入：\(humanName)", en: "Enter: \(humanName)", de: "Eingeben: \(humanName)",
                        es: "Escribe: \(humanName)", pt: "Digite: \(humanName)", fr: "Saisissez : \(humanName)",
                        ja: "入力：\(humanName)", ko: "입력: \(humanName)", it: "Inserisci: \(humanName)"
                    ))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField(l.tr(zh: "成员名字", en: "Member name", de: "Mitgliedsname"), text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($confirmNameFocused)
                    .disabled(isDeleting)
                    .onSubmit { attemptDelete() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))
                    .accessibilityIdentifier("human-delete-confirm-name-input")

                HStack(spacing: 10) {
                    Button(action: cancelAfterResigningKeyboard) {
                        Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("human-delete-confirm-cancel")

                    Button(action: attemptDelete) {
                        Group {
                            if isDeleting {
                                ProgressView()
                                    .tint(Color.white) // ui-v4: allow high-contrast progress indicator on destructive red fill
                            } else {
                                Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
                                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            }
                        }
                        .foregroundStyle(canDelete || isDeleting ? Color.white : Color.ohanaTertiaryText) // ui-v4: allow destructive red button needs white contrast
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canDelete || isDeleting ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                    .accessibilityIdentifier("human-delete-confirm-delete")
                }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private func cancelAfterResigningKeyboard() {
        confirmNameFocused = false
        onCancel()
    }

    private func attemptDelete() {
        guard canDelete else { return }
        confirmNameFocused = false
        onDelete()
    }
}
