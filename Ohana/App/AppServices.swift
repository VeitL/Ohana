//
//  AppServices.swift
//  Ohana
//
//  Instance-based dependency container for gradually retiring static services.
//

import Foundation
import Observation
import SwiftData

@MainActor
protocol SharedCareUndoRegistering {
    func register(_ token: SharedCareUndoToken, targetCount: Int)
}

extension SharedCareUndoCoordinator: SharedCareUndoRegistering {}

@MainActor
private struct AppServicesLiveGraph {
    let activeHumanSelection: UserDefaultsActiveHumanSelection
    let notificationRouteCenter: OhanaNotificationRouteCenter
    let notificationManager: NotificationManager
    let avatarPipeline: AvatarPipeline
    let coconutWallet: SwiftDataCoconutWalletManager
    let shopInventory: UserDefaultsShopInventoryManager
    let shopPurchaseFulfillment: ShopPurchaseFulfillmentService
    let domainRevisions: SharedDomainRevisionPublisher
    let questManager: QuestManager
    let locationManager: LocationManager
    let walkActivityPresenter: LiveWalkActivityPresenter
    let careLedger: CareLedgerService
    let automaticBackups: AutomaticBackupService
    let backupAdapter: SharedDataBackupManagerAdapter
    let oasisRewardManager: StaticOasisRewardManager
    let oasisTreeManager: OasisTreeManager
    let familyTasks: StaticFamilyTaskManager
    let reminderScheduling: ReminderSchedulingManager
    let medicationReminders: SharedMedicationReminderManager
    let userNotifications: SharedUserNotificationManager
    let guardianSafety: any GuardianSafetyManaging
    let reminderCompletion: ReminderCompletionService
    let careEventDependencies: CareEventServiceDependencies
    let walkingManager: PetWalkingManager
    let systemSurfaces: SystemSurfaceSnapshotRefreshing
}

@MainActor
@Observable
final class AppServices {
    let careEvents: CareEventRecording
    let activeHumanSelection: ActiveHumanSelecting
    let coconutWallet: CoconutWalletManaging
    let coconutExchange: CoconutExchangeManaging
    let careLedger: CareLedgerRecording
    let questManager: QuestManager
    let familyTasks: FamilyTaskManaging
    let gacha: GachaDrawing
    let memberCreation: MemberCreating
    let oasisRewards: OasisRewardManaging
    let privacy: HumanPrivacyManaging
    let passcodes: HumanPasscodeManaging
    let appIcons: AppIconManaging
    let shopInventory: ShopInventoryManaging
    let shopPurchaseFulfillment: ShopPurchaseFulfilling
    let islandToasts: IslandToastManager
    let metricKit: MetricKitObserving
    let backups: DataBackupManaging
    let automaticBackups: AutomaticBackupManaging
    let appReset: AppResetting
    let medicationReminders: MedicationReminderManaging
    let userNotifications: UserNotificationManaging
    let notificationRoutes: NotificationRoutePublishing
    let reminderActions: ReminderActionHandling
    let reminderScheduling: ReminderSchedulingManaging
    let reminderCompletion: ReminderCompleting
    let presenceSafety: PresenceSafetyManaging
    let guardianSafety: any GuardianSafetyManaging
    let onboardingJourney: OnboardingJourneyCoordinating
    let humanRequirements: HumanRequirementResolving
    let todayFocus: TodayFocusManaging
    let plantCarePlans: PlantCarePlanReading
    let plantReminderControls: PlantReminderControlling
    let plantGrowthDiaryExports: PlantGrowthDiaryExporting
    let plantIntelligence: PlantIntelligenceProviding
    let oasisTree: OasisTreeManaging
    let healthAlerts: PetHealthAlerting
    let walking: PetWalkingManaging
    let location: LocationProviding
    let careLedgerStats: CareLedgerStatsReading
    let domainRevisions: DomainRevisionPublishing
    let lifecycle: AppLifecycleHandling
    let cloudSync: CloudSyncManaging
    let commerce: CommerceEntitlementService
    let sharedCareUndo: SharedCareUndoRegistering
    let systemSurfaces: SystemSurfaceSnapshotRefreshing
    let systemSurfaceRoutes: SystemSurfaceRouteInbox
    var walkingPresentationRevision = 0

    convenience init(
        modelContainer: ModelContainer? = nil,
        commerce: CommerceEntitlementService? = nil
    ) {
        let commerce = commerce ?? CommerceEntitlementService()
        let graph = AppServices.makeLiveGraph(modelContainer: modelContainer, commerce: commerce)
        self.init(
            careEvents: CareEventService(dependencies: graph.careEventDependencies),
            activeHumanSelection: graph.activeHumanSelection,
            coconutWallet: graph.coconutWallet,
            coconutExchange: StaticCoconutExchangeManager(
                wallet: graph.coconutWallet,
                careLedger: graph.careLedger,
                questManager: graph.questManager
            ),
            careLedger: graph.careLedger,
            questManager: graph.questManager,
            familyTasks: graph.familyTasks,
            gacha: StaticGachaDrawer(
                wallet: graph.coconutWallet,
                careLedger: graph.careLedger,
                questManager: graph.questManager
            ),
            memberCreation: AppServices.makeMemberCreationService(
                graph.activeHumanSelection,
                graph.coconutWallet,
                graph.careLedger,
                graph.domainRevisions,
                graph.questManager,
                graph.shopInventory,
                graph.shopPurchaseFulfillment,
                commerce
            ),
            oasisRewards: graph.oasisRewardManager,
            privacy: StaticHumanPrivacyManager(),
            passcodes: StaticHumanPasscodeManager(),
            appIcons: SystemAppIconManager(),
            shopInventory: graph.shopInventory,
            shopPurchaseFulfillment: graph.shopPurchaseFulfillment,
            islandToasts: IslandToastManager(),
            metricKit: MetricKitObserver(),
            backups: graph.backupAdapter,
            automaticBackups: graph.automaticBackups,
            appReset: StaticAppResetter(
                questManager: graph.questManager,
                automaticBackups: graph.automaticBackups,
                prepareRuntimeForReset: {
                    graph.walkingManager.reset()
                    graph.walkActivityPresenter.endAll(immediate: true)
                }
            ),
            medicationReminders: graph.medicationReminders,
            userNotifications: graph.userNotifications,
            notificationRoutes: SharedNotificationRoutePublisher(center: graph.notificationRouteCenter),
            reminderActions: LiveReminderActionHandler(),
            reminderScheduling: graph.reminderScheduling,
            reminderCompletion: graph.reminderCompletion,
            guardianSafety: graph.guardianSafety,
            onboardingJourney: LiveOnboardingJourneyCoordinator(),
            humanRequirements: LiveHumanRequirementResolver(),
            todayFocus: StaticTodayFocusManager(
                questManager: graph.questManager,
                careLedger: graph.careLedger,
                revisions: graph.domainRevisions
            ),
            plantCarePlans: StaticPlantCarePlanReader(),
            plantReminderControls: StaticPlantReminderController(),
            plantGrowthDiaryExports: LivePlantGrowthDiaryExporter(),
            plantIntelligence: LocalPlantIntelligenceFallback(),
            oasisTree: SharedOasisTreeManager(manager: graph.oasisTreeManager),
            healthAlerts: SharedPetHealthAlertEngine(),
            walking: SharedPetWalkingManager(manager: graph.walkingManager),
            location: SharedLocationProvider(manager: graph.locationManager),
            careLedgerStats: CareLedgerStatsReader(),
            domainRevisions: graph.domainRevisions,
            lifecycle: AppLifecycleCoordinator(dependencies: .live(
                walkingManager: graph.walkingManager,
                automaticBackups: graph.automaticBackups,
                modelContainer: modelContainer
            )),
            cloudSync: AppServices.makeCloudSyncService(),
            commerce: commerce,
            systemSurfaces: graph.systemSurfaces,
            systemSurfaceRoutes: SystemSurfaceRouteInbox()
        )
        configureLiveRuntime(
            backupAdapter: graph.backupAdapter,
            automaticBackups: graph.automaticBackups,
            oasisTreeManager: graph.oasisTreeManager,
            avatarPipeline: graph.avatarPipeline,
            notificationManager: graph.notificationManager
        )
        self.systemSurfaces.start()
    }

    private static func makeLiveGraph(
        modelContainer: ModelContainer?,
        commerce: CommerceEntitlementService
    ) -> AppServicesLiveGraph {
        let activeHumanSelection = UserDefaultsActiveHumanSelection()
        let notificationRouteCenter = OhanaNotificationRouteCenter()
        let notificationManager = NotificationManager(routeCenter: notificationRouteCenter)
        let avatarPipeline = AvatarPipeline()
        let coconutWallet = SwiftDataCoconutWalletManager()
        let shopInventory = UserDefaultsShopInventoryManager()
        let shopPurchaseFulfillment = ShopPurchaseFulfillmentService()
        let domainRevisions = SharedDomainRevisionPublisher(center: ReadModelRevisionCenter.shared)
        let questManager = QuestManager(wallet: coconutWallet, revisions: domainRevisions)
        let locationManager = LocationManager()
        let walkActivityPresenter = LiveWalkActivityPresenter()
        let careLedger = CareLedgerService()
        let automaticBackups = AutomaticBackupService()
        let backupAdapter = SharedDataBackupManagerAdapter(projectionManager: questManager)
        let oasisRewardManager = StaticOasisRewardManager(
            activeHumanSelection: activeHumanSelection,
            wallet: coconutWallet,
            questManager: questManager
        )
        let oasisTreeManager = OasisTreeManager(
            questManager: questManager,
            careLedger: careLedger,
            oasisRewards: oasisRewardManager
        )
        let careEventEconomy = StaticCareEventEconomyAwarder(
            questManager: questManager,
            oasisRewards: oasisRewardManager
        )
        let familyTasks = StaticFamilyTaskManager(
            wallet: coconutWallet,
            careLedger: careLedger,
            questManager: questManager
        )
        let reminderScheduling = ReminderSchedulingManager(careLedger: careLedger)
        let medicationReminders = SharedMedicationReminderManager(careLedger: careLedger)
        let userNotifications = SharedUserNotificationManager(manager: notificationManager)
        let guardianSafety: any GuardianSafetyManaging = if let modelContainer {
            GuardianSafetyCoordinator(
                modelContainer: modelContainer,
                commerce: commerce,
                notifications: userNotifications
            )
        } else {
            DisabledGuardianSafetyCoordinator()
        }
        let reminderCompletion = makeReminderCompletion(
            careLedger, familyTasks, reminderScheduling, notificationManager
        )
        let careEventDependencies = makeCareEventDependencies(
            careEventEconomy, careLedger, reminderCompletion, familyTasks,
            domainRevisions, notificationManager
        )
        registerDomainDependencies(
            careEventDependencies, careEventEconomy, familyTasks,
            reminderScheduling, medicationReminders, reminderCompletion
        )
        let walkingManager = makeWalker(
            locationManager,
            questManager,
            careLedger,
            careEventDependencies,
            activeHumanSelection,
            walkActivityPresenter
        )
        let systemSurfaces: SystemSurfaceSnapshotRefreshing = if let modelContainer {
            SystemSurfaceSnapshotCoordinator(
                modelContainer: modelContainer,
                activeHumanSelection: activeHumanSelection,
                commerce: commerce,
                revisions: domainRevisions
            )
        } else {
            NoopSystemSurfaceSnapshotCoordinator()
        }
        walkActivityPresenter.dismissStaleActivities()
        AppWorkloadPolicy.shared.hasRunningWalkProvider = { walkingManager.hasActiveLocationWalk }
        return AppServicesLiveGraph(
            activeHumanSelection: activeHumanSelection,
            notificationRouteCenter: notificationRouteCenter,
            notificationManager: notificationManager,
            avatarPipeline: avatarPipeline,
            coconutWallet: coconutWallet,
            shopInventory: shopInventory,
            shopPurchaseFulfillment: shopPurchaseFulfillment,
            domainRevisions: domainRevisions,
            questManager: questManager,
            locationManager: locationManager,
            walkActivityPresenter: walkActivityPresenter,
            careLedger: careLedger,
            automaticBackups: automaticBackups,
            backupAdapter: backupAdapter,
            oasisRewardManager: oasisRewardManager,
            oasisTreeManager: oasisTreeManager,
            familyTasks: familyTasks,
            reminderScheduling: reminderScheduling,
            medicationReminders: medicationReminders,
            userNotifications: userNotifications,
            guardianSafety: guardianSafety,
            reminderCompletion: reminderCompletion,
            careEventDependencies: careEventDependencies,
            walkingManager: walkingManager,
            systemSurfaces: systemSurfaces
        )
    }

    private static func registerDomainDependencies(
        _ careEventDependencies: CareEventServiceDependencies,
        _ careEventEconomy: CareEventEconomyAwarding,
        _ familyTasks: FamilyTaskManaging,
        _ reminderScheduling: ReminderSchedulingManaging,
        _ medicationReminders: MedicationReminderManaging,
        _ reminderCompletion: ReminderCompleting
    ) {
        DomainServiceDependencyRegistry.register(
            careEventDependencies: { careEventDependencies },
            careEventEconomy: { careEventEconomy },
            familyTasks: { familyTasks },
            reminderScheduling: { _ in reminderScheduling },
            medicationReminders: { _ in medicationReminders },
            reminderCompletion: { _ in reminderCompletion }
        )
    }

    private static func makeReminderCompletion(
        _ careLedger: CareLedgerRecording,
        _ familyTasks: FamilyTaskManaging,
        _ reminderScheduling: ReminderSchedulingManaging,
        _ notifications: ReminderNotificationScheduling
    ) -> ReminderCompletionService {
        ReminderCompletionService(
            careLedger: careLedger,
            familyTasks: familyTasks,
            reminderScheduling: reminderScheduling,
            notifications: notifications
        )
    }

    private static func makeCareEventDependencies(
        _ economy: CareEventEconomyAwarding,
        _ careLedger: CareLedgerRecording,
        _ reminderCompletion: ReminderCompleting,
        _ familyTasks: FamilyTaskManaging,
        _ revisions: DomainRevisionPublishing,
        _ notifications: ReminderNotificationScheduling
    ) -> CareEventServiceDependencies {
        CareEventServiceDependencies(
            economy: economy,
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(
                reminderCompletion: reminderCompletion
            ),
            familyTasks: familyTasks,
            revisions: revisions,
            notifications: notifications
        )
    }

    private func configureLiveRuntime(
        backupAdapter: SharedDataBackupManagerAdapter,
        automaticBackups: AutomaticBackupService,
        oasisTreeManager: OasisTreeManager,
        avatarPipeline: AvatarPipeline,
        notificationManager: NotificationManager
    ) {
        backupAdapter.registerShopPurchaseSettlement { [weak self] context in
            guard let self else { return }
            _ = ShopPurchaseRecoveryService.settleRecoverable(
                context: context,
                services: self
            )
        }
        automaticBackups.registerShopPurchaseSettlement { [weak self] context in
            guard let self else { return }
            _ = ShopPurchaseRecoveryService.settleRecoverable(
                context: context,
                services: self
            )
        }
        OasisTreeManagerRegistry.current = oasisTreeManager
        AvatarPipelineRegistry.current = avatarPipeline
        ReminderNotificationSchedulerRegistry.registerLiveSchedulerFactory { notificationManager }
        ReminderNotificationSchedulerRegistry.current = notificationManager
    }

    private static func makeMemberCreationService(
        _ activeHumanSelection: ActiveHumanSelecting,
        _ wallet: CoconutWalletManaging,
        _ careLedger: CareLedgerRecording,
        _ revisions: DomainRevisionPublishing,
        _ questManager: QuestManager,
        _ shopInventory: ShopInventoryManaging,
        _ shopPurchaseFulfillment: ShopPurchaseFulfilling,
        _ commerce: CommerceEntitlementService
    ) -> MemberCreating {
        MemberCreationService(
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            careLedger: careLedger,
            revisions: revisions,
            questManager: questManager,
            shopInventory: shopInventory,
            shopPurchaseFulfillment: shopPurchaseFulfillment,
            personalAccessLevel: {
                commerce.personalAccessLevel
            }
        )
    }

    private static func makeWalker(
        _ location: any WalkLocationManaging,
        _ quests: QuestManager,
        _ ledger: CareLedgerRecording,
        _ careEvents: CareEventServiceDependencies,
        _ activeHuman: ActiveHumanSelecting,
        _ activityPresenter: WalkActivityPresenting
    ) -> PetWalkingManager {
        PetWalkingManager(
            locationManager: location,
            questManager: quests,
            careEconomy: careEvents.economy,
            careLedger: ledger,
            walkCareEvents: StaticWalkCareEventManager(dependencies: careEvents),
            activeHumanSelection: activeHuman,
            activityPresenter: activityPresenter
        )
    }

    private static func makeCloudSyncService() -> any CloudSyncManaging {
        guard AppCapabilityProfile.permitsCloudSyncRuntime else {
            return LocalDeviceCloudSyncService()
        }

        #if OHANA_FAMILY_CAPABILITIES
            return CloudSyncEngineService()
        #else
            return LocalDeviceCloudSyncService()
        #endif
    }

    init(
        careEvents: CareEventRecording,
        activeHumanSelection: ActiveHumanSelecting,
        coconutWallet: CoconutWalletManaging,
        coconutExchange: CoconutExchangeManaging,
        careLedger: CareLedgerRecording,
        questManager: QuestManager,
        familyTasks: FamilyTaskManaging,
        gacha: GachaDrawing,
        memberCreation: MemberCreating,
        oasisRewards: OasisRewardManaging,
        privacy: HumanPrivacyManaging,
        passcodes: HumanPasscodeManaging,
        appIcons: AppIconManaging,
        shopInventory: ShopInventoryManaging,
        shopPurchaseFulfillment: ShopPurchaseFulfilling,
        islandToasts: IslandToastManager,
        metricKit: MetricKitObserving,
        backups: DataBackupManaging,
        automaticBackups: AutomaticBackupManaging,
        appReset: AppResetting,
        medicationReminders: MedicationReminderManaging,
        userNotifications: UserNotificationManaging,
        notificationRoutes: NotificationRoutePublishing,
        reminderActions: ReminderActionHandling,
        reminderScheduling: ReminderSchedulingManaging,
        reminderCompletion: ReminderCompleting,
        presenceSafety: PresenceSafetyManaging? = nil,
        guardianSafety: (any GuardianSafetyManaging)? = nil,
        onboardingJourney: OnboardingJourneyCoordinating,
        humanRequirements: HumanRequirementResolving,
        todayFocus: TodayFocusManaging,
        plantCarePlans: PlantCarePlanReading,
        plantReminderControls: PlantReminderControlling,
        plantGrowthDiaryExports: PlantGrowthDiaryExporting,
        plantIntelligence: PlantIntelligenceProviding,
        oasisTree: OasisTreeManaging,
        healthAlerts: PetHealthAlerting,
        walking: PetWalkingManaging,
        location: LocationProviding,
        careLedgerStats: CareLedgerStatsReading,
        domainRevisions: DomainRevisionPublishing,
        lifecycle: AppLifecycleHandling,
        cloudSync: CloudSyncManaging,
        commerce: CommerceEntitlementService? = nil,
        sharedCareUndo: SharedCareUndoRegistering? = nil,
        systemSurfaces: SystemSurfaceSnapshotRefreshing? = nil,
        systemSurfaceRoutes: SystemSurfaceRouteInbox? = nil
    ) {
        self.careEvents = careEvents
        self.activeHumanSelection = activeHumanSelection
        self.coconutWallet = coconutWallet
        self.coconutExchange = coconutExchange
        self.careLedger = careLedger
        self.questManager = questManager
        self.familyTasks = familyTasks
        self.gacha = gacha
        self.memberCreation = memberCreation
        self.oasisRewards = oasisRewards
        self.privacy = privacy
        self.passcodes = passcodes
        self.appIcons = appIcons
        self.shopInventory = shopInventory
        self.shopPurchaseFulfillment = shopPurchaseFulfillment
        self.islandToasts = islandToasts
        self.metricKit = metricKit
        self.backups = backups
        self.automaticBackups = automaticBackups
        self.appReset = appReset
        self.medicationReminders = medicationReminders
        self.userNotifications = userNotifications
        self.notificationRoutes = notificationRoutes
        self.reminderActions = reminderActions
        self.reminderScheduling = reminderScheduling
        self.reminderCompletion = reminderCompletion
        self.presenceSafety = presenceSafety ?? LivePresenceSafetyManager()
        self.guardianSafety = guardianSafety ?? DisabledGuardianSafetyCoordinator()
        self.onboardingJourney = onboardingJourney
        self.humanRequirements = humanRequirements
        self.todayFocus = todayFocus
        self.plantCarePlans = plantCarePlans
        self.plantReminderControls = plantReminderControls
        self.plantGrowthDiaryExports = plantGrowthDiaryExports
        self.plantIntelligence = plantIntelligence
        self.oasisTree = oasisTree
        self.healthAlerts = healthAlerts
        self.walking = walking
        self.location = location
        self.careLedgerStats = careLedgerStats
        self.domainRevisions = domainRevisions
        self.lifecycle = lifecycle
        self.cloudSync = cloudSync
        self.commerce = commerce ?? CommerceEntitlementService()
        self.sharedCareUndo = sharedCareUndo ?? SharedCareUndoCoordinator.shared
        self.systemSurfaces = systemSurfaces ?? NoopSystemSurfaceSnapshotCoordinator()
        self.systemSurfaceRoutes = systemSurfaceRoutes ?? SystemSurfaceRouteInbox()
    }

    func publishWalkingPresentationChange() {
        walkingPresentationRevision &+= 1
    }
}
