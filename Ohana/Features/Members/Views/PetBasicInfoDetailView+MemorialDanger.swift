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
                    Text("记录中心 · 彩虹桥彼端")
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let d = pet.passedAwayDate {
                            Text("离世日期：\(d.formatted(.dateTime.year().month().day()))")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                                .accessibilityIdentifier("pet-memorial-passed-date")
                        }
                        Text("相伴 \(pet.daysTogetherAtPassing) 天 · \(pet.ageAtPassingText)")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    }
                    Spacer()
                    Button { showingUndoPassingAlert = true } label: {
                        Text("撤销离世")
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
            .alert("撤销离世标记", isPresented: $showingUndoPassingAlert) {
                Button("撤销", role: .destructive) {
                    undoPetPassedAway()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除 \(pet.name) 的离世记录，恢复为在世状态。")
            }
        } else {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "rainbow").foregroundStyle(Color.purple.opacity(0.6)).font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("生命终章")
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
                        Text("标记 \(pet.name) 已离世")
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
            .alert("确认标记离世", isPresented: $showingRainbowBridgeAlert) {
                Button("确认", role: .destructive) {
                    markPetPassedAway()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将标记 \(pet.name) 为离世，并让未来照护安排退出活跃提醒。原有数据会保留，此操作可撤销。")
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
}
