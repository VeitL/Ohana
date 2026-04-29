//
//  HumanNoteHistorySheet.swift
//  Ohana
//
//  人类备注历史页 — 长按「备注」快捷操作后进入
//  统一 chrome：隐私开关（leading）+ xmark 关闭（trailing）+ 底部 FAB
//

import SwiftUI
import SwiftData

// MARK: - Note Entry Model

struct HumanNoteEntry: Identifiable {
    let id: UUID
    let date: Date
    let dateString: String
    let text: String
    /// 与 human.notes 中存储的原始段落完全匹配，用于删除时精确过滤
    let rawString: String
}

// MARK: - Main Sheet

struct HumanNoteHistorySheet: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var showAddSheet = false

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.note, viewedBy: activeHumanId) }

    private var noteEntries: [HumanNoteEntry] { parseNotes() }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArkBackgroundView().ignoresSafeArea()

                if isPrivacyLocked {
                    privacyLockedView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if noteEntries.isEmpty {
                                emptyState
                            } else {
                                ForEach(noteEntries) { entry in
                                    noteRow(entry)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }

                    // ── 底部 FAB
                    Button { showAddSheet = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                            Text("添加备注")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(Color.goPrimary, in: Capsule())
                        .shadow(color: Color.goPrimary.opacity(0.4), radius: 14, y: 5)
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("备注记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HumanPrivacyToggleButton(human: human, field: .note)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                QuickHumanNoteSheet(human: human)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Note Row

    private func noteRow(_ entry: HumanNoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧彩点 + 日期
            VStack(alignment: .center, spacing: 4) {
                Circle()
                    .fill(Color.goPrimary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Text(entry.text)
                    .font(OhanaFont.body())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    deleteNote(entry)
                }
            } label: {
                Image(systemName: "trash")
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "note.text")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
            }
            Text("还没有备注")
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(.primary)
            Text("点击下方按钮为 \(human.name) 添加第一条备注")
                .font(OhanaFont.callout())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    // MARK: - Privacy Locked

    private var privacyLockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.goYellow)
            Text("备注仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(.primary)
            Text("当前家庭成员无权查看这些备注。")
                .font(OhanaFont.callout())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .ohanaStandardCard(cornerRadius: 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Parse & Delete

    private static let noteDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func parseNotes() -> [HumanNoteEntry] {
        guard !human.notes.isEmpty else { return [] }
        let parts = human.notes.components(separatedBy: "\n\n")
        return parts.compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            // 期望格式：[yyyy-MM-dd] 正文
            if trimmed.hasPrefix("["),
               let bracketEnd = trimmed.firstIndex(of: "]") {
                let dateStr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<bracketEnd])
                let rest = String(trimmed[trimmed.index(after: bracketEnd)...])
                    .trimmingCharacters(in: .whitespaces)
                if let date = Self.noteDateFormatter.date(from: dateStr) {
                    return HumanNoteEntry(id: UUID(), date: date,
                                         dateString: dateStr, text: rest,
                                         rawString: trimmed)
                }
            }
            // 没有日期标记的老备注
            return HumanNoteEntry(id: UUID(), date: .distantPast,
                                  dateString: "", text: trimmed,
                                  rawString: trimmed)
        }
        .sorted { $0.date > $1.date }
    }

    private func deleteNote(_ entry: HumanNoteEntry) {
        let parts = human.notes.components(separatedBy: "\n\n")
        let remaining = parts.filter { part in
            part.trimmingCharacters(in: .whitespacesAndNewlines) != entry.rawString
        }
        human.notes = remaining
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
