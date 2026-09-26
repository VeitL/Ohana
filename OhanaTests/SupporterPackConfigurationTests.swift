import Foundation
import Testing
@testable import Ohana

struct SupporterPackConfigurationTests {
    @Test("Local StoreKit products match the Personal and Family catalog contract")
    func storeKitConfigurationMatchesCatalog() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = rootURL.appending(path: "Ohana/Configuration/Ohana.storekit")
        let data = try Data(contentsOf: configurationURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let settings = try #require(root["settings"] as? [String: Any])
        #expect(settings["_locale"] as? String == "de_DE")
        #expect(settings["_storefront"] as? String == "DEU")
        let products = try #require(root["products"] as? [[String: Any]])
        let productsByID = Dictionary(uniqueKeysWithValues: products.compactMap { product in
            (product["productID"] as? String).map { ($0, product) }
        })

        #expect(Set(productsByID.keys) == Set([
            SupporterPackCatalog.productID,
            SupporterPackCatalog.personalLifetimeProductID
        ]))
        try assertProduct(
            productsByID[SupporterPackCatalog.productID],
            type: "NonConsumable",
            price: "14.99"
        )
        try assertProduct(
            productsByID[SupporterPackCatalog.personalLifetimeProductID],
            type: "NonConsumable",
            price: "49.99"
        )

        let groups = try #require(root["subscriptionGroups"] as? [[String: Any]])
        let group = try #require(groups.first)
        #expect(groups.count == 1)
        #expect(group["id"] as? String == SupporterPackCatalog.personalSubscriptionGroupID)
        try assertLocalizations(group["localizations"])
        let subscriptions = try #require(group["subscriptions"] as? [[String: Any]])
        let subscriptionsByID = Dictionary(uniqueKeysWithValues: subscriptions.compactMap { product in
            (product["productID"] as? String).map { ($0, product) }
        })
        #expect(Set(subscriptionsByID.keys) == Set([
            SupporterPackCatalog.personalMonthlyProductID,
            SupporterPackCatalog.personalYearlyProductID,
            SupporterPackCatalog.familyYearlyProductID
        ]))

        let monthly = subscriptionsByID[SupporterPackCatalog.personalMonthlyProductID]
        try assertProduct(monthly, type: "RecurringSubscription", price: "2.99")
        #expect(monthly?["recurringSubscriptionPeriod"] as? String == "P1M")
        #expect(monthly?["introductoryOffer"] is NSNull)
        #expect(monthly?["groupNumber"] as? Int == 2)

        let annual = subscriptionsByID[SupporterPackCatalog.personalYearlyProductID]
        try assertProduct(annual, type: "RecurringSubscription", price: "14.99")
        #expect(annual?["referenceName"] as? String == "Ohana Personal Yearly")
        #expect(annual?["recurringSubscriptionPeriod"] as? String == "P1Y")
        let trial = try #require(annual?["introductoryOffer"] as? [String: Any])
        #expect(trial["displayPrice"] as? String == "0")
        #expect(trial["paymentMode"] as? String == "free")
        #expect(trial["subscriptionPeriod"] as? String == "P2W")
        #expect(annual?["groupNumber"] as? Int == 2)

        let family = subscriptionsByID[SupporterPackCatalog.familyYearlyProductID]
        try assertProduct(family, type: "RecurringSubscription", price: "39.99")
        #expect(family?["referenceName"] as? String == "Ohana Family Yearly")
        #expect(family?["recurringSubscriptionPeriod"] as? String == "P1Y")
        #expect(family?["introductoryOffer"] is NSNull)
        #expect(family?["groupNumber"] as? Int == 1)

        let allProductIDs = Set(productsByID.keys).union(subscriptionsByID.keys)
        #expect(Set(allProductIDs.filter { $0.localizedCaseInsensitiveContains("family") }) == Set([
            SupporterPackCatalog.familyYearlyProductID
        ]))
        #expect(!allProductIDs.contains(where: { $0.localizedCaseInsensitiveContains("care") }))
    }

    @Test("Local and Sandbox schemes keep StoreKit environments separate")
    func schemeAndTargetMembershipAreSeparated() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scheme = try String(
            contentsOf: rootURL.appending(
                path: "Ohana.xcodeproj/xcshareddata/xcschemes/Ohana.xcscheme"
            ),
            encoding: .utf8
        )
        let sandboxScheme = try String(
            contentsOf: rootURL.appending(
                path: "Ohana.xcodeproj/xcshareddata/xcschemes/Ohana Sandbox.xcscheme"
            ),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: rootURL.appending(path: "Ohana.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        #expect(scheme.contains("../../Ohana/Configuration/Ohana.storekit"))
        #expect(sandboxScheme.contains("BuildableName = \"Ohana.app\""))
        #expect(!sandboxScheme.contains("StoreKitConfigurationFileReference"))
        let exceptionSectionStart = try #require(project.range(
            of: "/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */"
        ))
        let exceptionSectionEnd = try #require(project.range(
            of: "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */",
            range: exceptionSectionStart.upperBound ..< project.endIndex
        ))
        let exceptionSection = project[exceptionSectionStart.lowerBound ..< exceptionSectionEnd.upperBound]
        #expect(exceptionSection.contains("Configuration/Ohana.storekit"))
    }

    private func assertProduct(
        _ product: [String: Any]?,
        type: String,
        price: String
    ) throws {
        let product = try #require(product)
        #expect(product["type"] as? String == type)
        #expect(product["familyShareable"] as? Bool == false)
        #expect(product["displayPrice"] as? String == price)

        try assertLocalizations(product["localizations"])
    }

    private func assertLocalizations(_ value: Any?) throws {
        let localizations = try #require(value as? [[String: Any]])
        let locales = Set(localizations.compactMap { $0["locale"] as? String })
        #expect(locales == Set([
            "de_DE", "en_US", "es_ES", "fr_FR", "it_IT",
            "ja_JP", "ko_KR", "pt_BR", "zh_CN"
        ]))
        #expect(localizations.allSatisfy { localization in
            guard let displayName = localization["displayName"] as? String,
                  let description = localization["description"] as? String else {
                return false
            }
            return (2 ... 30).contains(displayName.count) && description.count <= 45
        })
    }
}
