//
//  ExpensePayerContributionPolicy.swift
//  Ohana
//
//  Shared exact, versioned payer allocations for one real-world expense fact.
//

import Foundation

nonisolated struct ExpensePayerContribution: Codable, Equatable, Hashable, Sendable {
    let humanID: UUID?
    let minorUnits: Int64

    init(humanID: UUID?, minorUnits: Int64) {
        self.humanID = humanID
        self.minorUnits = minorUnits
    }

    var amount: Double {
        Double(minorUnits) / Double(ExpensePayerContributionPolicy.minorUnitScale)
    }
}

nonisolated enum ExpensePayerContributionError: LocalizedError, Equatable, Sendable {
    case invalidAllocation
    case inactivePayer

    var errorDescription: String? {
        let l = L10n.current
        return switch self {
        case .invalidAllocation:
            l.tr(
                zh: "支付金额需要与总额一致。",
                en: "Payer amounts must match the total.",
                de: "Die Zahlbeträge müssen der Gesamtsumme entsprechen.",
                es: "Los importes pagados deben coincidir con el total.",
                pt: "Os valores pagos devem corresponder ao total.",
                fr: "Les montants payés doivent correspondre au total.",
                ja: "支払額の合計を総額と一致させてください。",
                ko: "결제 금액의 합계가 총액과 같아야 합니다.",
                it: "Gli importi pagati devono corrispondere al totale."
            )
        case .inactivePayer:
            l.tr(
                zh: "支付成员已发生变化，请重新选择。",
                en: "A payer changed. Select the payers again.",
                de: "Eine zahlende Person hat sich geändert. Wähle erneut aus.",
                es: "Una persona pagadora ha cambiado. Vuelve a seleccionarla.",
                pt: "Uma pessoa pagadora mudou. Selecione novamente.",
                fr: "Une personne payeuse a changé. Sélectionnez à nouveau.",
                ja: "支払うメンバーが変更されました。選び直してください。",
                ko: "결제 구성원이 변경되었습니다. 다시 선택해 주세요.",
                it: "Una persona pagante è cambiata. Seleziona di nuovo."
            )
        }
    }
}

nonisolated enum ExpensePayerContributionPolicy {
    static let currentSnapshotVersion = 1
    static let minorUnitScale: Int64 = 100

    private struct Snapshot: Codable, Equatable, Sendable {
        let version: Int
        let contributions: [ExpensePayerContribution]
    }

    static func equalSplit(total: Double, humanIDs: [UUID]) throws -> [ExpensePayerContribution] {
        let normalizedIDs = normalizedHumanIDs(humanIDs)
        guard !normalizedIDs.isEmpty,
              let totalUnits = minorUnits(total),
              totalUnits >= Int64(normalizedIDs.count)
        else {
            throw ExpensePayerContributionError.invalidAllocation
        }

        let count = Int64(normalizedIDs.count)
        let base = totalUnits / count
        let remainder = totalUnits % count
        return normalizedIDs.enumerated().map { index, humanID in
            ExpensePayerContribution(
                humanID: humanID,
                minorUnits: base + (Int64(index) < remainder ? 1 : 0)
            )
        }
    }

    static func contribution(humanID: UUID, amount: Double) throws -> ExpensePayerContribution {
        guard let units = minorUnits(amount), units > 0 else {
            throw ExpensePayerContributionError.invalidAllocation
        }
        return ExpensePayerContribution(humanID: humanID, minorUnits: units)
    }

    static func totalAmount(of contributions: [ExpensePayerContribution]) throws -> Double {
        guard !contributions.isEmpty else {
            throw ExpensePayerContributionError.invalidAllocation
        }
        var totalUnits: Int64 = 0
        for contribution in contributions {
            guard contribution.minorUnits > 0,
                  totalUnits <= Int64.max - contribution.minorUnits else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            totalUnits += contribution.minorUnits
        }
        return Double(totalUnits) / Double(minorUnitScale)
    }

    static func validated(
        _ contributions: [ExpensePayerContribution],
        total: Double,
        allowsUnknownPayer: Bool = false
    ) throws -> [ExpensePayerContribution] {
        guard !contributions.isEmpty,
              let totalUnits = minorUnits(total),
              totalUnits > 0
        else {
            throw ExpensePayerContributionError.invalidAllocation
        }

        var seen: Set<UUID> = []
        var hasUnknownPayer = false
        var sum: Int64 = 0
        var normalized: [ExpensePayerContribution] = []
        normalized.reserveCapacity(contributions.count)
        for contribution in contributions {
            guard contribution.minorUnits > 0,
                  sum <= Int64.max - contribution.minorUnits else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            if let humanID = contribution.humanID {
                guard seen.insert(humanID).inserted else {
                    throw ExpensePayerContributionError.invalidAllocation
                }
            } else {
                guard allowsUnknownPayer, !hasUnknownPayer else {
                    throw ExpensePayerContributionError.invalidAllocation
                }
                hasUnknownPayer = true
            }
            sum += contribution.minorUnits
            normalized.append(contribution)
        }
        guard sum == totalUnits else {
            throw ExpensePayerContributionError.invalidAllocation
        }
        return normalized
    }

    static func encode(_ contributions: [ExpensePayerContribution]) -> String {
        guard !contributions.isEmpty,
              let data = try? JSONEncoder().encode(
                  Snapshot(version: currentSnapshotVersion, contributions: contributions)
              ),
              let json = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return json
    }

    static func decode(_ raw: String) -> [ExpensePayerContribution]? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let data = clean.data(using: .utf8) else { return [] }
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           snapshot.version == currentSnapshotVersion {
            return snapshot.contributions
        }
        // Compatibility for early development fixtures that stored the array directly.
        return try? JSONDecoder().decode([ExpensePayerContribution].self, from: data)
    }

    static func validatedDecoded(_ raw: String, total: Double) throws -> [ExpensePayerContribution] {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        guard let decoded = decode(clean) else {
            throw ExpensePayerContributionError.invalidAllocation
        }
        return try validated(decoded, total: total, allowsUnknownPayer: true)
    }

    static func effectiveContributions(
        raw: String,
        executorID: String?,
        total: Double
    ) -> [ExpensePayerContribution] {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            return (try? validatedDecoded(clean, total: total)) ?? []
        }
        guard let executorID,
              let humanID = UUID(uuidString: executorID),
              let units = minorUnits(total),
              units != 0
        else {
            return []
        }
        return [ExpensePayerContribution(humanID: humanID, minorUnits: units)]
    }

    static func distributed(
        _ contributions: [ExpensePayerContribution],
        across childAmounts: [Double]
    ) throws -> [[ExpensePayerContribution]] {
        guard !contributions.isEmpty else {
            return Array(repeating: [], count: childAmounts.count)
        }
        var total: Int64 = 0
        for contribution in contributions {
            guard contribution.minorUnits >= 0,
                  total <= Int64.max - contribution.minorUnits else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            total += contribution.minorUnits
        }
        let childUnits = try childAmounts.map { amount -> Int64 in
            guard let units = minorUnits(amount), units >= 0 else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            return units
        }
        var childTotal: Int64 = 0
        for units in childUnits {
            guard childTotal <= Int64.max - units else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            childTotal += units
        }
        guard childTotal == total else {
            throw ExpensePayerContributionError.invalidAllocation
        }

        var remainingColumns = contributions.map(\.minorUnits)
        var remainingTotal = total
        var rows: [[ExpensePayerContribution]] = []
        rows.reserveCapacity(childUnits.count)

        for (rowIndex, rowTotal) in childUnits.enumerated() {
            if rowIndex == childUnits.count - 1 {
                rows.append(zip(contributions, remainingColumns).compactMap { contribution, units in
                    units > 0 ? ExpensePayerContribution(humanID: contribution.humanID, minorUnits: units) : nil
                })
                break
            }

            guard remainingTotal > 0 else {
                rows.append([])
                continue
            }
            var row = Array(repeating: Int64(0), count: contributions.count)
            var fractions: [(index: Int, remainder: Int64)] = []
            var assigned: Int64 = 0
            for index in contributions.indices {
                let product = rowTotal.multipliedReportingOverflow(by: remainingColumns[index])
                guard !product.overflow else {
                    throw ExpensePayerContributionError.invalidAllocation
                }
                let base = product.partialValue / remainingTotal
                row[index] = min(base, remainingColumns[index])
                assigned += row[index]
                fractions.append((index, product.partialValue % remainingTotal))
            }
            fractions.sort {
                if $0.remainder == $1.remainder { return $0.index < $1.index }
                return $0.remainder > $1.remainder
            }
            var missing = rowTotal - assigned
            for candidate in fractions where missing > 0 && row[candidate.index] < remainingColumns[candidate.index] {
                row[candidate.index] += 1
                missing -= 1
            }
            guard missing == 0 else {
                throw ExpensePayerContributionError.invalidAllocation
            }

            rows.append(zip(contributions, row).compactMap { contribution, units in
                units > 0 ? ExpensePayerContribution(humanID: contribution.humanID, minorUnits: units) : nil
            })
            for index in remainingColumns.indices {
                remainingColumns[index] -= row[index]
            }
            remainingTotal -= rowTotal
        }
        return rows
    }

    static func anonymized(
        _ contributions: [ExpensePayerContribution],
        removing humanID: UUID,
        total: Double
    ) throws -> [ExpensePayerContribution] {
        let validatedContributions = try validated(contributions, total: total, allowsUnknownPayer: true)
        var result: [ExpensePayerContribution] = []
        var unknownUnits: Int64 = 0
        var unknownInsertionIndex: Int?
        for contribution in validatedContributions {
            if contribution.humanID == nil || contribution.humanID == humanID {
                if unknownInsertionIndex == nil { unknownInsertionIndex = result.count }
                guard unknownUnits <= Int64.max - contribution.minorUnits else {
                    throw ExpensePayerContributionError.invalidAllocation
                }
                unknownUnits += contribution.minorUnits
            } else {
                result.append(contribution)
            }
        }
        guard unknownUnits > 0 else { return validatedContributions }
        result.insert(
            ExpensePayerContribution(humanID: nil, minorUnits: unknownUnits),
            at: min(unknownInsertionIndex ?? result.count, result.count)
        )
        return try validated(result, total: total, allowsUnknownPayer: true)
    }

    static func minorUnits(_ amount: Double) -> Int64? {
        guard amount.isFinite else { return nil }
        let scaled = amount * Double(minorUnitScale)
        let rounded = scaled.rounded()
        // `Double(Int64.max)` rounds to 2^63 on IEEE-754 and cannot be
        // converted to Int64. Keep the upper bound strictly exclusive.
        guard rounded.isFinite,
              rounded >= Double(Int64.min),
              rounded < Double(Int64.max)
        else {
            return nil
        }
        return Int64(rounded)
    }

    private static func normalizedHumanIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
