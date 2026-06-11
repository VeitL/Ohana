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
    let islandToasts: IslandToastManager
    let metricKit: MetricKitObserving
    let backups: DataBackupManaging
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
    let oasisTree: OasisTreeManaging
    let healthAlerts: PetHealthAlerting
    let walking: PetWalkingManaging
    let location: LocationProviding
    let careLedgerStats: CareLedgerStatsReading
    let domainRevisions: DomainRevisionPublishing
    let lifecycle: AppLifecycleHandling
    let cloudSync: CloudSyncManaging

    convenience init() {
        let activeHumanSelection = UserDefaultsActiveHumanSelection()
        let notificationRouteCenter = OhanaNotificationRouteCenter()
        let notificationManager = NotificationManager(routeCenter: notificationRouteCenter)
        let locationManager = LocationManager()
        let revisionCenter = ReadModelRevisionCenter()
        let avatarPipeline = AvatarPipeline()
        let coconutWallet = SwiftDataCoconutWalletManager()
        let domainRevisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let questManager = QuestManager(wallet: coconutWallet, revisions: domainRevisions)
        let walkingManager = PetWalkingManager(locationManager: locationManager, questManager: questManager)
        let careLedger = CareLedgerService()
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
        let reminderCompletion = ReminderCompletionService(careLedger: careLedger, familyTasks: familyTasks)
        let quickActionReminderCompletion = QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion)
        AppWorkloadPolicy.shared.hasRunningWalkProvider = { walkingManager.hasActiveLocationWalk }
        self.init(
            careEvents: CareEventService(
                dependencies: CareEventServiceDependencies(
                    questManager: questManager,
                    economy: careEventEconomy,
                    careLedger: careLedger,
                    reminderCompletion: reminderCompletion,
                    quickActionReminderCompletion: quickActionReminderCompletion,
                    familyTasks: familyTasks,
                    revisions: domainRevisions
                )
            ),
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
            islandToasts: IslandToastManager(),
            metricKit: MetricKitObserver(),
            backups: SharedDataBackupManagerAdapter(questManager: questManager),
            appReset: StaticAppResetter(questManager: questManager),
            medicationReminders: SharedMedicationReminderManager(careLedger: careLedger),
            userNotifications: SharedUserNotificationManager(manager: notificationManager),
            notificationRoutes: SharedNotificationRoutePublisher(center: notificationRouteCenter),
            reminderActions: LiveReminderActionHandler(),
            reminderScheduling: ReminderSchedulingManager(careLedger: careLedger),
            reminderCompletion: reminderCompletion,
            onboardingJourney: LiveOnboardingJourneyCoordinator(),
            humanRequirements: LiveHumanRequirementResolver(),
            todayFocus: StaticTodayFocusManager(
                questManager: questManager,
                careLedger: careLedger,
                revisions: domainRevisions
            ),
            oasisTree: SharedOasisTreeManager(manager: oasisTreeManager),
            healthAlerts: SharedPetHealthAlertEngine(),
            walking: SharedPetWalkingManager(manager: walkingManager),
            location: SharedLocationProvider(manager: locationManager),
            careLedgerStats: CareLedgerStatsReader(),
            domainRevisions: domainRevisions,
            lifecycle: AppLifecycleCoordinator(dependencies: .live(walkingManager: walkingManager)),
            cloudSync: AppServices.makeCloudSyncService()
        )
        OasisTreeManagerRegistry.current = oasisTreeManager
        AvatarPipelineRegistry.current = avatarPipeline
        OhanaNotifications.current = notificationManager
    }

    private static func makeCloudSyncService() -> any CloudSyncManaging {
        #if OHANA_LOCAL_DEVICE
            LocalDeviceCloudSyncService()
        #else
            CloudSyncEngineService()
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
        islandToasts: IslandToastManager,
        metricKit: MetricKitObserving,
        backups: DataBackupManaging,
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
        self.islandToasts = islandToasts
        self.metricKit = metricKit
        self.backups = backups
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
