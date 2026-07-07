//
//  ProtectionDashboardComponents.swift
//  Ohana
//
//  Shared V4 components for the pet protection cockpit.
//

import SwiftUI

enum ProtectionSection: String, CaseIterable, Identifiable {
    case documents
    case insurance

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .documents: "doc.text.fill"
        case .insurance: "shield.lefthalf.filled"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .documents:
            l.tr(zh: "证件", en: "Documents", de: "Dokumente")
        case .insurance:
            l.tr(zh: "保险", en: "Insurance", de: "Versicherung")
        }
    }

    var tint: Color {
        switch self {
        case .documents: Color(hex: "94A3B8")
        case .insurance: Color.goPurple
        }
    }
}

enum ProtectionRiskLevel: Equatable {
    case empty
    case protected
    case soon
    case expired

    var color: Color {
        switch self {
        case .empty: Color.ohanaSecondaryText
        case .protected: Color.goTeal
        case .soon: Color.goYellow
        case .expired: Color.goRed
        }
    }

    func label(_ l: L10n) -> String {
        switch self {
        case .empty:
            l.tr(zh: "未建立", en: "Not set", de: "Nicht eingerichtet")
        case .protected:
            l.tr(zh: "保障中", en: "Covered", de: "Aktiv")
        case .soon:
            l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig")
        case .expired:
            l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
    }
}

struct PetProtectionDashboardState {
    let documentCount: Int
    let insuranceCount: Int
    let documentsRisk: ProtectionRiskLevel
    let insuranceRisk: ProtectionRiskLevel
    let nextDocumentDate: Date?
    let nextInsuranceDate: Date?

    init(documents: [PetDocument], insurances: [PetInsurance], calendar: Calendar = .current, now: Date = Date()) {
        documentCount = documents.count
        insuranceCount = insurances.count
        documentsRisk = Self.risk(for: documents.compactMap(\.expiryDate), now: now, calendar: calendar, empty: documents.isEmpty)
        insuranceRisk = Self.risk(for: insurances.map(\.renewalDate), now: now, calendar: calendar, empty: insurances.isEmpty)
        nextDocumentDate = Self.nextDate(from: documents.compactMap(\.expiryDate), now: now)
        nextInsuranceDate = Self.nextDate(from: insurances.map(\.renewalDate), now: now)
    }

    func count(for section: ProtectionSection) -> Int {
        switch section {
        case .documents: documentCount
        case .insurance: insuranceCount
        }
    }

    func risk(for section: ProtectionSection) -> ProtectionRiskLevel {
        switch section {
        case .documents: documentsRisk
        case .insurance: insuranceRisk
        }
    }

    func nextDate(for section: ProtectionSection) -> Date? {
        switch section {
        case .documents: nextDocumentDate
        case .insurance: nextInsuranceDate
        }
    }

    private static func nextDate(from dates: [Date], now: Date) -> Date? {
        dates.filter { $0 >= now }.min()
    }

    private static func risk(for dates: [Date], now: Date, calendar: Calendar, empty: Bool) -> ProtectionRiskLevel {
        if empty { return .empty }
        if dates.contains(where: { $0 < now }) { return .expired }
        if dates.contains(where: { (calendar.dateComponents([.day], from: now, to: $0).day ?? 999) <= 30 }) {
            return .soon
        }
        return .protected
    }
}

struct ProtectionCoreCard: View {
    let section: ProtectionSection
    let count: Int
    let risk: ProtectionRiskLevel
    let nextDate: Date?
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: section.icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(section.tint)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(width: 30, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title(l))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(count)")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(count)
            }

            HStack(spacing: 5) {
                Circle().fill(risk.color).frame(width: 6, height: 6) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(nextText)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(risk.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(isSelected ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .stroke(isSelected ? Color.goPrimary.opacity(0.65) : Color.clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .onTapGesture(perform: onSelect)
        .buttonStyle(ScaleButtonStyle())
    }

    private var nextText: String {
        guard let nextDate else { return risk.label(l) }
        return shortDate(nextDate)
    }

    private func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        if Calendar.current.isDateInTomorrow(date) { return l.tr(zh: "明天", en: "Tomorrow", de: "Morgen") }
        return date.formatted(.dateTime.month().day())
    }
}

struct ProtectionEmptyState: View {
    let icon: String
    let title: String
    let actionTitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 30, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
            Text(title)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Button(action: action) {
                Text(actionTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }
}

struct ProtectionPetAvatar: View {
    let pet: Pet
    let size: CGFloat

    var body: some View {
        PetAvatarPortraitView(
            pet: pet,
            fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
            size: size,
            backgroundOpacity: 0.18
        )
    }
}

struct DocumentDetailRow: View {
    let doc: PetDocument
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingPreview = false
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    private var expiryColor: Color {
        if doc.isExpired { return Color.goRed }
        if doc.isExpiringSoon { return Color.goYellow }
        return Color.goTeal
    }

    private var statusText: String {
        if doc.isExpired { return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen") }
        if doc.isExpiringSoon { return l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig") }
        if doc.expiryDate != nil { return l.tr(zh: "保障中", en: "Valid", de: "Gültig") }
        return l.tr(zh: "长期", en: "Long-term", de: "Langfristig")
    }

    var body: some View {
        Button(action: onDetail) {
            HStack(spacing: 12) {
                Text(doc.documentCategory.emoji)
                    .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent

                VStack(alignment: .leading, spacing: 5) {
                    Text(doc.title.isEmpty ? doc.documentCategory.localizedLabel(l) : doc.title)
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(doc.documentCategory.localizedLabel(l))
                        if !doc.issuingAuthority.isEmpty { Text(doc.issuingAuthority) }
                        if let expiry = doc.expiryDate { Text(expiry.formatted(.dateTime.month().day())) }
                    }
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                }

                Spacer()

                if let previewSource {
                    AsyncDecodedImageView(
                        cacheID: previewSource.cacheID,
                        sourceSignature: previewSource.sourceSignature,
                        maxPixel: 160,
                        dataProvider: {
                            previewSource.dataProvider()
                        }
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "photo.fill") // a11y: allow decorative thumbnail placeholder; row title names the document.
                            .font(OhanaFont.adaptive(size: 17, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                        .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                        .onTapGesture { showingPreview = true }
                }

                Text(statusText)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(expiryColor)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(expiryColor.opacity(0.14), in: Capsule())
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button { onDetail() } label: {
                Label(l.tr(zh: "查看详情", en: "View details", de: "Details ansehen"), systemImage: "doc.text.magnifyingglass")
            }
            Button { onEdit() } label: {
                Label(l.tr(zh: "编辑证件", en: "Edit document", de: "Dokument bearbeiten"), systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label(l.tr(zh: "删除证件", en: "Delete document", de: "Dokument löschen"), systemImage: "trash")
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let previewSource {
                ZStack {
                    Color.arkInk.ignoresSafeArea()
                    AsyncDecodedImageView(
                        cacheID: "\(previewSource.cacheID)-preview",
                        sourceSignature: previewSource.sourceSignature,
                        maxPixel: 2200,
                        dataProvider: {
                            previewSource.dataProvider()
                        }
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                            .tint(Color.ohanaPrimaryActionText)
                    }
                        .ignoresSafeArea()
                    VStack {
                        HStack {
                            Spacer()
                            Button { showingPreview = false } label: {
                                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(16)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var previewSource: ProtectionDocumentPreviewSource? {
        if let attachment = doc.attachments.first(where: { $0.isImage && $0.canAttemptDataAttachmentLoad }) {
            return ProtectionDocumentPreviewSource(
                cacheID: "protection-document-\(attachment.id.uuidString)",
                sourceSignature: attachment.dataThumbnailSignature,
                dataProvider: { attachment.canAttemptDataAttachmentLoad ? attachment.data : nil }
            )
        }
        guard doc.shouldDisplayLegacyAttachmentSlot,
              doc.attachmentFilename.isEmpty || AttachmentPrivacySanitizer.isImageFilename(doc.attachmentFilename) else {
            return nil
        }
        return ProtectionDocumentPreviewSource(
            cacheID: "protection-document-legacy-\(doc.id.uuidString)",
            sourceSignature: doc.legacyAttachmentThumbnailSignature,
            dataProvider: { doc.canAttemptLegacyAttachmentLoad ? doc.attachmentData : nil }
        )
    }
}

private struct ProtectionDocumentPreviewSource {
    let cacheID: String
    let sourceSignature: String
    let dataProvider: @MainActor () -> Data?
}

struct ProtectionInsuranceRow: View {
    let insurance: PetInsurance
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    private var statusColor: Color {
        let days = insurance.daysUntilRenewal
        if days < 0 { return Color.goRed }
        if days <= 30 { return Color.goYellow }
        return Color.goTeal
    }

    var body: some View {
        Button(action: onDetail) {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPurple)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                VStack(alignment: .leading, spacing: 5) {
                    Text(insurance.productName.isEmpty ? l.tr(zh: "宠物保险", en: "Pet insurance", de: "Tierversicherung") : insurance.productName)
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if !insurance.companyName.isEmpty { Text(insurance.companyName) }
                        Text(AppCurrency.format(insurance.annualPremium, fractionDigits: 0))
                        Text(insurance.renewalDate.formatted(.dateTime.month().day()))
                    }
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                }
                Spacer()
                Text(renewalStatusLabel)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(statusColor.opacity(0.14), in: Capsule())
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button { onEdit() } label: {
                Label(l.tr(zh: "编辑保单", en: "Edit policy", de: "Police bearbeiten"), systemImage: "pencil")
            }
            Button { onDetail() } label: {
                Label(l.tr(zh: "查看详情", en: "View details", de: "Details ansehen"), systemImage: "doc.text.magnifyingglass")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label(l.tr(zh: "删除保单", en: "Delete policy", de: "Police löschen"), systemImage: "trash")
            }
        }
    }

    private var renewalStatusLabel: String {
        let days = insurance.daysUntilRenewal
        if days < 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if days <= 30 {
            return l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig")
        }
        return l.tr(zh: "保障中", en: "Covered", de: "Aktiv")
    }
}
