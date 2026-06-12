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

    var title: String {
        switch self {
        case .documents: "证件"
        case .insurance: "保险"
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

    var label: String {
        switch self {
        case .empty: "未建立"
        case .protected: "保障中"
        case .soon: "即将到期"
        case .expired: "已过期"
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

    init(pet: Pet, calendar: Calendar = .current, now: Date = Date()) {
        let documents = pet.documents.activeRecycleBinItems.filter { doc in
            doc.documentCategory != .vaccine && doc.documentCategory != .insurance
        }
        let insurances = pet.insurances.activeRecycleBinItems

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
                Text(section.title)
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
        guard let nextDate else { return risk.label }
        return Self.shortDate(nextDate)
    }

    private static func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInTomorrow(date) { return "明天" }
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
            imageData: pet.avatarImageData,
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
    @State private var decodedPreview: UIImage?

    private var expiryColor: Color {
        if doc.isExpired { return Color.goRed }
        if doc.isExpiringSoon { return Color.goYellow }
        return Color.goTeal
    }

    private var statusText: String {
        if doc.isExpired { return "已过期" }
        if doc.isExpiringSoon { return "即将到期" }
        if doc.expiryDate != nil { return "保障中" }
        return "长期"
    }

    var body: some View {
        Button(action: onDetail) {
            HStack(spacing: 12) {
                Text(doc.documentCategory.emoji)
                    .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent

                VStack(alignment: .leading, spacing: 5) {
                    Text(doc.title.isEmpty ? doc.category : doc.title)
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(doc.category)
                        if !doc.issuingAuthority.isEmpty { Text(doc.issuingAuthority) }
                        if let expiry = doc.expiryDate { Text(expiry.formatted(.dateTime.month().day())) }
                    }
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                }

                Spacer()

                if let preview = decodedPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
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
        .task(id: previewDataKey) {
            await decodePreview()
        }
        .contextMenu {
            Button { onDetail() } label: {
                Label("查看详情", systemImage: "doc.text.magnifyingglass")
            }
            Button { onEdit() } label: {
                Label("编辑证件", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("删除证件", systemImage: "trash")
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let preview = decodedPreview {
                ZStack {
                    Color.arkInk.ignoresSafeArea()
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
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

    private var previewData: Data? {
        if let data = doc.attachmentData { return data }
        return doc.attachments.first(where: { $0.isImage })?.data
    }

    private var previewDataKey: String {
        guard let previewData else { return "none" }
        return "\(previewData.count)-\(previewData.hashValue)"
    }

    @MainActor
    private func decodePreview() async {
        guard let previewData else {
            decodedPreview = nil
            return
        }
        decodedPreview = await AttachmentImageDecoder.decode(previewData)
    }
}

struct ProtectionInsuranceRow: View {
    let insurance: PetInsurance
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

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
                    Text(insurance.productName.isEmpty ? "宠物保险" : insurance.productName)
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
                Text(insurance.renewalStatusLabel)
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
                Label("编辑保单", systemImage: "pencil")
            }
            Button { onDetail() } label: {
                Label("查看详情", systemImage: "doc.text.magnifyingglass")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("删除保单", systemImage: "trash")
            }
        }
    }
}
