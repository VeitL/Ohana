import SwiftData
import SwiftUI

struct SettingsPetManagementSheet: View {
    let pets: [Pet]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var showingDeletePetAlert = false
    @State private var petToDelete: Pet? = nil
    @State private var deleteConfirmName = ""
    @State private var showingResetPetData = false
    @State private var petToReset: Pet? = nil

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerLine: Color { Color.ohanaDivider }
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaStaticAppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        header
                        petList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert(l.tr(zh: "删除 \(petToDelete?.name ?? "")", en: "Delete \(petToDelete?.name ?? "")", de: "\(petToDelete?.name ?? "") löschen"), isPresented: $showingDeletePetAlert) {
            TextField(l.tr(zh: "输入宠物名字确认", en: "Enter pet name to confirm", de: "Tiernamen zur Bestätigung eingeben"), text: $deleteConfirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                petToDelete = nil
                deleteConfirmName = ""
            }
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                deleteSelectedPetIfConfirmed()
            }
        } message: {
            let name = petToDelete?.name ?? ""
            Text(l.tr(
                zh: "请输入「\(name)」确认删除。删除后可在回收站中保留 30 天。",
                en: "Enter \"\(name)\" to confirm. Deleted pets stay recoverable for 30 days.",
                de: "Gib „\(name)“ zur Bestätigung ein. Gelöschte Tiere bleiben 30 Tage wiederherstellbar."
            ))
        }
        .alert(l.tr(zh: "重置 \(petToReset?.name ?? "") 的数据", en: "Reset \(petToReset?.name ?? "")'s data", de: "Daten von \(petToReset?.name ?? "") zurücksetzen"), isPresented: $showingResetPetData) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { petToReset = nil }
            Button(l.tr(zh: "重置记录", en: "Reset Records", de: "Einträge zurücksetzen"), role: .destructive) {
                if let pet = petToReset {
                    resetPetLogs(pet)
                }
                petToReset = nil
            }
        } message: {
            Text(l.tr(
                zh: "将清除该宠物所有日志记录（体重、花费、健康、护理、遛狗、噗噗等），基础信息保留。清除记录会在回收站中保留 30 天。",
                en: "All logs for this pet will be cleared, including weight, expenses, health, care, walks, and potty logs. Basic profile details stay. Cleared records remain recoverable for 30 days.",
                de: "Alle Protokolle dieses Tiers werden geleert, darunter Gewicht, Ausgaben, Gesundheit, Pflege, Spaziergänge und Toiletteneinträge. Basisdaten bleiben erhalten. Geleerte Einträge bleiben 30 Tage wiederherstellbar."
            ))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "宠物管理", en: "Pet Management", de: "Tierverwaltung"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "重置记录或删除成员", en: "Reset records or delete members", de: "Einträge zurücksetzen oder Mitglieder löschen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(primaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var petList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: OhanaRadius.hairline, style: .continuous)
                    .fill(Color.goPrimary)
                    .frame(width: 3, height: 14) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(l.tr(zh: "成员", en: "Members", de: "Mitglieder"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(tertiaryText)
                    .tracking(1.2)
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                    if index > 0 {
                        OhanaDashedDivider(color: dividerLine)
                            .padding(.leading, 44)
                    }
                    petRow(pet)
                }
            }
            .padding(14)
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
    }

    private func petRow(_ pet: Pet) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(pet.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 16)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            Text(pet.name)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
            Spacer()
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                petToReset = pet
                showingResetPetData = true
            } label: {
                petActionPill(l.tr(zh: "重置", en: "Reset", de: "Zurücksetzen"), color: Color.goYellow)
            }
            .buttonStyle(ScaleButtonStyle())
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                petToDelete = pet
                deleteConfirmName = ""
                showingDeletePetAlert = true
            } label: {
                petActionPill(l.tr(zh: "删除", en: "Delete", de: "Löschen"), color: Color.goRed)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(minHeight: 48)
    }

    private func petActionPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(color.opacity(0.86))
            .frame(minHeight: 34)
            .padding(.horizontal, 10)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func deleteSelectedPetIfConfirmed() {
        guard let pet = petToDelete,
              ConfirmationNameMatcher.matches(deleteConfirmName, expectedName: pet.name) else {
            deleteConfirmName = ""
            return
        }

        MemberCommandExecutor(context: modelContext, services: appServices).deletePet(
            pet,
            note: "settings.pet.deleted"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        petToDelete = nil
        deleteConfirmName = ""
    }

    private func resetPetLogs(_ pet: Pet) {
        MemberCommandExecutor(context: modelContext, services: appServices).clearPetActivityRecords(
            pet,
            note: "settings.pet.lifecycle.records.clear"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
