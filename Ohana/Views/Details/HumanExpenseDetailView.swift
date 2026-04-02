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
                // Header
                VStack(spacing: 8) {
                    Text("累计花费")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        Text(String(format: "%.2f", totalAmount))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.3))
                
                // List
                if myExpenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "yensign.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("暂无花费记录")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                Circle().fill(log.expenseCategory.emoji.isEmpty ? Color.goPrimary.opacity(0.15) : Color.goPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(log.expenseCategory.emoji)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.note.isEmpty ? "花费记录" : log.note)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            
            Text("-¥\(String(format: "%.2f", log.amount))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}
