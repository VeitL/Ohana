//
//  FamilyCollaborationDashboardView+Map.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    var mapHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "宠物地图", en: "Pet map", de: "Tierkarte"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                mapScopeButton(.mine, title: l.tr(zh: "待我", en: "Mine", de: "Meine"), count: assignedFamilyTasks.count, icon: "person.crop.circle.badge.clock", tint: Color.goPurple)
                mapScopeButton(.bounty, title: l.tr(zh: "悬赏", en: "Bounty", de: "Prämie"), count: bountyFamilyTasks.count, icon: "target", tint: Color.goTeal)
                progressScopePill
            }
        }
    }

    func mapScopeButton(_ scope: TaskScope, title: String, count: Int, icon: String, tint: Color) -> some View {
        let selected = selectedTaskScope == scope
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.feedback) { selectedTaskScope = scope }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .lineLimit(1)
                Text("\(count)")
                    .font(OhanaFont.caption2(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? tint : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var progressScopePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(l.tr(zh: "完成", en: "Done", de: "Fertig"))
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
            Text("\(Int(boardProgress * 100))%")
                .font(OhanaFont.caption2(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.goPrimary, in: Capsule())
        .animation(GoMotion.feedback, value: boardProgress)
    }

    var petMapSurface: some View {
        ZStack {
            ForEach(Array(activeMapPets.enumerated()), id: \.element.id) { index, pet in
                let offset = petMapOffset(index: index, count: activeMapPets.count)
                petMapNode(pet)
                    .offset(x: offset.x, y: offset.y)
            }

            floatingMemberRail
        }
        .frame(height: 274)
    }

    var floatingMemberRail: some View {
        HStack(spacing: 10) {
            ForEach(Array(humans.prefix(4).enumerated()), id: \.element.id) { index, human in
                floatingMemberNode(human, index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface.opacity(0.82), in: Capsule())
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14), radius: 18, x: 0, y: 12) // ui-v4: allow floating member rail depth
        .shadow(color: Color.goPrimary.opacity(0.10), radius: 20, x: 0, y: 0) // ui-v4: allow subtle family map glow
        .offset(y: memberRailFloating ? -3 : 2)
        .animation(
            shouldRunAmbientMotion
                ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // smoothness: allow visible-only family rail ambient float gated by AppWorkloadPolicy.
                : nil,
            value: memberRailFloating
        )
        .onAppear {
            isVisible = true
            updateAmbientMotion()
        }
        .onDisappear {
            isVisible = false
            memberRailFloating = false
        }
        .onChange(of: shouldRunAmbientMotion) { _, _ in
            updateAmbientMotion()
        }
    }

    func updateAmbientMotion() {
        memberRailFloating = shouldRunAmbientMotion
    }

    func floatingMemberNode(_ human: Human, index: Int) -> some View {
        VStack(spacing: 3) {
            Text(human.avatarEmoji)
                .font(OhanaFont.adaptive(size: 19)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.ohanaControlFill, in: Circle())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 8, x: 0, y: 5) // ui-v4: allow small floating avatar shadow
            Text(human.name)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(human.id.uuidString == activeHumanId ? Color.goPrimary : Color.ohanaSecondaryText)
                .lineLimit(1)
                .frame(width: 44)
        }
        .offset(y: index.isMultiple(of: 2) ? -1 : 1)
        .animation(GoMotion.feedback, value: activeHumanId)
    }

    var activeMapPets: [Pet] {
        Array(pets.filter { !$0.hasPassedAway }.prefix(6))
    }

    func petMapOffset(index: Int, count: Int) -> CGPoint {
        guard count > 1 else { return CGPoint(x: 0, y: -62) }
        let angle = (Double(index) / Double(count)) * (.pi * 2) - .pi / 2
        let radiusX: CGFloat = 112
        let radiusY: CGFloat = 86
        return CGPoint(x: cos(angle) * radiusX, y: sin(angle) * radiusY)
    }

    func petMapNode(_ pet: Pet) -> some View {
        let selected = selectedPet?.id == pet.id && selectedTaskScope == .pet
        let assigned = assignedTasks(for: pet).count
        let open = openReminders(for: pet).count
        let rewards = familyTasks(for: pet).filter(\.hasReward).count
        let count = assigned + open + rewards
        let tint: Color = assigned > 0 ? Color.goPurple : (rewards > 0 ? Color.goTeal : (open > 0 ? Color.goYellow : Color.goPrimary))

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.page) {
                selectedPetId = pet.id
                selectedTaskScope = .pet
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    petMapAvatar(pet, selected: selected, tint: tint)
                    if count > 0 {
                        Text("\(count)")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .monospacedDigit()
                            .frame(width: 23, height: 23) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(tint, in: Circle())
                            .offset(x: 3, y: -2)
                    }
                }
                Text(pet.name)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .frame(width: 82)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    func petMapAvatar(_ pet: Pet, selected: Bool, tint: Color) -> some View {
        let size: CGFloat = selected ? 72 : 66
        let bodyWidth: CGFloat = selected ? 92 : 82
        let bodyHeight: CGFloat = selected ? 96 : 88
        Group {
            if let signature = petAvatarSignatures[pet.id],
               let entry = FocusWalletAvatarCache.cachedEntry(for: pet.id, signature: signature),
               let image = entry.image {
                if entry.isTransparent {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: bodyWidth, height: bodyHeight)
                        .scaleEffect(selected ? 1.05 : 1, anchor: .bottom)
                        .shadow(color: selected ? tint.opacity(0.26) : Color.clear, radius: 14, x: 0, y: 8) // ui-v4: allow selected 2.5D pet focus glow without avatar background
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.ohanaCardSurface)
                            .frame(width: size, height: size)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size - 6, height: size - 6)
                            .clipShape(Circle())
                    }
                    .overlay(Circle().strokeBorder(selected ? tint : Color.ohanaCardStroke, lineWidth: selected ? 2.5 : 1))
                    .shadow(color: selected ? tint.opacity(0.24) : Color.clear, radius: 16, x: 0, y: 8) // ui-v4: allow selected pet map node focus glow
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.ohanaCardSurface)
                        .frame(width: size, height: size)
                    Text(pet.avatarEmoji)
                        .font(OhanaFont.adaptive(size: 32)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .frame(width: size - 6, height: size - 6)
                }
                .overlay(Circle().strokeBorder(selected ? tint : Color.ohanaCardStroke, lineWidth: selected ? 2.5 : 1))
                .shadow(color: selected ? tint.opacity(0.24) : Color.clear, radius: 16, x: 0, y: 8) // ui-v4: allow selected pet map node focus glow
            }
        }
        .animation(GoMotion.feedback, value: selected)
    }

    @MainActor
    func preparePetAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }

        var signatures: [UUID: String] = [:]
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for pet in activePets {
            guard let data = pet.avatarImageData else { continue }
            let signature = FocusWalletAvatarCache.signature(for: data)
            signatures[pet.id] = signature
            payloads.append(FocusWalletAvatarCache.Payload(id: pet.id, data: data))
        }

        let rawKey = payloads
            .map { "\($0.id.uuidString):\($0.data?.count ?? 0)" }
            .joined(separator: "|")
        let nextKey = rawKey.isEmpty ? "family-collaboration-pet-avatar-empty" : "family-collaboration-\(rawKey)"
        if petAvatarCacheKey != nextKey {
            avatarPipeline.cancel(key: petAvatarCacheKey)
            petAvatarCacheKey = nextKey
        }
        petAvatarSignatures = signatures
        guard !payloads.isEmpty else { return }
        avatarPipeline.seedPreviewEntries(payloads)
        avatarPipeline.preload(
            payloads: payloads,
            key: nextKey,
            delayMilliseconds: 56
        )
    }
}
