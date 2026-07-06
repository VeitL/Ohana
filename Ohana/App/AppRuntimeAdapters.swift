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
    private let manager = DataBackupManager()
    private let projectionManager: CoconutProjectionManaging

    init(projectionManager: CoconutProjectionManaging) {
        self.projectionManager = projectionManager
    }

    func exportJSON(container: ModelContainer, password: String?) async throws -> URL {
        try await manager.exportJSON(container: container, password: password)
    }

    func importJSON(from url: URL, context: ModelContext, password: String?) async throws {
        try await manager.importJSON(from: url, context: context, projectionManager: projectionManager, password: password)
    }
}

@MainActor
protocol AppResetting {
    func reset(context: ModelContext) throws
    func reset(context: ModelContext, options: AppResetService.Options) throws
    func resetForUITests(context: ModelContext) throws
}

@MainActor
final class StaticAppResetter: AppResetting {
    private let questManager: QuestManager

    init(questManager: QuestManager) {
        self.questManager = questManager
    }

    func reset(context: ModelContext) throws {
        try AppResetService.reset(
            context: context,
            options: AppResetService.Options(),
            questManager: questManager
        )
    }

    func reset(context: ModelContext, options: AppResetService.Options) throws {
        try AppResetService.reset(
            context: context,
            options: options,
            questManager: questManager
        )
    }

    func resetForUITests(context: ModelContext) throws {
        try reset(
            context: context,
            options: AppResetService.Options(
                preserveLocalePreferences: false,
                cancelPendingNotifications: false,
                deleteCustomBackground: true,
                resetSharedRuntimeState: true,
                cleanUpAutomaticBackups: false
            )
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
}
