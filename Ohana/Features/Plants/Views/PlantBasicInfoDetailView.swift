//
//  PlantBasicInfoDetailView.swift
//  Ohana
//
//  Read-first plant profile shared by standard and Zen routes.
//

import SwiftData
import SwiftUI

struct PlantBasicInfoDetailView: View {
    let plant: Plant
    var onClose: (() -> Void)? = nil
    var onChanged: (() -> Void)? = nil

    private enum PresentedSheet: String, Identifiable {
        case editor
        case avatarPreview

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var presentedSheet: PresentedSheet?
    @State private var showsMoreDetails = false
    @State private var showingArchiveConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var personalUpgradePrompt: PersonalUpgradePrompt?
    @State private var operationErrorMessage: String?
    @State private var showsSavedFeedback = false
    @State private var savedFeedbackTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ProfileDetailScaffold(
            title: l.tr(zh: "基础资料", en: "Profile", de: "Profil"),
            closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            showsEditAction: true,
            showsSavedFeedback: showsSavedFeedback,
            savedFeedbackTitle: l.tr(zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert"),
            closeAccessibilityIdentifier: "plant-basic-info-close-action",
            editAccessibilityIdentifier: "plant-basic-info-edit-action",
            onClose: onClose,
            onEdit: { presentedSheet = .editor }
        ) {
            identityHero
        } content: {
            profileContent
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .editor:
                EditPlantSheet(plant: plant, scope: .profile) {
                    presentSavedFeedback()
                    onChanged?()
                }
            case .avatarPreview:
                if let imageData = plant.avatarImageData {
                    ProfileAvatarPreviewSheet(
                        name: plant.name,
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
        .alert(
            l.tr(zh: "归档植物", en: "Archive plant", de: "Pflanze archivieren"),
            isPresented: $showingArchiveConfirmation
        ) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "归档", en: "Archive", de: "Archivieren"), role: .destructive, action: archivePlant)
        } message: {
            Text(l.tr(
                zh: "归档会保留档案和历史记录，并停止未来护理计划、日历事项和系统提醒。",
                en: "Archiving keeps the profile and history, and stops future care plans, calendar items, and system reminders.",
                de: "Beim Archivieren bleiben Profil und Verlauf erhalten; künftige Pflegepläne, Kalendereinträge und Erinnerungen werden gestoppt."
            ))
        }
        .alert(
            l.tr(zh: "恢复植物", en: "Restore plant", de: "Pflanze wiederherstellen"),
            isPresented: $showingRestoreConfirmation
        ) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "恢复活跃", en: "Restore active", de: "Aktiv wiederherstellen"), action: restorePlant)
        } message: {
            Text(l.tr(
                zh: "恢复后会按当前设置重新生成未来护理计划。",
                en: "Future care plans are regenerated from the current settings after restoring.",
                de: "Nach der Wiederherstellung werden künftige Pflegepläne aus den aktuellen Einstellungen neu erstellt."
            ))
        }
        .alert(
            l.tr(zh: "永久删除植物？", en: "Permanently delete plant?", de: "Pflanze dauerhaft löschen?"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "永久删除", en: "Delete permanently", de: "Dauerhaft löschen"), role: .destructive, action: deletePlant)
        } message: {
            Text(l.tr(
                zh: "将删除 \(plant.name) 的档案和全部历史记录。此操作无法恢复。",
                en: "This deletes \(plant.name)'s profile and all history. This cannot be undone.",
                de: "Profil und gesamter Verlauf von \(plant.name) werden gelöscht. Dies kann nicht rückgängig gemacht werden."
            ))
        }
        .alert(
            l.tr(zh: "操作未完成", en: "Action not completed", de: "Aktion nicht abgeschlossen"),
            isPresented: Binding(
                get: { operationErrorMessage != nil },
                set: { if !$0 { operationErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(operationErrorMessage ?? "")
        }
        .onDisappear {
            savedFeedbackTask?.cancel()
        }
        .accessibilityIdentifier("plant-basic-info-screen")
    }

    private var identityHero: some View {
        ProfileIdentityHero(
            name: plant.name,
            subtitle: plantSpeciesSummary,
            themeColorHex: plant.themeColorHex,
            fallbackColor: Color.green,
            statusTitle: plant.isArchived
                ? l.tr(zh: "已归档", en: "Archived", de: "Archiviert")
                : nil,
            avatarAccessibilityLabel: l.tr(
                zh: "\(plant.name) 的头像",
                en: "Avatar for \(plant.name)",
                de: "Avatar von \(plant.name)"
            ),
            nameAccessibilityIdentifier: "plant-basic-info-name-readback",
            onAvatarTap: plant.avatarImageData == nil ? nil : { presentedSheet = .avatarPreview }
        ) {
            plantAvatar(size: 88)
        } badges: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { plantProfileBadges }
                VStack(spacing: 8) { plantProfileBadges }
            }
        }
    }

    @ViewBuilder
    private var plantProfileBadges: some View {
        ProfileBadge(title: plant.healthStatus.displayName, systemImage: "heart.fill")
        if !placementSummary.isEmpty {
            ProfileBadge(title: placementSummary, systemImage: "mappin.and.ellipse")
        }
    }

    @ViewBuilder
    private func plantAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.goCardWhite.opacity(0.18))
                .frame(width: size, height: size)

            if let imageData = plant.avatarImageData {
                AsyncDecodedImageView(data: imageData) { image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView().tint(Color.goCardWhite)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
                    .font(OhanaFont.adaptive(size: size * 0.48))
            }
        }
        .overlay {
            Circle().strokeBorder(Color.goCardWhite.opacity(0.34), lineWidth: 1)
        }
    }

    private var profileContent: some View {
        VStack(spacing: 24) {
            if plant.isArchived {
                ProfileStatusBanner(
                    title: l.tr(zh: "此植物已归档", en: "This plant is archived", de: "Diese Pflanze ist archiviert"),
                    detail: plant.archivedAt.map {
                        l.tr(
                            zh: "归档于 \($0.formatted(.dateTime.year().month().day()))，资料和历史记录仍会保留。",
                            en: "Archived on \($0.formatted(.dateTime.year().month().day())). Profile and history are preserved.",
                            de: "Archiviert am \($0.formatted(.dateTime.year().month().day())). Profil und Verlauf bleiben erhalten."
                        )
                    },
                    systemImage: "archivebox.fill",
                    tint: Color.goYellow
                )
            }

            ProfileCompletionCard(
                snapshot: MemberProfileCompletenessPolicy.plant(plant),
                onContinue: plant.isArchived ? nil : { presentedSheet = .editor }
            )

            ProfileInfoSection(
                title: l.tr(zh: "基本资料", en: "Basic info", de: "Basisdaten"),
                systemImage: "leaf.fill",
                tint: Color.goPrimary
            ) {
                ProfileInfoRow(label: l.tr(zh: "名称", en: "Name", de: "Name"), value: plant.name)
                ProfileInfoRow(label: l.tr(zh: "物种或品种", en: "Species or variety", de: "Art oder Sorte"), value: valueOrEmpty(plantSpeciesSummary))
                ProfileInfoRow(label: l.tr(zh: "当前位置", en: "Current place", de: "Aktueller Standort"), value: valueOrEmpty(placementSummary))
                ProfileInfoRow(label: l.tr(zh: "当前状态", en: "Current status", de: "Aktueller Zustand"), value: plant.healthStatus.displayName)
                if let acquiredDate = plant.acquiredDate {
                    ProfileInfoRow(label: l.tr(zh: "获得日期", en: "Acquired date", de: "Kaufdatum"), value: acquiredDate.formatted(.dateTime.year().month().day()))
                }
            }

            ProfileInfoSection(
                title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"),
                systemImage: "sun.max.fill",
                tint: Color.goYellow
            ) {
                ProfileInfoRow(
                    label: l.tr(zh: "摆放", en: "Placement", de: "Platzierung"),
                    value: plant.isIndoor
                        ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen")
                        : l.tr(zh: "户外", en: "Outdoor", de: "Draußen")
                )
                ProfileInfoRow(label: l.tr(zh: "窗户朝向", en: "Window direction", de: "Fensterausrichtung"), value: plant.windowDirection.displayName)
                ProfileInfoRow(label: l.tr(zh: "光照", en: "Light", de: "Licht"), value: plant.lightLevel.displayName)
                ProfileInfoRow(label: l.tr(zh: "湿度偏好", en: "Humidity", de: "Luftfeuchte"), value: plant.humidityPreference.displayName)
                ProfileInfoRow(label: l.tr(zh: "温度偏好", en: "Temperature", de: "Temperatur"), value: plant.temperaturePreference.displayName)
            }

            DisclosureGroup(isExpanded: $showsMoreDetails) {
                VStack(spacing: 24) {
                    pottingSection
                    sourceAndGrowthSection
                    safetySection
                }
                .padding(.top, 16)
            } label: {
                Label(l.tr(zh: "更多资料", en: "More details", de: "Weitere Details"), systemImage: "list.bullet.rectangle")
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(Color.goPrimary)
            .accessibilityIdentifier("plant-profile-more-details")

            notesSection
            archiveManagementSection
        }
    }

    @ViewBuilder
    private var pottingSection: some View {
        ProfileInfoSection(
            title: l.tr(zh: "盆土与生长", en: "Potting & growth", de: "Topf & Wachstum"),
            systemImage: "shippingbox.fill",
            tint: Color.goTeal
        ) {
            if hasPottingDetails {
                if plant.potDiameterCm > 0 {
                    ProfileInfoRow(label: l.tr(zh: "盆径", en: "Pot diameter", de: "Topfdurchmesser"), value: "\(Int(plant.potDiameterCm)) cm")
                }
                if !plant.potMaterial.isEmpty {
                    ProfileInfoRow(label: l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), value: plant.potMaterial)
                }
                if !plant.soilType.isEmpty {
                    ProfileInfoRow(label: l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: plant.soilType)
                }
                ProfileInfoRow(
                    label: l.tr(zh: "排水孔", en: "Drainage", de: "Abzugsloch"),
                    value: plant.potHasDrainage ? l.tr(zh: "有", en: "Yes", de: "Ja") : l.tr(zh: "无", en: "No", de: "Nein")
                )
                if plant.isHydroponic {
                    ProfileInfoRow(label: l.tr(zh: "栽培方式", en: "Growing method", de: "Anbaumethode"), value: l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"))
                }
                if plant.isSucculent {
                    ProfileInfoRow(label: l.tr(zh: "植物类型", en: "Plant type", de: "Pflanzentyp"), value: l.tr(zh: "多肉或仙人掌类", en: "Succulent or cactus", de: "Sukkulente oder Kaktus"))
                }
            } else {
                ProfileEmptySectionRow(
                    title: emptyValue,
                    editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
                    onEdit: { presentedSheet = .editor }
                )
            }
        }
    }

    @ViewBuilder
    private var sourceAndGrowthSection: some View {
        ProfileInfoSection(
            title: l.tr(zh: "来源与尺寸", en: "Source & size", de: "Quelle & Größe"),
            systemImage: "ruler.fill",
            tint: Color.goMint
        ) {
            if hasSourceOrGrowthDetails {
                if let acquiredDate = plant.acquiredDate {
                    ProfileInfoRow(label: l.tr(zh: "获得日期", en: "Acquired date", de: "Kaufdatum"), value: acquiredDate.formatted(.dateTime.year().month().day()))
                }
                if !plant.acquisitionSource.isEmpty {
                    ProfileInfoRow(label: l.tr(zh: "来源", en: "Source", de: "Quelle"), value: plant.acquisitionSource)
                }
                if plant.currentHeightCm > 0 {
                    ProfileInfoRow(label: l.tr(zh: "高度", en: "Height", de: "Höhe"), value: "\(Int(plant.currentHeightCm)) cm")
                }
                if plant.currentSpreadCm > 0 {
                    ProfileInfoRow(label: l.tr(zh: "冠幅", en: "Spread", de: "Breite"), value: "\(Int(plant.currentSpreadCm)) cm")
                }
            } else {
                ProfileEmptySectionRow(
                    title: emptyValue,
                    editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
                    onEdit: { presentedSheet = .editor }
                )
            }
        }
    }

    private var safetySection: some View {
        ProfileInfoSection(
            title: l.tr(zh: "安全状态", en: "Safety", de: "Sicherheit"),
            systemImage: "shield.checkered",
            tint: safetyRiskCount > 0 ? Color.goRed : Color.goPrimary
        ) {
            ProfileInfoRow(
                label: l.tr(zh: "适合室内", en: "Suitable indoors", de: "Für drinnen geeignet"),
                value: plant.isIndoorSuitable ? l.tr(zh: "是", en: "Yes", de: "Ja") : l.tr(zh: "否", en: "No", de: "Nein")
            )
            ProfileInfoRow(label: l.tr(zh: "对猫", en: "For cats", de: "Für Katzen"), value: riskText(plant.isToxicToCats))
            ProfileInfoRow(label: l.tr(zh: "对狗", en: "For dogs", de: "Für Hunde"), value: riskText(plant.isToxicToDogs))
            ProfileInfoRow(label: l.tr(zh: "对儿童", en: "For children", de: "Für Kinder"), value: riskText(plant.isToxicToChildren))
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        ProfileInfoSection(
            title: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
            systemImage: "note.text",
            tint: Color.goOrange
        ) {
            if plant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ProfileEmptySectionRow(
                    title: emptyValue,
                    editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
                    onEdit: { presentedSheet = .editor }
                )
            } else {
                Text(plant.notes)
                    .font(OhanaFont.body(.medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    private var archiveManagementSection: some View {
        ProfileInfoSection(
            title: l.tr(zh: "档案管理", en: "Profile management", de: "Profilverwaltung"),
            systemImage: "archivebox",
            tint: Color.goYellow
        ) {
            VStack(spacing: 10) {
                Button {
                    if plant.isArchived {
                        showingRestoreConfirmation = true
                    } else {
                        showingArchiveConfirmation = true
                    }
                } label: {
                    Label(
                        plant.isArchived
                            ? l.tr(zh: "恢复为活跃植物", en: "Restore active plant", de: "Aktive Pflanze wiederherstellen")
                            : l.tr(zh: "归档植物", en: "Archive plant", de: "Pflanze archivieren"),
                        systemImage: plant.isArchived ? "arrow.uturn.backward.circle" : "archivebox"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.control))
                .accessibilityIdentifier(plant.isArchived ? "plant-profile-restore-action" : "plant-profile-archive-action")

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label(l.tr(zh: "永久删除植物", en: "Delete plant permanently", de: "Pflanze dauerhaft löschen"), systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.control))
                .accessibilityIdentifier("plant-profile-delete-action")
            }
            .padding(.top, 4)
        }
    }

    private var plantSpeciesSummary: String {
        if let entry = PlantCatalog.entry(id: plant.catalogSpeciesId) {
            return entry.localizedCommonName
        }
        return plant.species.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var placementSummary: String {
        let room = plant.roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !location.isEmpty, room != location { return "\(room) · \(location)" }
        return room.isEmpty ? location : room
    }

    private var emptyValue: String {
        l.tr(zh: "尚未填写", en: "Not added yet", de: "Noch nicht ausgefüllt")
    }

    private var hasPottingDetails: Bool {
        plant.potDiameterCm > 0 ||
            !plant.potMaterial.isEmpty ||
            !plant.soilType.isEmpty ||
            plant.isHydroponic ||
            plant.isSucculent
    }

    private var hasSourceOrGrowthDetails: Bool {
        plant.acquiredDate != nil ||
            !plant.acquisitionSource.isEmpty ||
            plant.currentHeightCm > 0 ||
            plant.currentSpreadCm > 0
    }

    private var safetyRiskCount: Int {
        [plant.isToxicToCats, plant.isToxicToDogs, plant.isToxicToChildren, !plant.isIndoorSuitable].count(where: { $0 })
    }

    private func valueOrEmpty(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyValue : value
    }

    private func riskText(_ hasRisk: Bool) -> String {
        hasRisk
            ? l.tr(zh: "有风险", en: "Risk", de: "Risiko")
            : l.tr(zh: "未标记风险", en: "No marked risk", de: "Kein markiertes Risiko")
    }

    private func archivePlant() {
        OhanaFeedback.medium()
        let command = DomainCommand.memberLifecycle(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: "archive.mark"
        )
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).archivePlant(
                plant,
                date: Date(),
                note: "plant.profile.archive"
            )
            handleLifecycleResult(result)
        }
    }

    private func restorePlant() {
        OhanaFeedback.medium()
        let command = DomainCommand.memberLifecycle(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: "archive.restore"
        )
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).restorePlant(
                plant,
                note: "plant.profile.restore"
            )
            if let denial = result.personalDenial {
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                OhanaFeedback.warning()
                return
            }
            handleLifecycleResult(result)
        }
    }

    private func handleLifecycleResult(_ result: MemberLifecycleCommandResult) {
        guard result.didPersist else {
            operationErrorMessage = l.tr(
                zh: "修改没有保存，请稍后重试。",
                en: "The change was not saved. Please try again.",
                de: "Die Änderung wurde nicht gespeichert. Bitte erneut versuchen."
            )
            OhanaFeedback.error()
            return
        }
        OhanaFeedback.success()
        onChanged?()
    }

    private func deletePlant() {
        let target = plant
        let command = DomainCommand.memberDeletion(entityID: plant.id, kind: EntityKind.plant.rawValue)
        OhanaFeedback.medium()
        onClose?()
        dismiss()
        commandQueue.enqueue(
            command,
            delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds
        ) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                target,
                note: "plant.profile.delete"
            )
            if result.didPersist {
                OhanaFeedback.success()
                onChanged?()
            } else {
                OhanaFeedback.error()
            }
        }
    }

    private func presentSavedFeedback() {
        savedFeedbackTask?.cancel()
        withAnimation(GoMotion.feedback) {
            showsSavedFeedback = true
        }
        savedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.feedback) {
                showsSavedFeedback = false
            }
        }
    }
}
