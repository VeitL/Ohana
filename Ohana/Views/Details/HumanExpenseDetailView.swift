//
//  HumanExpenseDetailView.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct HumanExpenseDetailView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenses: [PetExpenseLog]

    private var myExpenses: [PetExpenseLog] {
        allExpenses.filter { $0.executorId == human.id.uuidString }
    }

    private var totalAmount: Double {
        myExpenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // 累计花费 Hero
                VStack(spacing: 6) {
                    Text("累计花费")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.primary.opacity(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(OhanaFont.title3(.bold))
                            .foregroundStyle(Color.goPrimary)
                        Text(String(format: "%.2f", totalAmount))
                            .font(OhanaFont.metric(size: 40))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 0))

                GoDashedDivider()

                // List
                if myExpenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "yensign.circle")
                            .font(OhanaFont.metric(size: 48))
                            .foregroundStyle(.primary.opacity(0.2))
                        Text("暂无花费记录")
                            .font(OhanaFont.callout(.medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(myExpenses) { log in
                                expenseRow(log)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("\(human.name) 的花费")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func expenseRow(_ log: PetExpenseLog) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(log.expenseCategory.emoji.isEmpty ? "💰" : log.expenseCategory.emoji)
                    .font(OhanaFont.title3())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(log.note.isEmpty ? "花费记录" : log.note)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(OhanaFont.caption())
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()

            Text("-¥\(String(format: "%.2f", log.amount))")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goRed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
