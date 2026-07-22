import Combine
import Foundation
import SwiftData
import UserNotifications

@MainActor
protocol AppIconManaging {
    var supportsAlternateIcons: Bool { get }
    var currentDescriptor: AppIconShopDescriptor { get }

    func setIcon(
        _ descriptor: AppIconShopDescriptor,
        completion: @escaping (Result<Void, AppIconService.AppIconError>) -> Void
    )
}

@MainActor
final class SystemAppIconManager: AppIconManaging {
    var supportsAlternateIcons: Bool {
        AppIconService.supportsAlternateIcons
    }

    var currentDescriptor: AppIconShopDescriptor {
        AppIconService.currentDescriptor
    }

    func setIcon(
        _ descriptor: AppIconShopDescriptor,
        completion: @escaping (Result<Void, AppIconService.AppIconError>) -> Void
    ) {
        AppIconService.setIcon(descriptor, completion: completion)
    }
}

@MainActor
protocol DataBackupManaging {
    func exportJSON(container: ModelContainer, password: String?) async throws -> URL
    func importJSON(from url: URL, context: ModelContext, password: String?) async throws
}

extension DataBackupManaging {
    func exportJSON(container: ModelContainer) async throws -> URL {
        try await exportJSON(container: container, password: nil)
    }

    func importJSON(from url: URL, context: ModelContext) async throws {
        try await importJSON(from: url, context: context, password: nil)
    }
}

@MainActor
final class SharedDataBackupManagerAdapter: DataBackupManaging {
    private let manager: DataBackupManager
    private let projectionManager: CoconutProjectionManaging
    private var settleShopPurchases: ((ModelContext) -> Void)?

    init(
        projectionManager: CoconutProjectionManaging,
        manager: DataBackupManager = DataBackupManager()
    ) {
        self.projectionManager = projectionManager
        self.manager = manager
    }

    func registerShopPurchaseSettlement(_ settlement: @escaping (ModelContext) -> Void) {
        settleShopPurchases = settlement
    }

    func exportJSON(container: ModelContainer, password: String?) async throws -> URL {
        settleShopPurchases?(container.mainContext)
        return try await manager.exportJSON(
            container: container,
            password: password,
            scope: .manualExternalRestricted
        )
    }

    func importJSON(from url: URL, context: ModelContext, password: String?) async throws {
        try await manager.importJSON(
            from: url,
            context: context,
            projectionManager: projectionManager,
            password: password,
            settleShopPurchases: { [settleShopPurchases] in
                settleShopPurchases?(context)
            }
        )
    }
}

@MainActor
protocol AppResetting {
    func reset(context: ModelContext) async throws -> AppResetService.ResetResult
    func reset(context: ModelContext, options: AppResetService.Options) async throws -> AppResetService.ResetResult
    func resetForUITests(context: ModelContext) throws
}

@MainActor
final class StaticAppResetter: AppResetting {
    private let questManager: QuestManager
    private let automaticBackups: AutomaticBackupManaging
    private let defaults: UserDefaults
    private let attachmentStorage: HumanNoteAttachmentStorage
    private let deletePersistentData: (ModelContainer) throws -> Void
    private let prepareRuntimeForReset: () -> Void

    init(
        questManager: QuestManager,
        automaticBackups: AutomaticBackupManaging,
        defaults: UserDefaults = .standard,
        attachmentStorage: HumanNoteAttachmentStorage = .live,
        deletePersistentData: @escaping (ModelContainer) throws -> Void = { $0.deleteAllData() },
        prepareRuntimeForReset: @escaping () -> Void = {}
    ) {
        self.questManager = questManager
        self.automaticBackups = automaticBackups
        self.defaults = defaults
        self.attachmentStorage = attachmentStorage
        self.deletePersistentData = deletePersistentData
        self.prepareRuntimeForReset = prepareRuntimeForReset
    }

    func reset(context: ModelContext) async throws -> AppResetService.ResetResult {
        try await reset(context: context, options: AppResetService.Options())
    }

    func reset(context: ModelContext, options: AppResetService.Options) async throws -> AppResetService.ResetResult {
        prepareRuntimeForReset()
        if options.cleanUpAutomaticBackups {
            await automaticBackups.prepareForAppReset()
        }

        let humanNoteAttachmentCleanup = try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: attachmentStorage,
            deletePersistentData: deletePersistentData
        )
        guard options.cleanUpAutomaticBackups else {
            return AppResetService.ResetResult(
                automaticBackupCleanup: .notRequested,
                humanNoteAttachmentCleanup: humanNoteAttachmentCleanup
            )
        }

        let cleanup = await automaticBackups.removeManagedAutomaticBackupsForReset()
        return AppResetService.ResetResult(
            automaticBackupCleanup: cleanup,
            humanNoteAttachmentCleanup: humanNoteAttachmentCleanup
        )
    }

    func resetForUITests(context: ModelContext) throws {
        prepareRuntimeForReset()
        try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: AppResetService.Options(
                preserveLocalePreferences: false,
                cancelPendingNotifications: false,
                deleteCustomBackground: true,
                resetSharedRuntimeState: true,
                cleanUpAutomaticBackups: false
            ),
            questManager: questManager,
            attachmentStorage: attachmentStorage,
            deletePersistentData: deletePersistentData
        )
    }
}

@MainActor
protocol UserNotificationManaging {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestPermission() async -> Bool
    func pendingNotificationIds() async -> Set<String>
}

extension UserNotificationManaging {
    func authorizationStatus() async -> UNAuthorizationStatus {
        .notDetermined
    }
}

@MainActor
final class SharedUserNotificationManager: UserNotificationManaging {
    private let manager: NotificationManager

    convenience init() {
        self.init(manager: NotificationManager(routeCenter: OhanaNotificationRouteCenter()))
    }

    init(manager: NotificationManager) {
        self.manager = manager
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await manager.authorizationStatus()
    }

    func requestPermission() async -> Bool {
        await manager.requestPermission()
    }

    func pendingNotificationIds() async -> Set<String> {
        await manager.pendingNotificationIds()
    }
}

@MainActor
protocol NotificationRoutePublishing {
    var routeEvents: AnyPublisher<AppRoutePublishedEvent, Never> { get }
    var reminderActionEvents: AnyPublisher<ReminderNotificationActionEvent, Never> { get }

    func publishRouteEvent(_ event: AppRouteNotificationEvent)
    func acknowledgeRouteEvent(id: UUID)
    func acknowledgeReminderActionEvent(id: UUID)
}

@MainActor
final class SharedNotificationRoutePublisher: NotificationRoutePublishing {
    private let center: OhanaNotificationRouteCenter

    convenience init() {
        self.init(center: OhanaNotificationRouteCenter())
    }

    init(center: OhanaNotificationRouteCenter) {
        self.center = center
    }

    var routeEvents: AnyPublisher<AppRoutePublishedEvent, Never> {
        center.routeEvents
    }

    var reminderActionEvents: AnyPublisher<ReminderNotificationActionEvent, Never> {
        center.reminderActionEvents
    }

    func publishRouteEvent(_ event: AppRouteNotificationEvent) {
        center.publishRouteEvent(event)
    }

    func acknowledgeRouteEvent(id: UUID) {
        center.acknowledgeRouteEvent(id: id)
    }

    func acknowledgeReminderActionEvent(id: UUID) {
        center.acknowledgeReminderActionEvent(id: id)
    }
}
