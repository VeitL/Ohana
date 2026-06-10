import Foundation
@testable import Ohana

@MainActor
enum TestReadModelRevisions {
    static let center = ReadModelRevisionCenter()

    static var publisher: DomainRevisionPublishing {
        SharedDomainRevisionPublisher(center: center)
    }
}
