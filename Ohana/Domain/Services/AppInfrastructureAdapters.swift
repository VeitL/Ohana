import Combine
import Foundation
import SwiftData

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
    private let questManager: QuestManager

    convenience init() {
        self.init(questManager: QuestManager())
    }

    init(questManager: QuestManager) {
        self.questManager = questManager
    }

    func exportJSON(container: ModelContainer, password: String?) async throws -> URL {
        try await manager.exportJSON(container: container, password: password)
    }

    func importJSON(from url: URL, context: ModelContext, password: String?) async throws {
        try await manager.importJSON(from: url, context: context, projectionManager: questManager, password: password)
    }
}

@MainActor
protocol AppResetting {
    func reset(context: ModelContext) throws
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
}

@MainActor
protocol WalkCareEventManaging {
    @discardableResult
    func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String?,
        executorIds: [String],
        startDate: Date
    ) -> SharedPetActionResult
}

@MainActor
final class StaticWalkCareEventManager: WalkCareEventManaging {
    private let dependencies: CareEventServiceDependencies?

    init(dependencies: CareEventServiceDependencies? = nil) {
        self.dependencies = dependencies
    }

    func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String?,
        executorIds: [String],
        startDate: Date
    ) -> SharedPetActionResult {
        CareEventService.recordSharedWalk(
            sourcePet: sourcePet,
            targets: targets,
            distanceMeters: distanceMeters,
            endDate: endDate,
            context: context,
            executorId: executorId,
            executorIds: executorIds,
            startDate: startDate,
            dependencies: dependencies
        )
    }
}

@MainActor
protocol MedicationReminderManaging {
    func dosesTakenToday(for medicationId: UUID) -> Int
    func recordDose(for medicationId: UUID)
    func undoDose(for medicationId: UUID)
    func scheduleMedicationReminders(for pet: Pet, context: ModelContext?)
    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext?)
}

@MainActor
final class SharedMedicationReminderManager: MedicationReminderManaging {
    private let service: MedicationReminderService

    init(careLedger: CareLedgerRecording = CareLedgerService()) {
        service = MedicationReminderService(careLedger: careLedger)
    }

    func dosesTakenToday(for medicationId: UUID) -> Int {
        MedicationReminderService.dosesTakenToday(for: medicationId)
    }

    func recordDose(for medicationId: UUID) {
        MedicationReminderService.recordDose(for: medicationId)
    }

    func undoDose(for medicationId: UUID) {
        MedicationReminderService.undoDose(for: medicationId)
    }

    func scheduleMedicationReminders(for pet: Pet, context: ModelContext?) {
        service.scheduleMedicationReminders(for: pet, context: context)
    }

    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext?) {
        service.scheduleHumanMedicationReminders(for: human, meds: meds, context: context)
    }
}

@MainActor
protocol UserNotificationManaging {
    func requestPermission() async -> Bool
    func pendingNotificationIds() async -> Set<String>
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

@MainActor
protocol ReminderSchedulingManaging {
    @discardableResult
    func scheduleIfNeeded(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource,
        existingNotificationIds: Set<String>?,
        operation: String,
        saveLedger: Bool
    ) async -> ReminderNotificationScheduleResult

    func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource
    ) async

    func cancelAndReschedule(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource
    ) async

    func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext
    ) async

    func compensate(reminders: [Reminder], context: ModelContext)
}

@MainActor
final class ReminderSchedulingManager: ReminderSchedulingManaging {
    private let careLedger: CareLedgerRecording

    init(careLedger: CareLedgerRecording = CareLedgerService()) {
        self.careLedger = careLedger
    }

    @discardableResult
    func scheduleIfNeeded(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service,
        existingNotificationIds: Set<String>? = nil,
        operation: String = "schedule",
        saveLedger: Bool = true
    ) async -> ReminderNotificationScheduleResult {
        await ReminderSchedulingService.scheduleIfNeeded(
            reminder: reminder,
            context: context,
            source: source,
            existingNotificationIds: existingNotificationIds,
            operation: operation,
            saveLedger: saveLedger,
            careLedger: careLedger
        )
    }

    func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource = .service
    ) async {
        await ReminderSchedulingService.scheduleManyIfNeeded(
            reminders: reminders,
            context: context,
            source: source,
            careLedger: careLedger
        )
    }

    func cancelAndReschedule(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service
    ) async {
        await ReminderSchedulingService.cancelAndReschedule(
            reminder: reminder,
            context: context,
            source: source,
            careLedger: careLedger
        )
    }

    func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext
    ) async {
        await ReminderSchedulingService.refillMissingPendingNotifications(
            reminders: reminders,
            context: context,
            careLedger: careLedger
        )
    }

    func compensate(reminders: [Reminder], context: ModelContext) {
        ReminderSchedulingService.compensate(reminders: reminders, context: context, careLedger: careLedger)
    }
}
