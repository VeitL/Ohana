//
//  PetCardBackSettingsSheet.swift
//  Ohana
//
//  卡片背面齿轮按钮打开的设置菜单
//

import SwiftData
import SwiftUI

struct PetCardBackSettingsSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showEditPet = false
    @State private var showSitterCard = false

    @State private var showRainbowAlert = false
    @State private var rainbowDate = Date()
    @State private var showUndoPassingAlert = false

    @State private var showClearConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteNameInput = ""

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    var body: some View {
        NavigationStack {
            List {
                petInfoSection
                rainbowSection
                dangerSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditPet) { EditPetSheet(pet: pet) }
            .sheet(isPresented: $showSitterCard) { SitterCardPreviewSheet(pet: pet) }
            .alert("确认标记离世", isPresented: $showRainbowAlert) {
                Button("确认", role: .destructive) {
                    markPetPassedAway()
                }
                Button("取消", role: .cancel) {}
            } message: { Text("标记后将进入「彩虹桥」状态。") }
            .alert("撤销离世标记", isPresented: $showUndoPassingAlert) {
                Button("撤销", role: .destructive) {
                    undoPetPassedAway()
                }
                Button("取消", role: .cancel) {}
            }
            .alert("仅清空所有记录", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空记录", role: .destructive) { clearPetLogs() }
            } message: {
                Text("将清空护理、体重、花费、便便、健康、散步、喂食、清洁、里程碑、用药与相册记录，并移除日历中该宠物的计划与提醒；保留名字与证件/保险档案。此操作不可撤销。")
            }
            .alert("删除 \(pet.name)", isPresented: $showDeleteConfirm) {
                TextField("输入宠物名确认", text: $deleteNameInput) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                Button("取消", role: .cancel) { deleteNameInput = "" }
                Button("删除", role: .destructive) {
                    deletePetIfConfirmed()
                }
            } message: { Text("请输入 \"\(pet.name)\" 确认删除。") }
        }
    }

    private var petInfoSection: some View {
        Section("宠物信息") {
            Button { showEditPet = true } label: { Label("编辑资料", systemImage: "pencil.circle.fill") }
            Button { showSitterCard = true } label: { Label("寄养卡", systemImage: "person.crop.rectangle.fill") }
        }
    }

    @ViewBuilder
    private var rainbowSection: some View {
        if !pet.hasPassedAway {
            Section("生命终章") {
                DatePicker("日期", selection: $rainbowDate, in: ...Date(), displayedComponents: .date)
                    .tint(themeColor)
                Button(role: .destructive) { showRainbowAlert = true } label: {
                    Label("标记离世", systemImage: "rainbow")
                }
            }
        } else {
            Section("生命终章") {
                rainbowMemorialRow
                Button { showUndoPassingAlert = true } label: {
                    Label("撤销离世标记", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var rainbowMemorialRow: some View {
        HStack {
            Text("🌈").font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text("永远的家人")
                .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Spacer()
        }
    }

    private var dangerSection: some View {
        Section("危险区域") {
            Button(role: .destructive) { showClearConfirm = true } label: {
                Label("仅清空所有记录", systemImage: "eraser.fill")
            }
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("删除宠物", systemImage: "trash.fill")
            }
        }
    }

    private func clearPetLogs() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "records.clear"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).clearPetActivityRecords(
                pet,
                note: "pet.cardBack.records.clear"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    private func markPetPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markPetPassedAway(
                pet,
                date: rainbowDate,
                note: "pet.cardBack.passed.mark"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    private func undoPetPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.undo"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoPetPassedAway(
                pet,
                note: "pet.cardBack.passed.undo"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    private func deletePetIfConfirmed() {
        guard ConfirmationNameMatcher.matches(deleteNameInput, expectedName: pet.name) else {
            deleteNameInput = ""
            return
        }

        let command = DomainCommand.memberDeletion(entityID: pet.id, kind: EntityKind.pet.rawValue)
        deleteNameInput = ""
        showDeleteConfirm = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePet(
                pet,
                note: "pet.cardBack.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }
}
