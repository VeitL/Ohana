//
//  SettingsView+Backup.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    // MARK: - Backup Section
    @ViewBuilder
    var backupSection: some View {
        settingsSection(title: l.tr(zh: "数据备份", en: "Data Backup", de: "Datensicherung")) {
            VStack(spacing: 0) {
                automaticBackupControls

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 导出行
                HStack(spacing: 10) {
                    settingsIcon("arrow.down.doc.fill", color: Color.goTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "导出备份", en: "Export Backup", de: "Backup exportieren"))
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "备份包，媒体分离存储",
                            en: "Backup package with separate media",
                            de: "Backup-Paket mit separaten Medien"
                        ))
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isExporting {
                        ProgressView().tint(Color.goTeal).scaleEffect(0.8)
                    } else if let url = exportedJSONURL {
                        ShareLink(item: url,
                                  subject: Text(l.tr(zh: "Ohana 数据备份", en: "Ohana Data Backup", de: "Ohana Datensicherung")),
                                  message: Text(l.tr(
                                      zh: "该备份包含健康、位置、用药和家庭资料等敏感信息，请只分享给可信对象。",
                                      en: "This backup contains sensitive health, location, medication, and family data. Share it only with trusted people.",
                                      de: "Dieses Backup enthält sensible Gesundheits-, Standort-, Medikamenten- und Familiendaten. Nur vertrauenswürdig teilen."
                                  ))) {
                            backupPill(l.tr(zh: "分享", en: "Share", de: "Teilen"), icon: "square.and.arrow.up", color: Color.goTeal)
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
                            backupPill(l.tr(zh: "生成备份", en: "Create Backup", de: "Backup erstellen"), icon: "archivebox", color: Color.goTeal)
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
                        Text(l.tr(zh: "从备份恢复", en: "Restore from Backup", de: "Aus Backup wiederherstellen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "选择 .ohanabackup，旧 .json 仍可恢复",
                            en: "Choose .ohanabackup; legacy .json is still supported",
                            de: ".ohanabackup auswählen; alte .json werden weiter unterstützt"
                        ))
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
                            backupPill(l.tr(zh: "选择文件", en: "Choose File", de: "Datei wählen"), icon: "folder", color: Color.goOrange)
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
                    Text(l.tr(zh: "恢复会自动去重。", en: "Restore automatically deduplicates records.", de: "Die Wiederherstellung entfernt Duplikate automatisch."))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: backupImportContentTypes
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
        .alert(l.tr(zh: "恢复成功", en: "Restore Complete", de: "Wiederherstellung abgeschlossen"), isPresented: $showingImportSuccess) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK")) {}
        } message: {
            Text(l.tr(zh: "数据已成功导入，请重新进入 App 主页查看。", en: "Data was imported successfully. Reopen the app home to review it.", de: "Die Daten wurden erfolgreich importiert. Öffne die App-Startseite erneut, um sie zu prüfen."))
        }
        .alert(l.tr(zh: "操作失败", en: "Action Failed", de: "Aktion fehlgeschlagen"), isPresented: $showingImportErrorAlert) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK")) {}
        } message: {
            Text(importError ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
        }
        .onAppear {
            refreshAutomaticBackupStatus()
            showAutomaticBackupReminderIfNeeded()
        }
    }

    var backupImportContentTypes: [UTType] {
        var types: [UTType] = [.json, .directory]
        if let packageType = UTType(filenameExtension: DataBackupPackageFormat.packageFileExtension) {
            types.append(packageType)
        }
        return types
    }

    @ViewBuilder
    var automaticBackupControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                settingsIcon("icloud.and.arrow.up.fill", color: Color.goBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "自动备份", en: "Automatic backup", de: "Automatisches Backup"))
                        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text(automaticBackupSubtitle)
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { automaticBackupStatus.isEnabled },
                    set: { enabled in
                        appServices.automaticBackups.setEnabled(enabled, now: Date())
                        refreshAutomaticBackupStatus()
                    }
                ))
                .tint(Color.goBlue)
                .labelsHidden()
            }
            .frame(minHeight: 44)

            HStack(spacing: 8) {
                Image(systemName: automaticBackupStatusIcon)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                    .foregroundStyle(automaticBackupStatusColor.opacity(0.85))
                Text(automaticBackupStatusText)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(tertiaryText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if isRunningAutomaticBackup {
                    ProgressView().tint(Color.goBlue).scaleEffect(0.8)
                } else {
                    Button {
                        runAutomaticBackupNow()
                    } label: {
                        backupPill(l.tr(zh: "立即备份", en: "Back Up Now", de: "Jetzt sichern"), icon: "arrow.clockwise", color: Color.goBlue)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!automaticBackupStatus.isEnabled)
                    .opacity(automaticBackupStatus.isEnabled ? 1 : 0.45)
                }
            }
            .frame(minHeight: 34)

            if automaticBackupHasCurrentFailure {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by failure message text
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.goYellow.opacity(0.9))
                        .accessibilityHidden(true)
                    Text(automaticBackupStatus.lastFailureMessage ?? l.tr(
                        zh: "自动备份失败，请稍后重试。",
                        en: "Automatic backup failed. Try again later.",
                        de: "Das automatische Backup ist fehlgeschlagen."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(tertiaryText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    var automaticBackupSubtitle: String {
        automaticBackupStatus.isEnabled
            ? l.tr(zh: "每天自动保存到 iCloud Drive 文件", en: "Daily file in iCloud Drive", de: "Tägliche Datei in iCloud Drive")
            : l.tr(zh: "已关闭", en: "Off", de: "Aus")
    }

    var automaticBackupStatusText: String {
        if !automaticBackupStatus.isEnabled {
            return l.tr(zh: "自动备份已关闭。", en: "Automatic backup is off.", de: "Automatisches Backup ist aus.")
        }
        if automaticBackupHasCurrentFailure, let failureDate = automaticBackupStatus.lastFailureAt {
            return l.tr(
                zh: "上次尝试失败：\(automaticBackupDateText(failureDate))",
                en: "Last attempt failed: \(automaticBackupDateText(failureDate))",
                de: "Letzter Versuch fehlgeschlagen: \(automaticBackupDateText(failureDate))"
            )
        }
        if let successDate = automaticBackupStatus.lastSuccessAt {
            return l.tr(
                zh: "上次成功：\(automaticBackupDateText(successDate))",
                en: "Last success: \(automaticBackupDateText(successDate))",
                de: "Letzter Erfolg: \(automaticBackupDateText(successDate))"
            )
        }
        return l.tr(zh: "尚未完成首次自动备份。", en: "No automatic backup yet.", de: "Noch kein automatisches Backup.")
    }

    var automaticBackupStatusIcon: String {
        if !automaticBackupStatus.isEnabled { return "pause.circle.fill" }
        if automaticBackupHasCurrentFailure { return "exclamationmark.circle.fill" }
        if automaticBackupStatus.lastSuccessAt != nil { return "checkmark.circle.fill" }
        return "clock.fill"
    }

    var automaticBackupStatusColor: Color {
        if !automaticBackupStatus.isEnabled { return tertiaryText }
        if automaticBackupHasCurrentFailure { return Color.goYellow }
        if automaticBackupStatus.lastSuccessAt != nil { return Color.goTeal }
        return Color.goBlue
    }

    var automaticBackupHasCurrentFailure: Bool {
        guard let failureDate = automaticBackupStatus.lastFailureAt else { return false }
        guard let successDate = automaticBackupStatus.lastSuccessAt else { return true }
        return failureDate >= successDate
    }

    func automaticBackupDateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func refreshAutomaticBackupStatus() {
        automaticBackupStatus = appServices.automaticBackups.snapshot(now: Date())
    }

    func runAutomaticBackupNow() {
        guard !isRunningAutomaticBackup else { return }
        isRunningAutomaticBackup = true
        Task {
            let result = await appServices.automaticBackups.runNow(
                container: modelContext.container,
                trigger: .settingsManual
            )
            refreshAutomaticBackupStatus()
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appServices.islandToasts.show(l.tr(
                    zh: "自动备份已完成",
                    en: "Automatic backup completed",
                    de: "Automatisches Backup abgeschlossen"
                ))
            case let .failure(_, message):
                importError = message
                showingImportErrorAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .skipped(.alreadyRunning):
                appServices.islandToasts.show(l.tr(
                    zh: "自动备份正在进行",
                    en: "Automatic backup is already running",
                    de: "Automatisches Backup läuft bereits"
                ))
            case .skipped(.disabled):
                appServices.islandToasts.show(l.tr(
                    zh: "请先打开自动备份",
                    en: "Turn on automatic backup first",
                    de: "Automatisches Backup zuerst aktivieren"
                ))
            case .skipped(.notDue):
                appServices.islandToasts.show(l.tr(
                    zh: "今天已经备份过",
                    en: "Already backed up today",
                    de: "Heute bereits gesichert"
                ))
            }
            isRunningAutomaticBackup = false
        }
    }

    func showAutomaticBackupReminderIfNeeded() {
        let now = Date()
        let status = appServices.automaticBackups.snapshot(now: now)
        automaticBackupStatus = status
        guard status.shouldShowGentleReminder(now: now) else { return }
        appServices.islandToasts.show(l.tr(
            zh: "自动备份需要你看一眼",
            en: "Automatic backup needs attention",
            de: "Automatisches Backup braucht Aufmerksamkeit"
        ))
        appServices.automaticBackups.markReminderShown(now: now)
        refreshAutomaticBackupStatus()
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
