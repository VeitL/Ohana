//
//  HumanHealthMetricDetailQuery.swift
//  Ohana
//
//  Bounded SwiftData reads for one Human checkup metric route.
//

import Foundation
import SwiftData

@MainActor
struct HumanHealthMetricDetailPage {
    let logs: [HumanHealthMetricLog]
    let didReachFetchLimit: Bool
}

@MainActor
enum HumanHealthMetricDetailQuery {
    static func preferredUnitCode(
        humanID: UUID,
        metricKey: String,
        validUnitCodes: Set<String>,
        fallbackUnitCode: String,
        context: ModelContext
    ) -> String {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.human?.id == humanID && log.metricKey == metricKey
            },
            sortBy: sortDescriptors
        )
        descriptor.fetchLimit = 1

        guard let latest = try? context.fetch(descriptor).first,
              validUnitCodes.contains(latest.unitCode) else {
            return fallbackUnitCode
        }
        return latest.unitCode
    }

    static func page(
        humanID: UUID,
        metricKey: String,
        unitCode: String,
        context: ModelContext
    ) throws -> HumanHealthMetricDetailPage {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.human?.id == humanID
                    && log.metricKey == metricKey
                    && log.unitCode == unitCode
            },
            sortBy: sortDescriptors
        )
        descriptor.fetchLimit = HumanHealthMetricReadPolicy.detailProbeLimit

        let probed = try context.fetch(descriptor)
        return HumanHealthMetricDetailPage(
            logs: Array(probed.prefix(HumanHealthMetricReadPolicy.detailFetchLimit)),
            didReachFetchLimit: probed.count > HumanHealthMetricReadPolicy.detailFetchLimit
        )
    }

    private static var sortDescriptors: [SortDescriptor<HumanHealthMetricLog>] {
        [
            SortDescriptor(\HumanHealthMetricLog.date, order: .reverse),
            SortDescriptor(\HumanHealthMetricLog.createdAt, order: .reverse),
            SortDescriptor(\HumanHealthMetricLog.id, order: .reverse)
        ]
    }
}
