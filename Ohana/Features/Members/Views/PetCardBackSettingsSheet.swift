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
    @State private var personalUpgradePrompt: PersonalUpgradePrompt?

    @State private var showClearConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteNameInput = ""

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var l: L10n { L10n.current }

    var body: some View {
        NavigationStack {
            List {
                petInfoSection
                rainbowSection
                dangerSection
            }
            .navigationTitle(l.tr(zh: "设置", en: "Settings", de: "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) { dismiss() }
                }
            }
            .sheet(isPresented: $showEditPet) { EditPetSheet(pet: pet) }
            .sheet(isPresented: $showSitterCard) { SitterCardPreviewSheet(pet: pet) }
            .sheet(item: $personalUpgradePrompt) { prompt in
                PersonalPlanView(prompt: prompt)
                    .ohanaSheetPagePresentation()
            }
            .alert(l.tr(zh: "确认标记离世", en: "Confirm Passing", de: "Abschied bestätigen"), isPresented: $showRainbowAlert) {
                Button(l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), role: .destructive) {
                    markPetPassedAway()
                }
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            } message: {
                Text(l.tr(
                    zh: "标记后将进入「彩虹桥」状态。",
                    en: "This will move the pet into Rainbow Bridge status.",
                    de: "Dadurch wird das Haustier in den Regenbogenbrücken-Status versetzt."
                ))
            }
            .alert(l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Abschiedsmarkierung zurücknehmen"), isPresented: $showUndoPassingAlert) {
                Button(l.tr(zh: "撤销", en: "Undo", de: "Zurücknehmen"), role: .destructive) {
                    undoPetPassedAway()
                }
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            }
            .alert(l.tr(zh: "仅清空所有记录", en: "Clear Records Only", de: "Nur Aufzeichnungen löschen"), isPresented: $showClearConfirm) {
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
                Button(l.tr(zh: "清空记录", en: "Clear Records", de: "Aufzeichnungen löschen"), role: .destructive) { clearPetLogs() }
            } message: {
                Text(l.tr(
                    zh: "将清空护理、体重、花费、便便、健康、散步、喂食、清洁、里程碑、用药与相册记录，并移除日历中该宠物的计划与提醒；保留名字与证件/保险档案。此操作不可撤销。",
                    en: "This clears care, weight, expense, poop, health, walk, feeding, hygiene, milestone, medication, and album records, and removes this pet's calendar plans and reminders. Name, documents, and insurance files stay. This cannot be undone.",
                    de: "Dies löscht Pflege-, Gewichts-, Ausgaben-, Kot-, Gesundheits-, Spaziergangs-, Fütterungs-, Hygiene-, Meilenstein-, Medikamenten- und Albumdaten und entfernt Kalenderpläne sowie Erinnerungen für dieses Haustier. Name, Dokumente und Versicherungsdaten bleiben erhalten. Dies kann nicht rückgängig gemacht werden."
                ))
            }
            .alert(l.tr(zh: "删除 \(pet.name)", en: "Delete \(pet.name)", de: "\(pet.name) löschen"), isPresented: $showDeleteConfirm) {
                TextField(l.tr(zh: "输入宠物名确认", en: "Enter pet name to confirm", de: "Haustiernamen zur Bestätigung eingeben"), text: $deleteNameInput) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { deleteNameInput = "" }
                Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                    deletePetIfConfirmed()
                }
            } message: {
                Text(l.tr(
                    zh: "请输入 \"\(pet.name)\" 确认删除。",
                    en: "Enter \"\(pet.name)\" to confirm deletion.",
                    de: "Gib \"\(pet.name)\" ein, um das Löschen zu bestätigen."
                ))
            }
        }
    }

    private var petInfoSection: some View {
        Section(l.tr(zh: "宠物信息", en: "Pet Info", de: "Haustierinfos")) {
            Button { showEditPet = true } label: {
                Label(l.tr(zh: "编辑资料", en: "Edit Profile", de: "Profil bearbeiten"), systemImage: "pencil.circle.fill")
            }
            Button { showSitterCard = true } label: {
                Label(l.tr(zh: "寄养卡", en: "Sitter Card", de: "Sitter-Karte"), systemImage: "person.crop.rectangle.fill")
            }
        }
    }

    @ViewBuilder
    private var rainbowSection: some View {
        if !pet.hasPassedAway {
            Section(l.tr(zh: "生命终章", en: "Life Chapter", de: "Lebenskapitel")) {
                DatePicker(l.tr(zh: "日期", en: "Date", de: "Datum"), selection: $rainbowDate, in: ...Date(), displayedComponents: .date)
                    .tint(themeColor)
                Button(role: .destructive) { showRainbowAlert = true } label: {
                    Label(l.tr(zh: "标记离世", en: "Mark as Passed", de: "Als verstorben markieren"), systemImage: "rainbow")
                }
            }
        } else {
            Section(l.tr(zh: "生命终章", en: "Life Chapter", de: "Lebenskapitel")) {
                rainbowMemorialRow
                Button { showUndoPassingAlert = true } label: {
                    Label(l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Abschiedsmarkierung zurücknehmen"), systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var rainbowMemorialRow: some View {
        HStack {
            Text("🌈").font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(l.tr(zh: "永远的家人", en: "Forever Family", de: "Für immer Familie"))
                .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Spacer()
        }
    }

    private var dangerSection: some View {
        Section(l.tr(zh: "危险区域", en: "Danger Zone", de: "Gefahrenbereich")) {
            Button(role: .destructive) { showClearConfirm = true } label: {
                Label(l.tr(zh: "仅清空所有记录", en: "Clear Records Only", de: "Nur Aufzeichnungen löschen"), systemImage: "eraser.fill")
            }
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label(l.tr(zh: "删除宠物", en: "Delete Pet", de: "Haustier löschen"), systemImage: "trash.fill")
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
            if let denial = result.personalDenial {
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
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
