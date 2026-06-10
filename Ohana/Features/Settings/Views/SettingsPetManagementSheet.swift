import SwiftData
import SwiftUI

struct SettingsPetManagementSheet: View {
    let pets: [Pet]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var showingDeletePetAlert = false
    @State private var petToDelete: Pet? = nil
    @State private var deleteConfirmName = ""
    @State private var showingResetPetData = false
    @State private var petToReset: Pet? = nil

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerLine: Color { Color.ohanaDivider }

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
        .alert("删除 \(petToDelete?.name ?? "")", isPresented: $showingDeletePetAlert) {
            TextField("输入宠物名字确认", text: $deleteConfirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            Button("取消", role: .cancel) {
                petToDelete = nil
                deleteConfirmName = ""
            }
            Button("删除", role: .destructive) {
                deleteSelectedPetIfConfirmed()
            }
        } message: {
            let name = petToDelete?.name ?? ""
            Text("请输入「\(name)」确认删除。此操作不可撤销。")
        }
        .alert("重置 \(petToReset?.name ?? "") 的数据", isPresented: $showingResetPetData) {
            Button("取消", role: .cancel) { petToReset = nil }
            Button("重置记录", role: .destructive) {
                if let pet = petToReset {
                    resetPetLogs(pet)
                }
                petToReset = nil
            }
        } message: {
            Text("将清除该宠物所有日志记录（体重、花费、健康、护理、遛狗、噗噗等），基础信息保留。此操作不可撤销。")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("宠物管理")
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(primaryText)
                Text("重置记录或删除成员")
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
                Text("成员")
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
                petActionPill("重置", color: Color.goYellow)
            }
            .buttonStyle(ScaleButtonStyle())
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                petToDelete = pet
                deleteConfirmName = ""
                showingDeletePetAlert = true
            } label: {
                petActionPill("删除", color: Color.goRed)
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
