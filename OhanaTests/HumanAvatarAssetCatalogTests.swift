import Foundation
import Testing
@testable import Ohana

struct HumanAvatarAssetCatalogTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func avatarFilenameUsesGenderAndAgeGroup() {
        let now = date(year: 2026, month: 5, day: 8)

        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "男",
                birthday: date(year: 2011, month: 5, day: 8),
                now: now
            ) == "human_male_teen.png"
        )

        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "女",
                birthday: date(year: 1996, month: 5, day: 8),
                now: now
            ) == "human_female_young_adult.png"
        )

        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "非二元",
                birthday: date(year: 1986, month: 5, day: 8),
                now: now
            ) == "human_nonbinary_mid_adult.png"
        )

        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "nonbinary",
                birthday: date(year: 1966, month: 5, day: 8),
                now: now
            ) == "human_nonbinary_late_adult.png"
        )

        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "male",
                birthday: date(year: 1956, month: 5, day: 8),
                now: now
            ) == "human_male_senior.png"
        )
    }

    @Test func missingBirthdayDefaultsToYoungAdult() {
        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "女",
                birthday: nil
            ) == "human_female_young_adult.png"
        )
    }

    @Test func undisclosedGenderDoesNotUseGeneratedAvatar() {
        #expect(
            HumanAvatarAssetCatalog.avatarFilename(
                gender: "不透露",
                birthday: nil
            ) == nil
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
