//
//  SharedCareUndoCoordinator.swift
//  Ohana
//
//  App-shell owner for the dismissal-safe shared-care undo window.
//

import Combine
import SwiftData
import SwiftUI

nonisolated struct SharedCareUndoBannerSnapshot: Equatable, Sendable {
    let token: SharedCareUndoToken
    let targetCount: Int
}

@MainActor
final class SharedCareUndoCoordinator: ObservableObject {
    static let shared = SharedCareUndoCoordinator()

    @Published private(set) var banner: SharedCareUndoBannerSnapshot?

    private weak var appServices: AppServices?
    private var modelContext: ModelContext?
    private var deadlineTask: Task<Void, Never>?

    private init() {}

    func configure(context: ModelContext, appServices: AppServices) {
        modelContext = context
        self.appServices = appServices
        recover()
    }

    func register(_ token: SharedCareUndoToken, targetCount: Int) {
        guard token.receiptID != nil, token.undoDeadline != nil else { return }
        banner = SharedCareUndoBannerSnapshot(token: token, targetCount: max(2, targetCount))
        scheduleNextDeadline()
    }

    func undoCurrent() {
        guard let snapshot = banner,
              let context = modelContext else { return }
        do {
            _ = try QuickPottyCommandExecutor(context: context).undoSharedCare(
                snapshot.token,
                executorId: appServices?.activeHumanSelection.currentHumanId,
                date: Date()
            )
            deadlineTask?.cancel()
            deadlineTask = nil
            banner = nil
            recover()
        } catch SharedCareSessionUndoError.undoWindowExpired {
            recover()
        } catch {
            OhanaLog.warning(
                "SharedCareUndoCoordinator could not undo shared care: \(error.localizedDescription)",
                category: "Care"
            )
        }
    }

    func recover(now: Date = Date()) {
        guard let context = modelContext else { return }
        let results = SharedCareUndoFinalizationService.settleRecoverable(
            context: context,
            now: now
        )
        for result in results where result.disposition == .externalEffectsPending {
            settleNotifications(for: result)
        }
        let pendingTokens = SharedCareUndoFinalizationService.pendingUndoTokens(
            context: context,
            now: now
        )
        guard !pendingTokens.isEmpty else {
            banner = nil
            scheduleNextDeadline(now: now)
            return
        }
        guard let token = pendingTokens.first(where: { $0.receiptID == banner?.token.receiptID })
            ?? pendingTokens.last else { return }
        banner = SharedCareUndoBannerSnapshot(
            token: token,
            targetCount: targetCount(for: token, context: context)
        )
        scheduleNextDeadline(now: now)
    }

    func pauseDeadlineTimer() {
        deadlineTask?.cancel()
        deadlineTask = nil
    }

    private func scheduleNextDeadline(now: Date = Date()) {
        deadlineTask?.cancel()
        deadlineTask = nil
        guard let context = modelContext,
              let deadline = SharedCareUndoFinalizationService.nextRecoveryDate(
                  context: context,
                  now: now
              ) else { return }
        guard deadline > now else {
            recover(now: now)
            return
        }
        guard AppWorkloadPolicy.shared.shouldRunEssentialDeadlineTimer(isVisible: true) else {
            return
        }
        let nanoseconds = UInt64(max(0, deadline.timeIntervalSince(now)) * 1_000_000_000)
        deadlineTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.recover()
        }
    }

    private func settleNotifications(for result: SharedCareUndoFinalizationResult) {
        guard let context = modelContext,
              let appServices else { return }
        Task { @MainActor in
            let runtimeEffectsSettled = appServices.oasisRewards.rewardFeaturedCritterFromCare(
                type: .potty(isLitter: true),
                context: context,
                idempotencyID: result.receiptID
            )
            let reminders = result.notificationReminderIDs.compactMap { reminderID -> Reminder? in
                var descriptor = FetchDescriptor<Reminder>(
                    predicate: #Predicate<Reminder> { $0.id == reminderID }
                )
                descriptor.fetchLimit = 1
                return try? context.fetch(descriptor).first
            }
            if !reminders.isEmpty,
               await appServices.userNotifications.requestPermission() {
                await appServices.reminderScheduling.scheduleManyIfNeeded(
                    reminders: reminders,
                    context: context,
                    source: .detail
                )
            }
            do {
                try SharedCareUndoFinalizationService.markExternalEffectsSettled(
                    receiptID: result.receiptID,
                    context: context,
                    runtimeEffectsSettled: runtimeEffectsSettled,
                    notificationsSettled: true
                )
                if !runtimeEffectsSettled {
                    scheduleNextDeadline()
                }
            } catch {
                OhanaLog.warning(
                    "SharedCareUndoCoordinator could not checkpoint notification settlement: \(error.localizedDescription)",
                    category: "Care"
                )
            }
        }
    }

    private func targetCount(for token: SharedCareUndoToken, context: ModelContext) -> Int {
        guard let receiptID = token.receiptID else { return 2 }
        var descriptor = FetchDescriptor<SharedCareUndoReceipt>(
            predicate: #Predicate<SharedCareUndoReceipt> { $0.id == receiptID }
        )
        descriptor.fetchLimit = 1
        return max(2, (try? context.fetch(descriptor).first?.targetPetIds.count) ?? 2)
    }
}

struct SharedCareUndoBannerView: View {
    let snapshot: SharedCareUndoBannerSnapshot
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                .foregroundStyle(Color.goPrimary)
            Text(
                L10n.current.tr(
                    zh: "已为 \(snapshot.targetCount) 只猫记录铲砂",
                    en: "Scoop logged for \(snapshot.targetCount) cats",
                    de: "Klo für \(snapshot.targetCount) Katzen erfasst"
                )
            )
            .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            Spacer(minLength: 4)
            Button(action: undo) {
                Text(L10n.current.tr(zh: "撤销", en: "Undo", de: "Rückgängig"))
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .accessibilityHint(
                L10n.current.tr(
                    zh: "删除这一次共享铲砂记录",
                    en: "Deletes this shared litter scoop record",
                    de: "Löscht diesen gemeinsamen Katzenklo-Eintrag"
                )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            OhanaPopupGlassSurface(cornerRadius: OhanaRadius.card)
        }
        .accessibilityElement(children: .contain)
    }
}
