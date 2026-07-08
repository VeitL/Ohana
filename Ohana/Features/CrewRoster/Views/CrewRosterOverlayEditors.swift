//
//  CrewRosterOverlayEditors.swift
//  Ohana
//
//  Extracted editor/profile surfaces for CrewRosterOverlay.
//

import SwiftData
import SwiftUI
import UIKit

struct RosterHomeVisibilityToggle: View {
    let isOn: Bool
    let label: String
    var identifier: String?
    let onChange: (Bool) -> Bool

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var visualOverride: Bool?

    private var visualIsOn: Bool {
        visualOverride ?? isOn
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Button {
            let nextValue = !visualIsOn
            withAnimation(GoMotion.feedback) {
                visualOverride = nextValue
            }
            guard onChange(nextValue) else {
                withAnimation(GoMotion.feedback) {
                    visualOverride = isOn
                }
                return
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: visualIsOn ? "house.fill" : "house")
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(visualIsOn ? Color.goPrimary : Color.goCardWhite.opacity(0.78))
                    .symbolEffect(.bounce, value: visualIsOn)

                ZStack(alignment: visualIsOn ? .trailing : .leading) {
                    Capsule()
                        .fill(visualIsOn ? Color.goPrimary.opacity(0.92) : Color.goCardWhite.opacity(0.18))
                        .frame(width: 28, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    Circle()
                        .fill(visualIsOn ? Color.arkInk : Color.goCardWhite.opacity(0.92))
                        .frame(width: 12, height: 12) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .padding(.horizontal, 2)
                }
            }
            .frame(width: 58, height: 32)
            .contentShape(Rectangle())
            .animation(GoMotion.feedback, value: visualIsOn)
            .frame(width: 66, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(visualIsOn ? l.tr(zh: "开启", en: "On", de: "Ein") : l.tr(zh: "关闭", en: "Off", de: "Aus"))
        .accessibilityIdentifier(identifier ?? "")
        .onChange(of: isOn) { _, newValue in
            guard visualOverride == newValue else { return }
            visualOverride = nil
        }
    }
}

struct CrewRosterProfilePanel: View {
    let card: FocusCard
    let pet: Pet?
    let human: Human?
    let plant: Plant?
    let petSummary: CrewRosterPetSummary
    let allPets: [Pet]
    let allHumans: [Human]
    let detailProgress: CGFloat
    let isDetailMounted: Bool
    let onClose: () -> Void
    let onDeleted: () -> Void
    let onSaved: (UUID, String) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var isEditing = false
    @State private var showingPetPassedAlert = false
    @State private var showingPetUndoPassedAlert = false
    @State private var showingPetClearAlert = false
    @State private var showingPetDeleteSheet = false
    @State private var showingHumanPassedAlert = false
    @State private var showingHumanUndoPassedAlert = false
    @State private var showingHumanDeleteSheet = false
    @State private var showingPlantDeleteAlert = false
    @State private var passedDate = Date()

    @State private var name = ""
    @State private var avatarImageData: Data?
    @State private var avatarEmoji = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var gender = "unknown"
    @State private var role = "member"
    @State private var isNeutered = false
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var bloodType = ""
    @State private var heightText = ""
    @State private var mbti = ""
    @State private var nationality = ""
    @State private var city = ""
    @State private var location = ""
    @State private var wateringDays = 7
    @State private var fertilizingDays = 30
    @State private var themeHex = ""
    @State private var notes = ""
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current
    @State private var humanAvatarSignature = ""
    @State private var humanAvatarCacheKey = "crew-roster-profile-human-avatar-empty"
    @State private var avatarImageRevision = 0

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    private var tint: Color { Color(hex: resolvedThemeHex) }
    private var resolvedThemeHex: String {
        if !themeHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return themeHex }
        if let pet { return pet.safeThemeColorHex }
        if let human { return human.safeThemeColorHex }
        if let plant { return plant.themeColorHex }
        return "9EF06A"
    }

    private var l: L10n { L10n(appLanguage) }
    private var detailReveal: CGFloat { min(max(detailProgress, 0), 1) }
    private var controlReveal: CGFloat { WalletHeroTimeline.smooth(detailProgress, 0.12, 0.34) }
    private var summarySnapshot: CrewRosterProfileSummarySnapshot {
        CrewRosterProfileSummarySnapshot.make(card: card, l: l)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arkInk.opacity(0.58 * Double(detailReveal))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: CrewRosterProfileContinuityMetrics.summaryDetailGap) {
                CrewRosterProfileSummaryHeader(snapshot: summarySnapshot)

                if isDetailMounted {
                    detailScroll
                }
            }
            .padding(.horizontal, CrewRosterProfileContinuityMetrics.horizontalInset)
            .padding(.top, CrewRosterProfileContinuityMetrics.summaryTopInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            toolbar
                .opacity(Double(controlReveal))
                .allowsHitTesting(detailProgress > 0.985)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            loadEditState(includeAvatarData: false)
        }
        .task(id: humanAvatarSourceKey) {
            await prepareHumanAvatar()
        }
        .onDisappear {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
        }
        .alert(l.tr(zh: "确认标记离世", en: "Mark as passed away?", de: "Als verstorben markieren?"), isPresented: $showingPetPassedAlert) {
            Button(l.tr(zh: "确认", en: "Confirm", de: "Bestaetigen"), role: .destructive) {
                markPetPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "将进入纪念模式，并让未来照护安排退出活跃提醒。原有数据会保留，此操作可撤销。", en: "This pet will enter memorial mode and future care plans will leave active reminders. Existing data stays, and this can be undone.", de: "Dieses Haustier wechselt in den Gedenkmodus und kuenftige Pflegeplaene verlassen aktive Erinnerungen. Bestehende Daten bleiben erhalten und die Aktion kann rueckgaengig gemacht werden."))
        }
        .alert(l.tr(zh: "撤销离世标记", en: "Undo passed-away mark?", de: "Verstorben-Markierung rueckgaengig machen?"), isPresented: $showingPetUndoPassedAlert) {
            Button(l.tr(zh: "撤销", en: "Undo", de: "Rueckgaengig"), role: .destructive) {
                undoPetPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "将清除离世日期，恢复为在世状态。", en: "This clears the passed-away date and restores active status.", de: "Das Sterbedatum wird geloescht und der aktive Status wiederhergestellt."))
        }
        .alert(l.tr(zh: "仅清空所有记录", en: "Clear records only?", de: "Nur Eintraege loeschen?"), isPresented: $showingPetClearAlert) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "清空记录", en: "Clear records", de: "Eintraege loeschen"), role: .destructive) {
                clearPetActivityRecords()
            }
        } message: {
            Text(l.tr(zh: "将删除护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录；保留名字、头像、品种与证件/保险档案。此操作不可撤销。", en: "This deletes care, weight, expense, health, walk, feeding, hygiene, milestone, medication, and photo records while keeping the name, avatar, breed, documents, and insurance profile. This cannot be undone.", de: "Dies loescht Pflege-, Gewichts-, Ausgaben-, Gesundheits-, Spaziergangs-, Fuetterungs-, Hygiene-, Meilenstein-, Medikamenten- und Fotoeintraege. Name, Avatar, Rasse, Dokumente und Versicherung bleiben erhalten. Das kann nicht rueckgaengig gemacht werden."))
        }
        .alert(l.tr(zh: "确认标记纪念模式", en: "Mark memorial mode?", de: "Gedenkmodus markieren?"), isPresented: $showingHumanPassedAlert) {
            Button(l.tr(zh: "确认", en: "Confirm", de: "Bestaetigen"), role: .destructive) {
                markHumanPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "将把该成员设为纪念模式。", en: "This member will be moved into memorial mode.", de: "Dieses Mitglied wird in den Gedenkmodus versetzt."))
        }
        .alert(l.tr(zh: "撤销纪念模式", en: "Undo memorial mode?", de: "Gedenkmodus zuruecknehmen?"), isPresented: $showingHumanUndoPassedAlert) {
            Button(l.tr(zh: "撤销", en: "Undo", de: "Zuruecknehmen"), role: .destructive) {
                undoHumanPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "将清除该成员的纪念模式日期。", en: "This will clear the member's memorial-mode date.", de: "Das Datum fuer den Gedenkmodus dieses Mitglieds wird geloescht."))
        }
        .alert(l.tr(zh: "确认删除植物", en: "Delete plant?", de: "Pflanze loeschen?"), isPresented: $showingPlantDeleteAlert) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Loeschen"), role: .destructive) {
                guard let plant else { return }
                let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                    plant,
                    note: "crew.member.deleted.plant"
                )
                UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
                if result.didPersist {
                    onDeleted()
                }
            }
        } message: {
            let plantName = plant?.name ?? l.tr(zh: "这株植物", en: "this plant", de: "diese Pflanze")
            Text(l.tr(zh: "确定要删除 \(plantName) 吗？", en: "Delete \(plantName)?", de: "\(plantName) loeschen?"))
        }
        .sheet(isPresented: $showingPetDeleteSheet) {
            let petName = pet?.name ?? l.tr(zh: "宠物", en: "pet", de: "Haustier")
            CrewRosterDeleteConfirmationSheet(
                title: l.tr(zh: "彻底删除 \(petName)", en: "Delete \(petName) permanently", de: "\(petName) endgueltig loeschen"),
                name: pet?.name ?? "",
                warning: l.tr(zh: "这会删除宠物和所有关联记录，无法撤销。", en: "This deletes the pet and all linked records. It cannot be undone.", de: "Dies loescht das Haustier und alle verknuepften Eintraege. Das kann nicht rueckgaengig gemacht werden."),
                onCancel: { showingPetDeleteSheet = false },
                onDelete: deletePetWithCascade
            )
            .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        }
        .sheet(isPresented: $showingHumanDeleteSheet) {
            let humanName = human?.name ?? ""
            CrewRosterDeleteConfirmationSheet(
                title: l.tr(zh: "删除成员 \(humanName)", en: "Delete member \(humanName)", de: "Mitglied \(humanName) loeschen"),
                name: human?.name ?? "",
                warning: l.tr(zh: "这会删除成员资料、体重与运动记录，无法撤销。", en: "This will delete the member profile, weight logs, and workout records. It cannot be undone.", de: "Dies loescht Profil, Gewichtseintraege und Trainingsdaten des Mitglieds. Das kann nicht rueckgaengig gemacht werden."),
                onCancel: { showingHumanDeleteSheet = false },
                onDelete: deleteHumanAndReturnHome
            )
            .ohanaCompactSheetPresentation(detents: [.height(360), .medium])
        }
    }

    private var detailScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                isEditing ? AnyView(editContent) : AnyView(readContent)
            }
            .padding(.bottom, 28)
        }
        .opacity(Double(WalletHeroTimeline.smooth(detailProgress, 0.06, 0.28)))
        .mask(alignment: .top) {
            GeometryReader { proxy in
                Color.arkInk
                    .frame(height: proxy.size.height * detailReveal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                if isEditing {
                    saveChanges()
                } else {
                    loadEditState(includeAvatarData: true)
                    withAnimation(GoMotion.feedback) { isEditing = true }
                }
            } label: {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(isEditing ? l.save : l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"))

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(isEditing ? l.tr(zh: "编辑基本信息", en: "Editing basic info", de: "Basisdaten bearbeiten") : l.tr(zh: "基本信息", en: "Basic info", de: "Basisdaten"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.64))
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schliessen"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var readContent: some View {
        VStack(spacing: 12) {
            if let pet {
                petReadContent(pet)
            } else if let human {
                humanReadContent(human)
            } else if let plant {
                plantReadContent(plant)
            }
        }
    }

    private var editContent: some View {
        VStack(spacing: 12) {
            profileEditAvatar
            if pet != nil {
                petEditContent
            } else if human != nil {
                humanEditContent
            } else if plant != nil {
                plantEditContent
            }
        }
    }

    private func petReadContent(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            profileSection(l.tr(zh: "身份", en: "Identity", de: "Identitaet"), icon: "pawprint.fill") {
                infoRow(l.tr(zh: "物种", en: "Species", de: "Art"), emptyText(pet.localizedSpeciesName(l: l)))
                infoRow(l.tr(zh: "品种", en: "Breed", de: "Rasse"), emptyText(pet.breed))
                infoRow(l.tr(zh: "年龄", en: "Age", de: "Alter"), pet.hasPassedAway ? pet.ageAtPassingText : pet.ageText)
                infoRow(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), petGenderSummary(pet))
                infoRow(l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), "#\(pet.safeThemeColorHex.uppercased())")
            }
            profileSection(l.tr(zh: "照护", en: "Care", de: "Pflege"), icon: "heart.fill") {
                infoRow(l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), formattedDate(pet.birthday))
                infoRow(l.tr(zh: "到家日", en: "Home date", de: "Einzugstag"), formattedDate(pet.homeDate))
                infoRow(l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), pet.hasPassedAway ? localizedDays(pet.daysTogetherAtPassing) : localizedDays(pet.daysTogether))
                infoRow(l.tr(zh: "主粮", en: "Main food", de: "Hauptfutter"), emptyText(pet.foodBrand))
                infoRow(l.tr(zh: "粮仓", en: "Food stock", de: "Futtervorrat"), pet.restockWeight > 0 ? "\(Int(pet.restockWeight)) g" : localizedEmptyValue)
            }
            profileSection(l.tr(zh: "保障", en: "Protection", de: "Absicherung"), icon: "cross.case.fill") {
                infoRow(l.tr(zh: "芯片号", en: "Microchip", de: "Mikrochip"), emptyText(pet.microchipID))
                infoRow(l.tr(zh: "医院", en: "Clinic", de: "Praxis"), emptyText(pet.vetClinicName))
                infoRow(l.tr(zh: "医生", en: "Doctor", de: "Tierarzt"), emptyText(pet.vetDoctorName))
                infoRow(l.tr(zh: "电话", en: "Phone", de: "Telefon"), emptyText(pet.vetContact))
                infoRow(l.tr(zh: "过敏", en: "Allergies", de: "Allergien"), emptyText(pet.allergies))
                infoRow(l.tr(zh: "证件", en: "Documents", de: "Dokumente"), "\(petSummary.documentCount)")
            }
            if !pet.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection(l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text") { paragraph(pet.notes) }
            }
            petLifecycleSection(pet)
        }
    }

    private func humanReadContent(_ human: Human) -> some View {
        VStack(spacing: 12) {
            profileSection(l.tr(zh: "身份", en: "Identity", de: "Identitaet"), icon: "person.fill") {
                infoRow(l.tr(zh: "权限", en: "Role", de: "Rolle"), localizedRoleText(for: human.role))
                infoRow(l.tr(zh: "年龄", en: "Age", de: "Alter"), localizedHumanAge(human))
                infoRow(l.tr(zh: "性别/身份", en: "Gender / identity", de: "Geschlecht / Identitaet"), localizedGenderTitle(for: human.genderRaw))
                infoRow(l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), formattedDate(human.birthday))
                infoRow(l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), human.birthday.map { Human.westernZodiacDisplay(for: $0, l: l) } ?? localizedEmptyValue)
            }
            profileSection(l.tr(zh: "身体", en: "Body", de: "Koerper"), icon: "heart.text.square.fill") {
                infoRow(l.tr(zh: "血型", en: "Blood type", de: "Blutgruppe"), emptyText(human.bloodType))
                infoRow(l.tr(zh: "身高", en: "Height", de: "Groesse"), human.heightCm > 0 ? "\(Int(human.heightCm)) cm" : localizedEmptyValue)
                infoRow("MBTI", human.mbti.isEmpty ? localizedEmptyValue : human.mbti.uppercased())
            }
            profileSection(l.tr(zh: "家庭与显示", en: "Family & display", de: "Familie & Anzeige"), icon: "house.fill") {
                infoRow(l.tr(zh: "国籍", en: "Nationality", de: "Nationalitaet"), emptyText(human.nationality))
                infoRow(l.tr(zh: "现居地", en: "Current city", de: "Aktueller Ort"), emptyText(human.city))
                infoRow(l.tr(zh: "首页显示", en: "Home visibility", de: "Startseitenanzeige"), human.shouldShowOnHome ? l.tr(zh: "显示", en: "Shown", de: "Angezeigt") : l.tr(zh: "隐藏", en: "Hidden", de: "Ausgeblendet"))
                if HumanLocalPrivacyPolicy.isEnabled {
                    infoRow(l.tr(zh: "隐私项目", en: "Private fields", de: "Private Felder"), privacySummary(for: human))
                }
            }
            let humanNotes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            if !humanNotes.isEmpty {
                profileSection(l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text") { paragraph(humanNotes) }
            }
            humanLifecycleSection(human)
        }
    }

    private func plantReadContent(_ plant: Plant) -> some View {
        VStack(spacing: 12) {
            profileSection(l.tr(zh: "植物", en: "Plant", de: "Pflanze"), icon: "leaf.fill") {
                infoRow(l.tr(zh: "品种", en: "Species", de: "Art"), emptyText(plant.species))
                infoRow(l.tr(zh: "位置", en: "Location", de: "Standort"), emptyText(plant.location))
                infoRow(l.tr(zh: "浇水间隔", en: "Watering interval", de: "Giessintervall"), localizedDays(plant.wateringIntervalDays))
                infoRow(l.tr(zh: "施肥间隔", en: "Fertilizing interval", de: "Duengeintervall"), localizedDays(plant.fertilizingIntervalDays))
                infoRow(l.tr(zh: "上次浇水", en: "Last watered", de: "Zuletzt gegossen"), formattedDate(plant.lastWateredDate))
                infoRow(l.tr(zh: "上次施肥", en: "Last fertilized", de: "Zuletzt geduengt"), formattedDate(plant.lastFertilizedDate))
            }
            if !plant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection(l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text") { paragraph(plant.notes) }
            }
            destructiveButton(l.tr(zh: "删除植物", en: "Delete plant", de: "Pflanze loeschen"), icon: "trash.fill", color: Color.goRed) {
                showingPlantDeleteAlert = true
            }
        }
    }

    private var profileEditAvatar: some View {
        profileSection(l.tr(zh: "头像", en: "Avatar", de: "Avatar"), icon: "person.crop.square.fill") {
            HStack(spacing: 14) {
                profileAvatar(size: 72)
                EditableProfileAvatarPicker(
                    avatarImageData: editableAvatarImageData,
                    fallbackEmoji: avatarEmoji.isEmpty ? fallbackEmoji : avatarEmoji,
                    accentColor: tint,
                    cropSpecies: pet == nil ? "" : species,
                    silhouetteSystemName: human == nil ? nil : "person.fill"
                )
            }
        }
    }

    private var petEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: l.tr(zh: "名字", en: "Name", de: "Name"), text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorMenuRow(title: l.tr(zh: "物种", en: "Species", de: "Art"), icon: "pawprint.fill", selection: $species, options: speciesOptions)
            CrewRosterEditorTextField(title: l.tr(zh: "品种", en: "Breed", de: "Rasse"), text: $breed, icon: "tag.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(title: l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), selection: $gender, options: [
                ("male", l.tr(zh: "男孩", en: "Boy", de: "Junge")),
                ("female", l.tr(zh: "女孩", en: "Girl", de: "Maedchen")),
                ("unknown", l.tr(zh: "未知", en: "Unknown", de: "Unbekannt"))
            ])
            CrewRosterEditorToggleRow(title: l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"), icon: "checkmark.seal.fill", isOn: $isNeutered)
            CrewRosterEditorDateToggleRow(title: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorDateToggleRow(title: l.tr(zh: "到家日", en: "Home date", de: "Einzugstag"), icon: "house.fill", isOn: $hasHomeDate, date: $homeDate)
            CrewRosterThemeSwatchRow(title: l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), selectedHex: $themeHex)
            CrewRosterEditorTextField(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private var humanEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: l.tr(zh: "名字", en: "Name", de: "Name"), text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: l.tr(zh: "头像 Emoji", en: "Avatar emoji", de: "Avatar-Emoji"), text: $avatarEmoji, icon: "face.smiling") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(title: l.tr(zh: "权限", en: "Role", de: "Rolle"), selection: $role, options: [
                ("owner", localizedRoleText(for: "owner")),
                ("member", localizedRoleText(for: "member"))
            ])
            CrewRosterEditorMenuRow(
                title: l.tr(zh: "性别/身份", en: "Gender / identity", de: "Geschlecht / Identitaet"),
                icon: "person.fill",
                selection: $gender,
                options: HumanProfileOptions.genderOptions.map(\.key),
                optionTitle: { l.humanGenderDisplay($0) }
            )
            CrewRosterEditorDateToggleRow(title: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorMenuRow(
                title: l.tr(zh: "血型", en: "Blood type", de: "Blutgruppe"),
                icon: "drop.fill",
                selection: $bloodType,
                options: bloodTypeOptions
            )
            CrewRosterEditorTextField(title: l.tr(zh: "身高 cm", en: "Height cm", de: "Groesse cm"), text: $heightText, icon: "ruler.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorMenuRow(title: "MBTI", icon: "brain.head.profile", selection: $mbti, options: mbtiOptions)
            CrewRosterEditorTextField(title: l.tr(zh: "国籍", en: "Nationality", de: "Nationalitaet"), text: $nationality, icon: "globe.asia.australia.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: l.tr(zh: "现居地", en: "Current city", de: "Aktueller Ort"), text: $city, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterThemeSwatchRow(title: l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), selectedHex: $themeHex)
            CrewRosterEditorTextField(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private var plantEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: l.tr(zh: "名字", en: "Name", de: "Name"), text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: l.tr(zh: "品种", en: "Species", de: "Art"), text: $species, icon: "leaf.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: l.tr(zh: "位置", en: "Location", de: "Standort"), text: $location, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorStepperRow(title: l.tr(zh: "浇水间隔", en: "Watering interval", de: "Giessintervall"), icon: "drop.fill", value: $wateringDays, range: 1 ... 60, unit: l.tr(zh: "天", en: "days", de: "Tage"))
            CrewRosterEditorStepperRow(title: l.tr(zh: "施肥间隔", en: "Fertilizing interval", de: "Duengeintervall"), icon: "sparkles", value: $fertilizingDays, range: 1 ... 120, unit: l.tr(zh: "天", en: "days", de: "Tage"))
            CrewRosterThemeSwatchRow(title: l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), selectedHex: $themeHex)
            CrewRosterEditorTextField(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private func petLifecycleSection(_ pet: Pet) -> some View {
        profileSection(l.tr(zh: "生命与危险操作", en: "Life & danger actions", de: "Leben & riskante Aktionen"), icon: "exclamationmark.triangle.fill") {
            if pet.hasPassedAway {
                infoRow(l.tr(zh: "离世日期", en: "Passed-away date", de: "Sterbedatum"), formattedDate(pet.passedAwayDate))
                secondaryButton(l.tr(zh: "撤销离世标记", en: "Undo passed-away mark", de: "Verstorben-Markierung rueckgaengig machen"), icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingPetUndoPassedAlert = true
                }
            } else {
                DatePicker(l.tr(zh: "离世日期", en: "Passed-away date", de: "Sterbedatum"), selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton(l.tr(zh: "标记离世", en: "Mark as passed away", de: "Als verstorben markieren"), icon: "rainbow", color: Color.goPurple) {
                    showingPetPassedAlert = true
                }
            }
            secondaryButton(l.tr(zh: "仅清空所有记录", en: "Clear records only", de: "Nur Eintraege loeschen"), icon: "eraser.fill", color: Color.goOrange) {
                showingPetClearAlert = true
            }
            destructiveButton(l.tr(zh: "彻底删除 \(pet.name)", en: "Delete \(pet.name) permanently", de: "\(pet.name) endgueltig loeschen"), icon: "trash.fill", color: Color.goRed) {
                showingPetDeleteSheet = true
            }
        }
    }

    private func humanLifecycleSection(_ human: Human) -> some View {
        profileSection(l.tr(zh: "生命与危险操作", en: "Life & danger actions", de: "Leben & riskante Aktionen"), icon: "exclamationmark.triangle.fill") {
            if human.hasPassedAway {
                infoRow(l.tr(zh: "纪念日期", en: "Memorial date", de: "Gedenkdatum"), formattedDate(human.passedAwayDate))
                secondaryButton(l.tr(zh: "撤销纪念模式", en: "Undo memorial mode", de: "Gedenkmodus zuruecknehmen"), icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingHumanUndoPassedAlert = true
                }
            } else {
                DatePicker(l.tr(zh: "纪念日期", en: "Memorial date", de: "Gedenkdatum"), selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton(l.tr(zh: "标记纪念模式", en: "Mark memorial mode", de: "Gedenkmodus markieren"), icon: "sparkles", color: Color.goPurple) {
                    showingHumanPassedAlert = true
                }
            }
            destructiveButton(l.tr(zh: "删除成员", en: "Delete member", de: "Mitglied loeschen"), icon: "trash.fill", color: Color.goRed) {
                showingHumanDeleteSheet = true
            }
        }
    }

    private func profileSection(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite.opacity(0.88))
                Spacer(minLength: 0)
            }
            VStack(spacing: 9) { content() }
        }
        .padding(13)
        .background(Color.goCardWhite.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.54))
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.88))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.goCardWhite.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func secondaryButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func destructiveButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        secondaryButton(title, icon: icon, color: color, action: action)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        if let pet {
            if isEditing {
                PetAvatarPortraitView(
                    imageData: avatarImageData,
                    fallbackText: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
                    themeColor: tint,
                    size: size,
                    backgroundOpacity: 0.25,
                    transparentScale: 0.78
                )
            } else {
                PetAvatarPortraitView(
                    pet: pet,
                    fallbackText: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
                    themeColor: tint,
                    size: size,
                    backgroundOpacity: 0.25,
                    transparentScale: 0.78
                )
            }
        } else if human != nil {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: size, height: size)
                if let image = preparedHumanAvatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: max(0, size - 6), height: max(0, size - 6))
                        .clipShape(Circle())
                } else {
                    Text(selectedHumanAvatarFallback)
                        .font(.system(size: size * 0.42))
                }
            }
            .frame(width: size, height: size)
        } else if let plant {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: size, height: size)
                Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
                    .font(.system(size: size * 0.45))
            }
        }
    }

    private var displayName: String {
        if isEditing, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        return pet?.name ?? human?.name ?? plant?.name ?? card.name
    }

    private var fallbackEmoji: String {
        pet?.avatarEmoji ?? human?.avatarEmoji ?? plant?.avatarEmoji ?? "👤"
    }

    private var selectedHumanAvatarData: Data? {
        guard let human else { return nil }
        return isEditing ? avatarImageData : human.avatarImageData
    }

    private var selectedHumanAvatarFallback: String {
        let value = isEditing ? avatarEmoji : (human?.avatarEmoji ?? "")
        return value.isEmpty ? "👤" : value
    }

    private var editableAvatarImageData: Binding<Data?> {
        Binding(
            get: { avatarImageData },
            set: { newValue in
                avatarImageData = newValue
                avatarImageRevision &+= 1
            }
        )
    }

    private var preparedHumanAvatarImage: UIImage? {
        guard let human, !humanAvatarSignature.isEmpty else { return nil }
        return avatarPipeline.cachedImage(for: human.id, signature: humanAvatarSignature)
    }

    private var humanAvatarSourceKey: String {
        guard let human else { return "crew-roster-profile-human-avatar-none" }
        if isEditing {
            return "\(human.id.uuidString):editing:\(avatarImageRevision)"
        }
        let signature = human.hasAvatarImageAttachment ? human.avatarThumbnailSignature : "empty"
        return "\(human.id.uuidString):view:\(signature)"
    }

    private func emptyText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedEmptyValue : value
    }

    private func formattedDate(_ date: Date?) -> String {
        date?.formatted(.dateTime.year().month().day()) ?? localizedEmptyValue
    }

    private func localizedDays(_ days: Int) -> String {
        l.tr(zh: "\(days) 天", en: "\(days) days", de: "\(days) Tage")
    }

    private func petGenderSummary(_ pet: Pet) -> String {
        guard pet.isNeutered else { return pet.genderSymbol }
        return "\(pet.genderSymbol) · \(l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"))"
    }

    private func privacySummary(for human: Human) -> String {
        guard HumanLocalPrivacyPolicy.isEnabled else {
            return l.tr(zh: "首发未启用", en: "Not enabled in first release", de: "Zum Start nicht aktiviert")
        }
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(localizedPrivateFieldTitle)
        return titles.isEmpty ? l.tr(zh: "全部公开", en: "All public", de: "Alles oeffentlich") : titles.joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    private var localizedEmptyValue: String {
        l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? localizedEmptyValue : title
    }

    private func localizedHumanAge(_ human: Human) -> String {
        let referenceDate = human.passedAwayDate ?? Date()
        guard let birthday = human.birthday else { return l.tr(zh: "未知", en: "Unknown", de: "Unbekannt") }
        let years = max(0, Calendar.current.dateComponents([.year], from: birthday, to: referenceDate).year ?? 0)
        if years >= 1 {
            return l.tr(zh: "\(years)岁", en: "\(years) years old", de: "\(years) Jahre alt")
        }
        return l.tr(zh: "不满1岁", en: "Under 1", de: "Unter 1")
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
            l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermoegen & Wuensche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }

    private func loadEditState(includeAvatarData: Bool) {
        if let pet {
            name = pet.name
            avatarImageData = includeAvatarData ? pet.avatarImageData : nil
            avatarImageRevision &+= 1
            avatarEmoji = pet.avatarEmoji
            species = pet.species.isEmpty ? "其他" : pet.species
            breed = pet.breed
            gender = pet.gender.isEmpty ? "unknown" : pet.gender
            isNeutered = pet.isNeutered
            hasBirthday = pet.birthday != nil
            birthday = pet.birthday ?? Date()
            hasHomeDate = pet.homeDate != nil
            homeDate = pet.homeDate ?? Date()
            themeHex = pet.safeThemeColorHex
            notes = pet.notes
            passedDate = pet.passedAwayDate ?? Date()
        } else if let human {
            name = human.name
            avatarImageData = includeAvatarData ? human.avatarImageData : nil
            avatarImageRevision &+= 1
            avatarEmoji = human.avatarEmoji
            role = HumanProfileOptions.normalizedRole(human.role)
            gender = HumanProfileOptions.normalizedGender(human.genderRaw)
            hasBirthday = human.birthday != nil
            birthday = human.birthday ?? Date()
            bloodType = human.bloodType.isEmpty ? "未填写" : human.bloodType
            heightText = human.heightCm > 0 ? "\(Int(human.heightCm))" : ""
            mbti = human.mbti.isEmpty ? "未填写" : human.mbti.uppercased()
            nationality = human.nationality
            city = human.city
            themeHex = human.safeThemeColorHex
            notes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            passedDate = human.passedAwayDate ?? Date()
        } else if let plant {
            name = plant.name
            avatarImageData = includeAvatarData ? plant.avatarImageData : nil
            avatarImageRevision &+= 1
            avatarEmoji = plant.avatarEmoji
            species = plant.species
            location = plant.location
            wateringDays = plant.wateringIntervalDays
            fertilizingDays = plant.fertilizingIntervalDays
            themeHex = plant.themeColorHex
            notes = plant.notes
        }
    }

    private func saveChanges() {
        if let pet {
            let input = PetProfileCommandInput(
                name: name,
                avatarImageData: avatarImageData,
                species: species,
                breed: breed,
                gender: gender,
                isNeutered: isNeutered,
                birthday: hasBirthday ? birthday : nil,
                homeDate: hasHomeDate ? homeDate : nil,
                themeHex: themeHex,
                notes: notes
            )
            commandQueue.enqueue(.memberProfile(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
                let result = MemberCommandExecutor(context: modelContext, services: appServices).updatePetProfile(
                    pet,
                    input: input,
                    note: "crew.member.profile.pet"
                )
                guard result.didPersist else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                warmAvatarCache(id: result.entityID, data: result.persistedAvatarImageData)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(GoMotion.feedback) { isEditing = false }
                onSaved(result.entityID, result.kind)
            }
        } else if let human {
            let preservedNoteParts = human.notes
                .split(separator: "｜")
                .map(String.init)
                .filter { $0.hasPrefix("关系:") }
            let input = HumanProfileCommandInput(
                name: name,
                avatarImageData: avatarImageData,
                avatarEmoji: avatarEmoji,
                role: role,
                gender: gender,
                birthday: hasBirthday ? birthday : nil,
                bloodType: bloodType,
                heightText: heightText,
                mbti: mbti,
                nationality: nationality,
                city: city,
                themeHex: themeHex,
                notes: notes,
                preservedNoteParts: preservedNoteParts
            )
            commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
                let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                    human,
                    input: input,
                    note: "crew.member.profile.human"
                )
                guard result.didPersist else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                warmAvatarCache(id: result.entityID, data: result.persistedAvatarImageData)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(GoMotion.feedback) { isEditing = false }
                onSaved(result.entityID, result.kind)
            }
        } else if let plant {
            let input = PlantProfileCommandInput(
                name: name,
                avatarImageData: avatarImageData,
                avatarEmoji: avatarEmoji,
                species: species,
                location: location,
                wateringIntervalDays: wateringDays,
                fertilizingIntervalDays: fertilizingDays,
                potDiameterCm: plant.potDiameterCm,
                potMaterialRaw: plant.potMaterialRaw,
                soilTypeRaw: plant.soilTypeRaw,
                isIndoor: plant.isIndoor,
                windowDirection: plant.windowDirection,
                lightLevel: plant.lightLevel,
                healthStatus: plant.healthStatus,
                catalogSpeciesId: plant.catalogSpeciesId,
                isToxicToCats: plant.isToxicToCats,
                isToxicToDogs: plant.isToxicToDogs,
                isToxicToChildren: plant.isToxicToChildren,
                isIndoorSuitable: plant.isIndoorSuitable,
                remindersEnabled: plant.remindersEnabled,
                themeHex: themeHex,
                notes: notes
            )
            commandQueue.enqueue(.memberProfile(entityID: plant.id, kind: EntityKind.plant.rawValue)) {
                let result = MemberCommandExecutor(context: modelContext, services: appServices).updatePlantProfile(
                    plant,
                    input: input,
                    note: "crew.member.profile.plant"
                )
                guard result.didPersist else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                warmAvatarCache(id: result.entityID, data: result.persistedAvatarImageData)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(GoMotion.feedback) { isEditing = false }
                onSaved(result.entityID, result.kind)
            }
        }
    }

    private func markPetPassedAway() {
        guard let pet else { return }
        commandQueue.enqueue(.memberLifecycle(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "passed.mark")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markPetPassedAway(
                pet,
                date: passedDate,
                note: "crew.member.lifecycle.pet.passed.mark"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(result.entityID, result.kind)
        }
    }

    private func undoPetPassedAway() {
        guard let pet else { return }
        commandQueue.enqueue(.memberLifecycle(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "passed.undo")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoPetPassedAway(
                pet,
                note: "crew.member.lifecycle.pet.passed.undo"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(result.entityID, result.kind)
        }
    }

    private func clearPetActivityRecords() {
        guard let pet else { return }
        commandQueue.enqueue(.memberLifecycle(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "records.clear")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).clearPetActivityRecords(
                pet,
                note: "crew.member.lifecycle.pet.records.clear"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(result.entityID, result.kind)
        }
    }

    private func markHumanPassedAway() {
        guard let human else { return }
        commandQueue.enqueue(.memberLifecycle(entityID: human.id, kind: EntityKind.human.rawValue, action: "passed.mark")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: passedDate,
                note: "crew.member.lifecycle.human.passed.mark"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(result.entityID, result.kind)
        }
    }

    private func undoHumanPassedAway() {
        guard let human else { return }
        commandQueue.enqueue(.memberLifecycle(entityID: human.id, kind: EntityKind.human.rawValue, action: "passed.undo")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "crew.member.lifecycle.human.passed.undo"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(result.entityID, result.kind)
        }
    }

    @MainActor
    private func prepareHumanAvatar() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        guard let human, let data = selectedHumanAvatarData else {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
            humanAvatarSignature = ""
            humanAvatarCacheKey = "crew-roster-profile-human-avatar-empty"
            return
        }

        let signature = FocusWalletAvatarCache.signature(for: data)
        let nextKey = "crew-roster-profile-human-avatar-\(human.id.uuidString)-\(signature)"
        if humanAvatarCacheKey != nextKey {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
            humanAvatarCacheKey = nextKey
        }
        humanAvatarSignature = signature
        let payload = FocusWalletAvatarCache.Payload(id: human.id, data: data)
        avatarPipeline.seedPreviewEntries([payload], key: nextKey)
        avatarPipeline.preload(
            payloads: [payload],
            key: nextKey,
            delayMilliseconds: 48
        )
    }

    private func warmAvatarCache(id: UUID, data: Data?) {
        let payload = FocusWalletAvatarCache.Payload(id: id, data: data)
        let key = "crew-roster-profile-avatar-save-\(id.uuidString)-\(data?.count ?? 0)"
        avatarPipeline.seedPreviewEntries([payload], key: key)
        avatarPipeline.preload(
            payloads: [payload],
            key: key,
            delayMilliseconds: 48
        )
    }

    private func deletePetWithCascade() {
        guard let pet else { return }
        let command = DomainCommand.memberDeletion(entityID: pet.id, kind: EntityKind.pet.rawValue)
        showingPetDeleteSheet = false
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePet(
                pet,
                note: "crew.member.deleted.pet"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
            if result.didPersist {
                onDeleted()
            }
        }
    }

    private func deleteHumanAndReturnHome() {
        guard let human else { return }
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: human.id, kind: EntityKind.human.rawValue)
        showingHumanDeleteSheet = false
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                human,
                activeHumanID: activeHumanID,
                note: "crew.member.deleted.human"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            onDeleted()
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
        }
    }
}
