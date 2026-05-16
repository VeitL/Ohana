import Foundation
import SwiftData

enum CoconutExchangeRequestStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case confirmed
    case cancelled

    var id: String { rawValue }
}

@Model
final class CoconutExchangeRequest {
    #Index<CoconutExchangeRequest>([\.statusRaw], [\.senderId], [\.receiverId], [\.createdAt])

    var id: UUID
    var senderId: String
    var senderName: String
    var receiverId: String
    var receiverName: String
    var coconutCost: Int
    var currencyCode: String
    var localAmount: Double
    var statusRaw: String
    var createdAt: Date
    var confirmedAt: Date?
    var cancelledAt: Date?
    var updatedAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        senderId: String,
        senderName: String,
        receiverId: String,
        receiverName: String,
        coconutCost: Int,
        currencyCode: String,
        localAmount: Double,
        status: CoconutExchangeRequestStatus = .pending,
        createdAt: Date = Date(),
        confirmedAt: Date? = nil,
        cancelledAt: Date? = nil,
        updatedAt: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.receiverId = receiverId
        self.receiverName = receiverName
        self.coconutCost = coconutCost
        self.currencyCode = AppCurrency.normalize(currencyCode)
        self.localAmount = localAmount
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.cancelledAt = cancelledAt
        self.updatedAt = updatedAt
        self.note = note
    }

    var status: CoconutExchangeRequestStatus {
        get { CoconutExchangeRequestStatus(rawValue: statusRaw) ?? .pending }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var isPending: Bool { status == .pending }
}

struct CoconutExchangeOption: Identifiable, Equatable {
    let countryCode: String
    let currencyCode: String
    let coconutCost: Int
    let localAmount: Double

    var id: String { "\(countryCode)-\(currencyCode)-\(coconutCost)-\(localAmount)" }

    var formattedAmount: String {
        Self.format(localAmount, currencyCode: currencyCode)
    }

    static func options(for countryCode: String = AppCountry.code) -> [CoconutExchangeOption] {
        switch AppCountry.normalize(countryCode) {
        case "US":
            return [
                .init(countryCode: "US", currencyCode: "USD", coconutCost: 500, localAmount: 0.5),
                .init(countryCode: "US", currencyCode: "USD", coconutCost: 1_000, localAmount: 1),
                .init(countryCode: "US", currencyCode: "USD", coconutCost: 2_000, localAmount: 2)
            ]
        case "DE":
            return [
                .init(countryCode: "DE", currencyCode: "EUR", coconutCost: 500, localAmount: 0.5),
                .init(countryCode: "DE", currencyCode: "EUR", coconutCost: 1_000, localAmount: 1),
                .init(countryCode: "DE", currencyCode: "EUR", coconutCost: 2_000, localAmount: 2)
            ]
        case "GB":
            return [
                .init(countryCode: "GB", currencyCode: "GBP", coconutCost: 500, localAmount: 0.5),
                .init(countryCode: "GB", currencyCode: "GBP", coconutCost: 1_000, localAmount: 1),
                .init(countryCode: "GB", currencyCode: "GBP", coconutCost: 2_000, localAmount: 2)
            ]
        case "JP":
            return [
                .init(countryCode: "JP", currencyCode: "JPY", coconutCost: 500, localAmount: 80),
                .init(countryCode: "JP", currencyCode: "JPY", coconutCost: 1_000, localAmount: 150),
                .init(countryCode: "JP", currencyCode: "JPY", coconutCost: 2_000, localAmount: 300)
            ]
        case "HK":
            return [
                .init(countryCode: "HK", currencyCode: "HKD", coconutCost: 500, localAmount: 5),
                .init(countryCode: "HK", currencyCode: "HKD", coconutCost: 1_000, localAmount: 10),
                .init(countryCode: "HK", currencyCode: "HKD", coconutCost: 2_000, localAmount: 20)
            ]
        case "TW":
            return [
                .init(countryCode: "TW", currencyCode: "TWD", coconutCost: 500, localAmount: 15),
                .init(countryCode: "TW", currencyCode: "TWD", coconutCost: 1_000, localAmount: 30),
                .init(countryCode: "TW", currencyCode: "TWD", coconutCost: 2_000, localAmount: 60)
            ]
        default:
            return [
                .init(countryCode: "CN", currencyCode: "CNY", coconutCost: 500, localAmount: 2),
                .init(countryCode: "CN", currencyCode: "CNY", coconutCost: 1_000, localAmount: 5),
                .init(countryCode: "CN", currencyCode: "CNY", coconutCost: 2_000, localAmount: 10)
            ]
        }
    }

    static func format(_ amount: Double, currencyCode: String) -> String {
        let code = AppCurrency.normalize(currencyCode)
        let option = AppCurrency.supported.first { $0.code == code } ?? AppCurrency.currentOption
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: option.localeIdentifier)
        formatter.currencyCode = option.code
        formatter.currencySymbol = option.symbol
        let hasFraction = amount.rounded(.down) != amount
        formatter.minimumFractionDigits = hasFraction ? 1 : 0
        formatter.maximumFractionDigits = hasFraction ? 1 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(option.symbol)\(amount)"
    }
}

