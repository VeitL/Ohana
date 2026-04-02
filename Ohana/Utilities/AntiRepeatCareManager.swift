//
//  AntiRepeatCareManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

/// 防重复打卡工具类（家庭协作保护机制）
@MainActor
final class AntiRepeatCareManager {
    /// 检查指定宠物和护理类型是否在短时间内被记录过。如果存在近期记录，返回其格式化的警告信息。
    /// - Parameters:
    ///   - pet: 目标宠物
    ///   - type: 护理操作类型 (CareType)
    ///   - thresholdMinutes: 防重复时间窗口（分钟），喂食建议 120 分钟 (2小时)
    ///   - currentUserId: 当前用户的 ID，用于判断是否为"别人"代为操作的（可选）
    /// - Returns: 如果有近期记录，返回 (近期记录者名称, 几分钟前)；否则返回 nil
    static func checkRecentCareLog(
        for pet: Pet,
        type: CareType,
        thresholdMinutes: Int = 120,
        currentUserId: String? = nil,
        in humans: [Human]
    ) -> (executorName: String, minutesAgo: Int)? {
        let now = Date()
        
        // 查找指定类型、且在时间窗口内的所有记录
        let recentLogs = pet.careLogs
            .filter { $0.careType == type }
            .filter { now.timeIntervalSince($0.date) < Double(thresholdMinutes * 60) }
            .sorted { $0.date > $1.date }
        
        guard let latestLog = recentLogs.first else { return nil }
        
        // 计算发生了多少分钟
        let minutesAgo = Int(now.timeIntervalSince(latestLog.date) / 60)
        
        // 解析执行者名称
        var executorName = "某人"
        if let executorId = latestLog.executorId, !executorId.isEmpty {
            if executorId == currentUserId {
                executorName = "你"
            } else if let human = humans.first(where: { $0.id.uuidString == executorId }) {
                executorName = human.name
            }
        }
        
        return (executorName, max(1, minutesAgo))
    }
}
