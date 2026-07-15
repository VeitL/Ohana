//
//  SettingsView+DataIdentity.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    @ViewBuilder
    var settingsDataSections: some View {
        if !isRouteDataLoaded {
            deviceIdentityPlaceholderSection
            petManagementPlaceholderSection
        } else {
            if selectableSettingsHumans.count > 1 {
                if areDataSectionsMounted {
                    deviceIdentitySection(selectableSettingsHumans)
                } else {
                    deviceIdentityPlaceholderSection
                }
            }
            if let homePets, !homePets.isEmpty {
                if areDataSectionsMounted {
                    petManagementEntrySection(homePets)
                } else {
                    petManagementPlaceholderSection
                }
            }
        }
    }

    var selectableSettingsHumans: [SettingsHumanSnapshot] {
        SettingsActiveHumanSelectionPolicy.selectableHumans(from: homeHumans ?? [])
    }

    private var deviceIdentityPlaceholderSection: some View {
        settingsSection(title: l.tr(zh: "设备身份", en: "Device Identity", de: "Geräteidentität")) {
            VStack(alignment: .leading, spacing: 12) {
                settingsDataPlaceholderRow(titleWidth: 154, subtitleWidth: 96)
                    .frame(minHeight: 68)
                    .padding(12)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0 ..< 3, id: \.self) { _ in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.ohanaControlFill)
                                    .frame(width: 44, height: 44)
                                Capsule()
                                    .fill(tertiaryText.opacity(0.24))
                                    .frame(width: 40, height: 10) // a11y: allow non-interactive loading skeleton hidden from accessibility
                            }
                            .frame(minWidth: 56, minHeight: 72)
                        }
                    }
                }
                .scrollDisabled(true)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.28))
                        .frame(width: 12, height: 12) // a11y: allow non-interactive loading skeleton hidden from accessibility
                    Capsule()
                        .fill(tertiaryText.opacity(0.24))
                        .frame(width: 182, height: 10)
                }
                .frame(height: 18)
            }
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var petManagementPlaceholderSection: some View {
        settingsSection(title: l.tr(zh: "宠物管理", en: "Pet Management", de: "Tierverwaltung")) {
            settingsDataPlaceholderRow(titleWidth: 94, subtitleWidth: 136)
                .frame(minHeight: 44)
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func settingsDataPlaceholderRow(titleWidth: CGFloat, subtitleWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.ohanaControlFill)
                .frame(width: 32, height: 32) // a11y: allow non-interactive loading skeleton hidden from accessibility
            VStack(alignment: .leading, spacing: 7) {
                Capsule()
                    .fill(primaryText.opacity(0.22))
                    .frame(width: titleWidth, height: 14)
                Capsule()
                    .fill(tertiaryText.opacity(0.22))
                    .frame(width: subtitleWidth, height: 10)
            }
            Spacer()
            Capsule()
                .fill(tertiaryText.opacity(0.20))
                .frame(width: 8, height: 14) // a11y: allow non-interactive loading skeleton hidden from accessibility
        }
    }

    // MARK: - Device Identity
    func deviceIdentitySection(_ humans: [SettingsHumanSnapshot]) -> some View {
        settingsSection(title: l.tr(zh: "本机当前成员", en: "Current Member", de: "Aktuelles Mitglied")) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        /* Removing "Unbind" option to enforce mandatory identity */

                        ForEach(humans) { human in
                            let isSelected = currentActiveHumanId == human.id.uuidString
                            Button {
                                quickSwitch(to: human)
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        SettingsHumanIdentityAvatar(
                                            human: human,
                                            isSelected: isSelected
                                        )
                                        if HumanLocalPrivacyPolicy.isEnabled,
                                           human.hasPasscode {
                                            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.arkInk)
                                                .frame(width: 16, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                .background(Color.goYellow, in: Circle())
                                                .offset(x: 15, y: 15)
                                            }
                                    }
                                    Text(human.displayName(fallback: l.tr(zh: "成员", en: "Member", de: "Mitglied")))
                                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(isSelected ? Color.goPrimary : tertiaryText)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 56, minHeight: 72)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityIdentifier("settings-human-identity-switch-\(human.displayName(fallback: "Member"))")
                        }
                    }
                }
                if !currentActiveHumanId.isEmpty,
                   let selected = humans.first(where: { $0.id.uuidString == currentActiveHumanId }) {
                    let selectedName = selected.displayName(fallback: l.tr(zh: "成员", en: "Member", de: "Mitglied"))
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .foregroundStyle(Color.goPrimary)
                            .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(
                            zh: "任务和记录会默认使用 \(selectedName)",
                            en: "Tasks and records will default to \(selectedName)",
                            de: "Aufgaben und Einträge verwenden standardmäßig \(selectedName)"
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText)
                    }
                }
            }
        }
    }

    func petManagementEntrySection(_ pets: [SettingsPetSnapshot]) -> some View {
        settingsSection(title: l.tr(zh: "宠物管理", en: "Pet Management", de: "Tierverwaltung")) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(GoMotion.page) {
                    showingPetManagement = true
                }
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("pawprint.fill", color: Color.goPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "管理宠物", en: "Manage Pets", de: "Tiere verwalten"))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "\(pets.count) 位成员，可重置或删除",
                            en: "\(pets.count) members, reset or delete",
                            de: "\(pets.count) Mitglieder, zurücksetzen oder löschen"
                        ))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText.opacity(0.6))
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    var currentBackgroundStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: appBackgroundStyle) ?? .goIsland
    }

    func quickSwitch(to human: SettingsHumanSnapshot) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard !human.hasPassedAway else { return }
        guard currentActiveHumanId != human.id.uuidString else { return }
        if HumanLocalPrivacyPolicy.isEnabled,
           human.hasPasscode {
            quickSwitchHuman = human
        } else {
            switchActiveHuman(to: human)
        }
    }

    func switchActiveHuman(to human: SettingsHumanSnapshot, emitSuccessFeedback: Bool = true) {
        guard !human.hasPassedAway,
              let liveHuman = fetchSettingsHuman(id: human.id),
              !liveHuman.hasPassedAway else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        let oldHumanIdRaw = currentActiveHumanId
        guard oldHumanIdRaw != human.id.uuidString else { return }
        currentActiveHumanId = human.id.uuidString
        syncHomeCardStackAfterAccountSwitch(from: oldHumanIdRaw, to: liveHuman)
        if emitSuccessFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func reconcileCurrentActiveHumanSelection() {
        guard isRouteDataLoaded, let homeHumans else { return }
        let resolvedID = SettingsActiveHumanSelectionPolicy.resolvedHumanID(
            currentHumanID: UUID(uuidString: currentActiveHumanId),
            humans: homeHumans
        )
        let resolvedRaw = resolvedID?.uuidString ?? ""
        guard resolvedRaw != currentActiveHumanId else { return }

        guard let resolvedID,
              let resolvedHuman = selectableSettingsHumans.first(where: { $0.id == resolvedID }) else {
            currentActiveHumanId = ""
            return
        }
        switchActiveHuman(to: resolvedHuman, emitSuccessFeedback: false)
    }

    func syncHomeCardStackAfterAccountSwitch(from oldHumanIdRaw: String, to human: Human) {
        let pets = fetchSettingsPets()
        let humans = fetchSettingsHumans()
        let electronicPets = fetchSettingsElectronicPets()
        guard !humans.isEmpty else { return }
        let result = SettingsCommandExecutor(context: modelContext, services: appServices).syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            note: "settings.activeHuman.switch"
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if result.updatedHomeCardOrderRaw != homeCardOrderRaw {
                homeCardOrderRaw = result.updatedHomeCardOrderRaw
            }
        }
    }

    func fetchSettingsHuman(id: UUID) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchSettingsModels(descriptor, name: "Settings.Action.Human").first
    }

    func fetchSettingsPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchSettingsModels(descriptor, name: "Settings.Action.Pet").first
    }

    func fetchSettingsHousehold(id: UUID) -> Household? {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { household in
                household.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchSettingsModels(descriptor, name: "Settings.Action.Household").first
    }

    func fetchSettingsPets() -> [Pet] {
        fetchSettingsModels(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Settings.Action.Pets"
        )
    }

    func fetchSettingsHumans() -> [Human] {
        fetchSettingsModels(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Settings.Action.Humans"
        )
    }

    func fetchSettingsElectronicPets() -> [OasisElectronicPet] {
        fetchSettingsModels(
            FetchDescriptor<OasisElectronicPet>(),
            name: "Settings.Action.OasisElectronicPets"
        )
    }

    private func fetchSettingsModels<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor) // smoothness: allow action-time rehydrate after explicit settings command
        } catch {
            OhanaLog.warning(
                "Settings action fetch failed for \(name): \(error.localizedDescription)",
                category: "Settings"
            )
            return []
        }
    }
}
