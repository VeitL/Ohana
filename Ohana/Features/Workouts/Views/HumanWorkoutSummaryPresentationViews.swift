import SwiftUI

enum HumanWorkoutAppleHealthBindingAction {
    case bind
    case rebind
    case unbind
}

struct HumanWorkoutAppleHealthBindingCard: View {
    let humanName: String
    let state: HumanAppleHealthBindingState
    let boundHumanName: String?
    let onRequestAction: (HumanWorkoutAppleHealthBindingAction) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).accessibilityHidden(true)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            bindingControl

            Text(l.tr(
                zh: "绑定仅保存在本机；解绑不删除记录或更改系统权限。",
                en: "The binding stays on this device. Unbinding does not delete logs or change system access.",
                de: "Die Bindung bleibt auf diesem Gerät. Trennen löscht keine Einträge und ändert keine Systemrechte."
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .workoutSummaryCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("human-workout-apple-health-binding-card")
    }

    @ViewBuilder
    private var bindingControl: some View {
        switch state {
        case .unbound:
            bindingButton(
                title: l.tr(zh: "绑定到 \(humanName)", en: "Bind to \(humanName)", de: "Mit \(humanName) verbinden"),
                icon: "link",
                identifier: "human-workout-apple-health-bind-action"
            ) {
                onRequestAction(.bind)
            }
        case .boundToViewedHuman:
            HStack(spacing: 10) {
                Label(
                    l.tr(zh: "已绑定到 \(humanName)", en: "Bound to \(humanName)", de: "Mit \(humanName) verbunden"),
                    systemImage: "checkmark.seal.fill"
                )
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goTeal)
                Spacer(minLength: 8)
                Button(l.tr(zh: "解绑", en: "Unbind", de: "Trennen")) {
                    onRequestAction(.unbind)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("human-workout-apple-health-unbind-action")
            }
        case .boundToOtherHuman:
            bindingButton(
                title: l.tr(zh: "改绑到 \(humanName)", en: "Rebind to \(humanName)", de: "Mit \(humanName) neu verbinden"),
                icon: "arrow.triangle.2.circlepath",
                identifier: "human-workout-apple-health-rebind-action"
            ) {
                onRequestAction(.rebind)
            }
        case .viewedHumanUnavailable:
            Label(
                l.tr(zh: "纪念档案不能绑定 Apple Health", en: "Memorial profiles cannot bind Apple Health", de: "Gedenkprofile können nicht mit Apple Health verbunden werden"),
                systemImage: "lock.fill"
            )
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func bindingButton(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var title: String {
        switch state {
        case .unbound:
            l.tr(zh: "先选择 Apple Health 所属成员", en: "Choose who owns Apple Health", de: "Apple Health einer Person zuordnen")
        case .boundToViewedHuman:
            l.tr(zh: "Apple Health 设备绑定", en: "Apple Health device binding", de: "Apple-Health-Gerätebindung")
        case .boundToOtherHuman:
            l.tr(zh: "Apple Health 已绑定其他成员", en: "Apple Health is bound elsewhere", de: "Apple Health ist anderswo verbunden")
        case .viewedHumanUnavailable:
            l.tr(zh: "Apple Health 不适用于纪念档案", en: "Apple Health is unavailable here", de: "Apple Health ist hier nicht verfügbar")
        }
    }

    private var subtitle: String {
        switch state {
        case .unbound:
            return l.tr(
                zh: "绑定前不读取 Apple Health 数据。",
                en: "Apple Health data is not read before binding.",
                de: "Apple-Health-Daten werden vor der Bindung nicht gelesen."
            )
        case .boundToViewedHuman:
            return l.tr(
                zh: "仅显示在 \(humanName) 的本机运动页。",
                en: "Shown only on \(humanName)’s on-device workout screen.",
                de: "Nur in \(humanName)s lokaler Trainingsansicht sichtbar."
            )
        case .boundToOtherHuman:
            let owner = boundHumanName ?? l.tr(zh: "另一位成员", en: "another Human", de: "eine andere Person")
            return l.tr(
                zh: "当前绑定：\(owner) · 改绑需确认",
                en: "Currently bound to \(owner) · confirmation required to rebind",
                de: "Aktuell mit \(owner) verbunden · neue Bindung bestätigen"
            )
        case .viewedHumanUnavailable:
            return l.tr(
                zh: "仅保留历史，不读取实时数据。",
                en: "History only; live data is not read.",
                de: "Nur Verlauf; Live-Daten werden nicht gelesen."
            )
        }
    }

    private var icon: String {
        switch state {
        case .unbound: "person.crop.circle.badge.questionmark"
        case .boundToViewedHuman: "person.crop.circle.badge.checkmark"
        case .boundToOtherHuman: "person.crop.circle.badge.exclamationmark"
        case .viewedHumanUnavailable: "heart.slash.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .boundToViewedHuman: .goTeal
        case .boundToOtherHuman: .goYellow
        case .unbound, .viewedHumanUnavailable: .goPrimary
        }
    }
}

struct HumanWorkoutSectionHeading: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).accessibilityHidden(true)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.goPrimary.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .padding(.top, 4)
    }
}

struct HumanWorkoutHealthSnapshotCards: View {
    let authorizationStatus: HumanHealthAuthorizationStatus
    let activitySummaryStatus: HumanHealthActivitySummaryStatus
    let snapshot: HumanWorkoutHealthSnapshot
    let isLoading: Bool
    let onRequestHealthAccess: () -> Void
    let onRefresh: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        healthConnectionCard
        activityRingsCard
        metricCardsGrid
    }

    private var healthConnectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "heart.text.square.fill").accessibilityHidden(true)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(connectionTitle)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(connectionSubtitle)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .tint(Color.goPrimary)
                        .frame(width: 44, height: 44)
                }
            }

            HStack(spacing: 10) {
                if showsHealthSetupAction {
                    Button(action: onRequestHealthAccess) {
                        Text(connectionButtonTitle)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isLoading || authorizationStatus == .notAvailable)
                    .accessibilityIdentifier("human-workout-health-connect-action")
                }

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise").accessibilityHidden(true)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 48, height: 48)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isLoading || authorizationStatus == .notAvailable)
                .accessibilityLabel(l.tr(zh: "刷新运动数据", en: "Refresh workout data", de: "Trainingsdaten aktualisieren"))
                .accessibilityIdentifier("human-workout-health-refresh-action")
            }
        }
        .padding(16)
        .workoutSummaryCard()
    }

    private var activityRingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "活动环", en: "Activity Rings", de: "Aktivitätsringe"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            HStack(spacing: 18) {
                HumanWorkoutActivityRings(snapshot: snapshot, l: l)
                    .frame(width: 136, height: 136)

                VStack(alignment: .leading, spacing: 12) {
                    ActivityRingMetric(
                        title: l.tr(zh: "活动", en: "Move", de: "Bewegen"),
                        value: moveMetricText,
                        color: .goRed
                    )
                    ActivityRingMetric(
                        title: l.tr(zh: "锻炼", en: "Exercise", de: "Training"),
                        value: exerciseMetricText,
                        color: .goPrimary
                    )
                    ActivityRingMetric(
                        title: l.tr(zh: "站立", en: "Stand", de: "Stehen"),
                        value: standMetricText,
                        color: .goCardCyan
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let activityGoalStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(activityGoalStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-activity-goal-status")
            }

            if let todayComponentStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goYellow)
                    Text(todayComponentStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-today-component-status")
            }
        }
        .padding(16)
        .workoutSummaryCard()
    }

    private var metricCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HumanWorkoutMetricCard(
                title: l.tr(zh: "步数", en: "Step Count", de: "Schritte"),
                subtitle: todayMetricSubtitle(for: snapshot.componentAvailability.steps),
                value: todayMetricValue(
                    "\(snapshot.steps)",
                    state: snapshot.componentAvailability.steps
                ),
                unit: "",
                tint: .goPurple,
                points: snapshot.componentAvailability.steps == .available
                    ? chartPoints(from: snapshot.hourlySteps, idPrefix: "steps")
                    : []
            )
            HumanWorkoutMetricCard(
                title: l.tr(zh: "步行距离", en: "Step Distance", de: "Schrittdistanz"),
                subtitle: todayMetricSubtitle(for: snapshot.componentAvailability.distance),
                value: todayMetricValue(
                    String(format: "%.2f", snapshot.distanceKm),
                    state: snapshot.componentAvailability.distance
                ),
                unit: "km",
                tint: .goCardCyan,
                points: snapshot.componentAvailability.distance == .available
                    ? chartPoints(from: snapshot.hourlyDistanceKm, idPrefix: "distance")
                    : []
            )
        }
    }

    private var connectionTitle: String {
        switch authorizationStatus {
        case .notAvailable:
            l.tr(zh: "Apple Health 不可用", en: "Apple Health Unavailable", de: "Apple Health nicht verfügbar")
        case .notDetermined:
            l.tr(zh: "连接 Apple Health", en: "Connect Apple Health", de: "Apple Health verbinden")
        case .accessRequested:
            l.tr(zh: "Apple Health 已设置", en: "Apple Health Set Up", de: "Apple Health eingerichtet")
        case .unknown:
            l.tr(zh: "检查 Apple Health", en: "Check Apple Health", de: "Apple Health prüfen")
        case .failed:
            l.tr(zh: "读取 Apple Health 失败", en: "Apple Health Read Failed", de: "Apple Health konnte nicht gelesen werden")
        }
    }

    private var connectionSubtitle: String {
        switch authorizationStatus {
        case .notAvailable:
            l.tr(zh: "当前设备不支持读取 HealthKit 数据。", en: "This device cannot read HealthKit data.", de: "Dieses Gerät kann keine HealthKit-Daten lesen.")
        case .notDetermined:
            l.tr(zh: "读取步数、距离、活动能量、活动目标和运动记录，只用于此成员的本地页面。", en: "Read steps, distance, active energy, activity goals, and workouts for this member’s local screen.", de: "Liest Schritte, Distanz, Aktivenergie, Aktivitätsziele und Trainings für diese lokale Ansicht.")
        case .accessRequested:
            l.tr(zh: "页面直接显示 Apple Health 当前允许读取的数据；无法读取的单项会明确标为不可用。", en: "This screen shows data Apple Health currently allows; unreadable types are marked unavailable.", de: "Diese Ansicht zeigt aktuell erlaubte Apple-Health-Daten; nicht lesbare Typen werden als nicht verfügbar markiert.")
        case .unknown:
            l.tr(zh: "点按刷新，Ohana 会重新检查可读取的数据。", en: "Refresh to check readable data again.", de: "Aktualisiere, um lesbare Daten erneut zu prüfen.")
        case let .failed(message):
            message
        }
    }

    private var connectionButtonTitle: String {
        switch authorizationStatus {
        case .notAvailable:
            l.tr(zh: "不可用", en: "Unavailable", de: "Nicht verfügbar")
        default:
            l.tr(zh: "设置", en: "Set Up", de: "Einrichten")
        }
    }

    private var showsHealthSetupAction: Bool {
        switch authorizationStatus {
        case .notDetermined, .unknown, .failed:
            true
        case .notAvailable, .accessRequested:
            false
        }
    }

    private var moveMetricText: String {
        guard snapshot.componentAvailability.move == .available else { return "—" }
        if snapshot.moveMode == .moveTime {
            if snapshot.moveGoal > 0 {
                return "\(snapshot.moveValue)/\(snapshot.moveGoal) min"
            }
            return "\(snapshot.moveValue) min"
        }
        if snapshot.moveGoal > 0 {
            return "\(snapshot.moveValue)/\(snapshot.moveGoal) kcal"
        }
        return "\(snapshot.moveValue) kcal"
    }

    private var activityGoalStatusText: String? {
        switch activitySummaryStatus {
        case .notLoaded:
            nil
        case .noData:
            l.tr(
                zh: "今天没有可读取的活动目标。请在 Apple Health 中检查 Ohana 的“活动”读取权限。",
                en: "No activity goals are readable today. Check Ohana’s Activity access in Apple Health.",
                de: "Heute sind keine Aktivitätsziele lesbar. Prüfe Ohanas Aktivitätszugriff in Apple Health."
            )
        case .failed:
            l.tr(
                zh: "活动目标读取失败；成功读取的今日数值仍会显示，失败项目会标为不可用。",
                en: "Activity goals could not be read. Successfully read values remain visible; failed components are marked unavailable.",
                de: "Aktivitätsziele konnten nicht gelesen werden. Erfolgreich gelesene Werte bleiben sichtbar; fehlgeschlagene Komponenten werden als nicht verfügbar markiert."
            )
        case .available:
            switch snapshot.activityGoalAvailability {
            case .complete:
                nil
            case .partial:
                l.tr(
                    zh: "Apple Health 只提供了部分目标；已有目标的圆环仍按真实进度显示。",
                    en: "Apple Health provided only some goals; available rings still show real progress.",
                    de: "Apple Health lieferte nur einige Ziele; verfügbare Ringe zeigen den echten Fortschritt."
                )
            case .unavailable:
                l.tr(
                    zh: "Apple Health 未提供活动目标；今日数值仍会显示。",
                    en: "Apple Health did not provide activity goals; today’s values remain visible.",
                    de: "Apple Health lieferte keine Aktivitätsziele; heutige Werte bleiben sichtbar."
                )
            }
        }
    }

    private var todayComponentStatusText: String? {
        guard snapshot.componentAvailability.hasUnavailableComponent else { return nil }
        return l.tr(
            zh: "Apple Health 的部分今日项目无法读取，已标为不可用；不会用 0 代替失败结果。",
            en: "Some Apple Health components could not be read and are marked unavailable; failed reads are not replaced with zero.",
            de: "Einige heutige Apple-Health-Werte konnten nicht gelesen werden und sind als nicht verfügbar markiert; fehlgeschlagene Abfragen werden nicht durch null ersetzt."
        )
    }

    private func todayMetricSubtitle(for state: HumanHealthTodayComponentReadState) -> String {
        switch state {
        case .available:
            l.tr(zh: "今天", en: "Today", de: "Heute")
        case .notLoaded:
            l.tr(zh: "尚未读取", en: "Not loaded", de: "Nicht geladen")
        case .unavailable:
            l.tr(zh: "不可用", en: "Unavailable", de: "Nicht verfügbar")
        }
    }

    private func todayMetricValue(_ value: String, state: HumanHealthTodayComponentReadState) -> String {
        state == .available ? value : "—"
    }

    private var exerciseMetricText: String {
        guard snapshot.componentAvailability.exercise == .available else { return "—" }
        if snapshot.exerciseGoalMinutes > 0 {
            return "\(snapshot.exerciseMinutes)/\(snapshot.exerciseGoalMinutes) min"
        } else {
            return "\(snapshot.exerciseMinutes) min"
        }
    }

    private var standMetricText: String {
        guard snapshot.componentAvailability.stand == .available else { return "—" }
        if snapshot.standGoalHours > 0 {
            return "\(snapshot.standHours)/\(snapshot.standGoalHours) hrs"
        } else {
            return "\(snapshot.standHours) hrs"
        }
    }

    private func chartPoints(from points: [HumanHealthHourlyPoint], idPrefix: String) -> [OhanaMinimalChartPoint] {
        let start = Calendar.current.startOfDay(for: Date())
        return points.map { point in
            OhanaMinimalChartPoint(
                date: start.addingTimeInterval(Double(point.hour) * 3600),
                value: point.value,
                label: String(format: "%02d", point.hour),
                id: "\(idPrefix)-\(point.hour)"
            )
        }
    }
}

private struct HumanWorkoutActivityRings: View {
    let snapshot: HumanWorkoutHealthSnapshot
    let l: L10n

    var body: some View {
        ZStack {
            ActivityRing(
                progress: progress(
                    value: snapshot.moveValue,
                    goal: snapshot.moveGoal,
                    state: snapshot.componentAvailability.move
                ),
                color: .goRed,
                lineWidth: 18,
                inset: 0
            )
            ActivityRing(
                progress: progress(
                    value: snapshot.exerciseMinutes,
                    goal: snapshot.exerciseGoalMinutes,
                    state: snapshot.componentAvailability.exercise
                ),
                color: .goPrimary,
                lineWidth: 18,
                inset: 25
            )
            ActivityRing(
                progress: progress(
                    value: snapshot.standHours,
                    goal: snapshot.standGoalHours,
                    state: snapshot.componentAvailability.stand
                ),
                color: .goCardCyan,
                lineWidth: 18,
                inset: 50
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l.tr(zh: "活动环", en: "Activity rings", de: "Aktivitätsringe"))
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("human-workout-activity-rings")
    }

    private func progress(
        value: Int,
        goal: Int,
        state: HumanHealthTodayComponentReadState
    ) -> Double? {
        guard state == .available, goal > 0 else { return nil }
        return min(max(Double(value) / Double(goal), 0), 1.25)
    }

    private var accessibilityValue: String {
        let moveUnit = snapshot.moveMode == .moveTime ? minuteUnit : kilocalorieUnit
        let move = metricAccessibilityValue(
            value: snapshot.moveValue,
            goal: snapshot.moveGoal,
            unit: moveUnit,
            state: snapshot.componentAvailability.move
        )
        let exercise = metricAccessibilityValue(
            value: snapshot.exerciseMinutes,
            goal: snapshot.exerciseGoalMinutes,
            unit: minuteUnit,
            state: snapshot.componentAvailability.exercise
        )
        let stand = metricAccessibilityValue(
            value: snapshot.standHours,
            goal: snapshot.standGoalHours,
            unit: hourUnit,
            state: snapshot.componentAvailability.stand
        )
        return l.tr(
            zh: "活动 \(move)，锻炼 \(exercise)，站立 \(stand)",
            en: "Move \(move), exercise \(exercise), stand \(stand)",
            de: "Bewegen \(move), Training \(exercise), Stehen \(stand)"
        )
    }

    private func metricAccessibilityValue(
        value: Int,
        goal: Int,
        unit: String,
        state: HumanHealthTodayComponentReadState
    ) -> String {
        guard state == .available else {
            return l.tr(zh: "不可用", en: "unavailable", de: "nicht verfügbar")
        }
        guard goal > 0 else {
            return l.tr(
                zh: "\(value) \(unit)，目标不可用",
                en: "\(value) \(unit), goal unavailable",
                de: "\(value) \(unit), Ziel nicht verfügbar"
            )
        }
        return "\(value)/\(goal) \(unit)"
    }

    private var minuteUnit: String {
        l.tr(zh: "分钟", en: "minutes", de: "Minuten")
    }

    private var hourUnit: String {
        l.tr(zh: "小时", en: "hours", de: "Stunden")
    }

    private var kilocalorieUnit: String {
        l.tr(zh: "千卡", en: "kilocalories", de: "Kilokalorien")
    }
}

private struct ActivityRing: View {
    let progress: Double?
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(progress == nil ? 0.09 : 0.16), lineWidth: lineWidth)
            if let progress {
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if progress > 1 {
                    Circle()
                        .trim(from: 0, to: min(progress - 1, 0.25))
                        .stroke(color.opacity(0.72), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            } else {
                Circle()
                    .stroke(
                        color.opacity(0.34),
                        style: StrokeStyle(lineWidth: max(2, lineWidth * 0.22), lineCap: .round, dash: [1, 7])
                    )
            }
        }
        .padding(inset)
    }
}

private struct ActivityRingMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct HumanWorkoutMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let tint: Color
    let points: [OhanaMinimalChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 36))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                if !unit.isEmpty {
                    Text(unit.uppercased())
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(tint)
                }
            }
            OhanaMinimalBarChart(
                points: points,
                tint: tint,
                showsLabels: false,
                maxBarHeight: 74,
                emptyBarColor: Color.ohanaControlFill.opacity(0.72)
            )
            .frame(height: 82)
            HStack {
                ForEach(["00", "06", "12", "18"], id: \.self) { label in
                    Text(label)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    if label != "18" { Spacer() }
                }
            }
        }
        .padding(14)
        .frame(minHeight: 210, alignment: .top)
        .workoutSummaryCard()
    }
}

extension View {
    func workoutSummaryCard() -> some View {
        background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke.opacity(0.7), lineWidth: 1)
        }
    }
}
