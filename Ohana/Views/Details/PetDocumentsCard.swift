//
//  PetDocumentsCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetDocumentsCard: View {
    let pet: Pet

    private var expiringSoon: [PetDocument] {
        pet.documents.filter { $0.isExpiringSoon || $0.isExpired }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    var body: some View {
        // N9: 整卡点击进入证件详情页
        NavigationLink {
            DocumentsListView(pet: pet)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.goCardCyan)
                    Text("证件与保障")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(pet.documents.count) 份")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                }

                // 即将到期/已过期提醒
                if !expiringSoon.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(expiringSoon.prefix(2)) { doc in
                            HStack(spacing: 8) {
                                Text(doc.documentCategory.emoji)
                                Text(doc.title.isEmpty ? doc.category : doc.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(doc.isExpired ? "已过期" : "即将到期")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(doc.isExpired ? Color.goRed : Color.goYellow)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background((doc.isExpired ? Color.goRed : Color.goYellow).opacity(0.15), in: Capsule())
                            }
                        }
                    }
                } else if pet.documents.isEmpty {
                    Text("暂无证件，点击添加")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    // 显示前3份证件概览
                    HStack(spacing: 8) {
                        ForEach(pet.documents.prefix(5)) { doc in
                            Text(doc.documentCategory.emoji)
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        if pet.documents.count > 5 {
                            Text("+\(pet.documents.count - 5)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    }
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
