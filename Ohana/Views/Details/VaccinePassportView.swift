//
//  VaccinePassportView.swift
//  Ohana
//
//  N1: 疫苗本 — 管理宠物所有疫苗记录，支持添加/到期提醒
//

import SwiftUI
import SwiftData

struct VaccinePassportView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingAdd = false
    @State private var deletingLogIDs: Set<UUID> = []

    private var l: L10n { L10n(appLanguage) }

    private var vaccineLogs: [PetHealthLog] {
        pet.healthLogs
            .filter { $0.type == HealthLogType.vaccine.rawValue }
            .sorted { $0.date > $1.date }
    }

    private var latestVaccineLog: PetHealthLog? {
        vaccineLogs.first
    }

    private var nextExpiryLog: PetHealthLog? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return vaccineLogs
            .filter { $0.expirationDate != nil }
            .sorted { lhs, rhs in
                let lhsDays = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: lhs.expirationDate ?? .distantFuture)).day ?? Int.max
                let rhsDays = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: rhs.expirationDate ?? .distantFuture)).day ?? Int.max
                if lhsDays < 0 && rhsDays < 0 { return lhsDays > rhsDays }
                if lhsDays < 0 { return true }
                if rhsDays < 0 { return false }
                return lhsDays < rhsDays
            }
            .first
    }

    private var nextExpiryStatus: (text: String, color: Color) {
        guard let log = nextExpiryLog, let expiry = log.expirationDate else {
            return (l.tr(zh: "未设置到期", en: "No expiry set", de: "Kein Ablaufdatum"), Color.ohanaSecondaryText)
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        if days < 0 {
            return (l.tr(zh: "已过期 \(abs(days)) 天", en: "\(abs(days))d overdue", de: "\(abs(days))T überfällig"), Color.goRed)
        }
        if days == 0 {
            return (l.tr(zh: "今天到期", en: "Expires today", de: "Läuft heute ab"), Color.goYellow)
        }
        if days <= 30 {
            return (l.tr(zh: "\(days) 天后到期", en: "Expires in \(days)d", de: "In \(days)T fällig"), Color.goYellow)
        }
        return (expiry.formatted(.dateTime.year().month().day()), Color.ohanaFunctionalIcon)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    pageHeader
                    summaryStrip

                    if vaccineLogs.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(vaccineLogs) { log in
                                VaccineRow(log: log, onDelete: { delete(log) })
                            }
                        }
                    }

                    Spacer(minLength: 98)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addFab
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            AddVaccineSheet(pet: pet)
        }
    }

    private func delete(_ log: PetHealthLog) {
        guard !deletingLogIDs.contains(log.id) else { return }
        deletingLogIDs.insert(log.id)
        let command = DomainCommand.petHealthDelete(
            petID: pet.id,
            kind: "vaccine",
            recordID: log.id
        )

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            PetHealthCommandExecutor(context: modelContext).deleteHealthLog(
                log,
                pet: pet,
                note: "pet.vaccine.delete"
            )
            deletingLogIDs.remove(log.id)
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 46,
                backgroundOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "疫苗本", en: "Vaccine passport", de: "Impfpass"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 4)
    }

    private var summaryStrip: some View {
        HStack(alignment: .top, spacing: 18) {
            passportMetric(
                title: l.tr(zh: "记录", en: "Records", de: "Einträge"),
                value: "\(vaccineLogs.count)",
                detail: l.tr(zh: "针", en: "shots", de: "Impfungen")
            )
            passportMetric(
                title: l.tr(zh: "最近一针", en: "Latest", de: "Zuletzt"),
                value: latestVaccineLog?.date.formatted(.dateTime.month().day()) ?? "--",
                detail: latestVaccineLog?.note.isEmpty == false ? (latestVaccineLog?.note ?? "") : l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")
            )
            passportMetric(
                title: l.tr(zh: "到期", en: "Expiry", de: "Ablauf"),
                value: nextExpiryStatus.text,
                detail: nextExpiryLog?.note.isEmpty == false ? (nextExpiryLog?.note ?? "") : l.tr(zh: "有效期", en: "Validity", de: "Gültigkeit"),
                tint: nextExpiryStatus.color
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func passportMetric(title: String, value: String, detail: String, tint: Color = Color.ohanaPrimaryText) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(detail)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Button {
            showingAdd = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "syringe.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.ohanaFunctionalIcon)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "添加第一针疫苗", en: "Add first vaccine", de: "Erste Impfung hinzufügen"))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "记录名称、日期和有效期", en: "Name, date, validity", de: "Name, Datum, Gültigkeit"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 34, height: 34)
                    .background(Color.goPrimary, in: Circle())
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var addFab: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 58, height: 58)
                .background(Color.goPrimary, in: Circle())
                .shadow(color: Color.goPrimary.opacity(0.24), radius: 18, x: 0, y: 10) // ui-v4: allow floating FAB lift shadow
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加疫苗", en: "Add vaccine", de: "Impfung hinzufügen"))
    }
}

// MARK: - Vaccine Row
private struct VaccineRow: View {
    let log: PetHealthLog
    let onDelete: () -> Void
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    private var daysUntilExpiry: Int? {
        guard let exp = log.expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    private var statusColor: Color {
        guard let days = daysUntilExpiry else { return .primary.opacity(0.3) }
        if days < 0 { return Color.goRed }
        if days <= 30 { return Color.goYellow }
        return Color.ohanaFunctionalIcon
    }

    private var statusLabel: String {
        guard let days = daysUntilExpiry else {
            return l.tr(zh: "未设置有效期", en: "No expiry", de: "Kein Ablaufdatum")
        }
        if days < 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if days <= 30 {
            return days == 0
                ? l.tr(zh: "今日到期", en: "Expires today", de: "Läuft heute ab")
                : l.tr(zh: "\(days)天后到期", en: "In \(days)d", de: "In \(days)T")
        }
        return l.tr(zh: "有效中", en: "Valid", de: "Gültig")
    }

    private var expiryDateText: String {
        guard let expiryDate = log.expirationDate else {
            return l.tr(zh: "未设置到期日", en: "No expiry date", de: "Kein Ablaufdatum")
        }
        return expiryDate.formatted(.dateTime.year().month().day())
    }

    private var validityLengthText: String {
        guard let expiryDate = log.expirationDate else {
            return l.tr(zh: "未设置有效期", en: "No validity set", de: "Keine Gültigkeit")
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: log.date)
        let end = calendar.startOfDay(for: expiryDate)
        guard end >= start else {
            return l.tr(zh: "日期异常", en: "Check dates", de: "Datum prüfen")
        }
        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        if let years = components.year, years > 0 {
            let months = components.month ?? 0
            if months > 0 {
                return l.tr(zh: "\(years)年\(months)个月", en: "\(years)y \(months)m", de: "\(years)J \(months)M")
            }
            return l.tr(zh: "\(years)年", en: "\(years)y", de: "\(years)J")
        }
        if let months = components.month, months > 0 {
            return l.tr(zh: "\(months)个月", en: "\(months)m", de: "\(months)M")
        }
        let days = max(0, components.day ?? 0)
        return l.tr(zh: "\(days)天", en: "\(days)d", de: "\(days)T")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Text(log.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaFunctionalIcon)
                Text(log.date.formatted(.dateTime.year()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(width: 42)

            Rectangle()
                .fill(Color.ohanaDivider)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 9) {
                Text(log.note.isEmpty ? l.tr(zh: "疫苗接种", en: "Vaccine", de: "Impfung") : log.note)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    rowInfoPill(title: l.tr(zh: "有效期", en: "Valid", de: "Gültig"), value: validityLengthText)
                    rowInfoPill(title: l.tr(zh: "到期", en: "Expiry", de: "Ablauf"), value: expiryDateText)
                }

                HStack(spacing: 8) {
                    if !log.vetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        rowInlineMeta(icon: "stethoscope", text: log.vetName)
                    }
                    if log.cost > 0 {
                        rowInlineMeta(icon: AppCurrency.systemIconName, text: AppCurrency.format(log.cost, fractionDigits: 0))
                    }
                }
            }

            Spacer()

            Text(statusLabel)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(statusColor.opacity(0.14), in: Capsule())
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label(l.tr(zh: "删除记录", en: "Delete record", de: "Eintrag löschen"), systemImage: "trash")
            }
        }
    }

    private func rowInfoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func rowInlineMeta(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.ohanaFunctionalIcon)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
    }
}

// MARK: - Add Vaccine Sheet
struct AddVaccineSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var vaccineName: String = ""
    @State private var date: Date = Date()
    @State private var hasExpiry: Bool = false
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var vetName: String = ""
    @State private var costText: String = ""
    @State private var reminderDaysBefore: Int = 7
    @State private var enableReminder: Bool = true
    @State private var isSaving = false

    private let reminderOptions = [3, 7, 14, 30]
    private var l: L10n { L10n(appLanguage) }
    private var canSave: Bool {
        !isSaving && !vaccineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var vaccineSuggestions: [String] {
        if pet.species == "猫" {
            return [
                l.tr(zh: "猫三联", en: "FVRCP", de: "Katzenseuche/-schnupfen"),
                l.tr(zh: "狂犬疫苗", en: "Rabies", de: "Tollwut"),
                l.tr(zh: "猫白血病", en: "FeLV", de: "FeLV")
            ]
        }
        if pet.species == "狗" {
            return [
                l.tr(zh: "犬四联", en: "DHPP", de: "DHPP"),
                l.tr(zh: "狂犬疫苗", en: "Rabies", de: "Tollwut"),
                l.tr(zh: "犬窝咳", en: "Kennel Cough", de: "Zwingerhusten")
            ]
        }
        return [
            l.tr(zh: "核心疫苗", en: "Core Vaccine", de: "Kernimpfung"),
            l.tr(zh: "加强针", en: "Booster", de: "Auffrischung"),
            l.tr(zh: "体检接种", en: "Checkup Vaccine", de: "Impfung beim Check-up")
        ]
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        vaccineNameSection
                        dateSection
                        if hasExpiry {
                            reminderSection
                        }
                        clinicSection
                        costSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 46,
                backgroundOpacity: 0.16
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "添加疫苗", en: "Add Vaccine", de: "Impfung hinzufügen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var vaccineNameSection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"), icon: "syringe.fill", tint: Color.goTeal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vaccineSuggestions, id: \.self) { suggestion in
                            Button {
                                withAnimation(GoMotion.feedback) { vaccineName = suggestion }
                            } label: {
                                Text(suggestion)
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(vaccineName == suggestion ? Color.arkInk : Color.ohanaPrimaryText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(vaccineName == suggestion ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 24)
                    TextField(l.tr(zh: "自定义疫苗名称", en: "Custom vaccine name", de: "Eigener Impfstoffname"), text: $vaccineName)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .padding(12)
                .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var dateSection: some View {
        VStack(spacing: 10) {
            formBlock {
                HStack(spacing: 10) {
                    sectionLabel(l.tr(zh: "接种日期", en: "Vaccination Date", de: "Impfdatum"), icon: "calendar.badge.checkmark", tint: Color.goPrimary)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                }
            }

            formBlock {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        sectionLabel(l.tr(zh: "有效期", en: "Validity", de: "Gültigkeit"), icon: "clock.badge.checkmark", tint: Color.goYellow)
                        Spacer()
                        Button {
                            withAnimation(GoMotion.feedback) { hasExpiry.toggle() }
                        } label: {
                            Text(hasExpiry ? l.tr(zh: "清除", en: "Clear", de: "Leeren") : l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(hasExpiry ? Color.ohanaPrimaryText : Color.arkInk)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(hasExpiry ? Color.ohanaCardSurfaceElevated : Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    if hasExpiry {
                        DatePicker("", selection: $expiryDate, in: date..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.goYellow)
                    } else {
                        Text(l.tr(zh: "可选。没有有效期时只保存接种记录。", en: "Optional. Without an expiry date, only the vaccination record is saved.", de: "Optional. Ohne Ablaufdatum wird nur der Impfeintrag gespeichert."))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
        }
    }

    private var reminderSection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    sectionLabel(l.tr(zh: "到期提醒", en: "Reminder", de: "Erinnerung"), icon: "bell.badge.fill", tint: Color.goYellow)
                    Spacer()
                    Button {
                        withAnimation(GoMotion.feedback) { enableReminder.toggle() }
                    } label: {
                        Image(systemName: enableReminder ? "bell.fill" : "bell.slash.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(enableReminder ? Color.arkInk : Color.ohanaSecondaryText)
                            .frame(width: 44, height: 32)
                            .background(enableReminder ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                if enableReminder {
                    HStack(spacing: 8) {
                        ForEach(reminderOptions, id: \.self) { days in
                            Button {
                                withAnimation(GoMotion.feedback) { reminderDaysBefore = days }
                            } label: {
                                Text(l.tr(zh: "\(days)天", en: "\(days)d", de: "\(days)T"))
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(reminderDaysBefore == days ? Color.arkInk : Color.ohanaPrimaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(reminderDaysBefore == days ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var clinicSection: some View {
        formBlock {
            HStack(spacing: 10) {
                sectionLabel(l.tr(zh: "诊所", en: "Clinic", de: "Praxis"), icon: "stethoscope", tint: Color.goTeal)
                TextField(l.tr(zh: "医生 / 诊所（可选）", en: "Vet / clinic (optional)", de: "Tierarzt / Praxis (optional)"), text: $vetName)
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
    }

    private var costSection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(l.tr(zh: "费用", en: "Cost", de: "Kosten"), icon: AppCurrency.systemIconName, tint: Color.goYellow)
                InlineNumericInput(
                    text: $costText,
                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                    unit: AppCurrency.symbol,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    step: 10,
                    valueFont: .system(size: 18, weight: .black, design: .rounded),
                    valueAlignment: .leading,
                    fill: Color.ohanaCardSurfaceElevated,
                    cornerRadius: 18,
                    horizontalPadding: 12,
                    verticalPadding: 10,
                    usesMiniKeypad: true
                )
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Button(action: save) {
                Text(l.tr(zh: "保存疫苗记录", en: "Save Vaccine", de: "Impfung sichern"))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.clear)
        }
    }

    private func sectionLabel(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
            Text(title)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func formBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let input = PetHealthRecordCommandInput(
            type: .vaccine,
            date: date,
            name: vaccineName,
            note: "",
            vetName: vetName,
            cost: CountryDecimalInput.parse(costText, countryCode: AppCountry.code) ?? 0,
            expirationDate: hasExpiry ? expiryDate : nil,
            nextCheckupDate: nil,
            executorId: executorId,
            source: .detail,
            includesNameInNote: true,
            expirationReminderLeadDays: (hasExpiry && enableReminder) ? reminderDaysBefore : nil
        )
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: HealthLogType.vaccine.rawValue)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            PetHealthCommandExecutor(context: modelContext).recordHealth(
                pet: pet,
                input: input,
                note: "pet.vaccine.record"
            )
            dismiss()
        }
    }
}
