// FeatureAggregateView.swift
// Aggregate view per feature.
// Aggregate view per feature. Can be used standalone or embedded under a
// FeatureGroup segmented page. Embedded mode hides the extra entity chip row so
// the page does not show pet names twice above the actual content.

import SwiftData
import SwiftUI

struct FeatureAggregateView: View {
    let feature: PetFeature
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    var petAggregateSummaries: [UUID: FunctionMenuPetAggregateSummary] = [:]
    var showsNavigationChrome: Bool = true
    var showsEntityChips: Bool = true

    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current
    @State private var humanAvatarSignatures: [UUID: String] = [:]
    @State private var humanAvatarCacheKey = "feature-aggregate-human-avatar-empty"

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome && !$0.hasPassedAway } }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var l: L10n { L10n(appLanguage) }

    private func isDog(_ pet: Pet) -> Bool {
        Pet.isDogSpecies(pet.species)
    }

    // Pets visible in chip row (walks = dogs only)
    private var chipsForFeature: [Pet] {
        feature == .walks ? activePets.filter { isDog($0) } : activePets
    }

    // Features that show human chips
    private var showHumanChips: Bool { feature == .weight || feature == .expense }

    private var humansForFeature: [Human] {
        switch feature {
        case .weight:
            appServices.privacy.unlockedHumans(for: .weight, from: visibleHumans, viewedBy: activeHumanId)
        case .expense:
            appServices.privacy.unlockedHumans(for: .expense, from: visibleHumans, viewedBy: activeHumanId)
        default:
            visibleHumans
        }
    }

    private var humanAvatarSourceKey: String {
        let key = humansForFeature
            .map { "\($0.id.uuidString):\($0.avatarThumbnailSignature)" }
            .joined(separator: "|")
        return key.isEmpty ? "feature-aggregate-human-avatar-empty" : key
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showsNavigationChrome {
                    pageHeader
                }
                if showsEntityChips {
                    chipRow
                    Rectangle().fill(Color.ohanaDivider).frame(height: 1)
                }
                featureContent
            }
        }
        .task(id: humanAvatarSourceKey) {
            await prepareHumanAvatars()
        }
        .onDisappear {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
        }
        .accessibilityIdentifier("function-menu-aggregate-\(feature.rawValue)")
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: feature.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(feature.title(l: l))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "全部" — selected state, no action
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "全部", en: "All", de: "Alle"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.goPrimary, in: Capsule())

                // Pet chips
                ForEach(chipsForFeature) { pet in
                    Button { parentPath.append(petDest(feature, pet: pet)) } label: {
                        entityChip(avatar: { FMPetAvatar(pet: pet, size: 24) }, name: pet.name)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                // Human chips (weight / expense)
                if showHumanChips {
                    ForEach(humansForFeature) { human in
                        Button { parentPath.append(humanDest(feature, human: human)) } label: {
                            entityChip(avatar: { humanAvatarView(human) }, name: human.name)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func entityChip(avatar: () -> some View, name: String) -> some View {
        HStack(spacing: 6) {
            avatar()
            Text(name)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    @ViewBuilder
    private func humanAvatarView(_ human: Human) -> some View {
        let color = Color(hex: human.themeColorHex.isEmpty ? "4ECDC4" : human.themeColorHex)
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
            if let signature = humanAvatarSignatures[human.id],
               let img = avatarPipeline.cachedImage(for: human.id, signature: signature) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 24, height: 24).clipShape(Circle()) // a11y: allow decorative non-interactive frame; hit area handled by parent
            } else {
                Text(String(human.name.prefix(1)))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(color)
            }
        }
    }

    @MainActor
    private func prepareHumanAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }

        var signatures: [UUID: String] = [:]
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for human in humansForFeature {
            guard human.hasAvatarImageAttachment,
                  let data = human.avatarImageData else { continue }
            let signature = human.avatarThumbnailSignature
            signatures[human.id] = signature
            payloads.append(FocusWalletAvatarCache.Payload(id: human.id, data: data))
        }

        let rawKey = payloads
            .map { "\($0.id.uuidString):\(signatures[$0.id] ?? "")" }
            .joined(separator: "|")
        let nextKey = rawKey.isEmpty ? "feature-aggregate-human-avatar-empty" : "feature-aggregate-\(rawKey)"
        if humanAvatarCacheKey != nextKey {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
            humanAvatarCacheKey = nextKey
        }
        humanAvatarSignatures = signatures
        guard !payloads.isEmpty else { return }
        avatarPipeline.seedPreviewEntries(payloads, key: nextKey)
        avatarPipeline.preload(
            payloads: payloads,
            key: nextKey,
            delayMilliseconds: 56
        )
    }

    // MARK: - Feature Content

    @ViewBuilder
    private var featureContent: some View {
        switch feature {
        case .health:
            IslandHealthDashboard(standalone: false) { pet in
                parentPath.append(petDest(.health, pet: pet))
            }
        case .medications:
            IslandMedicationDashboard(standalone: false) { pet in
                parentPath.append(petDest(.medications, pet: pet))
            }
        case .food:
            IslandFoodDashboard(standalone: false) { pet in
                parentPath.append(petDest(.food, pet: pet))
            }
        case .hygiene:
            IslandHygieneDashboard(standalone: false) { pet in
                parentPath.append(petDest(.hygiene, pet: pet))
            }
        case .potty:
            IslandPottyDashboard(standalone: false) { pet in
                parentPath.append(petDest(.potty, pet: pet))
            }
        case .retention:
            IslandRetentionDashboard(standalone: false) { pet in
                parentPath.append(petDest(.retention, pet: pet))
            }
        case .weight:
            IslandWeightDashboard(standalone: false)
        case .expense:
            IslandExpenseDashboard(standalone: false)
        case .walks:
            IslandExplorationDashboard(standalone: false)
        default:
            summaryList
        }
    }

    private var summaryList: some View {
        List {
            ForEach(activePets) { pet in
                Button { parentPath.append(petDest(feature, pet: pet)) } label: {
                    HStack(spacing: 14) {
                        FMPetAvatar(pet: pet)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name)
                                .font(OhanaFont.adaptive(size: 15, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(subtitle(for: pet))
                                .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(ScaleButtonStyle())
                .listRowBackground(RoundedRectangle(cornerRadius: OhanaRadius.chip).fill(Color.ohanaCardSurface))
                .listRowSeparatorTint(Color.ohanaDivider)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Routing

    private func petDest(_ feature: PetFeature, pet: Pet) -> FMDest {
        switch feature {
        case .health: .petHealth(pet.persistentModelID)
        case .medications: .petMedications(pet.persistentModelID)
        case .food: .petFood(pet.persistentModelID)
        case .hygiene: .petHygiene(pet.persistentModelID)
        case .walks: .petWalks(pet.persistentModelID)
        case .potty: .petPotty(pet.persistentModelID)
        case .basicInfo: .petBasicInfo(pet.persistentModelID)
        case .documents: .petDocuments(pet.persistentModelID)
        case .moments: .petMoments(pet.persistentModelID)
        case .achievements: .petAchievements(pet.persistentModelID)
        case .retention: .petRetention(pet.persistentModelID)
        case .weight: .petWeight(pet.persistentModelID)
        case .expense: .petExpense(pet.persistentModelID)
        }
    }

    private func humanDest(_ feature: PetFeature, human: Human) -> FMDest {
        switch feature {
        case .expense: .humanExpense(human.persistentModelID)
        default: .humanWeight(human.persistentModelID)
        }
    }

    // MARK: - Per-pet subtitles (for summary list)

    private func subtitle(for pet: Pet) -> String {
        let summary = petAggregateSummaries[pet.id] ?? .empty
        switch feature {
        case .basicInfo:
            return pet.breed.isEmpty ? Pet.localizedSpeciesName(pet.species, l: l) : pet.breed
        case .documents:
            return l.tr(zh: "\(summary.documentCount) 份证件", en: "\(summary.documentCount) documents", de: "\(summary.documentCount) Dokumente")
        case .moments:
            return l.tr(zh: "\(summary.photoCount) 个时刻", en: "\(summary.photoCount) moments", de: "\(summary.photoCount) Momente")
        case .achievements:
            return l.tr(zh: "\(summary.milestoneCount) 个里程碑", en: "\(summary.milestoneCount) milestones", de: "\(summary.milestoneCount) Meilensteine")
        case .health, .medications, .food, .hygiene, .walks, .potty, .retention, .weight, .expense:
            return ""
        }
    }
}
