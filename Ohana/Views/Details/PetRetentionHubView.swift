//
//  PetRetentionHubView.swift
//  Ohana
//
//  Long-term retention hub: health trends, memories, cost, medical protection,
//  and achievements in one per-pet archive.
//

import SwiftUI

struct PetRetentionHubView: View {
    let pet: Pet

    private var latestWeightText: String {
        guard let latest = pet.weightLogs.sorted(by: { $0.date < $1.date }).last else { return "暂无" }
        return String(format: "%.1fkg", latest.weight)
    }

    private var weightTrendText: String {
        let sorted = pet.weightLogs.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return "\(pet.weightLogs.count) 条体重记录" }
        let delta = last.weight - first.weight
        if abs(delta) < 0.05 { return "体重基本稳定" }
        return delta > 0 ? String(format: "累计 +%.1fkg", delta) : String(format: "累计 %.1fkg", delta)
    }

    private var healthInsightText: String {
        let recent = pet.healthLogs.filter {
            $0.date >= (Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        }
        if recent.contains(where: { $0.healthLogType == .emergency || $0.healthLogType == .surgery }) {
            return "近 90 天有急诊或手术记录，建议关注复诊与恢复趋势"
        }
        if pet.weightLogs.count >= 2 { return "\(weightTrendText)，继续保持周期称重" }
        return "补充体重与体检记录后，会生成更完整的健康趋势"
    }

    private var monthExpense: Double {
        pet.expenseLogs.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) && $0.amount > 0
        }.reduce(0) { $0 + $1.amount }
    }

    private var projectedMonthlyExpense: Double {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let elapsed = max(1, Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 1)
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return monthExpense / Double(elapsed) * Double(daysInMonth)
    }

    private var photoYearCount: Int {
        pet.photoLogs.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .year)
        }.count
    }

    private var medicalRecordCount: Int {
        pet.healthLogs.filter { log in
            [.vaccine, .medication, .dewormingInternal, .dewormingExternal, .surgery, .dental, .checkup, .emergency].contains(log.healthLogType)
        }.count + pet.medications.count
    }

    private var expiringProtectionCount: Int {
        let expiringDocs = pet.documents.filter { $0.isExpired || $0.isExpiringSoon }.count
        let expiringInsurances = pet.insurances.filter { $0.daysUntilRenewal <= 30 }.count
        return expiringDocs + expiringInsurances
    }

    private var nextAchievementHint: String {
        let locked = AchievementManager.compute(for: pet).first { !$0.isUnlocked }
        return locked.map { "下一枚：\($0.title) · \($0.description)" } ?? "成就墙已全部点亮，继续保持"
    }

    private var achievementProgress: (unlocked: Int, total: Int) {
        let achievements = AchievementManager.compute(for: pet)
        return (achievements.filter(\.isUnlocked).count, achievements.count)
    }

    private var retentionScore: Int {
        [
            !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
            !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
            !pet.expenseLogs.isEmpty,
            !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
            achievementProgress.unlocked > 0 || pet.currentStreak > 0
        ].filter { $0 }.count
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard
                    insightStrip
                    sectionTitle("长期留存模块")
                    retentionCard(
                        icon: "waveform.path.ecg",
                        accent: .goTeal,
                        title: "健康趋势",
                        value: latestWeightText,
                        subtitle: healthInsightText,
                        destination: PetHealthDetailView(pet: pet, isModal: false)
                    )
                    retentionCard(
                        icon: "photo.on.rectangle.angled",
                        accent: .goPrimary,
                        title: "成长相册",
                        value: "\(pet.photoLogs.count) 张",
                        subtitle: "今年新增 \(photoYearCount) 张 · 重要时刻 \(pet.milestones.count) 个",
                        destination: PetMomentsHubView(pet: pet)
                    )
                    retentionCard(
                        icon: "chart.pie.fill",
                        accent: .goYellow,
                        title: "花费统计",
                        value: "¥\(Int(monthExpense))",
                        subtitle: "本月预测约 ¥\(Int(projectedMonthlyExpense)) · 共 \(pet.expenseLogs.count) 条记录",
                        destination: ExpenseHistoryView(pet: pet)
                    )
                    retentionCard(
                        icon: "shield.lefthalf.filled",
                        accent: .goOrange,
                        title: "保险 / 医疗记录",
                        value: "\(medicalRecordCount) 条",
                        subtitle: expiringProtectionCount > 0 ? "\(expiringProtectionCount) 项保障需要关注" : "证件、保单、疫苗与用药集中归档",
                        destination: DocumentsListView(pet: pet)
                    )
                    retentionCard(
                        icon: "tree.fill",
                        accent: .goLime,
                        title: "生命树成就",
                        value: "\(achievementProgress.unlocked)/\(achievementProgress.total)",
                        subtitle: nextAchievementHint,
                        destination: AchievementWallView(pet: pet)
                    )
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("\(pet.name) · 成长档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            FMPetAvatar(pet: pet, size: 58)
            VStack(alignment: .leading, spacing: 5) {
                Text("长期留存总览")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("已完善 \(retentionScore)/5 个长期价值模块")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(retentionScore), total: 5)
                    .tint(Color.goPrimary)
            }
            Spacer()
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var insightStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("本周建议")
            HStack(spacing: 10) {
                insightPill(icon: "heart.text.square.fill", title: protectionPrompt, color: expiringProtectionCount > 0 ? .goOrange : .goTeal)
                insightPill(icon: "camera.fill", title: photoYearCount == 0 ? "补一张近照" : "今年 \(photoYearCount) 张照片", color: .goPrimary)
            }
        }
    }

    private var protectionPrompt: String {
        if expiringProtectionCount > 0 { return "\(expiringProtectionCount) 项保障待处理" }
        if pet.insurances.isEmpty && pet.documents.isEmpty { return "补齐证件保障" }
        return "保障记录正常"
    }

    private func insightPill(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 12, weight: .black))
            Text(title).font(.system(size: 11, weight: .black, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(color.opacity(0.12), in: Capsule())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func retentionCard<Destination: View>(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        subtitle: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(value)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                    }
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .goTranslucentCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
