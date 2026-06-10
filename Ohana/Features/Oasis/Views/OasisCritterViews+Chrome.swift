//
//  OasisCritterViews+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension OasisCritterCodexView {
    var pageBody: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if mode == .codex, focusedCodexCatalogId == nil {
                        collectionStrip
                    } else {
                        selectedDetail
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, mode == .codex && focusedCodexCatalogId == nil ? 28 : 56)
            }
        }
    }

    var nestPopupBody: some View {
        VStack(spacing: 0) {
            popupChrome

            ScrollView(.vertical, showsIndicators: false) {
                selectedDetailContent
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
            }
        }
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 26, x: 0, y: 18) // ui-v4: allow centered modal lift
    }

    var popupChrome: some View {
        HStack(spacing: 10) {
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                close()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle(entry: nil))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(headerSubtitle(entry: nil))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
            coconutBalanceButton
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var header: some View {
        let entry = focusedCodexCatalogId.flatMap { OasisUpgradeRewardCatalog.critter(id: $0) }
        return HStack(alignment: .center, spacing: 12) {
            if mode == .codex, focusedCodexCatalogId != nil {
                Button {
                    withAnimation(GoMotion.stateChange) {
                        focusedCodexCatalogId = nil
                        lastInteractionOutcome = nil
                    }
                } label: {
                    Image(systemName: "chevron.left") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "返回图鉴", en: "Back to codex", de: "Zurück zum Album"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle(entry: entry))
                    .font(OhanaFont.adaptive(size: 25, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(headerSubtitle(entry: entry))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    func close() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    func headerTitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.name(l)
        }
        return mode == .codex
            ? l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album")
            : l.tr(zh: "电子宠物小窝", en: "Critter Nest", de: "Critter-Nest")
    }

    func headerSubtitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.tagline(l)
        }
        return mode == .codex
            ? l.tr(zh: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) 已唤醒", en: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) awake", de: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) wach")
            : l.tr(zh: "状态、照护和今日小愿望", en: "Status, care, and today's wish", de: "Status, Pflege und heutiger Wunsch")
    }
}
