import Foundation
@testable import Ohana

@MainActor
enum TestOasisTreeManagerProjection {
    static let manager = OasisTreeManager(questManager: TestQuestManagerProjection.manager)
}
