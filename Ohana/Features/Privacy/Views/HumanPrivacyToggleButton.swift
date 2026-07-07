//
//  HumanPrivacyToggleButton.swift
//  Ohana
//
//  各人类记录详情页共用的「公开 / 仅本人」隐私开关按钮
//  放置在 NavigationStack toolbar leading 位置
//

import SwiftData
import SwiftUI

/// 单字段隐私开关胶囊按钮
/// - 仅当 activeHumanId == human.id 时允许切换（即本人查看时）
/// - 其他家庭成员查看时按钮半透明且不可交互
struct HumanPrivacyToggleButton: View {
    let human: Human
    let field: HumanPrivateField

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var optimisticIsPrivate: Bool?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isFieldPrivate: Bool {
        human.privateFields.contains(field.rawValue)
    }

    private var displayIsPrivate: Bool {
        optimisticIsPrivate ?? isFieldPrivate
    }

    private var isOwner: Bool {
        UUID(uuidString: activeHumanIdStr) == human.id
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        if HumanLocalPrivacyPolicy.isEnabled {
            Button {
                guard isOwner else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                togglePrivacy()
            } label: {
                ZStack {
                    Capsule()
                        .fill(trackFill)
                        .frame(width: 68, height: 34)
                        .overlay {
                            Capsule()
                                .strokeBorder(trackStroke, lineWidth: 1.25)
                        }

                    Circle()
                        .fill(knobFill)
                        .frame(width: 26, height: 26) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .overlay {
                            Circle()
                                .strokeBorder(Color.ohanaCardStroke.opacity(displayIsPrivate ? 0.25 : 0.9), lineWidth: 1)
                        }
                        .overlay {
                            Image(systemName: displayIsPrivate ? "lock.fill" : "lock.open.fill")
                                .font(OhanaFont.adaptive(size: 10, weight: .black))
                                .foregroundStyle(knobIconColor)
                        }
                        .offset(x: displayIsPrivate ? 17 : -17)
                }
                .frame(width: 74, height: 44)
                .contentShape(Rectangle())
                .animation(GoMotion.feedback, value: displayIsPrivate)
                .accessibilityLabel(displayIsPrivate ? l.tr(zh: "隐私已开启，仅本人可见", en: "Privacy on, only owner can view", de: "Privat, nur selbst sichtbar") : l.tr(zh: "隐私已关闭，家庭成员可见", en: "Privacy off, visible to family", de: "Offen, für Familie sichtbar"))
            }
            .buttonStyle(ScaleButtonStyle())
            .opacity(isOwner ? 1 : 0.5)
            .disabled(!isOwner)
            .onDisappear {
                commandQueue.cancelAll()
                optimisticIsPrivate = nil
            }
        }
    }

    private func togglePrivacy() {
        let nextValue = !displayIsPrivate
        optimisticIsPrivate = nextValue
        let action = "field.\(field.rawValue).\(nextValue ? "private" : "public")"
        let command = DomainCommand.humanPrivacy(humanID: human.id, action: action)
        commandQueue.enqueue(command) {
            do {
                try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setPrivateField(
                    field,
                    isPrivate: nextValue,
                    for: human,
                    note: "human.privacy.field"
                )
                optimisticIsPrivate = nil
            } catch {
                optimisticIsPrivate = nil
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private var trackFill: Color {
        displayIsPrivate
            ? Color.goYellow.opacity(0.16)
            : Color.ohanaControlFill
    }

    private var trackStroke: Color {
        displayIsPrivate
            ? Color.goYellow.opacity(0.55)
            : Color.ohanaCardStroke.opacity(0.95)
    }

    private var knobFill: Color {
        displayIsPrivate ? Color.goYellow : Color.ohanaCardSurfaceElevated
    }

    private var knobIconColor: Color {
        displayIsPrivate ? Color.arkInk : Color.ohanaSecondaryText
    }
}

/// Owner-facing note shown on pages where private human data is still visible to its owner.
struct HumanPrivateDataNotice: View {
    let human: Human
    let field: HumanPrivateField

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var isOwner: Bool {
        UUID(uuidString: activeHumanIdStr) == human.id
    }

    private var isFieldPrivate: Bool {
        human.privateFields.contains(field.rawValue)
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        if HumanLocalPrivacyPolicy.isEnabled, isOwner, isFieldPrivate {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 28, height: 28) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goYellow.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "只有你能看到", en: "Only you can see this", de: "Nur du kannst das sehen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "\(field.localizedTitle(l))数据已设为隐私，其他家庭成员不会看到这些内容。", en: "\(field.localizedTitle(l)) is private. Other family members will not see it.", de: "\(field.localizedTitle(l)) ist privat. Andere Familienmitglieder sehen es nicht."))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.goYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.goYellow.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

private extension HumanPrivateField {
    func localizedTitle(_ l: L10n) -> String {
        switch self {
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .workout:
            l.tr(zh: "运动", en: "Workouts", de: "Training")
        case .medication:
            l.tr(zh: "吃药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen")
        case .wishlist:
            l.tr(zh: "椰子资产与心愿", en: "Coconuts & wishes", de: "Kokosnüsse & Wünsche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }
}
