//
//  SettingsView+Backup.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    // MARK: - Backup Section（TASK 1）
    @ViewBuilder
    var backupSection: some View {
        settingsSection(title: "数据备份") {
            VStack(spacing: 0) {
                // ── 导出行
                HStack(spacing: 10) {
                    settingsIcon("arrow.down.doc.fill", color: Color.goTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出备份")
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text("全量 JSON")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isExporting {
                        ProgressView().tint(Color.goTeal).scaleEffect(0.8)
                    } else if let url = exportedJSONURL {
                        ShareLink(item: url,
                                  subject: Text("Ohana 数据备份"),
                                  message: Text(l.tr(
                                      zh: "该备份包含健康、位置、用药和家庭资料等敏感信息，请只分享给可信对象。",
                                      en: "This backup contains sensitive health, location, medication, and family data. Share it only with trusted people.",
                                      de: "Dieses Backup enthält sensible Gesundheits-, Standort-, Medikamenten- und Familiendaten. Nur vertrauenswürdig teilen."
                                  ))) {
                            backupPill("分享", icon: "square.and.arrow.up", color: Color.goTeal)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Button {
                            isExporting = true
                            exportedJSONURL = nil
                            Task {
                                do {
                                    let password = try backupPasswordForExport()
                                    exportedJSONURL = try await appServices.backups
                                        .exportJSON(container: modelContext.container, password: password)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } catch {
                                    importError = error.localizedDescription
                                    showingImportErrorAlert = true
                                }
                                isExporting = false
                            }
                        } label: {
                            backupPill("生成备份", icon: "archivebox", color: Color.goTeal)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .frame(minHeight: 44)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill") // a11y: allow decorative icon covered by surrounding text
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.goYellow.opacity(0.8))
                    Text(l.tr(
                        zh: "备份包含健康、位置、用药和家庭资料。",
                        en: "Backups include health, location, medication, and family data.",
                        de: "Backups enthalten Gesundheits-, Standort-, Medikamenten- und Familiendaten."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(tertiaryText.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        settingsIcon("lock.fill", color: Color.goTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "密码加密", en: "Password encryption", de: "Passwortschutz"))
                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryText)
                            Text(l.tr(zh: "导出时可选，恢复加密备份时填写", en: "Optional for export; required to restore encrypted backups", de: "Optional beim Export, nötig für verschlüsselte Backups"))
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(tertiaryText)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { backupEncryptionEnabled },
                            set: {
                                backupEncryptionEnabled = $0
                                exportedJSONURL = nil
                            }
                        ))
                        .tint(Color.goTeal)
                        .labelsHidden()
                    }

                    VStack(spacing: 8) {
                        SecureField(l.tr(zh: "备份密码", en: "Backup password", de: "Backup-Passwort"), text: $backupPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)
                        if backupEncryptionEnabled {
                            SecureField(l.tr(zh: "确认密码", en: "Confirm password", de: "Passwort bestätigen"), text: $backupPasswordConfirmation)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.password)
                            Text(backupPasswordMinimumLengthHint)
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(backupPasswordIsBelowMinimum ? Color.goYellow : tertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .medium))
                    .foregroundStyle(primaryText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: backupPassword) { _, _ in exportedJSONURL = nil }
                    .onChange(of: backupPasswordConfirmation) { _, _ in exportedJSONURL = nil }
                }
                .frame(minHeight: 44)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 导入行
                HStack(spacing: 10) {
                    settingsIcon("square.and.arrow.down.fill", color: Color.goOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("从备份恢复")
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text("选择 .json")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isImporting {
                        ProgressView().tint(Color.goOrange).scaleEffect(0.8)
                    } else {
                        Button {
                            showingImportPicker = true
                        } label: {
                            backupPill("选择文件", icon: "folder", color: Color.goOrange)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .frame(minHeight: 44)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 说明行
                HStack(spacing: 8) {
                    Image(systemName: "info.circle") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goYellow.opacity(0.6))
                    Text("恢复会自动去重。")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case let .success(url):
                isImporting = true
                Task {
                    do {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        try await appServices.backups.importJSON(
                            from: url,
                            context: modelContext,
                            password: backupPasswordForImport()
                        )
                        showingImportSuccess = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        importError = error.localizedDescription
                        showingImportErrorAlert = true
                    }
                    isImporting = false
                }
            case let .failure(error):
                importError = error.localizedDescription
                showingImportErrorAlert = true
            }
        }
        .alert("恢复成功", isPresented: $showingImportSuccess) {
            Button("好的") {}
        } message: {
            Text("数据已成功导入，请重新进入 App 主页查看。")
        }
        .alert("操作失败", isPresented: $showingImportErrorAlert) {
            Button("好的") {}
        } message: {
            Text(importError ?? "未知错误")
        }
    }

    func backupPasswordForExport() throws -> String? {
        guard backupEncryptionEnabled else { return nil }
        let password = backupPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmation = backupPasswordConfirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else { throw BackupError.missingPassword }
        guard password.count >= DataBackupEncryption.minimumPasswordLength else {
            throw BackupError.weakPassword(minimum: DataBackupEncryption.minimumPasswordLength)
        }
        guard password == confirmation else { throw BackupError.passwordMismatch }
        return password
    }

    func backupPasswordForImport() -> String? {
        let password = backupPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        return password.isEmpty ? nil : password
    }

    var backupPasswordMinimumLengthHint: String {
        l.tr(
            zh: "至少 \(DataBackupEncryption.minimumPasswordLength) 位",
            en: "At least \(DataBackupEncryption.minimumPasswordLength) characters",
            de: "Mindestens \(DataBackupEncryption.minimumPasswordLength) Zeichen"
        )
    }

    var backupPasswordIsBelowMinimum: Bool {
        let password = backupPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        return !password.isEmpty && password.count < DataBackupEncryption.minimumPasswordLength
    }

    func backupPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(label).font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(color)
        .frame(minHeight: 34)
        .padding(.horizontal, 12)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.clear, lineWidth: 1))
    }
}
