//
//  PlantSiteDetailSheet.swift
//  Ohana
//
//  Site-level plant overview for the Plants dashboard.
//

import SwiftUI
import UIKit

struct PlantSiteDetailSheet: View {
    let siteName: String
    let plants: [Plant]
    let careTasks: [PlantCareTaskSnapshot]
    let onShowPlants: () -> Void
    let onOpenPlant: (UUID) -> Void
    let onOpenCareLog: (Plant, PlantCareType) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

    private var dueTasks: [PlantCareTaskSnapshot] {
        careTasks
            .filter { $0.daysUntilDue <= 0 }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    private var watchPlants: [Plant] {
        plants.filter { $0.healthStatus == .watching || $0.healthStatus == .stressed }
    }

    var body: some View {
        OhanaSheetWrapper(
            title: siteName,
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if !dueTasks.isEmpty {
                    dueCareSection
                }

                plantListSection
                showPlantsButton
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-site-detail-sheet")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative site glyph; heading and stats name this sheet.
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .frame(width: 44, height: 44)
                    .background(Color.goLime.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "位置总览", en: "Site overview", de: "Standortübersicht"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                    Text(siteName)
                        .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                metricPill(
                    icon: "leaf.fill",
                    value: "\(plants.count)",
                    label: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                    tint: Color.goTeal
                )
                metricPill(
                    icon: "calendar.badge.clock",
                    value: "\(dueTasks.count)",
                    label: l.tr(zh: "到期", en: "Due", de: "Fällig"),
                    tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow
                )
                metricPill(
                    icon: "eye.fill",
                    value: "\(watchPlants.count)",
                    label: l.tr(zh: "观察", en: "Watch", de: "Beobachten"),
                    tint: watchPlants.isEmpty ? Color.goTeal : Color.goRed
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var dueCareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: l.tr(zh: "今天要处理", en: "Needs care today", de: "Heute pflegen"),
                detail: l.tr(zh: "\(dueTasks.count) 项到期护理", en: "\(dueTasks.count) due tasks", de: "\(dueTasks.count) fällige Aufgaben")
            )

            VStack(spacing: 8) {
                ForEach(dueTasks.prefix(4)) { task in
                    if let plant = plants.first(where: { $0.id == task.plantID }) {
                        dueCareRow(task: task, plant: plant)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-site-detail-due-care")
    }

    private var plantListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: l.tr(zh: "这个位置的植物", en: "Plants in this site", de: "Pflanzen hier"),
                detail: l.tr(zh: "\(plants.count) 株植物", en: "\(plants.count) plants", de: "\(plants.count) Pflanzen")
            )

            VStack(spacing: 8) {
                ForEach(plants) { plant in
                    plantRow(plant)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-site-detail-plants")
    }

    private var showPlantsButton: some View {
        Button {
            onShowPlants()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill") // a11y: allow decorative filter glyph; button label names action.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "在 Plants 视图查看此位置", en: "View this site in Plants", de: "Diesen Standort in Pflanzen anzeigen"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Color.goLime, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-site-detail-view-plants")
    }

    private func dueCareRow(task: PlantCareTaskSnapshot, plant: Plant) -> some View {
        let careTypeName = task.careType.displayName(l: l)

        return HStack(spacing: 10) {
            Image(systemName: careSymbol(for: task.careType)) // a11y: decorative care glyph; row text names task.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: task.careType))
                .frame(width: 34, height: 34) // a11y: allow non-interactive care glyph; adjacent row text names the task.
                .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(plant.name) · \(careTypeName)")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                onOpenCareLog(plant, task.careType)
            } label: {
                Image(systemName: "checkmark") // a11y: allow decorative completion glyph; accessibility label names action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goLime, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "记录\(plant.name)的\(careTypeName)", en: "Log \(careTypeName) for \(plant.name)", de: "\(careTypeName) für \(plant.name) erfassen"))
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-site-detail-care-task-\(task.id)")
    }

    private func plantRow(_ plant: Plant) -> some View {
        Button {
            onOpenPlant(plant.id)
        } label: {
            HStack(spacing: 12) {
                PlantSiteImageTile(
                    imageData: previewImageData(for: plant),
                    tint: statusTint(for: plant)
                )
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.ohanaCardStroke.opacity(0.6), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(plant.species.isEmpty ? l.tr(zh: "未设置品种", en: "Species unset", de: "Art fehlt") : plant.species)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                statusPill(for: plant)
            }
            .padding(10)
            .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel([
            plant.name,
            plant.species.isEmpty ? l.tr(zh: "未设置品种", en: "Species unset", de: "Art fehlt") : plant.species,
            plant.healthStatus.displayName
        ].joined(separator: ", "))
        .accessibilityIdentifier("plant-site-detail-plant-row-\(plant.id.uuidString)")
    }

    private func metricPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon) // a11y: decorative metric glyph; adjacent text gives value.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func sectionHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer(minLength: 8)
            Text(detail)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
    }

    private func statusPill(for plant: Plant) -> some View {
        HStack(spacing: 4) {
            Image(systemName: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .accessibilityHidden(true)
            Text(plant.healthStatus.displayName)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(statusTint(for: plant))
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(Color.ohanaCardSurface.opacity(0.78), in: Capsule())
    }

    private func previewImageData(for plant: Plant) -> Data? {
        plant.avatarImageData ?? plant.careLogs
            .sorted { $0.date > $1.date }
            .first { $0.photoData != nil }?
            .photoData
    }

    private func statusTint(for plant: Plant) -> Color {
        switch plant.healthStatus {
        case .thriving:
            Color.goLime
        case .stable:
            Color.goTeal
        case .watching:
            Color.goYellow
        case .stressed:
            Color.goRed
        }
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goLime
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }
}

private struct PlantSiteImageTile: View {
    let imageData: Data?
    let tint: Color

    @State private var image: UIImage?

    private var imageSignature: String {
        guard let imageData else { return "none" }
        return "\(imageData.count)-\(imageData.first ?? 0)-\(imageData.last ?? 0)"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "leaf.fill") // a11y: allow decorative fallback plant glyph; parent row names the plant.
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(tint)
            }
        }
        .clipped()
        .task(id: imageSignature) {
            guard let imageData else {
                image = nil
                return
            }
            image = await AttachmentImageDecoder.decode(imageData)
        }
        .accessibilityHidden(true)
    }
}
