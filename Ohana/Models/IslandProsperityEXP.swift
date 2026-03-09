//
//  IslandProsperityEXP.swift
//  Ohana
//
//  岛屿繁荣度 EXP 系统（只增不减，动森模式）
//  EXP 来源：遛狗/便便/护理/健康/浇水/喂食/里程碑，每类行为 +1~+5

import SwiftData
import Foundation

// MARK: - EXP 来源枚举
enum ProsperitySource: String {
    case walk       = "遛狗"
    case potty      = "便便打卡"
    case hygiene    = "护理"
    case health     = "健康记录"
    case watering   = "植物浇水"
    case feeding    = "喂食记录"
    case milestone  = "里程碑"
    case appOpen    = "打开 App"

    var expValue: Int {
        switch self {
        case .walk:      return 5
        case .milestone: return 5
        case .potty:     return 3
        case .hygiene:   return 3
        case .health:    return 3
        case .watering:  return 2
        case .feeding:   return 2
        case .appOpen:   return 1
        }
    }
}

// MARK: - 繁荣度 EXP 管理器
struct IslandProsperityEXP {

    /// 给 Household 增加 EXP（只增不减）
    @MainActor
    static func addEXP(source: ProsperitySource, household: Household, context: ModelContext) {
        household.totalProsperity += source.expValue
        context.safeSave()
    }

    /// 根据 EXP 总量计算等级（对应 IslandLevel 视觉进化）
    static func level(from prosperity: Int) -> IslandLevel {
        switch prosperity {
        case ..<50:   return .seedling
        case 50..<200: return .blooming
        default:       return .paradise
        }
    }

    /// EXP 进度 0~1（当前等级内的进度）
    static func progress(from prosperity: Int) -> Double {
        switch prosperity {
        case ..<50:    return Double(prosperity) / 50.0
        case 50..<200: return Double(prosperity - 50) / 150.0
        default:       return 1.0
        }
    }

    /// 距离下一级还差多少 EXP
    static func expToNextLevel(from prosperity: Int) -> Int? {
        switch prosperity {
        case ..<50:    return 50 - prosperity
        case 50..<200: return 200 - prosperity
        default:       return nil  // 已满级
        }
    }

    /// 每日「打开 App」EXP，防止重复刷（每天最多 +1）
    /// F7: 使用固定 key 存储最后领取日期，避免 UserDefaults 键污染
    static func tryAddDailyOpenEXP(household: Household, context: ModelContext) {
        let key = "prosperity_lastOpenDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }
        UserDefaults.standard.set(today, forKey: key)
        household.totalProsperity += ProsperitySource.appOpen.expValue
        context.safeSave()
    }
}

// MARK: - 繁荣度展示组件（供 OverviewView 使用）
import SwiftUI

struct IslandEXPBadgeView: View {
    let prosperity: Int
    @State private var animateBar = false

    private var level: IslandLevel { IslandProsperityEXP.level(from: prosperity) }
    private var progress: Double   { IslandProsperityEXP.progress(from: prosperity) }
    private var remaining: Int?    { IslandProsperityEXP.expToNextLevel(from: prosperity) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(level.emoji)
                    .font(.system(size: 12))
                Text(level.displayName)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(level == .paradise ? Color.goLime : .white.opacity(0.7))
                Spacer()
                if let rem = remaining {
                    Text("还差 \(rem) EXP")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    Text("满级 ✨")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goLime)
                }
            }

            // EXP 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: level == .paradise
                                    ? [Color.goLime, Color.goTeal]
                                    : [Color.goPrimary.opacity(0.8), Color.goTeal],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: animateBar ? geo.size.width * progress : 0)
                        .animation(.spring(response: 1.2, dampingFraction: 0.75).delay(0.2), value: animateBar)
                }
            }
            .frame(height: 4)
            .onAppear { animateBar = true }

            Text("总 \(prosperity) 欧哈纳星光")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .goTranslucentCard(cornerRadius: 14)
    }
}
