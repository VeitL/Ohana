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
        if areDataSectionsMounted {
            if let homeHumans, !homeHumans.isEmpty {
                deviceIdentitySection(homeHumans)
            }
            if let homePets, !homePets.isEmpty {
                petManagementEntrySection(homePets)
            }
        }
    }

    // MARK: - Device Identity
    func deviceIdentitySection(_ humans: [Human]) -> some View {
        settingsSection(title: l.tr(zh: "设备身份", en: "Device Identity", de: "Geräteidentität")) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(GoMotion.page) {
                        showingAccountSwitcher = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        settingsIcon("person.2.badge.key.fill", color: Color.goPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "切换人类账户", en: "Switch Human Account", de: "Menschenkonto wechseln"))
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(primaryText)
                            Text(l.tr(zh: "账户与密码", en: "Account and PIN", de: "Konto und PIN"))
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
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
                                        if appServices.passcodes.hasPasscode(human) {
                                            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.arkInk)
                                                .frame(width: 16, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                .background(Color.goYellow, in: Circle())
                                                .offset(x: 15, y: 15)
                                        }
                                    }
                                    Text(human.name.isEmpty ? l.tr(zh: "成员", en: "Member", de: "Mitglied") : human.name)
                                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(isSelected ? Color.goPrimary : tertiaryText)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 56, minHeight: 72)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                if !currentActiveHumanId.isEmpty,
                   let selected = humans.first(where: { $0.id.uuidString == currentActiveHumanId }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .foregroundStyle(Color.goPrimary)
                            .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(
                            zh: "打卡记录将关联到 \(selected.name)",
                            en: "Check-ins will be linked to \(selected.name)",
                            de: "Check-ins werden mit \(selected.name) verknüpft"
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText)
                    }
                }
            }
        }
    }

    func petManagementEntrySection(_ pets: [Pet]) -> some View {
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

    func quickSwitch(to human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard currentActiveHumanId != human.id.uuidString else { return }
        if appServices.passcodes.hasPasscode(human) {
            quickSwitchHuman = human
        } else {
            switchActiveHuman(to: human)
        }
    }

    func switchActiveHuman(to human: Human, emitSuccessFeedback: Bool = true) {
        let oldHumanIdRaw = currentActiveHumanId
        guard oldHumanIdRaw != human.id.uuidString else { return }
        currentActiveHumanId = human.id.uuidString
        syncHomeCardStackAfterAccountSwitch(from: oldHumanIdRaw, to: human)
        if emitSuccessFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func syncHomeCardStackAfterAccountSwitch(from oldHumanIdRaw: String, to human: Human) {
        guard let homePets, let homeHumans else { return }
        let result = SettingsCommandExecutor(context: modelContext, services: appServices).syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: homePets,
            humans: homeHumans,
            electronicPets: homeElectronicPets ?? [],
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
}
