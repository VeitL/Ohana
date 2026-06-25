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
    let onboardingJourney: OnboardingJourneyCoordinating
    let humanRequirements: HumanRequirementResolving
    let todayFocus: TodayFocusManaging
    let plantCarePlans: PlantCarePlanReading
    let oasisTree: OasisTreeManaging
    let healthAlerts: PetHealthAlerting
    let walking: PetWalkingManaging
    let location: LocationProviding
    let careLedgerStats: CareLedgerStatsReading
    let domainRevisions: DomainRevisionPublishing
    let lifecycle: AppLifecycleHandling
    let cloudSync: CloudSyncManaging

    convenience init(modelContainer: ModelContainer? = nil) {
        let activeHumanSelection = UserDefaultsActiveHumanSelection()
        let notificationRouteCenter = OhanaNotificationRouteCenter()
        let notificationManager = NotificationManager(routeCenter: notificationRouteCenter)
        let revisionCenter = ReadModelRevisionCenter()
        let avatarPipeline = AvatarPipeline()
        let coconutWallet = SwiftDataCoconutWalletManager()
        let domainRevisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let questManager = QuestManager(wallet: coconutWallet, revisions: domainRevisions)
        let locationManager = LocationManager()
        let careLedger = CareLedgerService()
        let automaticBackups = AutomaticBackupService()
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
        let familyTasks = StaticFamilyTaskManager(wallet: coconutWallet, careLedger: careLedger, questManager: questManager)
        let reminderScheduling = ReminderSchedulingManager(careLedger: careLedger)
        let medicationReminders = SharedMedicationReminderManager(careLedger: careLedger)
        let reminderCompletion = ReminderCompletionService(
            careLedger: careLedger,
            familyTasks: familyTasks,
            reminderScheduling: reminderScheduling,
            notifications: notificationManager
        )
        let quickActionReminderCompletion = QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion)
        let careEventDependencies = CareEventServiceDependencies(
            economy: careEventEconomy,
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: quickActionReminderCompletion,
            familyTasks: familyTasks,
            revisions: domainRevisions,
            notifications: notificationManager
        )
        DomainServiceDependencyRegistry.register(
            careEventDependencies: { careEventDependencies },
            careEventEconomy: { careEventEconomy },
            familyTasks: { familyTasks },
            reminderScheduling: { _ in reminderScheduling },
            medicationReminders: { _ in medicationReminders },
            reminderCompletion: { _ in reminderCompletion }
        )
        let walkingManager = PetWalkingManager(
            locationManager: locationManager,
            questManager: questManager,
            careLedger: careLedger,
            walkCareEvents: StaticWalkCareEventManager(dependencies: careEventDependencies)
        )
        AppWorkloadPolicy.shared.hasRunningWalkProvider = { walkingManager.hasActiveLocationWalk }
        self.init(
            careEvents: CareEventService(dependencies: careEventDependencies),
            activeHumanSelection: activeHumanSelection,
            coconutWallet: coconutWallet,
            coconutExchange: StaticCoconutExchangeManager(wallet: coconutWallet, careLedger: careLedger, questManager: questManager),
            careLedger: careLedger,
            questManager: questManager,
            familyTasks: familyTasks,
            gacha: StaticGachaDrawer(wallet: coconutWallet, careLedger: careLedger, questManager: questManager),
            memberCreation: MemberCreationService(
                activeHumanSelection: activeHumanSelection,
                wallet: coconutWallet,
                careLedger: careLedger,
                revisions: domainRevisions,
                questManager: questManager
            ),
            oasisRewards: oasisRewardManager,
            privacy: StaticHumanPrivacyManager(),
            passcodes: StaticHumanPasscodeManager(),
            appIcons: SystemAppIconManager(),
            shopInventory: UserDefaultsShopInventoryManager(),
            shopPurchaseFulfillment: ShopPurchaseFulfillmentService(),
            islandToasts: IslandToastManager(),
            metricKit: MetricKitObserver(),
            backups: SharedDataBackupManagerAdapter(projectionManager: questManager),
            automaticBackups: automaticBackups,
            appReset: StaticAppResetter(questManager: questManager),
            medicationReminders: medicationReminders,
            userNotifications: SharedUserNotificationManager(manager: notificationManager),
            notificationRoutes: SharedNotificationRoutePublisher(center: notificationRouteCenter),
            reminderActions: LiveReminderActionHandler(),
            reminderScheduling: reminderScheduling,
            reminderCompletion: reminderCompletion,
            onboardingJourney: LiveOnboardingJourneyCoordinator(),
            humanRequirements: LiveHumanRequirementResolver(),
            todayFocus: StaticTodayFocusManager(
                questManager: questManager,
                careLedger: careLedger,
                revisions: domainRevisions
            ),
            plantCarePlans: StaticPlantCarePlanReader(),
            oasisTree: SharedOasisTreeManager(manager: oasisTreeManager),
            healthAlerts: SharedPetHealthAlertEngine(),
            walking: SharedPetWalkingManager(manager: walkingManager),
            location: SharedLocationProvider(manager: locationManager),
            careLedgerStats: CareLedgerStatsReader(),
            domainRevisions: domainRevisions,
            lifecycle: AppLifecycleCoordinator(dependencies: .live(
                walkingManager: walkingManager,
                automaticBackups: automaticBackups,
                modelContainer: modelContainer
            )),
            cloudSync: AppServices.makeCloudSyncService()
        )
        OasisTreeManagerRegistry.current = oasisTreeManager
        AvatarPipelineRegistry.current = avatarPipeline
        ReminderNotificationSchedulerRegistry.registerLiveSchedulerFactory { notificationManager }
        ReminderNotificationSchedulerRegistry.current = notificationManager
    }

    private static func makeCloudSyncService() -> any CloudSyncManaging {
        guard OnlineFeatureGate.allows(.onlineCollaboration) else {
            return LocalDeviceCloudSyncService()
        }

        #if OHANA_LOCAL_DEVICE
            return LocalDeviceCloudSyncService()
        #else
            return CloudSyncEngineService()
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
        onboardingJourney: OnboardingJourneyCoordinating,
        humanRequirements: HumanRequirementResolving,
        todayFocus: TodayFocusManaging,
        plantCarePlans: PlantCarePlanReading,
        oasisTree: OasisTreeManaging,
        healthAlerts: PetHealthAlerting,
        walking: PetWalkingManaging,
        location: LocationProviding,
        careLedgerStats: CareLedgerStatsReading,
        domainRevisions: DomainRevisionPublishing,
        lifecycle: AppLifecycleHandling,
        cloudSync: CloudSyncManaging
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
        self.onboardingJourney = onboardingJourney
        self.humanRequirements = humanRequirements
        self.todayFocus = todayFocus
        self.plantCarePlans = plantCarePlans
        self.oasisTree = oasisTree
        self.healthAlerts = healthAlerts
        self.walking = walking
        self.location = location
        self.careLedgerStats = careLedgerStats
        self.domainRevisions = domainRevisions
        self.lifecycle = lifecycle
        self.cloudSync = cloudSync
    }
}
