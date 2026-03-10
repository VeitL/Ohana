//
//  ExpenseSplitterCard.swift
//  Ohana
//
//  模块2：家庭财务 AA 结算室

import SwiftUI
import SwiftData

struct ExpenseSplitterCard: View {
    let filteredLogs: [PetExpenseLog]
    let humans: [Human]

    private struct SplitResult: Identifiable {
        let id: UUID
        let name: String
        let emoji: String
        let paid: Double
        let balance: Double      // 正=应收，负=应付
        let themeHex: String
    }

    private var totalExpense: Double { filteredLogs.reduce(0) { $0 + $1.amount } }

    private var results: [SplitResult] {
        guard !humans.isEmpty, totalExpense > 0 else { return [] }
        let average = totalExpense / Double(humans.count)
        return humans.map { human in
            let paid = filteredLogs
                .filter { $0.executorId == human.id.uuidString }
                .reduce(0.0) { $0 + $1.amount }
            let balance = paid - average
            let hex: String = human.themeColor
            return SplitResult(id: human.id, name: human.name,
                               emoji: human.avatarEmoji, paid: paid,
                               balance: balance, themeHex: hex)
        }.sorted { abs($0.balance) > abs($1.balance) }
    }

    private var settlementText: String {
        let payers   = results.filter { $0.balance > 0.5 }.sorted { $0.balance > $1.balance }
        let owes     = results.filter { $0.balance < -0.5 }.sorted { $0.balance < $1.balance }
        guard let top = payers.first, let debtor = owes.first else {
            return results.isEmpty ? "暂无记录" : "大家花费相当，无需结算 🎉"
        }
        return "\(debtor.name) 需向 \(top.name) 支付 ¥\(Int(abs(debtor.balance)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            HStack(spacing: 8) {
                Text("⚖️")
                    .font(.system(size: 18))
                Text("财务结算室")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if totalExpense > 0 {
                    Text("人均 ¥\(Int(totalExpense / max(1, Double(humans.count))))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            if results.isEmpty {
                Text("添加花费记录并指定支付人后，这里会自动计算谁欠谁多少钱。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.horizontal, 20).padding(.bottom, 18)
            } else {
                // 结算文案（大字报）
                Text(settlementText)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // 每人余额条
                VStack(spacing: 10) {
                    ForEach(results) { r in
                        balanceRow(r)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        )
    }

    private func balanceRow(_ r: SplitResult) -> some View {
        let accent = Color(hex: r.themeHex)
        let isPositive = r.balance >= 0
        return HStack(spacing: 12) {
            Text(r.emoji).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("实付 ¥\(Int(r.paid))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(isPositive ? "应收 ¥\(Int(r.balance))" : "应付 ¥\(Int(abs(r.balance)))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(isPositive ? Color.goLime : Color.goRed)
                Text(isPositive ? "垫付较多" : "少付了")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(12)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent.opacity(0.2), lineWidth: 1))
    }
}
