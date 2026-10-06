import SwiftUI

// Keep member-owned routes typed while using view destinations. The app's root
// stack binds [AppRoute], so it cannot append a HumanHealthSummaryRoute value.
struct HumanHealthSummaryDestinationView: View {
    let human: Human
    let route: HumanHealthSummaryRoute
    @Binding var quickRecord: HumanHealthQuickRecord?
    @Binding var savedRecordRoute: HumanHealthSummaryRoute?
    var onOpenAchievements: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onOpenTasks: (() -> Void)?
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""
    @State private var legacyFeaturePath = NavigationPath()
    private var l: L10n { L10n(appLanguage) }
    private var activeHumanID: UUID? { UUID(uuidString: activeHumanIDRaw) }

    var body: some View {
        switch route {
        case let .feature(destination):
            switch destination {
            case .medication:
                HumanMedicationView(human: human, showsDoneButton: false)
            case .metrics:
                HumanHealthCheckupView(human: human)
            case .conditions:
                HumanHealthConditionsView(human: human, showsCloseButton: false)
            case .reports:
                HumanHealthReportView(human: human)
            case .weight:
                HumanWeightHistoryView(human: human, showsCloseButton: false)
            case .workouts:
                HumanWorkoutSummaryView(human: human, showsCloseButton: false)
            }
        case let .condition(id):
            HumanHealthConditionRouteView(human: human, conditionID: id)
        case .profile:
            AppHumanRouteContainer(id: human.id, showsHealthHome: false, onPresentCoconutLog: onPresentCoconutLog ?? { _ in }, onOpenTasks: onOpenTasks ?? {})
        case .directory:
            HumanHealthMoreView(human: human, quickRecord: $quickRecord, savedRecordRoute: $savedRecordRoute, onOpenAchievements: onOpenAchievements, onPresentCoconutLog: onPresentCoconutLog, onOpenTasks: onOpenTasks)
        case .notes:
            HumanNoteHistorySheet(human: human, showsCloseButton: false)
        case .expenses:
            HumanExpenseDetailView(human: human, showsCloseButton: false)
        case .wishlist:
            HumanWishlistView(human: human)
        case .assets:
            if human.isPrivate(.wishlist, viewedBy: activeHumanID) { Text(l.tr(zh: "当前查看者不可见", en: "Hidden from the current viewer", de: "Für die aktuelle Person ausgeblendet")) }
            else { CoconutLogView(subject: .human(human.id), showsCloseButton: false) }
        case .achievements:
            FunctionMenuDestinationRouteContainer(destination: .featureAggregate(.achievements), parentPath: $legacyFeaturePath)
        case let .metric(metricKey):
            if let metric = HealthMetricCatalog.metric(forKey: metricKey) {
                HumanHealthMetricDetailView(human: human, metric: metric)
            } else {
                HumanHealthCheckupView(human: human)
            }
        }
    }
}
