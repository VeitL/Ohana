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

func localizedHumanAgeYears(_ years: Int, l: L10n) -> String {
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
    @Environment(\.memberProfileExperienceStyle) private var profileExperienceStyle

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
    @State private var eMBTIEnergy = ""
    @State private var eMBTIInformation = ""
    @State private var eMBTIDecision = ""
    @State private var eMBTILifestyle = ""
    @State private var eNationality = ""
    @State private var eCity = ""
    @State private var eUsesCustomNationality = false
    @State private var eCustomNationality = ""
    @State private var eUsesCustomResidence = false
    @State private var eCustomResidence = ""
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
            editedMBTI != human.mbti.uppercased() ||
            resolvedNationality != human.nationality ||
            resolvedResidence != human.city ||
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
                .tint(profileEditAccent)
                .accessibilityIdentifier("human-basic-info-birthday-toggle")
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(profileEditAccent)
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
                optionChipGrid(title: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), selection: $eBloodType, options: bloodTypeOptions, accent: profileEditAccent)
                Divider().opacity(0.1)
                heightStepperRow
                Divider().opacity(0.1)
                MemberCompactMBTIBar(
                    energy: $eMBTIEnergy,
                    information: $eMBTIInformation,
                    decision: $eMBTIDecision,
                    lifestyle: $eMBTILifestyle,
                    foreground: Color.ohanaPrimaryText,
                    onSelectionChanged: {}
                )
            }

            editSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
                optionPickerRow(
                    l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"),
                    selection: nationalityPickerSelection,
                    options: countryOptions
                )
                if profileExperienceStyle == .zen, eUsesCustomNationality {
                    TextField(
                        l.tr(zh: "输入国籍", en: "Enter nationality", de: "Nationalität eingeben"),
                        text: $eCustomNationality
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("human-basic-info-custom-nationality-input")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Divider().opacity(0.1)
                optionPickerRow(
                    l.tr(zh: "现居地", en: "Residence", de: "Wohnort"),
                    selection: residencePickerSelection,
                    options: residenceCityOptions
                )
                if profileExperienceStyle == .zen, eUsesCustomResidence {
                    TextField(
                        l.tr(zh: "输入现居地", en: "Enter residence", de: "Wohnort eingeben"),
                        text: $eCustomResidence
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("human-basic-info-custom-residence-input")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
        .tint(profileEditAccent)
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
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Label(title, systemImage: icon)
                .foregroundStyle(profileExperienceStyle == .zen ? profileEditAccent : iconColor)
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
        if profileExperienceStyle != .zen,
           !eNationality.isEmpty,
           !options.contains(eNationality) {
            options.insert(eNationality, at: 1)
        }
        return options
    }

    private var residenceCityOptions: [String] {
        let base = eNationality.isEmpty
            ? [""]
            : [""] + PetBreedDatabase.cities(for: eNationality)
        var options = base
        if profileExperienceStyle == .zen, !options.contains("其他") {
            options.append("其他")
        }
        if profileExperienceStyle != .zen,
           !eCity.isEmpty,
           !options.contains(eCity) {
            options.insert(eCity, at: 1)
        }
        return options
    }

    private var nationalityPickerSelection: Binding<String> {
        Binding(
            get: { eUsesCustomNationality ? "其他" : eNationality },
            set: { selection in
                withAnimation(GoMotion.selection) {
                    if profileExperienceStyle == .zen, selection == "其他" {
                        eUsesCustomNationality = true
                        eNationality = ""
                    } else {
                        eUsesCustomNationality = false
                        eCustomNationality = ""
                        eNationality = selection
                    }
                }
            }
        )
    }

    private var residencePickerSelection: Binding<String> {
        Binding(
            get: { eUsesCustomResidence ? "其他" : eCity },
            set: { selection in
                withAnimation(GoMotion.selection) {
                    if profileExperienceStyle == .zen, selection == "其他" {
                        eUsesCustomResidence = true
                        eCity = ""
                    } else {
                        eUsesCustomResidence = false
                        eCustomResidence = ""
                        eCity = selection
                    }
                }
            }
        )
    }

    private var resolvedNationality: String {
        (eUsesCustomNationality ? eCustomNationality : eNationality)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedResidence: String {
        (eUsesCustomResidence ? eCustomResidence : eCity)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                            .foregroundStyle(
                                heightOptionSelected(option)
                                    ? profileEditAccentForeground
                                    : Color.ohanaPrimaryText.opacity(0.78)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(heightOptionSelected(option) ? profileEditAccent : Color.primary.opacity(0.07), in: Capsule())
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
            .tint(profileEditAccent)
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
                            .foregroundStyle(
                                selected
                                    ? profileEditAccentForeground
                                    : Color.ohanaPrimaryText.opacity(0.82)
                            )
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
                .tint(profileExperienceStyle == .zen ? profileEditAccent : Color.goYellow)
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

    private var profileEditAccent: Color {
        guard profileExperienceStyle == .zen else { return Color.goPrimary }
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? Color.goPrimary : Color(hex: value)
    }

    private var profileEditAccentForeground: Color {
        guard profileExperienceStyle == .zen else { return Color.arkInk }
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = value.isEmpty ? "C8F34A" : value
        return WalletPetCardTheme.prefersDarkForeground(for: hex)
            ? Color.arkInk
            : Color.goCardWhite
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
        let mbti = MemberMBTISelectionPolicy.components(from: human.mbti)
        eMBTIEnergy = mbti[0]
        eMBTIInformation = mbti[1]
        eMBTIDecision = mbti[2]
        eMBTILifestyle = mbti[3]
        eUsesCustomNationality = profileExperienceStyle == .zen &&
            !human.nationality.isEmpty &&
            !PetBreedDatabase.countries.contains(human.nationality)
        eCustomNationality = eUsesCustomNationality ? human.nationality : ""
        eNationality = eUsesCustomNationality ? "" : human.nationality
        let recognizedResidenceOptions = eNationality.isEmpty
            ? []
            : PetBreedDatabase.cities(for: eNationality)
        eUsesCustomResidence = profileExperienceStyle == .zen &&
            !human.city.isEmpty &&
            !recognizedResidenceOptions.contains(human.city)
        eCustomResidence = eUsesCustomResidence ? human.city : ""
        eCity = eUsesCustomResidence ? "" : human.city
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
            mbti: editedMBTI,
            nationality: resolvedNationality,
            city: resolvedResidence,
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

    private var editedMBTI: String {
        MemberMBTISelectionPolicy.value(
            energy: eMBTIEnergy,
            information: eMBTIInformation,
            decision: eMBTIDecision,
            lifestyle: eMBTILifestyle
        )
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
