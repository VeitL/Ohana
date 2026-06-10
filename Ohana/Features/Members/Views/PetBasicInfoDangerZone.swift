//
//  PetBasicInfoDangerZone.swift
//  Ohana
//

import SwiftUI

struct PetBasicInfoDangerZone: View {
    let petName: String
    let onClear: () -> Void
    let onDelete: () -> Void

    @State private var showingClearConfirm = false
    @State private var showingDeleteSheet = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text("危险区域")
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
                    Text("仅清空所有记录")
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.goOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goOrange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                showingDeleteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("彻底删除 \(petName)")
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 8)
        .alert("仅清空所有记录", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空记录", role: .destructive) { onClear() }
        } message: {
            Text("将删除 \(petName) 的护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录，并移除日历中该宠物的计划；保留名字、头像、品种与证件/保险档案。此操作不可撤销。")
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

    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool

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
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("彻底删除 \(petName)")
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("输入名字后才能继续")
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
                    Text("这会删除宠物和所有关联记录，无法撤销。")
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text("请输入：\(petName)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField("宠物名字", text: $confirmName)
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($confirmNameFocused)
                    .onSubmit { attemptDelete() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: attemptDelete) {
                        Text("删除")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(canDelete ? Color.ohanaPrimaryActionText : Color.primary.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                }
            }
            .padding(20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                confirmNameFocused = true
            }
        }
    }

    private func attemptDelete() {
        guard canDelete else { return }
        confirmNameFocused = false
        onDelete()
    }
}
