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
            ? (catalogEntry?.localizedCommonName ?? L10n.current.tr(zh: "未知植物", en: "Unknown plant", de: "Unbekannte Pflanze"))
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
        let l = L10n.current
        if candidateCount == 0 {
            return l.tr(zh: "没有可确认的候选；请使用资料库搜索或手动添加。", en: "No confirmable candidates. Search the catalog or add it manually.", de: "Keine bestätigbaren Kandidaten. Suche im Katalog oder füge sie manuell hinzu.")
        }
        if candidateCount < requiredCandidateCount {
            return l.tr(zh: "候选数量不足，不能直接写入档案；请手动确认或改用资料库搜索。", en: "Not enough candidates to write directly to the profile. Confirm manually or use catalog search.", de: "Nicht genug Kandidaten für das direkte Profil. Bitte manuell bestätigen oder die Katalogsuche nutzen.")
        }
        return l.tr(zh: "识别结果仍可能出错；请确认正确物种后再写入植物档案。", en: "Recognition can still be wrong. Confirm the correct species before saving it to the plant profile.", de: "Die Erkennung kann trotzdem falsch sein. Bestätige die richtige Art, bevor sie im Pflanzenprofil gespeichert wird.")
    }

    private static func basicCare(from entry: PlantCatalogEntry?) -> String {
        guard let entry else { return "" }
        return "\(entry.lightRequirement.displayName) · \(entry.localizedWateringPreference)"
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
            uncertaintyMessage: L10n.current.tr(
                zh: "当前版本未连接植物识别服务。请使用资料库搜索或手动添加；Ohana 不会伪造识别结果。",
                en: "Plant recognition is not connected in this version. Use catalog search or add manually; Ohana will not fake recognition results.",
                de: "Die Pflanzenerkennung ist in dieser Version nicht verbunden. Nutze die Katalogsuche oder füge manuell hinzu; Ohana erzeugt keine falschen Erkennungsergebnisse."
            ),
            manualSearchSuggested: true
        )
    }

    func diagnosePlant(imageData _: Data?, symptoms: [String]) async -> PlantDiagnosisResult {
        let normalized = Set(symptoms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let l = L10n.current
        var causes: [PlantDiagnosisCause] = []
        if normalized.contains("虫子") || normalized.contains("白色斑点") {
            causes.append(PlantDiagnosisCause(
                id: "pests",
                title: l.tr(zh: "可能有虫害", en: "Possible pests", de: "Mögliche Schädlinge"),
                severity: l.tr(zh: "中等", en: "Medium", de: "Mittel"),
                steps: [
                    l.tr(zh: "先隔离植物", en: "Isolate the plant first", de: "Pflanze zuerst isolieren"),
                    l.tr(zh: "检查叶背、叶柄和土面", en: "Check leaf undersides, petioles, and soil surface", de: "Blattunterseiten, Blattstiele und Erdoberfläche prüfen"),
                    l.tr(zh: "用清水冲洗明显虫体", en: "Rinse visible pests with clean water", de: "Sichtbare Schädlinge mit klarem Wasser abspülen"),
                    l.tr(zh: "3-5 天后复查", en: "Recheck in 3-5 days", de: "In 3-5 Tagen erneut prüfen")
                ],
                shouldIsolate: true,
                recheckAfterDays: 4
            ))
        }
        if normalized.contains("根腐") || normalized.contains("发霉") || normalized.contains("掉叶") {
            causes.append(PlantDiagnosisCause(
                id: "overwatering",
                title: l.tr(zh: "可能过浇或根系缺氧", en: "Possible overwatering or low root oxygen", de: "Mögliche Überwässerung oder Sauerstoffmangel an den Wurzeln"),
                severity: l.tr(zh: "偏高", en: "Moderately high", de: "Eher hoch"),
                steps: [
                    l.tr(zh: "暂停浇水并检查盆底排水", en: "Pause watering and check pot drainage", de: "Gießen pausieren und Topfdrainage prüfen"),
                    l.tr(zh: "移到通风明亮处", en: "Move to a bright, ventilated spot", de: "An einen hellen, luftigen Standort stellen"),
                    l.tr(zh: "土壤持续潮湿时考虑换土", en: "Consider fresh soil if it stays wet", de: "Bei dauerhaft nasser Erde frische Erde erwägen"),
                    l.tr(zh: "2-3 天后复查", en: "Recheck in 2-3 days", de: "In 2-3 Tagen erneut prüfen")
                ],
                shouldIsolate: false,
                recheckAfterDays: 3
            ))
        }
        if normalized.contains("黄叶") || normalized.contains("叶尖发黑") || normalized.contains("叶片卷曲") || causes.isEmpty {
            causes.append(PlantDiagnosisCause(
                id: "stress",
                title: l.tr(zh: "可能是环境压力", en: "Possible environmental stress", de: "Möglicher Umgebungsstress"),
                severity: l.tr(zh: "轻中度", en: "Mild to medium", de: "Leicht bis mittel"),
                steps: [
                    l.tr(zh: "回顾最近是否搬动、暴晒、低温或漏浇", en: "Check for recent moves, harsh sun, cold, or missed watering", de: "Prüfe kürzliches Umstellen, starke Sonne, Kälte oder ausgelassenes Gießen"),
                    l.tr(zh: "保持一周稳定护理", en: "Keep care stable for one week", de: "Pflege eine Woche stabil halten"),
                    l.tr(zh: "只剪除完全枯黄叶片", en: "Only remove fully yellow or dry leaves", de: "Nur komplett gelbe oder trockene Blätter entfernen"),
                    l.tr(zh: "7 天后拍照对比", en: "Take a comparison photo after 7 days", de: "Nach 7 Tagen ein Vergleichsfoto machen")
                ],
                shouldIsolate: false,
                recheckAfterDays: 7
            ))
        }
        if causes.count < 2 {
            causes.append(PlantDiagnosisCause(
                id: "watering-rhythm",
                title: l.tr(zh: "可能是浇水节奏不稳定", en: "Possible inconsistent watering rhythm", de: "Möglicherweise unregelmäßiger Gießrhythmus"),
                severity: l.tr(zh: "轻中度", en: "Mild to medium", de: "Leicht bis mittel"),
                steps: [
                    l.tr(zh: "先记录盆土干湿和上次浇水时间", en: "Record soil moisture and the last watering time first", de: "Zuerst Erdfeuchte und letzte Gießzeit notieren"),
                    l.tr(zh: "避免少量频繁浇水", en: "Avoid tiny, frequent watering", de: "Häufiges Gießen in kleinen Mengen vermeiden"),
                    l.tr(zh: "下次浇透后等表土变干再浇", en: "Water thoroughly next time, then wait for the topsoil to dry", de: "Nächstes Mal gründlich gießen und warten, bis die Oberfläche trocken ist"),
                    l.tr(zh: "5-7 天后复查叶片", en: "Recheck leaves in 5-7 days", de: "Blätter in 5-7 Tagen erneut prüfen")
                ],
                shouldIsolate: false,
                recheckAfterDays: 6
            ))
        }
        if causes.count < 3 {
            causes.append(PlantDiagnosisCause(
                id: "light-mismatch",
                title: l.tr(zh: "可能是光照不匹配", en: "Possible light mismatch", de: "Möglicherweise unpassendes Licht"),
                severity: l.tr(zh: "轻度", en: "Mild", de: "Leicht"),
                steps: [
                    l.tr(zh: "避免突然从弱光搬到直晒", en: "Avoid sudden moves from low light to direct sun", de: "Nicht abrupt von wenig Licht in direkte Sonne stellen"),
                    l.tr(zh: "优先选择明亮散射光", en: "Prefer bright indirect light", de: "Helles indirektes Licht bevorzugen"),
                    l.tr(zh: "每周转盆一次观察新叶方向", en: "Rotate weekly and watch new leaf direction", de: "Wöchentlich drehen und Richtung neuer Blätter beobachten"),
                    l.tr(zh: "7 天后对比照片", en: "Compare photos after 7 days", de: "Nach 7 Tagen Fotos vergleichen")
                ],
                shouldIsolate: false,
                recheckAfterDays: 7
            ))
        }
        return PlantDiagnosisResult(
            uncertaintyMessage: l.tr(
                zh: "基础诊断不能替代专业判断；同一种症状可能来自浇水、光照、温度、虫害或土壤问题。",
                en: "Basic diagnosis is not professional advice. The same symptom can come from watering, light, temperature, pests, or soil.",
                de: "Die Basisdiagnose ersetzt keine fachliche Einschätzung. Dasselbe Symptom kann von Wasser, Licht, Temperatur, Schädlingen oder Erde kommen."
            ),
            causes: Array(causes.prefix(3))
        )
    }
}
