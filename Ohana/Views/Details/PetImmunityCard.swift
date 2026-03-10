//
//  PetImmunityCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetImmunityCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goCardCyan)
                Text("免疫健康")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                let urgentCount = upcomingCount
                if urgentCount > 0 {
                    Text("\(urgentCount) 项到期")
                        .font(.system(size: 11, weight: .bold))
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
        .goTranslucentCard(cornerRadius: 20)
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
        let vaccineLogs = pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.sorted { $0.date > $1.date }
        // Bug8: 同时匹配旧 medication 和新 dewormingInternal
        let dewormInternalLogs = pet.healthLogs.filter {
            $0.type == HealthLogType.dewormingInternal.rawValue || $0.type == HealthLogType.medication.rawValue
        }.sorted { $0.date > $1.date }
        let dewormExternalLogs = pet.healthLogs.filter { $0.type == HealthLogType.dewormingExternal.rawValue }.sorted { $0.date > $1.date }
        let checkupLogs = pet.healthLogs.filter { $0.type == HealthLogType.checkup.rawValue }.sorted { $0.date > $1.date }

        // Bug6: 优先使用 log.expirationDate，若无则按固定周期推算
        func nextDue(_ log: PetHealthLog?, fallback: (Date) -> Date?) -> Date? {
            guard let l = log else { return nil }
            return l.expirationDate ?? fallback(l.date)
        }

        return [
            ImmunityRow(icon: "💉", title: "疫苗",
                        lastDate: vaccineLogs.first?.date,
                        nextDueDate: nextDue(vaccineLogs.first) { Calendar.current.date(byAdding: .year, value: 1, to: $0) },
                        note: vaccineLogs.first?.note ?? ""),
            ImmunityRow(icon: "🪱", title: "体内驱虫",
                        lastDate: dewormInternalLogs.first?.date,
                        nextDueDate: nextDue(dewormInternalLogs.first) { Calendar.current.date(byAdding: .month, value: 3, to: $0) },
                        note: dewormInternalLogs.first?.note ?? ""),
            ImmunityRow(icon: "🐛", title: "体外驱虫",
                        lastDate: dewormExternalLogs.first?.date,
                        nextDueDate: nextDue(dewormExternalLogs.first) { Calendar.current.date(byAdding: .month, value: 1, to: $0) },
                        note: dewormExternalLogs.first?.note ?? ""),
            ImmunityRow(icon: "🩺", title: "年度体检",
                        lastDate: checkupLogs.first?.date,
                        nextDueDate: nextDue(checkupLogs.first) { Calendar.current.date(byAdding: .year, value: 1, to: $0) },
                        note: checkupLogs.first?.note ?? ""),
        ]
    }

    private var upcomingCount: Int {
        rows.filter { row in
            guard let due = row.nextDueDate else { return false }
            return due < Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        }.count
    }

    private func immunityRow(row: ImmunityRow) -> some View {
        let daysUntilDue: Int? = row.nextDueDate.map { due in
            Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        }
        let isOverdue = (daysUntilDue ?? 1) < 0
        let isUrgent  = !isOverdue && (daysUntilDue ?? 999) <= 30

        return HStack(spacing: 12) {
            Text(row.icon).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if let last = row.lastDate {
                    Text("上次: \(last, style: .date)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                } else {
                    Text("尚未记录")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                }
            }
            Spacer()
            if let days = daysUntilDue {
                if isOverdue {
                    Text("已逾期")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goRed.opacity(0.15), in: Capsule())
                } else if isUrgent {
                    Text("\(days)天后")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goYellow.opacity(0.15), in: Capsule())
                } else if let due = row.nextDueDate {
                    Text(due, style: .date)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                }
            }
        }
    }
}
