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
    let onChange: (Bool) -> Bool

    @State private var visualOverride: Bool?

    private var visualIsOn: Bool {
        visualOverride ?? isOn
    }

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
        .accessibilityValue(visualIsOn ? "开启" : "关闭")
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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
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
        .onAppear(perform: loadEditState)
        .task(id: humanAvatarSourceKey) {
            await prepareHumanAvatar()
        }
        .onDisappear {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
        }
        .alert("确认标记离世", isPresented: $showingPetPassedAlert) {
            Button("确认", role: .destructive) {
                markPetPassedAway()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将进入纪念模式，并让未来照护安排退出活跃提醒。原有数据会保留，此操作可撤销。")
        }
        .alert("撤销离世标记", isPresented: $showingPetUndoPassedAlert) {
            Button("撤销", role: .destructive) {
                undoPetPassedAway()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除离世日期，恢复为在世状态。")
        }
        .alert("仅清空所有记录", isPresented: $showingPetClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空记录", role: .destructive) {
                clearPetActivityRecords()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } message: {
            Text("将删除护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录；保留名字、头像、品种与证件/保险档案。此操作不可撤销。")
        }
        .alert("确认标记纪念模式", isPresented: $showingHumanPassedAlert) {
            Button("确认", role: .destructive) {
                markHumanPassedAway()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把该成员设为纪念模式。")
        }
        .alert("撤销纪念模式", isPresented: $showingHumanUndoPassedAlert) {
            Button("撤销", role: .destructive) {
                undoHumanPassedAway()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除该成员的纪念模式日期。")
        }
        .alert("确认删除植物", isPresented: $showingPlantDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let plant else { return }
                MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                    plant,
                    note: "crew.member.deleted.plant"
                )
                onDeleted()
            }
        } message: {
            Text("确定要删除 \(plant?.name ?? "这株植物") 吗？")
        }
        .sheet(isPresented: $showingPetDeleteSheet) {
            CrewRosterDeleteConfirmationSheet(
                title: "彻底删除 \(pet?.name ?? "宠物")",
                name: pet?.name ?? "",
                warning: "这会删除宠物和所有关联记录，无法撤销。",
                onCancel: { showingPetDeleteSheet = false },
                onDelete: deletePetWithCascade
            )
            .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        }
        .sheet(isPresented: $showingHumanDeleteSheet) {
            CrewRosterDeleteConfirmationSheet(
                title: "删除成员 \(human?.name ?? "")",
                name: human?.name ?? "",
                warning: "这会删除成员资料、体重与运动记录，无法撤销。",
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
                    loadEditState()
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
            .accessibilityLabel(isEditing ? "保存" : "编辑")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(isEditing ? "编辑基本信息" : "基本信息")
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
            .accessibilityLabel("关闭")
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
            profileSection("身份", icon: "pawprint.fill") {
                infoRow("物种", emptyText(pet.species))
                infoRow("品种", emptyText(pet.breed))
                infoRow("年龄", pet.hasPassedAway ? pet.ageAtPassingText : pet.ageText)
                infoRow("性别", pet.genderSymbol + (pet.isNeutered ? " · 已绝育" : ""))
                infoRow("主题色", "#\(pet.safeThemeColorHex.uppercased())")
            }
            profileSection("照护", icon: "heart.fill") {
                infoRow("生日", formattedDate(pet.birthday))
                infoRow("到家日", formattedDate(pet.homeDate))
                infoRow("陪伴", pet.hasPassedAway ? "\(pet.daysTogetherAtPassing) 天" : "\(pet.daysTogether) 天")
                infoRow("主粮", emptyText(pet.foodBrand))
                infoRow("粮仓", pet.restockWeight > 0 ? "\(Int(pet.restockWeight)) g" : "未填写")
            }
            profileSection("保障", icon: "cross.case.fill") {
                infoRow("芯片号", emptyText(pet.microchipID))
                infoRow("医院", emptyText(pet.vetClinicName))
                infoRow("医生", emptyText(pet.vetDoctorName))
                infoRow("电话", emptyText(pet.vetContact))
                infoRow("过敏", emptyText(pet.allergies))
                infoRow("证件", "\(petSummary.documentCount)")
            }
            if !pet.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(pet.notes) }
            }
            petLifecycleSection(pet)
        }
    }

    private func humanReadContent(_ human: Human) -> some View {
        VStack(spacing: 12) {
            profileSection("身份", icon: "person.fill") {
                infoRow("权限", HumanPermissionRole.title(for: human.role))
                infoRow("年龄", human.hasPassedAway ? human.ageAtPassingText : human.ageText)
                infoRow("性别/身份", HumanGenderIdentity.title(for: human.genderRaw))
                infoRow("生日", formattedDate(human.birthday))
                infoRow("星座", human.birthday.map { Human.westernZodiacChinese(for: $0) } ?? "未填写")
            }
            profileSection("身体", icon: "heart.text.square.fill") {
                infoRow("血型", emptyText(human.bloodType))
                infoRow("身高", human.heightCm > 0 ? "\(Int(human.heightCm)) cm" : "未填写")
                infoRow("MBTI", human.mbti.isEmpty ? "未填写" : human.mbti.uppercased())
            }
            profileSection("家庭与显示", icon: "house.fill") {
                infoRow("国籍", emptyText(human.nationality))
                infoRow("现居地", emptyText(human.city))
                infoRow("首页显示", human.shouldShowOnHome ? "显示" : "隐藏")
                infoRow("隐私项目", privacySummary(for: human))
            }
            let humanNotes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            if !humanNotes.isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(humanNotes) }
            }
            humanLifecycleSection(human)
        }
    }

    private func plantReadContent(_ plant: Plant) -> some View {
        VStack(spacing: 12) {
            profileSection("植物", icon: "leaf.fill") {
                infoRow("品种", emptyText(plant.species))
                infoRow("位置", emptyText(plant.location))
                infoRow("浇水间隔", "\(plant.wateringIntervalDays) 天")
                infoRow("施肥间隔", "\(plant.fertilizingIntervalDays) 天")
                infoRow("上次浇水", formattedDate(plant.lastWateredDate))
                infoRow("上次施肥", formattedDate(plant.lastFertilizedDate))
            }
            if !plant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(plant.notes) }
            }
            destructiveButton("删除植物", icon: "trash.fill", color: Color.goRed) {
                showingPlantDeleteAlert = true
            }
        }
    }

    private var profileEditAvatar: some View {
        profileSection("头像", icon: "person.crop.square.fill") {
            HStack(spacing: 14) {
                profileAvatar(size: 72)
                EditableProfileAvatarPicker(
                    avatarImageData: $avatarImageData,
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
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorMenuRow(title: "物种", icon: "pawprint.fill", selection: $species, options: speciesOptions)
            CrewRosterEditorTextField(title: "品种", text: $breed, icon: "tag.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(title: "性别", selection: $gender, options: [("male", "男孩"), ("female", "女孩"), ("unknown", "未知")])
            CrewRosterEditorToggleRow(title: "已绝育", icon: "checkmark.seal.fill", isOn: $isNeutered)
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorDateToggleRow(title: "到家日", icon: "house.fill", isOn: $hasHomeDate, date: $homeDate)
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private var humanEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "头像 Emoji", text: $avatarEmoji, icon: "face.smiling") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(title: "权限", selection: $role, options: [("owner", "管理者"), ("member", "成员")])
            CrewRosterEditorMenuRow(title: "性别/身份", icon: "person.fill", selection: $gender, options: HumanProfileOptions.genderOptions.map(\.key))
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorMenuRow(title: "血型", icon: "drop.fill", selection: $bloodType, options: bloodTypeOptions)
            CrewRosterEditorTextField(title: "身高 cm", text: $heightText, icon: "ruler.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorMenuRow(title: "MBTI", icon: "brain.head.profile", selection: $mbti, options: mbtiOptions)
            CrewRosterEditorTextField(title: "国籍", text: $nationality, icon: "globe.asia.australia.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "现居地", text: $city, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private var plantEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "品种", text: $species, icon: "leaf.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "位置", text: $location, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorStepperRow(title: "浇水间隔", icon: "drop.fill", value: $wateringDays, range: 1 ... 60, unit: "天")
            CrewRosterEditorStepperRow(title: "施肥间隔", icon: "sparkles", value: $fertilizingDays, range: 1 ... 120, unit: "天")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
    }

    private func petLifecycleSection(_ pet: Pet) -> some View {
        profileSection("生命与危险操作", icon: "exclamationmark.triangle.fill") {
            if pet.hasPassedAway {
                infoRow("离世日期", formattedDate(pet.passedAwayDate))
                secondaryButton("撤销离世标记", icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingPetUndoPassedAlert = true
                }
            } else {
                DatePicker("离世日期", selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton("标记离世", icon: "rainbow", color: Color.goPurple) {
                    showingPetPassedAlert = true
                }
            }
            secondaryButton("仅清空所有记录", icon: "eraser.fill", color: Color.goOrange) {
                showingPetClearAlert = true
            }
            destructiveButton("彻底删除 \(pet.name)", icon: "trash.fill", color: Color.goRed) {
                showingPetDeleteSheet = true
            }
        }
    }

    private func humanLifecycleSection(_ human: Human) -> some View {
        profileSection("生命与危险操作", icon: "exclamationmark.triangle.fill") {
            if human.hasPassedAway {
                infoRow("纪念日期", formattedDate(human.passedAwayDate))
                secondaryButton("撤销纪念模式", icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingHumanUndoPassedAlert = true
                }
            } else {
                DatePicker("纪念日期", selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton("标记纪念模式", icon: "sparkles", color: Color.goPurple) {
                    showingHumanPassedAlert = true
                }
            }
            destructiveButton("删除成员", icon: "trash.fill", color: Color.goRed) {
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
            PetAvatarPortraitView(
                imageData: isEditing ? avatarImageData : pet.avatarImageData,
                fallbackText: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
                themeColor: tint,
                size: size,
                backgroundOpacity: 0.25,
                transparentScale: 0.78
            )
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

    private var preparedHumanAvatarImage: UIImage? {
        guard let human, !humanAvatarSignature.isEmpty else { return nil }
        return avatarPipeline.cachedImage(for: human.id, signature: humanAvatarSignature)
    }

    private var humanAvatarSourceKey: String {
        guard let human else { return "crew-roster-profile-human-avatar-none" }
        let dataCount = selectedHumanAvatarData?.count ?? 0
        return "\(human.id.uuidString):\(isEditing):\(dataCount)"
    }

    private func emptyText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写" : value
    }

    private func formattedDate(_ date: Date?) -> String {
        date?.formatted(.dateTime.year().month().day()) ?? "未填写"
    }

    private func privacySummary(for human: Human) -> String {
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(\.title)
        return titles.isEmpty ? "全部公开" : titles.joined(separator: "、")
    }

    private func loadEditState() {
        if let pet {
            name = pet.name
            avatarImageData = pet.avatarImageData
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
            avatarImageData = human.avatarImageData
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
            avatarImageData = plant.avatarImageData
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
                warmAvatarCache(id: result.entityID, data: input.avatarImageData)
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
                warmAvatarCache(id: result.entityID, data: input.avatarImageData)
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
                warmAvatarCache(id: result.entityID, data: input.avatarImageData)
                onSaved(result.entityID, result.kind)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(GoMotion.feedback) { isEditing = false }
    }

    private func markPetPassedAway() {
        guard let pet else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(.memberLifecycle(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "passed.mark")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markPetPassedAway(
                pet,
                date: passedDate,
                note: "crew.member.lifecycle.pet.passed.mark"
            )
            onSaved(result.entityID, result.kind)
        }
    }

    private func undoPetPassedAway() {
        guard let pet else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(.memberLifecycle(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "passed.undo")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoPetPassedAway(
                pet,
                note: "crew.member.lifecycle.pet.passed.undo"
            )
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
            onSaved(result.entityID, result.kind)
        }
    }

    private func markHumanPassedAway() {
        guard let human else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(.memberLifecycle(entityID: human.id, kind: EntityKind.human.rawValue, action: "passed.mark")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: passedDate,
                note: "crew.member.lifecycle.human.passed.mark"
            )
            onSaved(result.entityID, result.kind)
        }
    }

    private func undoHumanPassedAway() {
        guard let human else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(.memberLifecycle(entityID: human.id, kind: EntityKind.human.rawValue, action: "passed.undo")) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "crew.member.lifecycle.human.passed.undo"
            )
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
        avatarPipeline.seedPreviewEntries([payload])
        avatarPipeline.preload(
            payloads: [payload],
            key: nextKey,
            delayMilliseconds: 48
        )
    }

    private func warmAvatarCache(id: UUID, data: Data?) {
        let payload = FocusWalletAvatarCache.Payload(id: id, data: data)
        avatarPipeline.seedPreviewEntries([payload])
        avatarPipeline.preload(
            payloads: [payload],
            key: "crew-roster-profile-avatar-save-\(id.uuidString)-\(data?.count ?? 0)",
            delayMilliseconds: 48
        )
    }

    private func deletePetWithCascade() {
        guard let pet else { return }
        let command = DomainCommand.memberDeletion(entityID: pet.id, kind: EntityKind.pet.rawValue)
        showingPetDeleteSheet = false
        onDeleted()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            MemberCommandExecutor(context: modelContext, services: appServices).deletePet(
                pet,
                note: "crew.member.deleted.pet"
            )
        }
    }

    private func deleteHumanAndReturnHome() {
        guard let human else { return }
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: human.id, kind: EntityKind.human.rawValue)
        showingHumanDeleteSheet = false
        onDeleted()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                human,
                activeHumanID: activeHumanID,
                note: "crew.member.deleted.human"
            )
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
