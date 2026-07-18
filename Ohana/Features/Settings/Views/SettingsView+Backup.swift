//
//  SettingsView+Backup.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsBackupPage: View {
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage("ohana_has_onboarded") var hasOnboarded = false
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""
    @State var showingAppResetAlert = false
    @State var appResetErrorMessage: String?
    @State var exportedJSONURL: URL?
    @State var isExporting = false
    @State var isImporting = false
    @State var automaticBackupStatus = AutomaticBackupStatusStore().snapshot()
    @State var isRunningAutomaticBackup = false
    @State var isRetryingAutomaticBackupCleanup = false
    @State var isRemovingLegacyAutomaticBackup = false
    @State var automaticBackupCleanupError: String?
    @State var backupEncryptionEnabled = false
    @State var backupPassword = ""
    @State var backupPasswordConfirmation = ""
    @State var showingBackupSavePicker = false
    @State var showingImportPicker = false
    @State var importError: String?
    @State var showingImportSuccess = false
    @State var showingImportErrorAlert = false

    let onClose: () -> Void

    var l: L10n { L10n(appLanguage) }
    var primaryText: Color { Color.ohanaPrimaryText }
    var tertiaryText: Color { Color.ohanaTertiaryText }
    var dividerLine: Color { Color.ohanaDivider }

    var body: some View {
        Form {
            backupSection
            resetSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(OhanaStaticAppBackground())
        .navigationTitle(SettingsDestination.dataAndBackup.title(l))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .cancel, action: onClose) {
                    Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("settings-close-action")
            }
        }
        .alert(l.tr(zh: "重置 App", en: "Reset App", de: "App zurücksetzen"), isPresented: $showingAppResetAlert) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "重置", en: "Reset", de: "Zurücksetzen"), role: .destructive) { resetApp() }
        } message: {
            Text(l.tr(
                zh: "此操作将删除 App 内的成员、记录、提醒、任务、奖励和本地自定义内容，无法恢复。重置后会从引导页面重新开始。",
                en: "This deletes members, logs, reminders, tasks, rewards, and local custom content. It cannot be undone. After reset, Ohana starts from onboarding.",
                de: "Dies löscht Mitglieder, Einträge, Erinnerungen, Aufgaben, Belohnungen und lokale Anpassungen. Danach startet Ohana im Onboarding."
            ))
        }
        .alert(l.tr(zh: "重置失败", en: "Reset Failed", de: "Zurücksetzen fehlgeschlagen"), isPresented: Binding(
            get: { appResetErrorMessage != nil },
            set: { if !$0 { appResetErrorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) { appResetErrorMessage = nil }
        } message: {
            Text(appResetErrorMessage ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
        }
        .alert(l.tr(zh: "iCloud 备份需要处理", en: "iCloud Backup Needs Attention", de: "iCloud-Backup braucht Aufmerksamkeit"), isPresented: Binding(
            get: { automaticBackupCleanupError != nil },
            set: { if !$0 { automaticBackupCleanupError = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) { automaticBackupCleanupError = nil }
        } message: {
            Text(automaticBackupCleanupError ?? l.tr(zh: "请重试删除旧的自动备份。", en: "Retry removing the previous automatic backup.", de: "Versuche erneut, das vorherige automatische Backup zu entfernen."))
        }
        .accessibilityIdentifier("settings-data-backup-screen")
    }

    var resetSection: some View {
        settingsSection(title: l.tr(zh: "数据", en: "Data", de: "Daten")) {
            Button {
                showingAppResetAlert = true
            } label: {
                SettingsNavigationLabel(
                    icon: "arrow.counterclockwise.circle.fill",
                    title: l.tr(zh: "重置 App", en: "Reset App", de: "App zurücksetzen"),
                    subtitle: l.tr(zh: "删除数据并回到引导页", en: "Delete data and restart onboarding", de: "Daten löschen und Onboarding starten")
                )
            }
            .tint(Color.goRed)
        }
    }

    func resetApp() {
        Task { @MainActor in
            do {
                let resetResult = try await appServices.appReset.reset(context: modelContext)
                currentActiveHumanId = ""
                withAnimation(GoMotion.page) { hasOnboarded = false }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if case .pending = resetResult.humanNoteAttachmentCleanup {
                    appServices.islandToasts.show(l.tr(
                        zh: "App 数据已删除，但部分本地备注附件未能清理。请联系支持。",
                        en: "App data was deleted, but some local note attachments could not be removed. Contact support.",
                        de: "Die App-Daten wurden gelöscht, aber einige lokale Notizanhänge konnten nicht entfernt werden. Kontaktiere den Support."
                    ))
                }
                if case let .pending(message) = resetResult.automaticBackupCleanup {
                    automaticBackupCleanupError = message
                }
            } catch {
                appResetErrorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        Section { content() } header: { Text(title) }
    }

    func settingsIcon(_ icon: String, color _: Color) -> some View {
        SettingsDestinationIcon(systemName: icon)
    }
}

extension SettingsBackupPage {
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
                            zh: "受限备份包，媒体分离存储",
                            en: "Restricted backup package with separate media",
                            de: "Eingeschränktes Backup-Paket mit separaten Medien"
                        ))
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isExporting {
                        ProgressView().tint(Color.goTeal).scaleEffect(0.8)
                    } else if let url = exportedJSONURL {
                        VStack(alignment: .trailing, spacing: 6) {
                            Button {
                                showingBackupSavePicker = true
                            } label: {
                                backupPill(l.tr(zh: "保存到文件", en: "Save to Files", de: "In Dateien sichern"), icon: "folder", color: Color.goTeal)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            ShareLink(item: url,
                                      subject: Text(l.tr(zh: "Ohana 数据备份", en: "Ohana Data Backup", de: "Ohana Datensicherung")),
                                      message: Text(l.tr(
                                          zh: "该受限备份不包含人类健康、HealthKit、自由文本家庭任务或派生经济/账本侧车，但仍可能包含家庭、宠物、位置和账单等敏感资料，请只分享给可信对象。",
                                          en: "This restricted backup excludes human health, HealthKit, free-text family tasks, and derived economy/ledger sidecars, but it may still contain sensitive household, pet, location, and expense data. Share it only with trusted people.",
                                          de: "Dieses eingeschränkte Backup schließt menschliche Gesundheits- und HealthKit-Daten, Freitext-Familienaufgaben sowie abgeleitete Wirtschafts- und Buchungsdaten aus. Es kann weiterhin sensible Familien-, Haustier-, Standort- und Ausgabendaten enthalten. Teile es nur mit vertrauenswürdigen Personen."
                                      ))) {
                                backupPill(l.tr(zh: "分享", en: "Share", de: "Teilen"), icon: "square.and.arrow.up", color: Color.goTeal)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    } else {
                        Button {
                            isExporting = true
                            exportedJSONURL = nil
                            Task {
                                do {
                                    let password = try backupPasswordForExport()
                                    exportedJSONURL = try await appServices.backups
                                        .exportJSON(container: modelContext.container, password: password)
                                    showingBackupSavePicker = true
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

                if let url = exportedJSONURL {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative success icon covered by status text
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goTeal.opacity(0.85))
                            .accessibilityHidden(true)
                        Text(l.tr(
                            zh: "已生成 \(url.lastPathComponent)。请保存到“文件”，恢复时选择同一个 .ohanabackup。",
                            en: "\(url.lastPathComponent) is ready. Save it to Files, then choose the same .ohanabackup when restoring.",
                            de: "\(url.lastPathComponent) ist bereit. Sichere es in Dateien und wähle dieselbe .ohanabackup beim Wiederherstellen."
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(tertiaryText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill") // a11y: allow decorative icon covered by surrounding text
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.goYellow.opacity(0.8))
                    Text(l.tr(
                        zh: "导出和自动备份均不包含人类健康、HealthKit、体重、运动、用药、健康报告、自由文本家庭任务或派生经济/账本侧车；这些数据不会写入 iCloud 或其他文件服务。",
                        en: "Neither export nor automatic backup includes human health, HealthKit, weight, workout, medication, health-report data, free-text family tasks, or derived economy/ledger sidecars, so those records are not written to iCloud or another file provider.",
                        de: "Weder Export noch automatisches Backup enthalten menschliche Gesundheits-, HealthKit-, Gewichts-, Trainings-, Medikations- oder Gesundheitsberichtsdaten, Freitext-Familienaufgaben oder abgeleitete Wirtschafts- und Buchungsdaten. Diese Daten werden daher nicht in iCloud oder einen anderen Dateidienst geschrieben."
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
                            zh: "选择刚才保存的 .ohanabackup，旧 .json 仍可恢复",
                            en: "Choose the .ohanabackup you saved; legacy .json is still supported",
                            de: "Gespeicherte .ohanabackup auswählen; alte .json werden weiter unterstützt"
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
        .sheet(isPresented: $showingBackupSavePicker) {
            if let url = exportedJSONURL {
                BackupPackageFileExporter(url: url) { result in
                    handleBackupSaveCompletion(result)
                }
                .ignoresSafeArea()
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

            Text(l.tr(
                zh: "自动备份不会写入人类健康、HealthKit、体重、运动、用药、健康报告、自由文本家庭任务或派生经济/账本侧车；手动导出同样受此安全限制。",
                en: "Automatic backup excludes human health, HealthKit, weight, workout, medication, health-report data, free-text family tasks, and derived economy/ledger sidecars. Manual export has the same safety restriction.",
                de: "Das automatische Backup schließt menschliche Gesundheits-, HealthKit-, Gewichts-, Trainings-, Medikations- und Gesundheitsberichtsdaten, Freitext-Familienaufgaben sowie abgeleitete Wirtschafts- und Buchungsdaten aus. Für den manuellen Export gilt dieselbe Sicherheitsbeschränkung."
            ))
            .font(OhanaFont.adaptive(size: 11, weight: .medium))
            .foregroundStyle(tertiaryText.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            if automaticBackupStatus.requiresRestrictedBackupReplacement {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill") // a11y: allow decorative icon covered by safety warning text
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goYellow.opacity(0.9))
                            .accessibilityHidden(true)
                        Text(l.tr(
                            zh: "检测到早期版本的 Ohana 自动备份。它可能仍含有人类健康数据；请立即生成受限备份以原位替换，或删除旧备份。",
                            en: "An automatic backup from an earlier Ohana version was detected. It may still contain human health data; replace it now with a restricted backup or remove it.",
                            de: "Es wurde ein automatisches Backup aus einer früheren Ohana-Version erkannt. Es kann noch menschliche Gesundheitsdaten enthalten; ersetze es jetzt durch ein eingeschränktes Backup oder entferne es."
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(tertiaryText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        replaceLegacyAutomaticBackup()
                    } label: {
                        if isRunningAutomaticBackup {
                            ProgressView()
                                .tint(Color.goPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            backupPill(
                                l.tr(zh: "立即替换为受限备份", en: "Replace with Restricted Backup", de: "Durch eingeschränktes Backup ersetzen"),
                                icon: "arrow.triangle.2.circlepath",
                                color: Color.goPrimary
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isRunningAutomaticBackup || isRemovingLegacyAutomaticBackup)
                    .accessibilityHint(l.tr(
                        zh: "生成新的受限自动备份，并替换 Ohana 管理的旧 iCloud Drive 文件",
                        en: "Creates a restricted automatic backup and replaces Ohana's managed previous iCloud Drive file",
                        de: "Erstellt ein eingeschränktes automatisches Backup und ersetzt Ohanas verwaltete vorherige iCloud-Drive-Datei"
                    ))

                    Button {
                        removeLegacyAutomaticBackup()
                    } label: {
                        if isRemovingLegacyAutomaticBackup {
                            ProgressView()
                                .tint(Color.goRed)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            backupPill(
                                l.tr(zh: "删除旧自动备份", en: "Remove Previous Backup", de: "Vorheriges Backup entfernen"),
                                icon: "trash",
                                color: Color.goRed
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isRunningAutomaticBackup || isRemovingLegacyAutomaticBackup)
                    .accessibilityHint(l.tr(
                        zh: "删除 Ohana 管理的早期 iCloud Drive 自动备份",
                        en: "Removes Ohana's managed earlier automatic iCloud Drive backup",
                        de: "Entfernt Ohanas verwaltetes früheres automatisches iCloud-Drive-Backup"
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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

            if automaticBackupStatus.resetCleanupPending {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.slash.fill") // a11y: allow decorative icon covered by cleanup warning text
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goYellow.opacity(0.9))
                            .accessibilityHidden(true)
                        Text(l.tr(
                            zh: "上次重置已清除本机数据，但未能删除 iCloud Drive 中 Ohana 管理的旧自动备份。该文件可能仍保留原来的数据。",
                            en: "The last reset cleared this device, but could not remove Ohana's previous automatic backup from iCloud Drive. That file may still contain the earlier data.",
                            de: "Der letzte Reset hat dieses Gerät gelöscht, konnte aber Ohanas vorheriges automatisches Backup nicht aus iCloud Drive entfernen. Diese Datei kann noch frühere Daten enthalten."
                        ))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(tertiaryText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        retryAutomaticBackupCleanup()
                    } label: {
                        if isRetryingAutomaticBackupCleanup {
                            ProgressView()
                                .tint(Color.goPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            backupPill(
                                l.tr(zh: "重试删除旧备份", en: "Retry Backup Removal", de: "Backup-Loeschung erneut versuchen"),
                                icon: "trash",
                                color: Color.goPrimary
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isRetryingAutomaticBackupCleanup)
                    .accessibilityHint(l.tr(
                        zh: "重新尝试删除重置前的 iCloud Drive 自动备份",
                        en: "Attempts to remove the automatic iCloud Drive backup from before the reset",
                        de: "Versucht erneut, das automatische iCloud-Drive-Backup vor dem Reset zu entfernen"
                    ))
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
            ? l.tr(zh: "每天保存受限数据到 iCloud Drive 文件", en: "Daily restricted-data file in iCloud Drive", de: "Tägliche Datei mit eingeschränkten Daten in iCloud Drive")
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
            case .skipped(.cancelledByReset):
                break
            }
            isRunningAutomaticBackup = false
        }
    }

    func retryAutomaticBackupCleanup() {
        guard !isRetryingAutomaticBackupCleanup else { return }
        isRetryingAutomaticBackupCleanup = true
        Task {
            let result = await appServices.automaticBackups.retryManagedAutomaticBackupCleanup()
            refreshAutomaticBackupStatus()
            switch result {
            case .removed:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appServices.islandToasts.show(l.tr(
                    zh: "旧自动备份已删除",
                    en: "Previous automatic backup removed",
                    de: "Vorheriges automatisches Backup entfernt"
                ))
            case let .pending(message):
                automaticBackupCleanupError = message
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .notRequested:
                break
            }
            isRetryingAutomaticBackupCleanup = false
        }
    }

    func replaceLegacyAutomaticBackup() {
        guard !isRunningAutomaticBackup, !isRemovingLegacyAutomaticBackup else { return }
        if !automaticBackupStatus.isEnabled {
            appServices.automaticBackups.setEnabled(true, now: Date())
            refreshAutomaticBackupStatus()
        }
        runAutomaticBackupNow()
    }

    func removeLegacyAutomaticBackup() {
        guard !isRunningAutomaticBackup, !isRemovingLegacyAutomaticBackup else { return }
        isRemovingLegacyAutomaticBackup = true
        Task {
            let result = await appServices.automaticBackups.removeLegacyAutomaticBackupForHealthSafety()
            refreshAutomaticBackupStatus()
            switch result {
            case .removed:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appServices.islandToasts.show(l.tr(
                    zh: "旧自动备份已删除",
                    en: "Previous automatic backup removed",
                    de: "Vorheriges automatisches Backup entfernt"
                ))
            case let .pending(message):
                automaticBackupCleanupError = message
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .notRequested:
                break
            }
            isRemovingLegacyAutomaticBackup = false
        }
    }

    func handleBackupSaveCompletion(_ result: Result<[URL], Error>) {
        showingBackupSavePicker = false
        switch result {
        case let .success(urls):
            guard let savedURL = urls.first else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appServices.islandToasts.show(l.tr(
                zh: "已保存：\(savedURL.lastPathComponent)",
                en: "Saved: \(savedURL.lastPathComponent)",
                de: "Gesichert: \(savedURL.lastPathComponent)"
            ))
        case let .failure(error):
            importError = error.localizedDescription
            showingImportErrorAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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

private struct BackupPackageFileExporter: UIViewControllerRepresentable {
    let url: URL
    let onCompletion: (Result<[URL], Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .formSheet
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (Result<[URL], Error>) -> Void

        init(onCompletion: @escaping (Result<[URL], Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion(.success(urls))
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCompletion(.success([]))
        }
    }
}
