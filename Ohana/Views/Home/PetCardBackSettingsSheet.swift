//
//  PetCardBackSettingsSheet.swift
//  Ohana
//
//  卡片背面齿轮按钮打开的设置菜单
//

import SwiftUI
import SwiftData

struct PetCardBackSettingsSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
                    RainbowBridgeService.markPassedAway(pet: pet, date: rainbowDate, context: modelContext)
                }
                Button("取消", role: .cancel) {}
            } message: { Text("标记后将进入「彩虹桥」状态。") }
            .alert("撤销离世标记", isPresented: $showUndoPassingAlert) {
                Button("撤销", role: .destructive) {
                    RainbowBridgeService.undoPassedAway(pet: pet, context: modelContext)
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
                TextField("输入宠物名确认", text: $deleteNameInput)
                Button("取消", role: .cancel) { deleteNameInput = "" }
                Button("删除", role: .destructive) {
                    guard deleteNameInput == pet.name else { return }
                    modelContext.delete(pet)
                    modelContext.safeSave()
                    dismiss()
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
            Text("🌈").font(.system(size: 20))
            Text("永远的家人")
                .font(.system(size: 14, weight: .bold, design: .rounded))
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
        pet.clearAllActivityRecords(in: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
