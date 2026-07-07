//
//  PetImmunityCard.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct PetImmunityCard: View {
    let pet: Pet
    let healthLogs: [PetHealthLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    init(pet: Pet, healthLogs: [PetHealthLog] = []) {
        self.pet = pet
        self.healthLogs = healthLogs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.checkered").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goCardCyan)
                Text(l.tr(zh: "免疫健康", en: "Immunity health", de: "Immunschutz"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                let urgentCount = upcomingCount
                if urgentCount > 0 {
                    Text(l.tr(zh: "\(urgentCount) 项到期", en: "\(urgentCount) due", de: "\(urgentCount) fällig"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold))
                        .foregroundStyle(Color.goRed)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goRed.opacity(0.15), in: Capsule())
                }
            }

            ForEach(rows, id: \.title) { row in
                immunityRow(row: row)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    // MARK: - Data
    private struct ImmunityRow {
        let icon: String
        let title: String
        let lastDate: Date?
        let nextDueDate: Date?
        let note: String
    }

    private var rows: [ImmunityRow] {
        let vaccineLogs = healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.sorted { $0.date > $1.date }
        // Bug8: 同时匹配旧 medication 和新 dewormingInternal
        let dewormInternalLogs = healthLogs.filter {
            $0.type == HealthLogType.dewormingInternal.rawValue || $0.type == HealthLogType.medication.rawValue
        }.sorted { $0.date > $1.date }
        let dewormExternalLogs = healthLogs.filter { $0.type == HealthLogType.dewormingExternal.rawValue }.sorted { $0.date > $1.date }
        let checkupLogs = healthLogs.filter { $0.type == HealthLogType.checkup.rawValue }.sorted { $0.date > $1.date }

        // Bug6: 优先使用 log.expirationDate，若无则按固定周期推算
        func nextDue(_ log: PetHealthLog?, fallback: (Date) -> Date?) -> Date? {
            guard let l = log else { return nil }
            return l.expirationDate ?? fallback(l.date)
        }

        return [
            ImmunityRow(icon: "💉", title: HealthLogType.vaccine.localizedLabel(l),
                        lastDate: vaccineLogs.first?.date,
                        nextDueDate: nextDue(vaccineLogs.first) { Calendar.current.date(byAdding: .year, value: 1, to: $0) },
                        note: vaccineLogs.first?.note ?? ""),
            ImmunityRow(icon: "🪱", title: HealthLogType.dewormingInternal.localizedLabel(l),
                        lastDate: dewormInternalLogs.first?.date,
                        nextDueDate: nextDue(dewormInternalLogs.first) { Calendar.current.date(byAdding: .month, value: 3, to: $0) },
                        note: dewormInternalLogs.first?.note ?? ""),
            ImmunityRow(icon: "🐛", title: HealthLogType.dewormingExternal.localizedLabel(l),
                        lastDate: dewormExternalLogs.first?.date,
                        nextDueDate: nextDue(dewormExternalLogs.first) { Calendar.current.date(byAdding: .month, value: 1, to: $0) },
                        note: dewormExternalLogs.first?.note ?? ""),
            ImmunityRow(icon: "🩺", title: l.tr(zh: "年度体检", en: "Annual checkup", de: "Jahres-Check-up"),
                        lastDate: checkupLogs.first?.date,
                        nextDueDate: nextDue(checkupLogs.first) { Calendar.current.date(byAdding: .year, value: 1, to: $0) },
                        note: checkupLogs.first?.note ?? "")
        ]
    }

    private var upcomingCount: Int {
        rows.count(where: { row in
            guard let due = row.nextDueDate else { return false }
            return due < Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        })
    }

    private func immunityRow(row: ImmunityRow) -> some View {
        let daysUntilDue: Int? = row.nextDueDate.map { due in
            Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        }
        let isOverdue = (daysUntilDue ?? 1) < 0
        let isUrgent = !isOverdue && (daysUntilDue ?? 999) <= 30

        return HStack(spacing: 12) {
            Text(row.icon).font(OhanaFont.adaptive(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if let last = row.lastDate {
                    Text(l.tr(zh: "上次: \(last.formatted(.dateTime.year().month().day()))", en: "Last: \(last.formatted(.dateTime.year().month().day()))", de: "Zuletzt: \(last.formatted(.dateTime.year().month().day()))"))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                } else {
                    Text(l.tr(zh: "尚未记录", en: "No record yet", de: "Noch kein Eintrag"))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                }
            }
            Spacer()
            if let days = daysUntilDue {
                if isOverdue {
                    Text(l.tr(zh: "已逾期", en: "Overdue", de: "Überfällig"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goRed.opacity(0.15), in: Capsule())
                } else if isUrgent {
                    Text(l.tr(zh: "\(days)天后", en: "In \(days)d", de: "In \(days) T."))
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goYellow.opacity(0.15), in: Capsule())
                } else if let due = row.nextDueDate {
                    Text(due, style: .date)
                        .font(OhanaFont.adaptive(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                }
            }
        }
    }
}
