//
//  CheckInRewardFeedback.swift
//  Ohana
//
//  Shared one-shot feedback for check-ins and coconut rewards.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

nonisolated enum PetCareCompletionKind: Equatable, Sendable {
    case feed
    case water
    case play
    case potty
    case hygiene
    case medication
    case walk
    case care

    func title(l: L10n) -> String {
        switch self {
        case .feed: l.tr(zh: "用餐完成", en: "Meal complete", de: "Mahlzeit erledigt")
        case .water: l.tr(zh: "补水完成", en: "Water complete", de: "Wasser erledigt")
        case .play: l.tr(zh: "陪玩完成", en: "Play complete", de: "Spielzeit erledigt")
        case .potty: l.tr(zh: "如厕照护完成", en: "Potty care complete", de: "Toilettenpflege erledigt")
        case .hygiene: l.tr(zh: "清洁完成", en: "Fresh and clean", de: "Pflege erledigt")
        case .medication: l.tr(zh: "用药完成", en: "Medication complete", de: "Medikament gegeben")
        case .walk: l.tr(zh: "散步完成", en: "Walk complete", de: "Spaziergang erledigt")
        case .care: l.tr(zh: "照护完成", en: "Care complete", de: "Pflege erledigt")
        }
    }
}

nonisolated struct PetCareCompletionTrigger: Equatable, Sendable {
    let petID: UUID
    let kind: PetCareCompletionKind

    static func resolve(_ mutation: DomainMutationResult) -> PetCareCompletionTrigger? {
        guard mutation.wroteBusinessFact else { return nil }
        let command = mutation.command
        let resolvedKind: PetCareCompletionKind?

        switch (command.feature, command.action) {
        case ("feeding", "log"):
            let source = command.parameters["source"]?.lowercased() ?? ""
            resolvedKind = ["update", "delete"].contains(source) ? nil : .feed
        case ("water", "log"):
            let source = command.parameters["source"]?.lowercased() ?? ""
            if source == "delete" {
                resolvedKind = nil
            } else if source.contains("water_change") || source.contains("filter_clean") {
                resolvedKind = .hygiene
            } else {
                resolvedKind = .water
            }
        case ("petCare", "record"):
            resolvedKind = kind(forCareAction: command.parameters["type"] ?? "")
        case ("catCare", "record"):
            resolvedKind = kind(forCareAction: command.parameters["action"] ?? "")
        case ("hygiene", "record"):
            resolvedKind = .hygiene
        case ("petMedication", "dose"):
            resolvedKind = .medication
        case ("walks", "complete"):
            resolvedKind = .walk
        case ("quickCare", _):
            resolvedKind = kindForQuickCare(command.action)
        default:
            resolvedKind = nil
        }

        guard let resolvedKind,
              let petID = petID(from: command) else { return nil }
        return PetCareCompletionTrigger(petID: petID, kind: resolvedKind)
    }

    private static func petID(from command: DomainCommand) -> UUID? {
        ["petID", "entityID"]
            .compactMap { command.parameters[$0] }
            .compactMap(UUID.init(uuidString:))
            .first
    }

    private static func kindForQuickCare(_ action: String) -> PetCareCompletionKind? {
        let value = action.lowercased()
        guard !value.contains("claim"),
              !value.hasPrefix("health"),
              !value.contains("expense") else { return nil }
        return kind(forCareAction: value) ?? .care
    }

    private static func kind(forCareAction rawValue: String) -> PetCareCompletionKind? {
        let value = rawValue.lowercased()
        if value.contains("feeding") || value.contains("feed") || value.contains("plannedfeed") || value.contains("喂食") {
            return .feed
        }
        if value.contains("play") || value.contains("freeflight") || value.contains("逗玩") || value.contains("放飞") {
            return .play
        }
        if value.contains("potty") || value.contains("litter") || value.contains("铲屎") || value.contains("便") || value.contains("尿") {
            return .potty
        }
        if value.contains("hygiene") || value.contains("groom") || value.contains("clean") || value.contains("change") || value.contains("misting") || value.contains("substrate") || value.contains("清理") || value.contains("换水") || value.contains("保湿") || value.contains("垫材") {
            return .hygiene
        }
        if value.contains("watering") || value.contains("water") || value.contains("喂水") {
            return .water
        }
        if value.contains("medication") || value.contains("medicine") || value.contains("用药") {
            return .medication
        }
        if value.contains("walk") || value.contains("散步") || value.contains("遛") {
            return .walk
        }
        return value.isEmpty ? nil : .care
    }
}

struct PetCareCompletionReactionSnapshot: Identifiable, Equatable {
    let id = UUID()
    let petID: UUID
    let petName: String
    let primaryTagID: String?
    let kind: PetCareCompletionKind
    let occurredAt: Date
}

@MainActor
private final class PetCareCompletionReactionCenter: ObservableObject {
    @Published private(set) var activeReaction: PetCareCompletionReactionSnapshot?

    private var hideTask: Task<Void, Never>?
    private var lastFingerprint: String?
    private var lastOccurredAt = Date.distantPast

    func enqueue(_ reaction: PetCareCompletionReactionSnapshot) {
        let fingerprint = "\(reaction.petID.uuidString):\(reaction.kind)"
        if fingerprint == lastFingerprint,
           reaction.occurredAt.timeIntervalSince(lastOccurredAt) < 0.45 {
            return
        }
        lastFingerprint = fingerprint
        lastOccurredAt = reaction.occurredAt
        activeReaction = reaction

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                self.activeReaction = nil
            }
        }
    }

    func cancel() {
        hideTask?.cancel()
        hideTask = nil
    }
}

private struct PetCareCompletionReactionOverlay: View {
    @StateObject private var center = PetCareCompletionReactionCenter()
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(AppServices.self) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var l: L10n { L10n(appLanguage) }
    private var shouldAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var body: some View {
        let animate = shouldAnimate
        VStack {
            if let reaction = center.activeReaction {
                reactionPill(reaction)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    ))
                    .padding(.top, 68)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .onReceive(appServices.domainRevisions.domainMutationEvents) { mutation in
            guard let trigger = PetCareCompletionTrigger.resolve(mutation),
                  let reaction = PetCareCompletionReactionDataContainer.snapshot(
                      for: trigger,
                      occurredAt: mutation.occurredAt,
                      context: modelContext
                  ) else { return }
            center.enqueue(reaction)
        }
        .onDisappear { center.cancel() }
        .animation(animate ? GoMotion.feedback : GoMotion.reduced, value: center.activeReaction?.id)
    }

    private func reactionPill(_ reaction: PetCareCompletionReactionSnapshot) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: PetPersonalityTag.lookup(reaction.primaryTagID ?? "")?.sfSymbol ?? "heart.fill")
                .font(OhanaFont.adaptive(size: 15, weight: .bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 32, height: 32) // a11y: allow non-interactive decorative glyph
                .background(Color.goPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(reaction.petName) · \(reaction.kind.title(l: l))")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(PetPersonalityCareReaction.line(
                    petName: reaction.petName,
                    primaryTagID: reaction.primaryTagID,
                    l: l
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 390, alignment: .leading)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.24), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
final class CoconutRewardFeedbackCenter: ObservableObject {
    @Published private(set) var activeEvent: OhanaCoconutRewardEvent?
    @Published private(set) var coalescedAmount = 0

    private var hideTask: Task<Void, Never>?

    func enqueue(_ event: OhanaCoconutRewardEvent) {
        // 气泡只报椰子数,不报养分数字;但保留消息(如每日预算耗尽的"今日椰子已满"安慰语)。
        guard event.amount > 0 || event.growthXP > 0 else { return }
        // 仅当同一成员的奖励气泡仍在屏时才累加;跨成员奖励另起气泡,
        // 否则标题显示后来者、数额却是两人之和,与账本对不上。
        let shouldMerge = activeEvent != nil && activeEvent?.actorId == event.actorId
        activeEvent = event
        coalescedAmount = shouldMerge ? coalescedAmount + event.amount : event.amount

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                self.activeEvent = nil
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            self.coalescedAmount = 0
        }
    }
}

struct CoconutRewardFeedbackOverlay: View {
    var playsHaptics = true

    @StateObject private var center = CoconutRewardFeedbackCenter()
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastHandledEventID: UUID?
    @State private var hapticTask: Task<Void, Never>?

    private var shouldAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var body: some View {
        let animate = shouldAnimate
        VStack {
            if let event = center.activeEvent {
                rewardPill(event)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.86).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
                    .padding(.top, 14)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .onReceive(appServices.domainRevisions.coconutRewardEvents) { event in
            guard lastHandledEventID != event.id else { return }
            lastHandledEventID = event.id
            center.enqueue(event)
            if animate, playsHaptics {
                hapticTask?.cancel()
                hapticTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    hapticTask = nil
                }
            }
        }
        .onDisappear {
            hapticTask?.cancel()
            hapticTask = nil
        }
        .animation(animate ? GoMotion.feedback : GoMotion.reduced, value: center.activeEvent?.id)
    }

    private func rewardPill(_ event: OhanaCoconutRewardEvent) -> some View {
        HStack(spacing: 8) {
            Text(event.emoji)
                .font(OhanaFont.adaptive(size: 20))
            if !rewardAmountText.isEmpty {
                Text(rewardAmountText)
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
            }
            Text(event.title)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.goYellow.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    private var rewardAmountText: String {
        // 气泡只报椰子。树的养分静默累积、在椰子树页展示,不在此和椰子并排造成对账混淆。
        center.coalescedAmount > 0 ? "+\(center.coalescedAmount)🥥" : ""
    }
}

struct GlobalCoconutRewardFeedbackLayer: View {
    var playsHaptics = true

    var body: some View {
        if !Self.shouldHideGlobalRewardFeedbackOverlay {
            ZStack {
                PetCareCompletionReactionOverlay()
                    .zIndex(119)
                CoconutRewardFeedbackOverlay(playsHaptics: playsHaptics)
                    .zIndex(120)
            }
        }
    }

    private static var shouldHideGlobalRewardFeedbackOverlay: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-OHANA_ENABLE_PRODUCTION_OVERLAYS_IN_UI_TESTS") {
            return false
        }
        return isRunningTests
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || arguments.contains("-OHANA_UI_TESTS")
    }
}

private struct GlobalCoconutRewardFeedbackOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            GlobalCoconutRewardFeedbackLayer(playsHaptics: false)
        }
    }
}

extension View {
    func globalCoconutRewardFeedbackOverlay() -> some View {
        modifier(GlobalCoconutRewardFeedbackOverlayModifier())
    }
}

struct CheckInFeedbackToken: Identifiable {
    enum Kind {
        case gain
        case loss
        case done
    }

    let id = UUID()
    let kind: Kind
    let deltaText: String
    let tint: Color
    let createdAt = Date()
}

struct CheckInFeedbackBadge: View {
    let token: CheckInFeedbackToken

    var body: some View {
        Text(token.deltaText)
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                token.tint,
                in: Capsule()
            )
            .contentTransition(.numericText())
            .transition(.scale(scale: 0.84).combined(with: .opacity))
    }
}

struct CheckInPulseModifier: ViewModifier {
    let token: CheckInFeedbackToken?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(token == nil || reduceMotion ? 1 : 1.025)
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.feedback, value: token?.id)
    }
}

extension View {
    func checkInPulse(_ token: CheckInFeedbackToken?) -> some View {
        modifier(CheckInPulseModifier(token: token))
    }
}
