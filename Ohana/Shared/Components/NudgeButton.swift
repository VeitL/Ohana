//
//  NudgeButton.swift
//  Ohana
//
//  Lightweight reminder nudge button used by member reminder rows.
//

import SwiftUI
import UIKit

struct NudgeButton: View {
    let targetHuman: Human

    @State private var showAlert = false
    @State private var nudged = false

    private var l: L10n { L10n() }

    var body: some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            nudged = true
            showAlert = true
        } label: {
            Label(
                nudged
                    ? l.tr(zh: "已催", en: "Nudged", de: "Erinnert")
                    : l.tr(zh: "催办", en: "Nudge", de: "Erinnern"),
                systemImage: nudged ? "checkmark.circle.fill" : "hand.wave.fill"
            )
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(nudged ? Color.goPrimary : Color.ohanaSecondaryText)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                nudged ? Color.goPrimary.opacity(0.12) : Color.ohanaCardSurfaceElevated.opacity(0.55),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    nudged ? Color.goPrimary.opacity(0.35) : Color.ohanaPrimaryText.opacity(0.12),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(
            nudged
                ? l.tr(zh: "已提醒 \(targetHuman.name)", en: "\(targetHuman.name) has been nudged", de: "\(targetHuman.name) wurde erinnert")
                : l.tr(zh: "提醒 \(targetHuman.name)", en: "Nudge \(targetHuman.name)", de: "\(targetHuman.name) erinnern")
        )
        .alert(
            l.tr(zh: "已提醒 \(targetHuman.name)", en: "\(targetHuman.name) has been nudged", de: "\(targetHuman.name) wurde erinnert"),
            isPresented: $showAlert
        ) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "已通知 \(targetHuman.name) 快去完成任务",
                en: "\(targetHuman.name) has been notified to finish the task",
                de: "\(targetHuman.name) wurde an die Aufgabe erinnert"
            ))
        }
    }
}
