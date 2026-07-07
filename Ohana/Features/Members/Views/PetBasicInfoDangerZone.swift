//
//  PetBasicInfoDangerZone.swift
//  Ohana
//

import SwiftUI

struct PetBasicInfoDangerZone: View {
    let petName: String
    let onClear: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var showingClearConfirm = false
    @State private var showingDeleteSheet = false
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "危险区域", en: "Danger zone", de: "Gefahrenbereich"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .tracking(2)
                Spacer()
            }

            Button {
                showingClearConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eraser.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "仅清空所有记录", en: "Clear records only", de: "Nur Einträge löschen"))
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.goOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(Color.goOrange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                showingDeleteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "彻底删除 \(petName)", en: "Delete \(petName)", de: "\(petName) löschen"))
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("pet-danger-delete-action")
        }
        .padding(.top, 8)
        .alert(l.tr(zh: "仅清空所有记录", en: "Clear records only", de: "Nur Einträge löschen"), isPresented: $showingClearConfirm) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "清空记录", en: "Clear records", de: "Einträge löschen"), role: .destructive) { onClear() }
        } message: {
            Text(l.tr(
                zh: "将删除 \(petName) 的护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录，并移除日历中该宠物的计划；保留名字、头像、品种与证件/保险档案。此操作不可撤销。",
                en: "This deletes \(petName)'s care, weight, expense, health, walk, feeding, hygiene, milestone, medication, and album records, and removes this pet's calendar plans. Name, avatar, breed, documents, and insurance files are kept. This cannot be undone.",
                de: "Dies löscht Pflege-, Gewichts-, Ausgaben-, Gesundheits-, Spaziergangs-, Fütterungs-, Hygiene-, Meilenstein-, Medikations- und Albumeinträge von \(petName) und entfernt Kalenderpläne. Name, Avatar, Rasse, Dokumente und Versicherungsdaten bleiben erhalten. Dies kann nicht rückgängig gemacht werden."
            ))
        }
        .sheet(isPresented: $showingDeleteSheet) {
            PetDeleteConfirmationSheet(
                petName: petName,
                onCancel: { showingDeleteSheet = false },
                onDelete: {
                    showingDeleteSheet = false
                    onDelete()
                }
            )
            .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        }
    }
}

private struct PetDeleteConfirmationSheet: View {
    let petName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool
    private var l: L10n { L10n(appLanguage) }

    private var canDelete: Bool {
        ConfirmationNameMatcher.matches(confirmName, expectedName: petName)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "彻底删除 \(petName)", en: "Delete \(petName)", de: "\(petName) löschen"))
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "输入名字后才能继续", en: "Type the name to continue", de: "Gib den Namen ein, um fortzufahren"))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "这会删除宠物和所有关联记录，无法撤销。",
                        en: "This deletes the pet and all linked records. It cannot be undone.",
                        de: "Dies löscht das Tier und alle verknüpften Einträge. Es kann nicht rückgängig gemacht werden."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text(l.tr(zh: "请输入：\(petName)", en: "Type: \(petName)", de: "Eingeben: \(petName)"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField(l.tr(zh: "宠物名字", en: "Pet name", de: "Tiername"), text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($confirmNameFocused)
                    .onSubmit { attemptDelete() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))
                    .accessibilityIdentifier("pet-delete-confirm-name-input")

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("pet-delete-confirm-cancel")

                    Button(action: attemptDelete) {
                        Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(canDelete ? Color.ohanaPrimaryActionText : Color.primary.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                    .accessibilityIdentifier("pet-delete-confirm-delete")
                }
            }
            .padding(20)
        }
    }

    private func attemptDelete() {
        guard canDelete else { return }
        confirmNameFocused = false
        onDelete()
    }
}
