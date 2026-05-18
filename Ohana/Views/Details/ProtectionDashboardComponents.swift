//
//  ProtectionDashboardComponents.swift
//  Ohana
//
//  Shared V4 components for the pet protection cockpit.
//

import SwiftUI

enum ProtectionSection: String, CaseIterable, Identifiable {
    case documents
    case vaccines
    case insurance

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .vaccines: return "syringe.fill"
        case .insurance: return "shield.lefthalf.filled"
        }
    }

    var title: String {
        switch self {
        case .documents: return "证件"
        case .vaccines: return "疫苗本"
        case .insurance: return "保险"
        }
    }

    var tint: Color {
        switch self {
        case .documents: return Color(hex: "94A3B8")
        case .vaccines: return Color.goTeal
        case .insurance: return Color.goPurple
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
        case .empty: return Color.ohanaSecondaryText
        case .protected: return Color.goTeal
        case .soon: return Color.goYellow
        case .expired: return Color.goRed
        }
    }

    var label: String {
        switch self {
        case .empty: return "未建立"
        case .protected: return "保障中"
        case .soon: return "即将到期"
        case .expired: return "已过期"
        }
    }
}

struct PetProtectionDashboardState {
    let documentCount: Int
    let vaccineCount: Int
    let insuranceCount: Int
    let documentsRisk: ProtectionRiskLevel
    let vaccineRisk: ProtectionRiskLevel
    let insuranceRisk: ProtectionRiskLevel
    let nextDocumentDate: Date?
    let nextVaccineDate: Date?
    let nextInsuranceDate: Date?

    init(pet: Pet, calendar: Calendar = .current, now: Date = Date()) {
        let documents = pet.documents
        let vaccines = pet.healthLogs.filter { $0.healthLogType == .vaccine }
        let insurances = pet.insurances

        documentCount = documents.count
        vaccineCount = vaccines.count
        insuranceCount = insurances.count
        documentsRisk = Self.risk(for: documents.compactMap(\.expiryDate), now: now, calendar: calendar, empty: documents.isEmpty)
        vaccineRisk = Self.risk(for: vaccines.compactMap(\.expirationDate), now: now, calendar: calendar, empty: vaccines.isEmpty)
        insuranceRisk = Self.risk(for: insurances.map(\.renewalDate), now: now, calendar: calendar, empty: insurances.isEmpty)
        nextDocumentDate = Self.nextDate(from: documents.compactMap(\.expiryDate), now: now)
        nextVaccineDate = Self.nextDate(from: vaccines.compactMap(\.expirationDate), now: now)
        nextInsuranceDate = Self.nextDate(from: insurances.map(\.renewalDate), now: now)
    }

    func count(for section: ProtectionSection) -> Int {
        switch section {
        case .documents: return documentCount
        case .vaccines: return vaccineCount
        case .insurance: return insuranceCount
        }
    }

    func risk(for section: ProtectionSection) -> ProtectionRiskLevel {
        switch section {
        case .documents: return documentsRisk
        case .vaccines: return vaccineRisk
        case .insurance: return insuranceRisk
        }
    }

    func nextDate(for section: ProtectionSection) -> Date? {
        switch section {
        case .documents: return nextDocumentDate
        case .vaccines: return nextVaccineDate
        case .insurance: return nextInsuranceDate
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
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(section.tint)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(width: 30, height: 28)
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
                    .contentTransition(.numericText())
            }

            HStack(spacing: 5) {
                Circle().fill(risk.color).frame(width: 6, height: 6)
                Text(nextText)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(risk.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(isSelected ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Color.goPrimary.opacity(0.65) : Color.clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                .font(.system(size: 30, weight: .black))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ProtectionPetAvatar: View {
    let pet: Pet
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: pet.safeThemeColorHex).opacity(0.18))
                .frame(width: size, height: size)
            if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji)
                    .font(.system(size: size * 0.48))
            }
        }
    }
}

struct DocumentDetailRow: View {
    let doc: PetDocument
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingPreview = false

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
                    .font(.system(size: 24))
                    .frame(width: 42, height: 42)

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

                if let preview = previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
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
            if let preview = previewImage {
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
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .black))
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

    private var previewImage: UIImage? {
        if let data = doc.attachmentData, let ui = UIImage(data: data) { return ui }
        if let first = doc.attachments.first(where: { $0.isImage }), let ui = UIImage(data: first.data) { return ui }
        return nil
    }
}

struct ProtectionVaccineRow: View {
    let log: PetHealthLog
    let onDelete: () -> Void

    private var expiryColor: Color {
        guard let date = log.expirationDate else { return Color.ohanaSecondaryText }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return Color.goRed }
        if days <= 30 { return Color.goYellow }
        return Color.goTeal
    }

    private var statusText: String {
        guard let date = log.expirationDate else { return "未设有效期" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "已过期" }
        if days == 0 { return "今日到期" }
        if days <= 30 { return "\(days)天" }
        return date.formatted(.dateTime.month().day())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "syringe.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(log.note.isEmpty ? "疫苗接种" : log.note)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                HStack(spacing: 8) {
                    Text(log.date.formatted(.dateTime.month().day()))
                    if !log.vetName.isEmpty { Text(log.vetName) }
                    if log.cost > 0 { Text(AppCurrency.format(log.cost, fractionDigits: 0)) }
                }
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
            }
            Spacer()
            Text(statusText)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(expiryColor)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(expiryColor.opacity(0.14), in: Capsule())
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("删除疫苗", systemImage: "trash")
            }
        }
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
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.goPurple)
                    .frame(width: 42, height: 42)
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
