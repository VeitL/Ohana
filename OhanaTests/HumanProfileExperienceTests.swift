import Foundation
import XCTest

final class HumanProfileExperienceTests: XCTestCase {
    func testHumanProfileUsesSharedReadFirstScaffoldAndSafeDeletionPresentation() throws {
        let shared = try source("Ohana/Shared/Components/ProfileDetailComponents.swift")
        let human = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift")
        let creation = try source("Ohana/Features/Members/Views/MemberCardCreationContentView+Steps.swift")

        for component in [
            "ProfileDetailScaffold",
            "ProfileIdentityHero",
            "ProfileInfoSection",
            "ProfileInfoRow",
            "ProfileEmptySectionRow",
            "ProfileCompletionCard"
        ] {
            XCTAssertTrue(shared.contains("struct \(component)"))
        }

        XCTAssertTrue(human.contains("ProfileDetailScaffold("))
        XCTAssertTrue(human.contains("ProfileIdentityHero("))
        XCTAssertTrue(human.contains("ProfileCompletionCard("))
        XCTAssertTrue(human.contains("HumanProfileEditPolicy.canEdit"))
        XCTAssertFalse(human.contains("showsEditAction: isViewingOwnProfile"))
        XCTAssertTrue(human.contains("completion(.failed(message:"))
        XCTAssertTrue(human.contains("completion(.deleted)"))
        XCTAssertTrue(human.contains("all related local data"))
        XCTAssertTrue(human.contains(".interactiveDismissDisabled(isDeleting)"))
        XCTAssertFalse(human.contains(".height(360)"))
        XCTAssertTrue(human.contains("human-lifecycle-management-disclosure"))
        XCTAssertTrue(shared.contains(".toolbarBackground(Color.ohanaCardSurfaceElevated, for: .navigationBar)"))
        XCTAssertTrue(shared.contains("DisclosureGroup(isExpanded: $showsCompletionExplanation)"))
        XCTAssertTrue(creation.contains("if HumanLocalPrivacyPolicy.isEnabled"))
        XCTAssertTrue(creation.contains("compactHumanGenderGrid"))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
