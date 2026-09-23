import SwiftUI

extension HomeFabFunctionShortcut {
    var accessibilityIdentifierFragment: String {
        switch action {
        case let .addEntity(type):
            return "add-\(type.rawValue)"
        case let .submenu(submenu):
            return "submenu-\(submenu.rawValue.dashSeparatedIdentifier)"
        case let .destination(destination):
            switch destination {
            case .petFeatureCollection:
                return "pet-feature-collection"
            case .petSharedCheckIn:
                return "pet-shared-check-in"
            case .plantFeatureCollection:
                return "plant-feature-collection"
            case let .featureAggregate(feature):
                return "feature-\(feature.rawValue)"
            case let .featureGroup(group):
                return "feature-group-\(group.rawValue)"
            case .plantsBatchCare:
                return "plants-batch-care"
            case let .plantsBatchCareFiltered(careType):
                return "plants-batch-care-\(careType.rawValue)"
            case .plantsBatchQuickRecord:
                return "plants-batch-quick-record"
            case let .plantCareAggregate(feature):
                return "plant-care-\(feature.rawValue)"
            case .coconutShop:
                return "coconutShop"
            case .gacha:
                return "gacha"
            case .wealthDashboard:
                return "wealth"
            case .familyWeeklyReport:
                return "weeklyReport"
            case .familyLongTermReview:
                return "longTermReview"
            case .careLedgerAnalysis:
                return "careLedgerAnalysis"
            case .reminderObservability:
                return "reminderObservability"
            default:
                break
            }
        case .unavailable:
            break
        }
        return "more"
    }
}

private extension String {
    var dashSeparatedIdentifier: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
