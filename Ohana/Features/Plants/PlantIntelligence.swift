//
//  PlantIntelligence.swift
//  Ohana
//
//  Provider boundary for future AI recognition/diagnosis. The launch fallback is
//  honest and deterministic: no fake recognition, no fake confidence.
//

import Foundation

nonisolated struct PlantRecognitionCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let speciesName: String
    let latinName: String
    let confidence: Double
    let catalogEntryId: String?
    let basicCare: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
}

nonisolated struct PlantRecognitionResult: Equatable, Sendable {
    let mostLikely: PlantRecognitionCandidate?
    let candidates: [PlantRecognitionCandidate]
    let uncertaintyMessage: String
    let manualSearchSuggested: Bool
}

nonisolated struct PlantDiagnosisCause: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let severity: String
    let steps: [String]
    let shouldIsolate: Bool
    let recheckAfterDays: Int
}

nonisolated struct PlantDiagnosisResult: Equatable, Sendable {
    let uncertaintyMessage: String
    let causes: [PlantDiagnosisCause]
}

nonisolated enum PlantRecognitionPolicy {
    static let requiredCandidateCount = 3
    static let maximumDisplayedCandidateCount = 3

    static func normalized(_ result: PlantRecognitionResult) -> PlantRecognitionResult {
        let rawCandidates = ([result.mostLikely].compactMap(\.self) + result.candidates)
        var seenKeys = Set<String>()
        let normalizedCandidates = rawCandidates.compactMap { candidate -> PlantRecognitionCandidate? in
            let enriched = enrichedCandidate(candidate)
            let key = candidateKey(enriched)
            guard !key.isEmpty, !seenKeys.contains(key) else { return nil }
            seenKeys.insert(key)
            return enriched
        }
        .sorted {
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.speciesName.localizedStandardCompare($1.speciesName) == .orderedAscending
        }
        let displayed = Array(normalizedCandidates.prefix(maximumDisplayedCandidateCount))
        let mostLikely = displayed.first
        let uncertainty = uncertaintyMessage(
            raw: result.uncertaintyMessage,
            candidateCount: displayed.count
        )
        return PlantRecognitionResult(
            mostLikely: mostLikely,
            candidates: displayed,
            uncertaintyMessage: uncertainty,
            manualSearchSuggested: result.manualSearchSuggested || displayed.isEmpty || displayed.count < requiredCandidateCount
        )
    }

    static func isConfirmable(_ result: PlantRecognitionResult) -> Bool {
        let normalized = normalized(result)
        return normalized.mostLikely != nil &&
            normalized.candidates.count >= requiredCandidateCount &&
            !normalized.manualSearchSuggested
    }

    static func confirmedCatalogEntry(for candidate: PlantRecognitionCandidate) -> PlantCatalogEntry? {
        if let catalogEntryId = candidate.catalogEntryId,
           let entry = PlantCatalog.entry(id: catalogEntryId) {
            return entry
        }
        return PlantCatalog.bestMatch(commonName: candidate.speciesName, latinName: candidate.latinName)
    }

    private static func enrichedCandidate(_ candidate: PlantRecognitionCandidate) -> PlantRecognitionCandidate {
        let catalogEntry = confirmedCatalogEntry(for: candidate)
        let speciesName = trimmed(candidate.speciesName).isEmpty
            ? (catalogEntry?.commonName ?? "未知植物")
            : trimmed(candidate.speciesName)
        let latinName = trimmed(candidate.latinName).isEmpty
            ? (catalogEntry?.latinName ?? "")
            : trimmed(candidate.latinName)
        let catalogId = candidate.catalogEntryId ?? catalogEntry?.id
        let id = trimmed(candidate.id).isEmpty
            ? [catalogId, latinName, speciesName].compactMap(\.self).joined(separator: "|")
            : trimmed(candidate.id)
        return PlantRecognitionCandidate(
            id: id,
            speciesName: speciesName,
            latinName: latinName,
            confidence: min(1, max(0, candidate.confidence)),
            catalogEntryId: catalogId,
            basicCare: trimmed(candidate.basicCare).isEmpty ? basicCare(from: catalogEntry) : trimmed(candidate.basicCare),
            isToxicToCats: catalogEntry?.isToxicToCats ?? candidate.isToxicToCats,
            isToxicToDogs: catalogEntry?.isToxicToDogs ?? candidate.isToxicToDogs,
            isToxicToChildren: catalogEntry?.isToxicToChildren ?? candidate.isToxicToChildren,
            isIndoorSuitable: catalogEntry?.isIndoorSuitable ?? candidate.isIndoorSuitable
        )
    }

    private static func uncertaintyMessage(raw: String, candidateCount: Int) -> String {
        let message = trimmed(raw)
        if !message.isEmpty { return message }
        if candidateCount == 0 {
            return "没有可确认的候选；请使用资料库搜索或手动添加。"
        }
        if candidateCount < requiredCandidateCount {
            return "候选数量不足，不能直接写入档案；请手动确认或改用资料库搜索。"
        }
        return "识别结果仍可能出错；请确认正确物种后再写入植物档案。"
    }

    private static func basicCare(from entry: PlantCatalogEntry?) -> String {
        guard let entry else { return "" }
        return "\(entry.lightRequirement.displayName) · \(entry.wateringPreference)"
    }

    private static func candidateKey(_ candidate: PlantRecognitionCandidate) -> String {
        if let catalogEntryId = candidate.catalogEntryId, !catalogEntryId.isEmpty {
            return catalogEntryId
        }
        return [candidate.latinName, candidate.speciesName]
            .map(normalized)
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}

nonisolated protocol PlantIntelligenceProviding: Sendable {
    func recognizePlant(imageData: Data) async -> PlantRecognitionResult
    func diagnosePlant(imageData: Data?, symptoms: [String]) async -> PlantDiagnosisResult
}

nonisolated struct LocalPlantIntelligenceFallback: PlantIntelligenceProviding {
    func recognizePlant(imageData _: Data) async -> PlantRecognitionResult {
        PlantRecognitionResult(
            mostLikely: nil,
            candidates: [],
            uncertaintyMessage: "当前版本未连接植物识别服务。请使用资料库搜索或手动添加；Ohana 不会伪造识别结果。",
            manualSearchSuggested: true
        )
    }

    func diagnosePlant(imageData _: Data?, symptoms: [String]) async -> PlantDiagnosisResult {
        let normalized = Set(symptoms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        var causes: [PlantDiagnosisCause] = []
        if normalized.contains("虫子") || normalized.contains("白色斑点") {
            causes.append(PlantDiagnosisCause(
                id: "pests",
                title: "可能有虫害",
                severity: "中等",
                steps: ["先隔离植物", "检查叶背、叶柄和土面", "用清水冲洗明显虫体", "3-5 天后复查"],
                shouldIsolate: true,
                recheckAfterDays: 4
            ))
        }
        if normalized.contains("根腐") || normalized.contains("发霉") || normalized.contains("掉叶") {
            causes.append(PlantDiagnosisCause(
                id: "overwatering",
                title: "可能过浇或根系缺氧",
                severity: "偏高",
                steps: ["暂停浇水并检查盆底排水", "移到通风明亮处", "土壤持续潮湿时考虑换土", "2-3 天后复查"],
                shouldIsolate: false,
                recheckAfterDays: 3
            ))
        }
        if normalized.contains("黄叶") || normalized.contains("叶尖发黑") || normalized.contains("叶片卷曲") || causes.isEmpty {
            causes.append(PlantDiagnosisCause(
                id: "stress",
                title: "可能是环境压力",
                severity: "轻中度",
                steps: ["回顾最近是否搬动、暴晒、低温或漏浇", "保持一周稳定护理", "只剪除完全枯黄叶片", "7 天后拍照对比"],
                shouldIsolate: false,
                recheckAfterDays: 7
            ))
        }
        if causes.count < 2 {
            causes.append(PlantDiagnosisCause(
                id: "watering-rhythm",
                title: "可能是浇水节奏不稳定",
                severity: "轻中度",
                steps: ["先记录盆土干湿和上次浇水时间", "避免少量频繁浇水", "下次浇透后等表土变干再浇", "5-7 天后复查叶片"],
                shouldIsolate: false,
                recheckAfterDays: 6
            ))
        }
        if causes.count < 3 {
            causes.append(PlantDiagnosisCause(
                id: "light-mismatch",
                title: "可能是光照不匹配",
                severity: "轻度",
                steps: ["避免突然从弱光搬到直晒", "优先选择明亮散射光", "每周转盆一次观察新叶方向", "7 天后对比照片"],
                shouldIsolate: false,
                recheckAfterDays: 7
            ))
        }
        return PlantDiagnosisResult(
            uncertaintyMessage: "基础诊断不能替代专业判断；同一种症状可能来自浇水、光照、温度、虫害或土壤问题。",
            causes: Array(causes.prefix(3))
        )
    }
}
