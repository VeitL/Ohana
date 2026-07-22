//
//  GuardianSafetyDashboardRouteContainer.swift
//  Ohana
//
//  Optional Family-only, App-to-App guardian experience. Local profiles and
//  sensitive household facts never enter this surface or its API contract.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import UIKit

@MainActor
struct GuardianSafetyDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppExperienceMode.zenOwnerHumanIDKey) private var ownerHumanIDRaw = ""
    @State private var routeData = GuardianSafetyDashboardRouteData()

    private let initialInviteCode: String?
    private let initialIncidentID: String?

    init(initialInviteCode: String? = nil, initialIncidentID: String? = nil) {
        self.initialInviteCode = initialInviteCode
        self.initialIncidentID = initialIncidentID
    }

    var body: some View {
        Group {
            if routeData.hasLoaded {
                GuardianSafetyDashboardContentView(
                    initialInviteCode: initialInviteCode,
                    initialIncidentID: initialIncidentID,
                    ownerID: routeData.ownerID,
                    ownerIsAvailable: routeData.ownerIsAvailable,
                    waitingGuardianSignalCount: routeData.waitingGuardianSignalCount
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OhanaStaticAppBackground())
                    .navigationTitle(L10n(appLanguage).tr(
                        zh: "亲友守护",
                        en: "Guardian circle",
                        de: "Schutzkreis"
                    ))
                    .navigationBarTitleDisplayMode(.inline)
                    .accessibilityLabel(L10n(appLanguage).tr(
                        zh: "正在载入亲友守护",
                        en: "Loading guardian circle",
                        de: "Schutzkreis wird geladen"
                    ))
            }
        }
        .task(id: loadKey) {
            await loadRouteData()
        }
    }

    private var selectedOwnerID: UUID? {
        UUID(uuidString: ownerHumanIDRaw)
    }

    private var loadKey: GuardianSafetyDashboardLoadKey {
        GuardianSafetyDashboardLoadKey(
            ownerID: selectedOwnerID,
            homeRevision: appServices.domainRevisions.homeRevision.value
        )
    }

    private func loadRouteData() async {
        let loader = GuardianSafetyDashboardRouteDataActor(modelContainer: modelContext.container)
        do {
            let loaded = try await loader.load(ownerID: selectedOwnerID)
            guard !Task.isCancelled else { return }
            routeData = loaded
        } catch {
            guard !Task.isCancelled else { return }
            routeData = GuardianSafetyDashboardRouteData(
                ownerID: selectedOwnerID,
                ownerIsAvailable: false,
                waitingGuardianSignalCount: 0,
                hasLoaded: true
            )
        }
    }
}

private nonisolated struct GuardianSafetyDashboardLoadKey: Equatable, Hashable, Sendable {
    let ownerID: UUID?
    let homeRevision: Int
}

private nonisolated struct GuardianSafetyDashboardRouteData: Equatable, Sendable {
    var ownerID: UUID?
    var ownerIsAvailable: Bool
    var waitingGuardianSignalCount: Int
    var hasLoaded: Bool

    init(
        ownerID: UUID? = nil,
        ownerIsAvailable: Bool = false,
        waitingGuardianSignalCount: Int = 0,
        hasLoaded: Bool = false
    ) {
        self.ownerID = ownerID
        self.ownerIsAvailable = ownerIsAvailable
        self.waitingGuardianSignalCount = waitingGuardianSignalCount
        self.hasLoaded = hasLoaded
    }
}

@ModelActor
private actor GuardianSafetyDashboardRouteDataActor {
    func load(ownerID: UUID?) throws -> GuardianSafetyDashboardRouteData {
        let ownerIsAvailable: Bool
        if let ownerID {
            var ownerDescriptor = FetchDescriptor<Human>(
                predicate: #Predicate<Human> { human in
                    human.id == ownerID && human.passedAwayDate == nil
                }
            )
            ownerDescriptor.fetchLimit = 1
            ownerIsAvailable = try modelContext.fetchCount(ownerDescriptor) > 0
        } else {
            ownerIsAvailable = false
        }

        let waitingDescriptor = FetchDescriptor<GuardianSafetySyncOutbox>(
            predicate: #Predicate<GuardianSafetySyncOutbox> { $0.stateRaw != "sent" }
        )
        return try GuardianSafetyDashboardRouteData(
            ownerID: ownerID,
            ownerIsAvailable: ownerIsAvailable,
            waitingGuardianSignalCount: modelContext.fetchCount(waitingDescriptor),
            hasLoaded: true
        )
    }
}

@MainActor
private struct GuardianSafetyDashboardContentView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(AppExperienceController.self) private var experienceController
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    let ownerID: UUID?
    let ownerIsAvailable: Bool
    let waitingGuardianSignalCount: Int

    @State private var pendingInviteCode: String
    @State private var focusedIncidentID: String?
    @State private var invitationCode = ""
    @State private var policyEnabled = false
    @State private var selectedWeekdays = Set(1 ... 7)
    @State private var deadline = Date()
    @State private var gracePeriodMinutes = 60
    @State private var isPaused = false
    @State private var pauseUntil = Date()
    @State private var notice: GuardianDashboardNotice?
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var didApplyRemotePolicy = false

    init(
        initialInviteCode: String? = nil,
        initialIncidentID: String? = nil,
        ownerID: UUID?,
        ownerIsAvailable: Bool,
        waitingGuardianSignalCount: Int
    ) {
        self.ownerID = ownerID
        self.ownerIsAvailable = ownerIsAvailable
        self.waitingGuardianSignalCount = waitingGuardianSignalCount
        _pendingInviteCode = State(initialValue: initialInviteCode ?? "")
        _focusedIncidentID = State(initialValue: initialIncidentID)
    }

    private var l: L10n { L10n(appLanguage) }
    private var guardian: any GuardianSafetyManaging { appServices.guardianSafety }
    private var ownerRelationships: [GuardianRemoteRelationshipDTO] {
        guardian.dashboard.relationships.filter { !$0.currentUserIsGuardian && $0.status != .revoked }
    }
    private var guardianRelationships: [GuardianRemoteRelationshipDTO] {
        guardian.dashboard.relationships.filter(\.currentUserIsGuardian)
    }
    private var acceptedGuardians: [GuardianRemoteRelationshipDTO] {
        ownerRelationships.filter { $0.status == .accepted }
    }
    private var reachableGuardianCount: Int {
        acceptedGuardians.count { $0.reachability == .active }
    }
    private var canInvite: Bool {
        appServices.commerce.hasFamilyEntitlement &&
            acceptedGuardians.count < OhanaPlanCapabilities.make(for: .family).contacts.maximumAcceptedGuardians
    }
    private var serviceIsConfigured: Bool { OnlineFeatureGate.allows(.guardianSafety) }

    var body: some View {
        Form {
            if !serviceIsConfigured {
                releaseGateSection
            } else {
                serviceContent
            }
            privacySection
            if serviceIsConfigured {
                accountSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(OhanaStaticAppBackground())
        .navigationTitle(t("亲友守护", "Guardian circle", "Schutzkreis"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshService()
        }
        .task {
            await guardian.start()
            applyRemotePolicyIfNeeded(force: true)
            await resolvePendingRouteIfPossible()
        }
        .onChange(of: guardian.dashboard) { _, _ in
            applyRemotePolicyIfNeeded(force: true)
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(t("好", "OK", "OK")))
            )
        }
        .confirmationDialog(
            t("删除在线守护账号？", "Delete online guardian account?", "Online-Schutzkonto löschen?"),
            isPresented: $isShowingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button(t("删除账号", "Delete account", "Konto löschen"), role: .destructive) {
                Task { await guardian.deleteOnlineAccount() }
            }
            Button(t("取消", "Cancel", "Abbrechen"), role: .cancel) {}
        } message: {
            Text(t(
                "所有守护调度会立即停止；云端最小关系数据将在 30 天内清除。本机签到、成员与椰子不受影响。",
                "All guardian scheduling stops immediately. Minimal online relationship data is deleted within 30 days. Local check-ins, members, and coconuts are unaffected.",
                "Alle Schutzplanungen enden sofort. Minimale Online-Beziehungsdaten werden innerhalb von 30 Tagen gelöscht. Lokale Check-ins, Mitglieder und Kokosnüsse bleiben erhalten."
            ))
        }
        .accessibilityIdentifier("guardian-safety-dashboard")
    }

    @ViewBuilder
    private var serviceContent: some View {
        switch guardian.accountState {
        case .unavailable:
            releaseGateSection
        case .signedOut, .failed:
            signInSection
        case .signingIn:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(t("正在使用 Apple 登录…", "Signing in with Apple…", "Anmeldung mit Apple…"))
                }
            }
        case .signedIn:
            if !appServices.commerce.hasFamilyEntitlement {
                familyPlanSection
            }
            statusSection
            acceptInvitationSection
            guardianRoleSection
            if appServices.commerce.hasFamilyEntitlement {
                ownerPolicySection
                ownerGuardiansSection
                invitationSection
            }
            incidentSection
            if case let .failed(message) = guardian.dashboardState {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var releaseGateSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("尚未开放", "Not yet enabled", "Noch nicht aktiviert"))
                        .font(OhanaFont.headline())
                    Text(t(
                        "App 内守护代码已保持关闭。只有 AWS、APNs、Apple 登录、隐私声明、StoreKit Sandbox 与双真机验证全部通过后才会开放。",
                        "The in-app guardian runtime remains off. It will open only after AWS, APNs, Sign in with Apple, privacy, StoreKit Sandbox, and two-device gates pass.",
                        "Der App-Schutz bleibt deaktiviert. Er wird erst nach bestandenen AWS-, APNs-, Apple-Anmelde-, Datenschutz-, StoreKit-Sandbox- und Zwei-Geräte-Prüfungen geöffnet."
                    ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "checkmark.shield.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goPrimary)
            }
        } header: {
            Text("Ohana Family")
        } footer: {
            Text(t(
                "当前不会注册远程推送、要求登录或展示购买按钮。本机打卡与提醒照常工作。",
                "This build does not register remote alerts, require an account, or show a purchase action. Local check-ins and reminders keep working.",
                "Dieser Build registriert keine Remote-Mitteilungen, verlangt kein Konto und zeigt keinen Kauf. Lokale Check-ins und Erinnerungen funktionieren weiter."
            ))
        }
    }

    private var signInSection: some View {
        Section {
            Button {
                Task {
                    await guardian.signIn()
                    await resolvePendingRouteIfPossible()
                }
            } label: {
                Label(
                    t("使用 Apple 登录", "Continue with Apple", "Mit Apple fortfahren"),
                    systemImage: "apple.logo"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .accessibilityIdentifier("guardian-sign-in-apple")
        } header: {
            Text(t("仅在线守护需要账号", "An account is only for online guarding", "Ein Konto ist nur für Online-Schutz nötig"))
        } footer: {
            Text(t(
                "普通本地功能继续免登录。Ohana 只用匿名账号 ID 连接守护邀请、设备推送和最小事件状态。",
                "Local features remain account-free. Ohana uses an anonymous account ID only for guardian invitations, device alerts, and minimal incident state.",
                "Lokale Funktionen bleiben kontofrei. Ohana nutzt eine anonyme Konto-ID nur für Einladungen, Gerätehinweise und minimale Ereigniszustände."
            ))
        }
    }

    private var familyPlanSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ohana Family")
                        .font(OhanaFont.title3(.bold))
                    Spacer()
                    Text(appServices.commerce.familyDisplayPrice.map { "\($0) / \(t("年", "year", "Jahr"))" } ?? "—")
                        .font(OhanaFont.body(.semibold))
                }
                Text(t(
                    "最多 3 位 App 内守护人、星期计划、宽限期、两次克制提醒。无试用，不增加椰子奖励或扭蛋概率。",
                    "Up to three in-app guardians, weekday schedules, a grace period, and two restrained alerts. No trial and no coconut or gacha advantage.",
                    "Bis zu drei App-Vertrauenspersonen, Wochentage, Karenzzeit und zwei zurückhaltende Hinweise. Kein Probeabo und keine Kokosnuss- oder Gacha-Vorteile."
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaSecondaryText)
                Button(t("订阅年度 Family", "Subscribe to Family yearly", "Family jährlich abonnieren")) {
                    purchaseFamily()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appServices.commerce.isPurchasing || appServices.commerce.familyDisplayPrice == nil)
                Button(t("恢复购买", "Restore purchases", "Käufe wiederherstellen")) {
                    restorePurchases()
                }
                .buttonStyle(.borderless)
                .disabled(appServices.commerce.isRestoring)
            }
            .padding(.vertical, 4)
        } footer: {
            Text(t(
                "Family 与 Personal 属于同一订阅组。Family 失效后，有独立 Personal/Lifetime 则回落至 Personal，否则回 Free。",
                "Family and Personal share one subscription group. If Family expires, an independent Personal/Lifetime entitlement remains; otherwise the plan returns to Free.",
                "Family und Personal gehören zur selben Abo-Gruppe. Nach Ablauf bleibt ein separates Personal/Lifetime-Recht bestehen, sonst gilt Free."
            ))
        }
    }

    private var statusSection: some View {
        Section {
            LabeledContent(t("账号", "Account", "Konto"), value: accountStatusText)
            LabeledContent(t("套餐", "Plan", "Tarif"), value: appServices.commerce.ohanaPlanLevel.rawValue.capitalized)
            LabeledContent(t("服务状态", "Service status", "Dienststatus"), value: dashboardStatusText)
            if appServices.commerce.hasFamilyEntitlement {
                LabeledContent(t("可达守护人", "Reachable guardians", "Erreichbare Personen"), value: "\(reachableGuardianCount)/\(acceptedGuardians.count)")
            }
            if waitingGuardianSignalCount > 0 {
                Label(
                    l.tr(
                        zh: "本机签到已保存，守护状态等待同步",
                        en: "The local check-in is saved; guardian status is waiting to sync",
                        de: "Der lokale Check-in ist gespeichert; der Schutzstatus wartet auf Synchronisierung",
                        es: "El registro local está guardado; el estado de protección espera sincronización",
                        pt: "O check-in local foi salvo; o estado de proteção aguarda sincronização",
                        fr: "Le pointage local est enregistré ; l’état de garde attend la synchronisation",
                        ja: "端末内のチェックインは保存済みです。見守り状態は同期待ちです",
                        ko: "기기 내 체크인은 저장되었으며 보호 상태는 동기화 대기 중입니다",
                        it: "Il check-in locale è salvato; lo stato di protezione attende la sincronizzazione"
                    ),
                    systemImage: "arrow.triangle.2.circlepath.icloud"
                )
                .font(OhanaFont.footnote())
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text(t("状态", "Status", "Status"))
        }
    }

    private var acceptInvitationSection: some View {
        Section {
            TextField(t("16 位邀请码", "16-character invite code", "16-stelliger Einladungscode"), text: $invitationCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .accessibilityIdentifier("guardian-invite-code")
            Button(t("接受守护邀请", "Accept guardian invitation", "Schutzeinladung annehmen")) {
                let code = invitationCode
                invitationCode = ""
                Task { await guardian.acceptInvitation(code: code) }
            }
            .disabled(invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text(t("成为守护人", "Become a guardian", "Vertrauensperson werden"))
        } footer: {
            Text(t(
                "邀请只能在已安装的 Ohana 中登录并明确接受；网页不会直接建立关系。",
                "An invitation must be explicitly accepted after signing in inside the installed Ohana app; the web page cannot create the relationship.",
                "Eine Einladung muss nach der Anmeldung in der installierten Ohana-App ausdrücklich angenommen werden; die Webseite erstellt keine Beziehung."
            ))
        }
    }

    @ViewBuilder
    private var guardianRoleSection: some View {
        if !guardianRelationships.isEmpty {
            Section {
                ForEach(guardianRelationships) { relationship in
                    relationshipRow(relationship, allowsRevoke: relationship.status != .revoked)
                }
            } header: {
                Text(t("我守护的人", "People I guard", "Personen, die ich schütze"))
            } footer: {
                Text(t(
                    "守护人只能看到当前漏签事件、日期、确认和通知状态；看不到成员资料、宠物、植物、健康、体重或花费。",
                    "Guardians can only see current missed-check-in incidents, dates, acknowledgements, and notification status—not profiles, pets, plants, health, weight, or expenses.",
                    "Vertrauenspersonen sehen nur aktuelle Ereignisse, Daten, Bestätigungen und Mitteilungsstatus – keine Profile, Tiere, Pflanzen, Gesundheit, Gewicht oder Ausgaben."
                ))
            }
        }
    }

    private var ownerPolicySection: some View {
        Section {
            if experienceController.mode != .zen {
                Label(
                    t("切换到佛系模式后才能开始守护日。", "Switch to Zen mode before guard days can begin.", "Wechsle in den Zen-Modus, bevor Schutztage beginnen können."),
                    systemImage: "moon.stars.fill"
                )
                .foregroundStyle(.orange)
            } else if !ownerIsAvailable {
                Label(
                    t("请先在佛系模式中绑定在世的本人。", "Bind a living owner in Zen mode first.", "Lege zuerst eine lebende eigene Person im Zen-Modus fest."),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .foregroundStyle(.orange)
            }

            Toggle(t("开启亲友守护", "Enable guardian monitoring", "Schutz aktivieren"), isOn: $policyEnabled)
                .tint(Color.goPrimary)
                .disabled(!ownerIsAvailable || experienceController.mode != .zen || reachableGuardianCount == 0)

            if acceptedGuardians.isEmpty || reachableGuardianCount == 0 {
                Label(
                    t("至少需要 1 位已接受且通知可用的守护人。没有短信备用通道。", "At least one accepted guardian with working notifications is required. There is no SMS fallback.", "Mindestens eine bestätigte Person mit verfügbaren Mitteilungen ist nötig. Es gibt keinen SMS-Ersatz."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OhanaFont.footnote())
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(t("守护日", "Guard days", "Schutztage"))
                    .font(OhanaFont.subheadline(.semibold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(1 ... 7, id: \.self) { weekday in
                        Button {
                            if selectedWeekdays.contains(weekday) {
                                selectedWeekdays.remove(weekday)
                            } else {
                                selectedWeekdays.insert(weekday)
                            }
                        } label: {
                            Text(weekdayLabel(weekday))
                                .font(OhanaFont.caption2(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedWeekdays.contains(weekday) ? Color.goPrimary : Color.ohanaSecondaryText)
                        .accessibilityValue(selectedWeekdays.contains(weekday) ? t("已选择", "Selected", "Ausgewählt") : t("未选择", "Not selected", "Nicht ausgewählt"))
                    }
                }
            }

            DatePicker(
                t("截止时间", "Deadline", "Frist"),
                selection: $deadline,
                displayedComponents: .hourAndMinute
            )
            Stepper(
                t("宽限期：\(gracePeriodMinutes) 分钟", "Grace period: \(gracePeriodMinutes) minutes", "Karenzzeit: \(gracePeriodMinutes) Minuten"),
                value: $gracePeriodMinutes,
                in: PresenceReminderCapabilities.gracePeriodMinutes,
                step: 15
            )
            Toggle(t("计划暂停", "Schedule a pause", "Pause planen"), isOn: $isPaused)
                .tint(Color.goPrimary)
            if isPaused {
                DatePicker(
                    t("暂停至", "Paused until", "Pausiert bis"),
                    selection: $pauseUntil,
                    in: Date() ... maximumPauseDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            Button(t("保存守护计划", "Save guardian schedule", "Schutzplan speichern")) {
                savePolicy()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedWeekdays.isEmpty || !ownerIsAvailable || (policyEnabled && reachableGuardianCount == 0))
        } header: {
            Text(t("我的守护计划", "My guardian schedule", "Mein Schutzplan"))
        } footer: {
            Text(t(
                "默认 20:00 截止、60 分钟宽限。第 1 个漏签守护日仅记录；第 2 日提交首次推送；第 3 日最多跟进一次。APNs 为尽力而为，只能表述服务器尚未收到打卡。",
                "Default: 20:00 deadline and 60-minute grace. The first missed guard day is recorded; day two submits the first alert; day three submits at most one follow-up. APNs is best effort and only means the server has not received a check-in.",
                "Standard: 20:00 Uhr und 60 Minuten Karenz. Der erste fehlende Schutztag wird erfasst, am zweiten wird der erste Hinweis eingereicht, am dritten höchstens eine Nachfrage. APNs arbeitet nach bestem Bemühen; der Server hat nur noch keinen Check-in erhalten."
            ))
        }
    }

    private var ownerGuardiansSection: some View {
        Section {
            if ownerRelationships.isEmpty {
                ContentUnavailableView(
                    t("还没有守护人", "No guardians yet", "Noch keine Vertrauenspersonen"),
                    systemImage: "person.2.badge.plus",
                    description: Text(t("创建一次性邀请，对方在 48 小时内接受。", "Create a one-time invitation for someone to accept within 48 hours.", "Erstelle eine einmalige Einladung, die innerhalb von 48 Stunden angenommen wird."))
                )
            } else {
                ForEach(ownerRelationships) { relationship in
                    relationshipRow(relationship, allowsRevoke: true)
                }
            }
        } header: {
            HStack {
                Text(t("我的守护人", "My guardians", "Meine Vertrauenspersonen"))
                Spacer()
                Text("\(acceptedGuardians.count)/3")
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private var invitationSection: some View {
        Section {
            Button {
                Task { await guardian.createInvitation() }
            } label: {
                Label(t("创建一次性邀请", "Create one-time invitation", "Einmalige Einladung erstellen"), systemImage: "qrcode")
            }
            .disabled(!canInvite)

            if let invitation = guardian.latestInvitation {
                VStack(spacing: 14) {
                    if let image = GuardianQRCodeRenderer.image(for: invitation.url.absoluteString) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 164, height: 164)
                            .accessibilityLabel(t("邀请二维码", "Invitation QR code", "Einladungs-QR-Code"))
                    }
                    Text(invitation.code)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .textSelection(.enabled)
                    Text(invitation.url.absoluteString)
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    ShareLink(item: invitation.url) {
                        Label(t("分享邀请", "Share invitation", "Einladung teilen"), systemImage: "square.and.arrow.up")
                    }
                    Text(t("有效至 \(invitation.expiresAt.formatted(date: .abbreviated, time: .shortened))", "Valid until \(invitation.expiresAt.formatted(date: .abbreviated, time: .shortened))", "Gültig bis \(invitation.expiresAt.formatted(date: .abbreviated, time: .shortened))"))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } header: {
            Text(t("邀请", "Invitation", "Einladung"))
        } footer: {
            Text(t(
                "链接、二维码和邀请码均为同一个一次性邀请，48 小时后失效。未安装者先前往 App Store，之后仍须登录并确认接受。",
                "The link, QR code, and code are the same one-time invitation and expire after 48 hours. Someone without the app goes to the App Store first, then must still sign in and accept.",
                "Link, QR-Code und Code gehören zur selben einmaligen Einladung und verfallen nach 48 Stunden. Ohne App geht es zuerst zum App Store; danach sind Anmeldung und Annahme weiter erforderlich."
            ))
        }
    }

    @ViewBuilder
    private var incidentSection: some View {
        if !guardian.dashboard.incidents.isEmpty {
            Section {
                ForEach(guardian.dashboard.incidents) { incident in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(incidentTitle(incident), systemImage: incidentSymbol(incident.status))
                                .font(OhanaFont.body(.semibold))
                            Spacer()
                            Text(incident.lastGuardDayKey)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Text(incidentDetail(incident))
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if incidentCanBeAcknowledged(incident) {
                            Button(t("已联系到本人", "I reached them", "Kontakt hergestellt")) {
                                Task { await guardian.acknowledgeIncident(id: incident.id) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                    .id(incident.id)
                }
            } header: {
                Text(t("守护事件", "Guardian incidents", "Schutzereignisse"))
            } footer: {
                Text(t(
                    "“已联系到本人”只关闭当前守护事件，不会生成打卡、恢复连续或发放奖励。已提交给 APNs 不等于对方已收到。",
                    "“I reached them” only closes the guardian incident. It does not create a check-in, restore a streak, or award coconuts. Submitted to APNs does not mean delivered.",
                    "„Kontakt hergestellt“ schließt nur das Ereignis. Es erzeugt keinen Check-in, stellt keine Serie wieder her und vergibt keine Kokosnüsse. An APNs übermittelt bedeutet nicht zugestellt."
                ))
            }
        }
    }

    private var privacySection: some View {
        Section {
            Label(
                t("只同步最少守护信号", "Only minimal guardian signals sync", "Nur minimale Schutzsignale werden synchronisiert"),
                systemImage: "lock.shield.fill"
            )
            Text(t(
                "服务端仅保存匿名账号 ID、守护关系、时区和计划版本、守护日结果、事件状态、设备端点与通知尝试。不上传姓名、打卡分数、宠物、植物、健康、体重或花费。",
                "The server stores only an anonymous account ID, guardian relationships, time zone and schedule revision, guard-day results, incident state, device endpoints, and notification attempts. Names, scores, pets, plants, health, weight, and expenses are never uploaded.",
                "Der Server speichert nur anonyme Konto-ID, Schutzbeziehungen, Zeitzone und Planversion, Schutztagergebnisse, Ereignisstatus, Geräteendpunkte und Mitteilungsversuche. Namen, Werte, Tiere, Pflanzen, Gesundheit, Gewicht und Ausgaben werden nie hochgeladen."
            ))
            .font(OhanaFont.footnote())
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(t("隐私边界", "Privacy boundary", "Datenschutzgrenze"))
        }
    }

    private var accountSection: some View {
        Section {
            if case .signedIn = guardian.accountState {
                Button(t("退出在线守护账号", "Sign out of guardian account", "Vom Schutzkonto abmelden")) {
                    Task { await guardian.signOut() }
                }
                Button(t("删除在线守护账号", "Delete online guardian account", "Online-Schutzkonto löschen"), role: .destructive) {
                    isShowingDeleteAccountConfirmation = true
                }
            }
        } header: {
            Text(t("账号", "Account", "Konto"))
        }
    }

    private func relationshipRow(
        _ relationship: GuardianRemoteRelationshipDTO,
        allowsRevoke: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: reachabilitySymbol(relationship.reachability))
                .foregroundStyle(reachabilityColor(relationship.reachability))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(relationship.displayLabel)
                    .font(OhanaFont.body(.semibold))
                Text(relationshipStatusText(relationship))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                if relationship.currentUserIsGuardian,
                   relationship.protectedPolicyStatus == .paused,
                   let pauseUntil = relationship.protectedPauseUntil {
                    Text(l.tr(
                        zh: "守护暂停至 \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        en: "Guardian monitoring paused until \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        de: "Schutz pausiert bis \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        es: "Protección en pausa hasta \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        pt: "Proteção pausada até \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        fr: "Garde en pause jusqu’au \(pauseUntil.formatted(date: .abbreviated, time: .shortened))",
                        ja: "見守りは \(pauseUntil.formatted(date: .abbreviated, time: .shortened)) まで一時停止中",
                        ko: "보호가 \(pauseUntil.formatted(date: .abbreviated, time: .shortened))까지 일시 중지됨",
                        it: "Protezione in pausa fino al \(pauseUntil.formatted(date: .abbreviated, time: .shortened))"
                    ))
                    .font(OhanaFont.caption())
                    .foregroundStyle(.orange)
                } else if relationship.currentUserIsGuardian,
                          relationship.protectedPolicyStatus == .stopped ||
                          relationship.protectedPolicyStatus == .inactive {
                    Text(l.tr(
                        zh: "对方的守护已停止",
                        en: "Their guardian monitoring has stopped",
                        de: "Der Schutz der anderen Person wurde beendet",
                        es: "La protección de la otra persona se ha detenido",
                        pt: "A proteção da outra pessoa foi encerrada",
                        fr: "La garde de cette personne est arrêtée",
                        ja: "相手の見守りは停止しています",
                        ko: "상대방의 보호가 중지되었습니다",
                        it: "La protezione dell’altra persona è terminata"
                    ))
                    .font(OhanaFont.caption())
                    .foregroundStyle(.orange)
                }
            }
            Spacer()
            if allowsRevoke {
                Menu {
                    Button(t("撤销关系", "Revoke relationship", "Beziehung widerrufen"), role: .destructive) {
                        Task { await guardian.revokeRelationship(id: relationship.id) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityHidden(true)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(t("关系操作", "Relationship actions", "Beziehungsaktionen"))
            }
        }
    }

    private func refreshService() async {
        await appServices.commerce.refreshEntitlements()
        if appServices.commerce.hasFamilyEntitlement {
            await guardian.syncFamilyEntitlement()
        }
        await guardian.refresh()
        await guardian.flushOutbox()
    }

    private func resolvePendingRouteIfPossible() async {
        guard case .signedIn = guardian.accountState else { return }
        if !pendingInviteCode.isEmpty {
            let code = pendingInviteCode
            pendingInviteCode = ""
            await guardian.acceptInvitation(code: code)
        }
        if let focusedIncidentID {
            self.focusedIncidentID = nil
            await guardian.markIncidentOpened(id: focusedIncidentID)
        }
    }

    private func savePolicy() {
        guard let ownerID, ownerIsAvailable else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: deadline)
        let requestedPause = isPaused
            ? GuardianSafetyEvaluationPolicy.clampedPauseUntil(requested: pauseUntil, now: Date())
            : nil
        let request = GuardianPolicyUpdateRequest(
            isEnabled: policyEnabled,
            weekdays: selectedWeekdays.sorted(),
            deadlineHour: components.hour ?? 20,
            deadlineMinute: components.minute ?? 0,
            gracePeriodMinutes: gracePeriodMinutes,
            pauseUntil: requestedPause,
            timeZoneIdentifier: TimeZone.current.identifier,
            scheduleRevision: (guardian.dashboard.policy?.scheduleRevision ?? 0) + 1
        )
        Task { await guardian.updatePolicy(request, ownerHumanID: ownerID) }
    }

    private func purchaseFamily() {
        Task {
            switch await appServices.commerce.purchaseFamilyYearly() {
            case .purchased:
                await guardian.syncFamilyEntitlement()
                await guardian.refresh()
            case .pending:
                notice = GuardianDashboardNotice(
                    title: "Ohana Family",
                    message: t("购买正在等待批准。", "The purchase is waiting for approval.", "Der Kauf wartet auf Genehmigung.")
                )
            case .cancelled:
                break
            case .failed:
                notice = GuardianDashboardNotice(
                    title: "Ohana Family",
                    message: appServices.commerce.lastErrorMessage ?? t("暂时无法完成购买。", "The purchase could not be completed.", "Der Kauf konnte nicht abgeschlossen werden.")
                )
            }
        }
    }

    private func restorePurchases() {
        Task {
            let outcome = await appServices.commerce.restorePurchases()
            if outcome == .restored, appServices.commerce.hasFamilyEntitlement {
                await guardian.syncFamilyEntitlement()
                await guardian.refresh()
            } else if outcome != .restored {
                notice = GuardianDashboardNotice(
                    title: "Ohana Family",
                    message: appServices.commerce.lastErrorMessage ?? t("没有可恢复的 Family 订阅。", "No Family subscription was available to restore.", "Kein Family-Abo konnte wiederhergestellt werden.")
                )
            }
        }
    }

    private func applyRemotePolicyIfNeeded(force: Bool) {
        guard force || !didApplyRemotePolicy, let policy = guardian.dashboard.policy else { return }
        didApplyRemotePolicy = true
        policyEnabled = policy.isEnabled
        selectedWeekdays = Set(policy.weekdays)
        gracePeriodMinutes = min(max(policy.gracePeriodMinutes, 15), 180)
        var components = DateComponents()
        components.hour = policy.deadlineHour
        components.minute = policy.deadlineMinute
        deadline = Calendar.current.nextDate(
            after: Date().addingTimeInterval(-86400),
            matching: components,
            matchingPolicy: .nextTime
        ) ?? Date()
        isPaused = policy.pauseUntil.map { $0 > Date() } == true
        pauseUntil = policy.pauseUntil ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private var maximumPauseDate: Date {
        Calendar.current.date(byAdding: .day, value: GuardianSafetyEvaluationPolicy.maximumPauseDays, to: Date())
            ?? Date().addingTimeInterval(30 * 86400)
    }

    private var accountStatusText: String {
        switch guardian.accountState {
        case .unavailable: t("不可用", "Unavailable", "Nicht verfügbar")
        case .signedOut: t("未登录", "Signed out", "Abgemeldet")
        case .signingIn: t("登录中", "Signing in", "Anmeldung")
        case .signedIn: t("已使用 Apple 登录", "Signed in with Apple", "Mit Apple angemeldet")
        case .failed: t("需要处理", "Needs attention", "Aktion nötig")
        }
    }

    private var dashboardStatusText: String {
        switch guardian.dashboardState {
        case .unavailable: t("未开放", "Not enabled", "Nicht aktiviert")
        case .signedOut: t("等待登录", "Waiting for sign-in", "Wartet auf Anmeldung")
        case .loading: t("同步中", "Syncing", "Synchronisiert")
        case .loaded: t("已同步", "Synced", "Synchronisiert")
        case .failed: t("同步失败", "Sync failed", "Synchronisierung fehlgeschlagen")
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "?" }
        return symbols[weekday - 1]
    }

    private func relationshipStatusText(_ relationship: GuardianRemoteRelationshipDTO) -> String {
        let status = switch relationship.status {
        case .invited: t("等待接受", "Awaiting acceptance", "Wartet auf Annahme")
        case .accepted: t("已接受", "Accepted", "Angenommen")
        case .revoked:
            relationship.currentUserIsGuardian
                ? t("守护已停止", "Guardian monitoring stopped", "Schutz beendet")
                : t("已撤销", "Revoked", "Widerrufen")
        }
        let reachability = switch relationship.reachability {
        case .unknown: t("通知状态未知", "Notification status unknown", "Mitteilungsstatus unbekannt")
        case .active: t("通知可用", "Notifications available", "Mitteilungen verfügbar")
        case .notificationsDisabled: t("通知已关闭", "Notifications off", "Mitteilungen aus")
        case .unreachable: t("设备不可达", "Device unreachable", "Gerät nicht erreichbar")
        case .revoked: t("关系已撤销", "Relationship revoked", "Beziehung widerrufen")
        }
        let notificationState: String? = switch relationship.latestNotificationState {
        case .submitted: t("推送已提交", "Push submitted", "Push übermittelt")
        case .opened: t("已打开", "Opened", "Geöffnet")
        case .acknowledged: t("已确认", "Acknowledged", "Bestätigt")
        case .unreachable: t("提交失败", "Submission unavailable", "Übermittlung nicht möglich")
        case nil: nil
        }
        return [status, reachability, notificationState].compactMap(\.self).joined(separator: " · ")
    }

    private func reachabilitySymbol(_ reachability: GuardianNotificationReachability) -> String {
        switch reachability {
        case .active: "bell.badge.fill"
        case .unknown: "questionmark.circle"
        case .notificationsDisabled: "bell.slash.fill"
        case .unreachable: "wifi.slash"
        case .revoked: "person.crop.circle.badge.xmark"
        }
    }

    private func reachabilityColor(_ reachability: GuardianNotificationReachability) -> Color {
        switch reachability {
        case .active: .green
        case .unknown: .secondary
        case .notificationsDisabled, .unreachable: .orange
        case .revoked: .red
        }
    }

    private func incidentTitle(_ incident: GuardianRemoteIncidentDTO) -> String {
        switch incident.status {
        case .monitoring: t("守护观察中", "Monitoring", "Überwachung")
        case .initialSubmitted: t("首次推送已提交", "Initial alert submitted", "Erster Hinweis eingereicht")
        case .followUpSubmitted: t("跟进推送已提交", "Follow-up submitted", "Nachfrage eingereicht")
        case .acknowledged: t("已确认联系", "Contact acknowledged", "Kontakt bestätigt")
        case .recovered: t("已恢复打卡", "Check-in resumed", "Check-in fortgesetzt")
        case .closed: t("事件已关闭", "Incident closed", "Ereignis geschlossen")
        }
    }

    private func incidentDetail(_ incident: GuardianRemoteIncidentDTO) -> String {
        let misses = t(
            "连续 \(incident.consecutiveMisses) 个守护日尚未收到打卡",
            "No check-in received for \(incident.consecutiveMisses) consecutive guard days",
            "Seit \(incident.consecutiveMisses) Schutztagen kein Check-in empfangen"
        )
        switch incident.status {
        case .initialSubmitted, .followUpSubmitted:
            return "\(misses)。\(t("推送已提交，不代表设备已展示或对方已读。", "The alert was submitted; this does not mean it was displayed or read.", "Der Hinweis wurde eingereicht; das bedeutet nicht angezeigt oder gelesen."))"
        case .acknowledged:
            return t("守护人已表示联系到本人；这不是签到。", "A guardian reported making contact; this is not a check-in.", "Eine Vertrauensperson meldete Kontakt; dies ist kein Check-in.")
        case .recovered:
            return t("服务器后来收到新的本人签到，事件已关闭。", "The server later received a new owner check-in and closed the incident.", "Der Server erhielt später einen neuen Check-in und schloss das Ereignis.")
        case .monitoring, .closed:
            return misses
        }
    }

    private func incidentSymbol(_ status: GuardianIncidentStatus) -> String {
        switch status {
        case .monitoring: "clock.badge.questionmark"
        case .initialSubmitted, .followUpSubmitted: "bell.badge.fill"
        case .acknowledged: "person.crop.circle.badge.checkmark"
        case .recovered: "checkmark.circle.fill"
        case .closed: "archivebox.fill"
        }
    }

    private func incidentCanBeAcknowledged(_ incident: GuardianRemoteIncidentDTO) -> Bool {
        guardianRelationships.contains { $0.status == .accepted } &&
            (incident.status == .initialSubmitted || incident.status == .followUpSubmitted)
    }

    private func t(_ zh: String, _ en: String, _ de: String) -> String {
        l.tr(zh: zh, en: en, de: de)
    }
}

private nonisolated struct GuardianDashboardNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private nonisolated enum GuardianQRCodeRenderer {
    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(
                  output,
                  from: output.extent
              )
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
