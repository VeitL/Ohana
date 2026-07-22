//
//  CommerceEntitlementService.swift
//  Ohana
//
//  StoreKit 2 entitlement boundary. Free care features never depend on this
//  service being available or on product loading succeeding.
//

import Foundation
import Observation
import Security
import StoreKit

nonisolated enum CommercePurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
    case failed
}

nonisolated enum CommerceRestoreOutcome: Equatable, Sendable {
    case restored
    case noPurchases
    case failed
}

nonisolated enum CommerceEntitlementStatus: Equatable, Sendable {
    case checking
    case ownedVerified
    case notOwnedVerified
    case temporarilyUnknown
}

nonisolated enum CommerceStorefrontProductKind: Equatable, Sendable {
    case nonConsumable
    case autoRenewableSubscription
    case unsupported
}

nonisolated struct CommerceStorefrontProduct: Equatable, Sendable {
    let id: String
    let displayPrice: String
    let kind: CommerceStorefrontProductKind
    let isFamilyShareable: Bool
    let isEligibleForIntroOffer: Bool

    var isNonConsumable: Bool { kind == .nonConsumable }
    var isAutoRenewableSubscription: Bool { kind == .autoRenewableSubscription }

    init(
        id: String,
        displayPrice: String,
        isNonConsumable: Bool = true,
        isFamilyShareable: Bool = false,
        isEligibleForIntroOffer: Bool = false
    ) {
        self.id = id
        self.displayPrice = displayPrice
        kind = isNonConsumable ? .nonConsumable : .unsupported
        self.isFamilyShareable = isFamilyShareable
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
    }

    init(
        id: String,
        displayPrice: String,
        kind: CommerceStorefrontProductKind,
        isFamilyShareable: Bool = false,
        isEligibleForIntroOffer: Bool = false
    ) {
        self.id = id
        self.displayPrice = displayPrice
        self.kind = kind
        self.isFamilyShareable = isFamilyShareable
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
    }
}

nonisolated struct CommerceStorefrontTransaction: Equatable, Sendable {
    let id: UInt64
    let productID: String
    let kind: CommerceStorefrontProductKind
    let isDirectPurchase: Bool
    let revocationDate: Date?
    let expirationDate: Date?
    /// Apple's signed JWS representation. Family online services submit this
    /// to the backend for independent verification; local entitlement UI never
    /// treats the payload itself as trusted server authority.
    let signedTransactionInfo: String?
    /// True only when StoreKit returned this transaction from its authoritative
    /// current-entitlements sequence. This preserves Apple-granted grace and
    /// billing-retry access instead of second-guessing it with a local date.
    let isCurrentEntitlement: Bool

    var isNonConsumable: Bool { kind == .nonConsumable }
    var isAutoRenewableSubscription: Bool { kind == .autoRenewableSubscription }

    init(
        id: UInt64,
        productID: String,
        isNonConsumable: Bool = true,
        isDirectPurchase: Bool = true,
        revocationDate: Date?,
        expirationDate: Date? = nil,
        isCurrentEntitlement: Bool = false,
        signedTransactionInfo: String? = nil
    ) {
        self.id = id
        self.productID = productID
        kind = isNonConsumable ? .nonConsumable : .unsupported
        self.isDirectPurchase = isDirectPurchase
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
        self.isCurrentEntitlement = isCurrentEntitlement
        self.signedTransactionInfo = signedTransactionInfo
    }

    init(
        id: UInt64,
        productID: String,
        kind: CommerceStorefrontProductKind,
        isDirectPurchase: Bool = true,
        revocationDate: Date?,
        expirationDate: Date? = nil,
        isCurrentEntitlement: Bool = false,
        signedTransactionInfo: String? = nil
    ) {
        self.id = id
        self.productID = productID
        self.kind = kind
        self.isDirectPurchase = isDirectPurchase
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
        self.isCurrentEntitlement = isCurrentEntitlement
        self.signedTransactionInfo = signedTransactionInfo
    }
}

nonisolated enum CommerceStorefrontVerification: Equatable, Sendable {
    case verified(CommerceStorefrontTransaction)
    case unverified(productID: String?)
}

nonisolated enum CommerceStorefrontPurchaseResult: Equatable, Sendable {
    case success(CommerceStorefrontVerification)
    case pending
    case userCancelled
}

nonisolated protocol CommerceStorefrontClient: Sendable {
    func products(for identifiers: Set<String>) async throws -> [CommerceStorefrontProduct]
    func purchase(productID: String) async throws -> CommerceStorefrontPurchaseResult
    func currentEntitlements(productID: String) async throws -> [CommerceStorefrontVerification]
    func currentEntitlements(productIDs: Set<String>) async throws -> [CommerceStorefrontVerification]
    func storefrontUpdates() async -> AsyncStream<Void>
    func transactionUpdates() async -> AsyncStream<CommerceStorefrontVerification>
    func finish(transactionID: UInt64) async
    func sync() async throws
}

nonisolated extension CommerceStorefrontClient {
    func currentEntitlements(productIDs: Set<String>) async throws -> [CommerceStorefrontVerification] {
        var result: [CommerceStorefrontVerification] = []
        for productID in productIDs.sorted() {
            await result.append(contentsOf: try currentEntitlements(productID: productID))
        }
        return result
    }
}

nonisolated protocol CommerceEntitlementPersisting: AnyObject {
    func cachedSupporterPackEntitlement() -> Bool
    func setCachedSupporterPackEntitlement(_ isEntitled: Bool)
    func cachedFamilyEntitlement() -> Bool
    func setCachedFamilyEntitlement(_ isEntitled: Bool)
}

nonisolated extension CommerceEntitlementPersisting {
    /// Compatibility bridge: the original Supporter cache becomes the
    /// aggregate Personal cache so existing verified owners migrate in place.
    func cachedPersonalEntitlement() -> Bool {
        cachedSupporterPackEntitlement()
    }

    func setCachedPersonalEntitlement(_ isEntitled: Bool) {
        setCachedSupporterPackEntitlement(isEntitled)
    }

    /// Compatibility defaults keep test doubles and older embedding clients
    /// source-compatible. Production Keychain storage overrides both methods.
    func cachedFamilyEntitlement() -> Bool { false }

    func setCachedFamilyEntitlement(_: Bool) {}
}

final nonisolated class KeychainCommerceEntitlementCache: CommerceEntitlementPersisting, @unchecked Sendable {
    private let service = "com.guanchen.li.Ohana.commerce"

    func cachedSupporterPackEntitlement() -> Bool {
        cachedEntitlement(account: CommerceEntitlementCache.supporterPackKeychainAccount)
    }

    func setCachedSupporterPackEntitlement(_ isEntitled: Bool) {
        setCachedEntitlement(
            isEntitled,
            account: CommerceEntitlementCache.supporterPackKeychainAccount
        )
    }

    func cachedFamilyEntitlement() -> Bool {
        cachedEntitlement(account: CommerceEntitlementCache.familyKeychainAccount)
    }

    func setCachedFamilyEntitlement(_ isEntitled: Bool) {
        setCachedEntitlement(
            isEntitled,
            account: CommerceEntitlementCache.familyKeychainAccount
        )
    }

    private func cachedEntitlement(account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = data.first
        else { return false }
        return value == 1
    }

    private func setCachedEntitlement(_ isEntitled: Bool, account: String) {
        let data = Data([isEntitled ? 1 : 0])
        let update: [String: Any] = [kSecValueData as String: data]
        let query = baseQuery(account: account)
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

nonisolated enum CommerceStorefrontError: LocalizedError, Equatable {
    case productUnavailable
    case familyUnavailable
    case verificationFailed

    var errorDescription: String? {
        let l = L10n()
        switch self {
        case .productUnavailable:
            return l.tr(
                zh: "Ohana Personal 暂时无法使用。",
                en: "Ohana Personal is temporarily unavailable.",
                de: "Ohana Personal ist vorübergehend nicht verfügbar."
            )
        case .familyUnavailable:
            return l.tr(
                zh: "Ohana Family 守护尚未开放。",
                en: "Ohana Family guardian is not available yet.",
                de: "Ohana Family-Schutz ist noch nicht verfügbar."
            )
        case .verificationFailed:
            return l.tr(
                zh: "此购买无法验证，未解锁任何付费内容。",
                en: "This purchase could not be verified. No paid content was unlocked.",
                de: "Dieser Kauf konnte nicht verifiziert werden. Es wurden keine bezahlten Inhalte freigeschaltet."
            )
        }
    }
}

actor StoreKitCommerceStorefrontClient: CommerceStorefrontClient {
    private var productsByID: [String: Product] = [:]
    private var productCacheGeneration: UInt64 = 0
    private var transactionsAwaitingFinish: [UInt64: Transaction] = [:]

    func products(for identifiers: Set<String>) async throws -> [CommerceStorefrontProduct] {
        let products = try await loadProducts(for: identifiers)
        var storefrontProducts: [CommerceStorefrontProduct] = []
        for product in products {
            let subscription = product.subscription
            let isEligibleForIntroOffer = if subscription?.introductoryOffer != nil {
                await subscription?.isEligibleForIntroOffer == true
            } else {
                false
            }
            storefrontProducts.append(CommerceStorefrontProduct(
                id: product.id,
                displayPrice: product.displayPrice,
                kind: storefrontKind(for: product.type),
                isFamilyShareable: product.isFamilyShareable,
                isEligibleForIntroOffer: isEligibleForIntroOffer
            ))
        }
        return storefrontProducts
    }

    func purchase(productID: String) async throws -> CommerceStorefrontPurchaseResult {
        let product: Product
        if let cachedProduct = productsByID[productID] {
            product = cachedProduct
        } else if let loadedProduct = try await loadProducts(for: [productID]).first {
            product = loadedProduct
        } else {
            throw CommerceStorefrontError.productUnavailable
        }
        guard SupporterPackCatalog.purchasableProductIDs.contains(productID),
              productMatchesCatalog(productID: productID, productType: product.type),
              !product.isFamilyShareable
        else {
            throw CommerceStorefrontError.verificationFailed
        }

        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            return .success(map(verification, rememberForFinishing: true))
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw CommerceStorefrontError.productUnavailable
        }
    }

    func currentEntitlements(productID: String) async throws -> [CommerceStorefrontVerification] {
        var entitlements: [CommerceStorefrontVerification] = []
        for await verification in Transaction.currentEntitlements(for: productID) {
            entitlements.append(map(
                verification,
                rememberForFinishing: false,
                isCurrentEntitlement: true
            ))
        }
        return entitlements
    }

    func currentEntitlements(productIDs: Set<String>) async throws -> [CommerceStorefrontVerification] {
        var entitlements: [CommerceStorefrontVerification] = []
        for productID in productIDs.sorted() {
            for await verification in Transaction.currentEntitlements(for: productID) {
                entitlements.append(map(
                    verification,
                    rememberForFinishing: false,
                    isCurrentEntitlement: true
                ))
            }
        }
        return entitlements
    }

    func storefrontUpdates() async -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                for await _ in Storefront.updates {
                    guard !Task.isCancelled, let self else { break }
                    await self.invalidateProductCache()
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func transactionUpdates() async -> AsyncStream<CommerceStorefrontVerification> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                for await verification in Transaction.updates {
                    guard !Task.isCancelled, let self else { break }
                    let update = await self.map(
                        verification,
                        rememberForFinishing: true,
                        isCurrentEntitlement: false
                    )
                    continuation.yield(update)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func finish(transactionID: UInt64) async {
        guard let transaction = transactionsAwaitingFinish.removeValue(forKey: transactionID) else { return }
        await transaction.finish()
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    private func loadProducts(for identifiers: Set<String>) async throws -> [Product] {
        productCacheGeneration &+= 1
        let loadGeneration = productCacheGeneration
        for identifier in identifiers {
            productsByID.removeValue(forKey: identifier)
        }

        let products = try await Product.products(for: identifiers)
        guard loadGeneration == productCacheGeneration else { return [] }
        for product in products {
            productsByID[product.id] = product
        }
        return products
    }

    private func invalidateProductCache() {
        productCacheGeneration &+= 1
        productsByID.removeAll()
    }

    private func map(
        _ verification: VerificationResult<Transaction>,
        rememberForFinishing: Bool,
        isCurrentEntitlement: Bool = false
    ) -> CommerceStorefrontVerification {
        switch verification {
        case let .verified(transaction):
            if rememberForFinishing,
               SupporterPackCatalog.entitlementProductIDs.contains(transaction.productID),
               productMatchesCatalog(
                   productID: transaction.productID,
                   productType: transaction.productType
               ),
               transaction.ownershipType == .purchased {
                transactionsAwaitingFinish[transaction.id] = transaction
            }
            return .verified(CommerceStorefrontTransaction(
                id: transaction.id,
                productID: transaction.productID,
                kind: storefrontKind(for: transaction.productType),
                isDirectPurchase: transaction.ownershipType == .purchased,
                revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate,
                isCurrentEntitlement: isCurrentEntitlement,
                signedTransactionInfo: verification.jwsRepresentation
            ))
        case let .unverified(transaction, _):
            return .unverified(productID: transaction.productID)
        }
    }

    private func storefrontKind(for type: Product.ProductType) -> CommerceStorefrontProductKind {
        switch type {
        case .nonConsumable:
            .nonConsumable
        case .autoRenewable:
            .autoRenewableSubscription
        case .consumable, .nonRenewable:
            .unsupported
        default:
            .unsupported
        }
    }

    private func productMatchesCatalog(
        productID: String,
        productType: Product.ProductType
    ) -> Bool {
        if SupporterPackCatalog.expectsNonConsumable(productID: productID) {
            return productType == .nonConsumable
        }
        return SupporterPackCatalog.purchasableProductIDs.contains(productID) &&
            productType == .autoRenewable
    }
}

@MainActor
@Observable
final class CommerceEntitlementService {
    private(set) var hasPersonalEntitlement: Bool
    private(set) var hasFamilyEntitlement: Bool
    private(set) var entitlementStatus: CommerceEntitlementStatus
    private(set) var activePersonalProductIDs: Set<String> = []
    private(set) var activeFamilyProductIDs: Set<String> = []
    private(set) var personalDisplayPrices: [PersonalPurchaseChoice: String] = [:]
    private(set) var familyDisplayPrice: String?
    private(set) var latestVerifiedFamilyTransactionJWS: String?
    private(set) var introOfferEligiblePersonalChoices: Set<PersonalPurchaseChoice> = []

    /// Compatibility alias for the existing Supporter UI and cosmetic gates.
    var hasSupporterPack: Bool { hasPersonalEntitlement }
    var personalAccessLevel: PersonalAccessLevel {
        hasPersonalEntitlement ? .personal : .free
    }

    func allows(_ feature: PersonalFeature) -> Bool {
        PersonalFeatureAccessPolicy.allows(feature, level: personalAccessLevel)
    }
    private(set) var displayPrice: String?
    private(set) var isLoadingProduct = false
    private(set) var isPurchasing = false
    private(set) var isPurchasePending = false
    private(set) var isRestoring = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let storefront: any CommerceStorefrontClient
    @ObservationIgnored private let persistence: any CommerceEntitlementPersisting
    @ObservationIgnored private let familyPurchasesEnabled: @Sendable () -> Bool
    @ObservationIgnored private var storefrontListener: Task<Void, Never>?
    @ObservationIgnored private var transactionListener: Task<Void, Never>?
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var entitlementMutationGeneration: UInt64 = 0
    @ObservationIgnored private var productLoadGeneration: UInt64 = 0

    var activePersonalPurchaseChoices: Set<PersonalPurchaseChoice> {
        Set(activePersonalProductIDs.compactMap(SupporterPackCatalog.purchaseChoice(for:)))
    }

    var hasLegacySupporterPackEntitlement: Bool {
        activePersonalProductIDs.contains(SupporterPackCatalog.productID)
    }

    init(
        storefront: any CommerceStorefrontClient = StoreKitCommerceStorefrontClient(),
        persistence: any CommerceEntitlementPersisting = KeychainCommerceEntitlementCache(),
        familyPurchasesEnabled: @escaping @Sendable () -> Bool = {
            GuardianSafetyConfiguration.current != nil
        }
    ) {
        self.storefront = storefront
        self.persistence = persistence
        self.familyPurchasesEnabled = familyPurchasesEnabled
        let cachedPersonal = persistence.cachedPersonalEntitlement()
        let cachedFamily = persistence.cachedFamilyEntitlement()
        hasFamilyEntitlement = cachedFamily
        hasPersonalEntitlement = cachedPersonal || cachedFamily
        entitlementStatus = .temporarilyUnknown
    }

    deinit {
        storefrontListener?.cancel()
        transactionListener?.cancel()
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        startTransactionListener()
        startStorefrontListener()

        // StoreKit work is fallible and never gates the app's free bootstrap.
        async let entitlementRefresh: Bool = refreshCurrentEntitlement(reportError: false)
        async let productLoad: Void = loadPersonalProducts(reportError: false)
        _ = await (entitlementRefresh, productLoad)
    }

    /// Revalidates entitlement and account-dependent product presentation after
    /// returning to the foreground. This never blocks the free app experience.
    func refreshEntitlements() async {
        // A user-initiated restore owns its sync + refresh window. Letting an
        // automatic foreground refresh interleave can replace the shared
        // status with `.checking` just before restore reports its result.
        guard !isRestoring else {
            await loadPersonalProducts(reportError: false)
            return
        }
        async let entitlementRefresh: Bool = refreshCurrentEntitlement(reportError: false)
        async let productLoad: Void = loadPersonalProducts(reportError: false)
        _ = await (entitlementRefresh, productLoad)
    }

    func displayPrice(for choice: PersonalPurchaseChoice) -> String? {
        personalDisplayPrices[choice]
    }

    func isEligibleForIntroOffer(for choice: PersonalPurchaseChoice) -> Bool {
        introOfferEligiblePersonalChoices.contains(choice)
    }

    /// Explicit retry used by the commerce surface after an earlier product
    /// lookup failed. Prices remain nil unless StoreKit supplies them.
    func reloadPersonalProducts() async {
        guard !isLoadingProduct else { return }
        lastErrorMessage = nil
        await loadPersonalProducts(reportError: true)
    }

    /// Compatibility entry point for the existing Supporter commerce surface.
    func reloadSupporterProduct() async {
        await reloadPersonalProducts()
    }

    func purchaseSupporterPack() async -> CommercePurchaseOutcome {
        await purchasePersonal(.lifetime)
    }

    func purchasePersonal(_ choice: PersonalPurchaseChoice) async -> CommercePurchaseOutcome {
        await purchase(productID: choice.productID, requiresFamily: false)
    }

    func purchaseFamilyYearly() async -> CommercePurchaseOutcome {
        guard familyPurchasesEnabled() else {
            lastErrorMessage = CommerceStorefrontError.familyUnavailable.localizedDescription
            return .failed
        }
        return await purchase(productID: SupporterPackCatalog.familyYearlyProductID, requiresFamily: true)
    }

    private func purchase(
        productID: String,
        requiresFamily: Bool
    ) async -> CommercePurchaseOutcome {
        if isPurchasePending { return .pending }
        guard !isPurchasing, !isRestoring else { return .failed }
        lastErrorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await storefront.purchase(productID: productID)
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification,
                      transaction.productID == productID,
                      isValidCommerceTransaction(transaction)
                else {
                    lastErrorMessage = CommerceStorefrontError.verificationFailed.localizedDescription
                    return .failed
                }
                let didReconcile = await reconcileVerifiedTransaction(transaction)
                let hasRequestedEntitlement = requiresFamily
                    ? hasFamilyEntitlement
                    : hasPersonalEntitlement
                return didReconcile && hasRequestedEntitlement ? .purchased : .failed
            case .pending:
                isPurchasePending = true
                return .pending
            case .userCancelled:
                return .cancelled
            }
        } catch {
            lastErrorMessage = commerceErrorMessage(error)
            return .failed
        }
    }

    func restorePurchases() async -> CommerceRestoreOutcome {
        guard !isRestoring, !isPurchasing else { return .failed }
        lastErrorMessage = nil
        isRestoring = true
        entitlementMutationGeneration &+= 1
        defer { isRestoring = false }

        do {
            try await storefront.sync()
            await refreshCurrentEntitlement(reportError: true)
            switch entitlementStatus {
            case .ownedVerified where lastErrorMessage == nil:
                return .restored
            case .notOwnedVerified where lastErrorMessage == nil:
                // StoreKit has completed an explicit account sync and still
                // reports no entitlement. Clear an earlier in-process pending
                // hint so a declined Ask to Buy request cannot strand the UI.
                isPurchasePending = false
                return .noPurchases
            case .checking, .ownedVerified, .notOwnedVerified, .temporarilyUnknown:
                return .failed
            }
        } catch {
            entitlementStatus = .temporarilyUnknown
            lastErrorMessage = commerceErrorMessage(error)
            return .failed
        }
    }

    private func startTransactionListener() {
        guard transactionListener == nil else { return }
        let storefront = storefront
        transactionListener = Task { [weak self] in
            let updates = await storefront.transactionUpdates()
            for await verification in updates {
                guard !Task.isCancelled, let self else { break }
                guard case let .verified(transaction) = verification,
                      self.isValidCommerceTransaction(transaction)
                else { continue }
                await self.reconcileVerifiedTransaction(transaction)
            }
        }
    }

    private func startStorefrontListener() {
        guard storefrontListener == nil else { return }
        let storefront = storefront
        storefrontListener = Task { [weak self] in
            let updates = await storefront.storefrontUpdates()
            for await _ in updates {
                guard !Task.isCancelled, let self else { break }
                await self.refreshEntitlements()
            }
        }
    }

    private func loadPersonalProducts(reportError: Bool) async {
        productLoadGeneration &+= 1
        let loadGeneration = productLoadGeneration
        isLoadingProduct = true
        defer {
            if loadGeneration == productLoadGeneration {
                isLoadingProduct = false
            }
        }
        do {
            let requestedProductIDs = familyPurchasesEnabled()
                ? SupporterPackCatalog.purchasableProductIDs
                : SupporterPackCatalog.purchasablePersonalProductIDs
            let products = try await storefront.products(for: requestedProductIDs)
            guard loadGeneration == productLoadGeneration else { return }
            var prices: [PersonalPurchaseChoice: String] = [:]
            var introOfferEligibleChoices: Set<PersonalPurchaseChoice> = []
            var loadedFamilyDisplayPrice: String?
            for product in products {
                guard isValidCommerceProduct(product), !product.isFamilyShareable else { continue }
                if product.id == SupporterPackCatalog.familyYearlyProductID {
                    loadedFamilyDisplayPrice = product.displayPrice
                } else if let choice = SupporterPackCatalog.purchaseChoice(for: product.id),
                          choice.productID == product.id {
                    prices[choice] = product.displayPrice
                    if product.isEligibleForIntroOffer {
                        introOfferEligibleChoices.insert(choice)
                    }
                }
            }
            personalDisplayPrices = prices
            familyDisplayPrice = loadedFamilyDisplayPrice
            introOfferEligiblePersonalChoices = introOfferEligibleChoices
            displayPrice = prices[.lifetime]
            if prices.count == PersonalPurchaseChoice.allCases.count {
                lastErrorMessage = nil
            }
            if prices.count != PersonalPurchaseChoice.allCases.count, reportError {
                lastErrorMessage = CommerceStorefrontError.productUnavailable.localizedDescription
            }
        } catch {
            guard loadGeneration == productLoadGeneration else { return }
            personalDisplayPrices = [:]
            familyDisplayPrice = nil
            introOfferEligiblePersonalChoices = []
            displayPrice = nil
            if reportError {
                lastErrorMessage = commerceErrorMessage(error)
            }
        }
    }

    @discardableResult
    private func refreshCurrentEntitlement(reportError: Bool) async -> Bool {
        entitlementMutationGeneration &+= 1
        let refreshGeneration = entitlementMutationGeneration
        entitlementStatus = .checking
        do {
            let verifications = try await storefront.currentEntitlements(
                productIDs: SupporterPackCatalog.entitlementProductIDs
            )
            guard refreshGeneration == entitlementMutationGeneration else { return false }
            let relevantVerifiedTransactions = verifications.compactMap { verification -> CommerceStorefrontTransaction? in
                guard case let .verified(transaction) = verification,
                      isValidCommerceTransaction(transaction)
                else { return nil }
                return transaction
            }

            let activeProductIDs = Set(
                relevantVerifiedTransactions
                    .filter(isActive)
                    .map(\.productID)
            )
            latestVerifiedFamilyTransactionJWS = relevantVerifiedTransactions.first {
                SupporterPackCatalog.familySubscriptionProductIDs.contains($0.productID) && isActive($0)
            }?.signedTransactionInfo
            if !activeProductIDs.isEmpty {
                lastErrorMessage = nil
                setEntitlements(
                    activeProductIDs: activeProductIDs,
                    status: .ownedVerified
                )
                isPurchasePending = false
                return true
            } else if !relevantVerifiedTransactions.isEmpty || verifications.isEmpty {
                lastErrorMessage = nil
                setEntitlements(activeProductIDs: [], status: .notOwnedVerified)
                return true
            } else {
                entitlementStatus = .temporarilyUnknown
                if reportError {
                    lastErrorMessage = CommerceStorefrontError.verificationFailed.localizedDescription
                }
                return false
            }
            // An unverified response never grants access and does not overwrite
            // a previously verified offline cache entry.
        } catch {
            guard refreshGeneration == entitlementMutationGeneration else { return false }
            // Preserve the last verified value when StoreKit is unavailable.
            entitlementStatus = .temporarilyUnknown
            if reportError {
                lastErrorMessage = commerceErrorMessage(error)
            }
            return false
        }
    }

    @discardableResult
    private func reconcileVerifiedTransaction(
        _ transaction: CommerceStorefrontTransaction
    ) async -> Bool {
        let didRefresh = await refreshCurrentEntitlement(reportError: true)
        guard didRefresh else { return false }
        isPurchasePending = false
        await storefront.finish(transactionID: transaction.id)
        return true
    }

    private func setEntitlements(
        activeProductIDs: Set<String>,
        status: CommerceEntitlementStatus
    ) {
        let familyProductIDs = activeProductIDs.intersection(
            SupporterPackCatalog.familySubscriptionProductIDs
        )
        let personalProductIDs = activeProductIDs.intersection(
            SupporterPackCatalog.personalEntitlementProductIDs
        )
        activeFamilyProductIDs = familyProductIDs
        activePersonalProductIDs = personalProductIDs
        hasFamilyEntitlement = !familyProductIDs.isEmpty
        hasPersonalEntitlement = hasFamilyEntitlement || !personalProductIDs.isEmpty
        entitlementStatus = status
        persistence.setCachedPersonalEntitlement(!personalProductIDs.isEmpty)
        persistence.setCachedFamilyEntitlement(hasFamilyEntitlement)
        if !hasFamilyEntitlement {
            latestVerifiedFamilyTransactionJWS = nil
        }
    }

    private func isValidCommerceProduct(_ product: CommerceStorefrontProduct) -> Bool {
        if SupporterPackCatalog.expectsNonConsumable(productID: product.id) {
            return product.isNonConsumable
        }
        return SupporterPackCatalog.purchasableProductIDs.contains(product.id) &&
            product.isAutoRenewableSubscription
    }

    private func isValidCommerceTransaction(_ transaction: CommerceStorefrontTransaction) -> Bool {
        guard SupporterPackCatalog.entitlementProductIDs.contains(transaction.productID),
              transaction.isDirectPurchase
        else { return false }
        if SupporterPackCatalog.expectsNonConsumable(productID: transaction.productID) {
            return transaction.isNonConsumable
        }
        return transaction.isAutoRenewableSubscription
    }

    private func isActive(_ transaction: CommerceStorefrontTransaction) -> Bool {
        guard transaction.revocationDate == nil else { return false }
        if transaction.isCurrentEntitlement { return true }
        guard let expirationDate = transaction.expirationDate else { return true }
        return expirationDate > Date()
    }

    private func commerceErrorMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        let systemDescription = error.localizedDescription
        if !systemDescription.isEmpty {
            return systemDescription
        }
        return L10n().tr(
            zh: "App Store 无法完成此请求，请重试。",
            en: "The App Store could not complete this request. Please try again.",
            de: "Der App Store konnte diese Anfrage nicht abschließen. Bitte versuche es erneut."
        )
    }
}
