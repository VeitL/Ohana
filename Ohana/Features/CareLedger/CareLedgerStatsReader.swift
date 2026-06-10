import Foundation

typealias CareLedgerReportEntry = CareLedgerStatsService.ReportEntry

@MainActor
protocol CareLedgerStatsReading {
    func reportEntries(
        events: [CareLedgerEvent],
        pets: [Pet],
        humans: [Human],
        interval: DateInterval
    ) -> [CareLedgerReportEntry]
}

@MainActor
final class CareLedgerStatsReader: CareLedgerStatsReading {
    private let service: CareLedgerStatsService

    init() {
        service = CareLedgerStatsService()
    }

    init(service: CareLedgerStatsService) {
        self.service = service
    }

    func reportEntries(
        events: [CareLedgerEvent],
        pets: [Pet],
        humans: [Human],
        interval: DateInterval
    ) -> [CareLedgerReportEntry] {
        service.reportEntries(
            events: events,
            pets: pets,
            humans: humans,
            interval: interval
        )
    }
}
