//
//  PetBasicInfoDetailView+MemorialDanger.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

extension PetBasicInfoDetailView {
    @ViewBuilder
    var rainbowBridgeSection: some View {
        if pet.hasPassedAway {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text("🌈").font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "记录中心 · 彩虹桥彼端", en: "Record center · Rainbow Bridge", de: "Archiv · Regenbogenbrücke"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let d = pet.passedAwayDate {
                            Text(l.tr(
                                zh: "离世日期：\(d.formatted(.dateTime.year().month().day()))",
                                en: "Date of passing: \(d.formatted(.dateTime.year().month().day()))",
                                de: "Sterbedatum: \(d.formatted(.dateTime.year().month().day()))"
                            ))
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                                .accessibilityIdentifier("pet-memorial-passed-date")
                        }
                        Text(l.tr(
                            zh: "相伴 \(pet.daysTogetherAtPassing) 天 · \(pet.ageAtPassingText)",
                            en: "Together for \(pet.daysTogetherAtPassing) days · \(localizedPetAgeAtPassing)",
                            de: "\(pet.daysTogetherAtPassing) Tage zusammen · \(localizedPetAgeAtPassing)"
                        ))
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    }
                    Spacer()
                    Button { showingUndoPassingAlert = true } label: {
                        Text(l.tr(zh: "撤销离世", en: "Undo passing", de: "Zurücknehmen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goYellow)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goYellow.opacity(0.1), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("pet-memorial-undo-action")
                }
                .padding(14)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1))
            }
            .alert(l.tr(zh: "撤销离世标记", en: "Undo passing mark", de: "Sterbemarkierung zurücknehmen"), isPresented: $showingUndoPassingAlert) {
                Button(l.tr(zh: "撤销", en: "Undo", de: "Zurücknehmen"), role: .destructive) {
                    undoPetPassedAway()
                }
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            } message: {
                Text(l.tr(
                    zh: "将清除 \(pet.name) 的离世记录，恢复为在世状态。",
                    en: "This clears \(pet.name)'s passing record and restores active status.",
                    de: "Dies entfernt den Sterbeeintrag von \(pet.name) und stellt den aktiven Status wieder her."
                ))
            }
        } else {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "rainbow").foregroundStyle(Color.purple.opacity(0.6)).font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "生命终章", en: "End of life", de: "Lebensende"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.purple.opacity(0.6))
                        .tracking(2)
                    Spacer()
                }
                Button {
                    rainbowBridgeDate = Date()
                    showingRainbowBridgeAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Text("🌈")
                        Text(l.tr(zh: "标记 \(pet.name) 已离世", en: "Mark \(pet.name) as passed away", de: "\(pet.name) als verstorben markieren"))
                            .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                    .foregroundStyle(Color.purple.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("pet-memorial-mark-action")
            }
            .alert(l.tr(zh: "确认标记离世", en: "Confirm passing mark", de: "Sterbemarkierung bestätigen"), isPresented: $showingRainbowBridgeAlert) {
                Button(l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), role: .destructive) {
                    markPetPassedAway()
                }
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            } message: {
                Text(l.tr(
                    zh: "将标记 \(pet.name) 为离世，并让未来照护安排退出活跃提醒。原有数据会保留，此操作可撤销。",
                    en: "This marks \(pet.name) as passed away and removes future care from active reminders. Existing data is kept and this can be undone.",
                    de: "Dies markiert \(pet.name) als verstorben und entfernt zukünftige Pflege aus aktiven Erinnerungen. Vorhandene Daten bleiben erhalten und dies kann rückgängig gemacht werden."
                ))
            }
        }
    }

    // MARK: - Danger Zone
    var deleteDangerZone: some View {
        PetBasicInfoDangerZone(
            petName: pet.name,
            onClear: clearPetLogs,
            onDelete: { deletePetWithCascade(pet) }
        )
    }

    // MARK: - Delete Helpers
    func markPetPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markPetPassedAway(
                pet,
                date: rainbowBridgeDate,
                note: "petBasicInfo.passed.mark"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func undoPetPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.undo"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoPetPassedAway(
                pet,
                note: "petBasicInfo.passed.undo"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func deletePetWithCascade(_ p: Pet) {
        let command = DomainCommand.memberDeletion(entityID: p.id, kind: EntityKind.pet.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePet(
                p,
                note: "petBasicInfo.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func clearPetLogs() {
        let command = DomainCommand.memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "records.clear"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).clearPetActivityRecords(
                pet,
                note: "petBasicInfo.records.clear"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    // MARK: - Edit State

    private var localizedPetAgeAtPassing: String {
        guard let birthday = pet.birthday,
              let passed = pet.passedAwayDate else {
            return l.tr(zh: "未知年龄", en: "Unknown age", de: "Unbekanntes Alter")
        }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: passed).year ?? 0
        return years > 0
            ? l.tr(zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.")
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }
}
