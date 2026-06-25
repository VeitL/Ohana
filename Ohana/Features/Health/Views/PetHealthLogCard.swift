//
//  PetHealthLogCard.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct PetHealthLogCard: View {
    let pet: Pet
    let healthLogs: [PetHealthLog]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var showingAllLogs = false
    private var l: L10n { L10n(appLanguage) }

    init(pet: Pet, healthLogs: [PetHealthLog] = []) {
        self.pet = pet
        self.healthLogs = healthLogs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goRed)
                Text(l.tr(zh: "健康日志", en: "Health Log", de: "Gesundheitsprotokoll"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(l.tr(
                    zh: "\(healthLogs.count) 条",
                    en: "\(healthLogs.count) records",
                    de: "\(healthLogs.count) Einträge"
                ))
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }

            let recentLogs = healthLogs.sorted { $0.date > $1.date }.prefix(5)
            ForEach(Array(recentLogs)) { log in
                HStack(spacing: 10) {
                    Text(log.healthLogType.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(healthLogTypeTitle(log.healthLogType, l: l))
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        if !log.note.isEmpty {
                            Text(log.note)
                                .font(OhanaFont.adaptive(size: 12))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                .lineLimit(1)
                        }
                        // 显示有效期
                        if let expirationDate = log.expirationDate {
                            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                            let isExpired = daysUntil <= 0
                            let isUrgent = daysUntil <= 7 && daysUntil > 0

                            HStack(spacing: 4) {
                                Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "calendar")
                                    .font(OhanaFont.adaptive(size: 10))
                                Text(expirationStatusText(daysUntil: daysUntil, expirationDate: expirationDate))
                                    .font(OhanaFont.adaptive(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isExpired ? Color.goRed : (isUrgent ? Color.goYellow : .primary.opacity(0.5)))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((isExpired ? Color.goRed : (isUrgent ? Color.goYellow : .primary.opacity(0.08))).opacity(0.2), in: Capsule())
                        }

                        // 显示下次体检提醒（仅体检记录）
                        if log.healthLogType == .checkup, let nextCheckupDate = log.nextCheckupDate {
                            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextCheckupDate).day ?? 0
                            let isOverdue = daysUntil <= 0
                            let isSoon = daysUntil <= 30 && daysUntil > 0

                            HStack(spacing: 4) {
                                Image(systemName: "bell.circle").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 10))
                                Text(checkupStatusText(daysUntil: daysUntil, nextCheckupDate: nextCheckupDate))
                                    .font(OhanaFont.adaptive(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isOverdue ? Color.goRed : (isSoon ? Color.goYellow : Color.goTeal))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((isOverdue ? Color.goRed : (isSoon ? Color.goYellow : Color.goTeal)).opacity(0.15), in: Capsule())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(log.date, style: .date)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        if log.cost > 0 {
                            Text(AppCurrency.format(log.cost, fractionDigits: 0))
                                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                                .foregroundStyle(Color.goYellow)
                        }
                    }
                }
            }

            if healthLogs.isEmpty {
                Text(l.tr(zh: "暂无健康日志", en: "No health logs yet", de: "Noch keine Gesundheitseinträge"))
                    .font(OhanaFont.adaptive(size: 13, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            if healthLogs.count > 5 {
                Button { showingAllLogs = true } label: {
                    HStack(spacing: 4) {
                        Text(l.tr(
                            zh: "查看全部 \(healthLogs.count) 条",
                            en: "View all \(healthLogs.count)",
                            de: "Alle \(healthLogs.count) anzeigen"
                        ))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
        .navigationDestination(isPresented: $showingAllLogs) {
            HealthLogListView(pet: pet, healthLogs: healthLogs)
        }
    }

    private func expirationStatusText(daysUntil: Int, expirationDate: Date) -> String {
        if daysUntil <= 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if daysUntil <= 7 {
            return l.tr(zh: "剩余\(daysUntil)天", en: "\(daysUntil)d left", de: "\(daysUntil) T. übrig")
        }
        return l.tr(
            zh: "有效期至\(expirationDate.formatted(.dateTime.month().day()))",
            en: "Valid until \(expirationDate.formatted(.dateTime.month().day()))",
            de: "Gültig bis \(expirationDate.formatted(.dateTime.month().day()))"
        )
    }

    private func checkupStatusText(daysUntil: Int, nextCheckupDate: Date) -> String {
        if daysUntil <= 0 {
            return l.tr(zh: "体检已过期", en: "Checkup overdue", de: "Check-up überfällig")
        }
        if daysUntil <= 30 {
            return l.tr(zh: "体检剩余\(daysUntil)天", en: "\(daysUntil)d until checkup", de: "\(daysUntil) T. bis Check-up")
        }
        return l.tr(
            zh: "下次体检\(nextCheckupDate.formatted(.dateTime.month().day()))",
            en: "Next checkup \(nextCheckupDate.formatted(.dateTime.month().day()))",
            de: "Nächster Check-up \(nextCheckupDate.formatted(.dateTime.month().day()))"
        )
    }
}

// MARK: - Full Health Log List
struct HealthLogListView: View {
    let pet: Pet
    let healthLogs: [PetHealthLog]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var selectedType: HealthLogType? = nil
    private var l: L10n { L10n(appLanguage) }

    private var filteredLogs: [PetHealthLog] {
        let sorted = healthLogs.sorted { $0.date > $1.date }
        guard let type = selectedType else { return sorted }
        return sorted.filter { $0.type == type.rawValue }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    typeFilterChips
                        .padding(.horizontal, 16)
                    ForEach(filteredLogs) { log in
                        healthLogRow(log)
                            .padding(.horizontal, 16)
                    }
                    if filteredLogs.isEmpty {
                        Text(l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge"))
                            .font(OhanaFont.adaptive(size: 14, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            .padding(.top, 40)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(l.tr(
            zh: "\(pet.name) 健康日志",
            en: "\(pet.name) Health Log",
            de: "\(pet.name) Gesundheitsprotokoll"
        ))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: l.tr(zh: "全部", en: "All", de: "Alle"), isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(HealthLogType.allCases, id: \.rawValue) { type in
                    filterChip(label: "\(type.emoji) \(healthLogTypeTitle(type, l: l))", isSelected: selectedType == type) {
                        selectedType = (selectedType == type) ? nil : type
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : .primary.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.goPrimary : .clear, in: Capsule())
                .goSelectableSurface(isSelected: isSelected, tint: Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func healthLogRow(_ log: PetHealthLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goRed.opacity(0.12))
                    .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(log.healthLogType.emoji)
                    .font(OhanaFont.adaptive(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(healthLogTypeTitle(log.healthLogType, l: l))
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !log.note.isEmpty {
                    Text(log.note)
                        .font(OhanaFont.adaptive(size: 12))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(log.date, style: .date)
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                if log.cost > 0 {
                    Text(AppCurrency.format(log.cost, fractionDigits: 0))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
    }
}

private func healthLogTypeTitle(_ type: HealthLogType, l: L10n = L10n(AppLanguage.code)) -> String {
    switch type {
    case .general:
        l.tr(zh: "常规", en: "General", de: "Allgemein")
    case .vaccine:
        l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
    case .medication:
        l.tr(zh: "用药", en: "Medication", de: "Medikation")
    case .dewormingInternal:
        l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
    case .dewormingExternal:
        l.tr(zh: "体外驱虫", en: "External parasite care", de: "Äußerer Parasitenschutz")
    case .surgery:
        l.tr(zh: "手术", en: "Surgery", de: "Operation")
    case .dental:
        l.tr(zh: "牙科", en: "Dental", de: "Dental")
    case .checkup:
        l.tr(zh: "体检", en: "Checkup", de: "Check-up")
    case .emergency:
        l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
    case .other:
        l.tr(zh: "其他", en: "Other", de: "Sonstiges")
    }
}
