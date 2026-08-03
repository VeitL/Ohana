//
//  HumanLabScanLocalization.swift
//  Ohana
//
//  Complete app-language copy for the on-device lab report scan and review flow.
//

import Foundation

nonisolated enum HumanLabScanCopy {
    enum Key: CaseIterable, Hashable, Sendable {
        case scanLabReport
        case checkupEntryDetail
        case reportEntryDetail
        case entryAccessibility
        case reportEmptyStateDetail
        case conclusionConflictTitle
        case reviewAgain
        case saveAsNormalAnyway
        case conclusionConflictMessage
        case processedOnDevice
        case recognizingStatus
        case reviewBeforeSaving
        case savingStatus
        case importCompleteStatus
        case retryStatus
        case save
        case retrySave
        case done
        case reviewSafetyDetail
        case truncationTitle
        case truncationDetail
        case chooseAnotherReport
        case saveFailureTitle
        case personalSaveFailure
        case genericSaveFailure
        case reportDetails
        case reportDate
        case conclusion
        case choose
        case conclusionRequiredDetail
        case normalConclusionWarning
        case hospitalOptional
        case hospitalName
        case doctorOptional
        case doctorName
        case summaryOptional
        case summaryPlaceholder
        case notesOptional
        case notesPlaceholder
        case recognizedResults
        case deselectAll
        case includeInImport
        case unmappedMetric
        case needsReview
        case openItemReview
        case noValue
        case normal
        case low
        case high
        case chooseReportSource
        case sourceGuidance
        case medicalDisclaimer
        case scanPaperReport
        case choosePhotos
        case choosePDF
        case privacyTitle
        case privacyDetail
        case recognizingTitle
        case recognizingDetail
        case cancelRecognition
        case recognitionFailureTitle
        case genericRecognitionFailure
        case pdfTooLarge
        case unreadablePDF
        case noReadablePages
        case noCandidates
        case truncatedWithoutCandidates
        case completedTitle
        case reviewResult
        case apply
        case originalLabel
        case metricLabel
        case recognizedRow
        case source
        case originalReport
        case metric
        case notMapped
        case valueQualifier
        case exact
        case lessThan
        case greaterThan
        case value
        case savedUnit
        case chooseUnit
        case originalUnit
        case metricAndValue
        case exactValueGuidance
        case reportRangeText
        case reportRangePlaceholder
        case lowerBound
        case upperBound
        case reportFlag
        case notMarked
        case reportReference
        case referenceDisclaimer
        case includeThisImport
        case includeRequirements
    }

    static func text(_ key: Key, l: L10n) -> String {
        l.text(resource(key))
    }

    static func resource(_ key: Key) -> AppLocalizedText {
        guard let resource = catalog[key] else {
            preconditionFailure("Missing lab scan localization resource: \(key)")
        }
        return resource
    }

    static var coverageResources: [AppLocalizedText] {
        Key.allCases.map(resource) + [
            sourcePageOnDevice(1),
            completedDetail(importedCount: 2),
            recognizedResultsSummary(pageCount: 2, selectedCount: 3, totalCount: 4),
            reportRange("0.4–4.0"),
            pageNumber(2),
            pageLimitExceeded(maximum: 6)
        ]
    }

    static func sourcePageOnDevice(_ pageNumber: Int) -> AppLocalizedText {
        AppLocalizedText(
            zh: "第 \(pageNumber) 页 · 本机识别", en: "Page \(pageNumber) · on-device", de: "Seite \(pageNumber) · auf dem Gerät",
            es: "Página \(pageNumber) · en el dispositivo", pt: "Página \(pageNumber) · no dispositivo", fr: "Page \(pageNumber) · sur l’appareil",
            ja: "\(pageNumber)ページ目 · デバイス上で認識", ko: "\(pageNumber)페이지 · 기기 내 인식", it: "Pagina \(pageNumber) · sul dispositivo"
        )
    }

    static func completedDetail(importedCount: Int) -> AppLocalizedText {
        AppLocalizedText(
            zh: "已原子保存 1 份报告和 \(importedCount) 项指标记录。现在可以在指标趋势中继续追踪。", en: "Saved 1 report and \(importedCount) metric records atomically. You can now follow them in metric trends.", de: "1 Bericht und \(importedCount) Messwerte wurden atomar gespeichert. Sie können nun in den Trends verfolgt werden.",
            es: "Se guardaron de forma atómica 1 informe y \(importedCount) registros de métricas. Ya puedes seguirlos en las tendencias.", pt: "Foram salvos atomicamente 1 relatório e \(importedCount) registros de métricas. Agora você pode acompanhá-los nas tendências.", fr: "1 rapport et \(importedCount) mesures ont été enregistrés de façon atomique. Vous pouvez maintenant les suivre dans les tendances.",
            ja: "1件の報告書と\(importedCount)件の指標記録を一括保存しました。指標の推移で引き続き確認できます。", ko: "보고서 1개와 지표 기록 \(importedCount)개를 원자적으로 저장했습니다. 이제 지표 추세에서 계속 확인할 수 있습니다.", it: "Sono stati salvati atomicamente 1 referto e \(importedCount) valori. Ora puoi seguirli nelle tendenze."
        )
    }

    static func recognizedResultsSummary(
        pageCount: Int,
        selectedCount: Int,
        totalCount: Int
    ) -> AppLocalizedText {
        AppLocalizedText(
            zh: "\(pageCount) 页 · 已选择 \(selectedCount) / \(totalCount) 项", en: "\(pageCount) pages · \(selectedCount) of \(totalCount) selected", de: "\(pageCount) Seiten · \(selectedCount) von \(totalCount) ausgewählt",
            es: "\(pageCount) páginas · \(selectedCount) de \(totalCount) seleccionados", pt: "\(pageCount) páginas · \(selectedCount) de \(totalCount) selecionados", fr: "\(pageCount) pages · \(selectedCount) sur \(totalCount) sélectionnés",
            ja: "\(pageCount)ページ · \(totalCount)件中\(selectedCount)件を選択", ko: "\(pageCount)페이지 · \(totalCount)개 중 \(selectedCount)개 선택", it: "\(pageCount) pagine · \(selectedCount) di \(totalCount) selezionati"
        )
    }

    static func reportRange(_ reference: String) -> AppLocalizedText {
        AppLocalizedText(
            zh: "报告参考范围：\(reference)", en: "Report range: \(reference)", de: "Berichtsbereich: \(reference)",
            es: "Intervalo del informe: \(reference)", pt: "Faixa do relatório: \(reference)", fr: "Intervalle du rapport : \(reference)",
            ja: "報告書の基準範囲：\(reference)", ko: "보고서 참고 범위: \(reference)", it: "Intervallo del referto: \(reference)"
        )
    }

    static func pageNumber(_ pageNumber: Int) -> AppLocalizedText {
        AppLocalizedText(
            zh: "第 \(pageNumber) 页", en: "Page \(pageNumber)", de: "Seite \(pageNumber)",
            es: "Página \(pageNumber)", pt: "Página \(pageNumber)", fr: "Page \(pageNumber)",
            ja: "\(pageNumber)ページ目", ko: "\(pageNumber)페이지", it: "Pagina \(pageNumber)"
        )
    }

    static func pageLimitExceeded(maximum: Int) -> AppLocalizedText {
        AppLocalizedText(
            zh: "这份报告超过 \(maximum) 页。为避免静默漏页，请拆成不超过 \(maximum) 页的小批次后重新扫描。", en: "This report has more than \(maximum) pages. To avoid silently missing pages, scan it again in batches of no more than \(maximum).", de: "Dieser Bericht hat mehr als \(maximum) Seiten. Bitte erneut in Abschnitten mit höchstens \(maximum) Seiten scannen.",
            es: "Este informe tiene más de \(maximum) páginas. Para evitar omitir páginas sin aviso, vuelve a escanearlo en lotes de hasta \(maximum).", pt: "Este relatório tem mais de \(maximum) páginas. Para evitar páginas omitidas sem aviso, digitalize-o novamente em lotes de até \(maximum).", fr: "Ce rapport compte plus de \(maximum) pages. Pour éviter toute page manquante, scannez-le à nouveau par lots de \(maximum) pages maximum.",
            ja: "この報告書は\(maximum)ページを超えています。ページの取りこぼしを防ぐため、\(maximum)ページ以下のまとまりに分けて再スキャンしてください。", ko: "이 보고서는 \(maximum)페이지를 초과합니다. 페이지 누락을 방지하려면 \(maximum)페이지 이하로 나누어 다시 스캔하세요.", it: "Questo referto supera \(maximum) pagine. Per evitare pagine mancanti, scansionalo di nuovo in gruppi di massimo \(maximum) pagine."
        )
    }

    private static let catalog: [Key: AppLocalizedText] = [
        .scanLabReport: AppLocalizedText(
            zh: "扫描化验单", en: "Scan Lab Report", de: "Laborbericht scannen",
            es: "Escanear informe de laboratorio", pt: "Digitalizar relatório laboratorial", fr: "Scanner un rapport de laboratoire",
            ja: "検査報告書をスキャン", ko: "검사 보고서 스캔", it: "Scansiona referto di laboratorio"
        ),
        .checkupEntryDetail: AppLocalizedText(
            zh: "本机识别后逐项核对，再批量保存", en: "Recognize on device, review each item, then save together", de: "Auf dem Gerät erkennen, einzeln prüfen und gemeinsam speichern",
            es: "Reconoce en el dispositivo, revisa cada elemento y guarda todo junto", pt: "Reconheça no dispositivo, revise cada item e salve tudo junto", fr: "Reconnaissez sur l’appareil, vérifiez chaque élément, puis enregistrez le tout",
            ja: "デバイス上で認識し、項目ごとに確認してからまとめて保存", ko: "기기에서 인식하고 항목별로 검토한 뒤 한 번에 저장", it: "Riconosci sul dispositivo, verifica ogni voce e salva tutto insieme"
        ),
        .reportEntryDetail: AppLocalizedText(
            zh: "原始照片仅在本机识别；只保存你逐项确认的结构化结果", en: "Source photos are recognized only on device; only structured results you confirm item by item are saved", de: "Quellfotos werden nur auf dem Gerät erkannt; gespeichert werden nur einzeln bestätigte strukturierte Ergebnisse",
            es: "Las fotos originales se reconocen solo en el dispositivo; solo se guardan los resultados estructurados que confirmes uno por uno", pt: "As fotos originais são reconhecidas somente no dispositivo; apenas resultados estruturados confirmados item a item são salvos", fr: "Les photos sources sont reconnues uniquement sur l’appareil ; seuls les résultats structurés confirmés un par un sont enregistrés",
            ja: "元の写真はデバイス上でのみ認識され、項目ごとに確認した構造化結果だけが保存されます", ko: "원본 사진은 기기에서만 인식되며 항목별로 확인한 구조화된 결과만 저장됩니다", it: "Le foto originali vengono riconosciute solo sul dispositivo; vengono salvati soltanto i risultati strutturati confermati uno per uno"
        ),
        .entryAccessibility: AppLocalizedText(
            zh: "扫描化验单，本机识别并逐项复核", en: "Scan a lab report, recognize on device, and review each item", de: "Laborbericht scannen, auf dem Gerät erkennen und einzeln prüfen",
            es: "Escanear un informe de laboratorio, reconocerlo en el dispositivo y revisar cada elemento", pt: "Digitalizar um relatório laboratorial, reconhecer no dispositivo e revisar cada item", fr: "Scanner un rapport de laboratoire, le reconnaître sur l’appareil et vérifier chaque élément",
            ja: "検査報告書をスキャンし、デバイス上で認識して項目ごとに確認", ko: "검사 보고서를 스캔하고 기기에서 인식한 뒤 항목별로 검토", it: "Scansiona un referto, riconoscilo sul dispositivo e verifica ogni voce"
        ),
        .reportEmptyStateDetail: AppLocalizedText(
            zh: "可以本机扫描化验单，或手动添加第一条检测报告。", en: "Scan a lab report on device or add the first report manually.", de: "Scanne einen Laborbericht auf dem Gerät oder füge den ersten Bericht manuell hinzu.",
            es: "Escanea un informe de laboratorio en el dispositivo o añade el primer informe manualmente.", pt: "Digitalize um relatório laboratorial no dispositivo ou adicione o primeiro relatório manualmente.", fr: "Scannez un rapport de laboratoire sur l’appareil ou ajoutez le premier rapport manuellement.",
            ja: "デバイス上で検査報告書をスキャンするか、最初の報告書を手動で追加できます。", ko: "기기에서 검사 보고서를 스캔하거나 첫 보고서를 직접 추가할 수 있습니다.", it: "Scansiona un referto sul dispositivo o aggiungi manualmente il primo referto."
        ),
        .conclusionConflictTitle: AppLocalizedText(
            zh: "报告结论与结果标记不一致", en: "Conclusion conflicts with result flags", de: "Ergebnis widerspricht den Messwert-Markierungen",
            es: "La conclusión no coincide con las marcas de los resultados", pt: "A conclusão não corresponde às marcações dos resultados", fr: "La conclusion ne correspond pas aux indicateurs des résultats",
            ja: "報告書の結論と結果の印が一致しません", ko: "보고서 결론과 결과 표시가 일치하지 않습니다", it: "La conclusione non corrisponde agli indicatori dei risultati"
        ),
        .reviewAgain: AppLocalizedText(
            zh: "返回复核", en: "Review Again", de: "Erneut prüfen",
            es: "Revisar de nuevo", pt: "Revisar novamente", fr: "Vérifier à nouveau",
            ja: "再確認", ko: "다시 검토", it: "Verifica di nuovo"
        ),
        .saveAsNormalAnyway: AppLocalizedText(
            zh: "仍按正常保存", en: "Save as Normal Anyway", de: "Trotzdem als normal speichern",
            es: "Guardar como normal de todos modos", pt: "Salvar como normal mesmo assim", fr: "Enregistrer quand même comme normal",
            ja: "それでも正常として保存", ko: "그래도 정상으로 저장", it: "Salva comunque come normale"
        ),
        .conclusionConflictMessage: AppLocalizedText(
            zh: "已选择的项目包含报告印刷的偏高或偏低标记。Ohana 不会替你判断整份报告结论；仅当你已对照原报告确认时，才继续按“正常”保存。", en: "Selected items include printed high or low flags. Ohana cannot decide the report's overall conclusion; continue as Normal only after checking the original report.", de: "Ausgewählte Werte enthalten gedruckte Hoch- oder Niedrig-Markierungen. Ohana kann das Gesamtergebnis nicht beurteilen; nur nach Prüfung des Originals als normal speichern.",
            es: "Los elementos seleccionados incluyen marcas impresas de valor alto o bajo. Ohana no puede decidir la conclusión general; continúa como Normal solo tras comprobar el informe original.", pt: "Os itens selecionados incluem marcações impressas de valor alto ou baixo. O Ohana não pode decidir a conclusão geral; continue como Normal somente após conferir o relatório original.", fr: "Les éléments sélectionnés comportent des indicateurs imprimés de valeur haute ou basse. Ohana ne peut pas déterminer la conclusion globale ; continuez comme Normal uniquement après vérification du rapport original.",
            ja: "選択した項目には、報告書に印刷された高値または低値の印があります。Ohanaは報告書全体の結論を判断できません。原本と照合した場合のみ「正常」として続行してください。", ko: "선택한 항목에 보고서에 인쇄된 높음 또는 낮음 표시가 있습니다. Ohana는 보고서 전체 결론을 판단할 수 없습니다. 원본 보고서를 확인한 경우에만 정상으로 계속 저장하세요.", it: "Le voci selezionate includono indicatori stampati di valore alto o basso. Ohana non può stabilire la conclusione complessiva; continua come Normale solo dopo aver verificato il referto originale."
        ),
        .processedOnDevice: AppLocalizedText(
            zh: "全程本机处理", en: "Processed on device", de: "Verarbeitung auf dem Gerät",
            es: "Procesado en el dispositivo", pt: "Processado no dispositivo", fr: "Traité sur l’appareil",
            ja: "すべてデバイス上で処理", ko: "모두 기기에서 처리", it: "Elaborato sul dispositivo"
        ),
        .recognizingStatus: AppLocalizedText(
            zh: "正在识别", en: "Recognizing", de: "Erkennung läuft",
            es: "Reconociendo", pt: "Reconhecendo", fr: "Reconnaissance en cours",
            ja: "認識中", ko: "인식 중", it: "Riconoscimento in corso"
        ),
        .reviewBeforeSaving: AppLocalizedText(
            zh: "逐项核对后保存", en: "Review before saving", de: "Vor dem Speichern prüfen",
            es: "Revisar antes de guardar", pt: "Revisar antes de salvar", fr: "Vérifier avant d’enregistrer",
            ja: "保存前に項目を確認", ko: "저장 전 항목 검토", it: "Verifica prima di salvare"
        ),
        .savingStatus: AppLocalizedText(
            zh: "正在保存", en: "Saving", de: "Wird gespeichert",
            es: "Guardando", pt: "Salvando", fr: "Enregistrement en cours",
            ja: "保存中", ko: "저장 중", it: "Salvataggio in corso"
        ),
        .importCompleteStatus: AppLocalizedText(
            zh: "导入完成", en: "Import complete", de: "Import abgeschlossen",
            es: "Importación completada", pt: "Importação concluída", fr: "Importation terminée",
            ja: "インポート完了", ko: "가져오기 완료", it: "Importazione completata"
        ),
        .retryStatus: AppLocalizedText(
            zh: "需要重试", en: "Try again", de: "Erneut versuchen",
            es: "Volver a intentarlo", pt: "Tentar novamente", fr: "Réessayer",
            ja: "再試行が必要です", ko: "다시 시도해 주세요", it: "Riprova"
        ),
        .save: AppLocalizedText(
            zh: "保存", en: "Save", de: "Speichern",
            es: "Guardar", pt: "Salvar", fr: "Enregistrer",
            ja: "保存", ko: "저장", it: "Salva"
        ),
        .retrySave: AppLocalizedText(
            zh: "重试保存", en: "Retry Save", de: "Erneut speichern",
            es: "Reintentar guardado", pt: "Tentar salvar novamente", fr: "Réessayer l’enregistrement",
            ja: "保存を再試行", ko: "저장 다시 시도", it: "Riprova a salvare"
        ),
        .done: AppLocalizedText(
            zh: "完成", en: "Done", de: "Fertig",
            es: "Listo", pt: "Concluído", fr: "Terminé",
            ja: "完了", ko: "완료", it: "Fine"
        ),
        .reviewSafetyDetail: AppLocalizedText(
            zh: "请逐项对照原报告。低置信度、未映射或带“< / >”的结果不会自动保存。", en: "Check every item against the original. Low-confidence, unmapped, or “< / >” results are not saved automatically.", de: "Jeden Wert mit dem Original abgleichen. Unsichere, nicht zugeordnete oder mit „< / >“ versehene Ergebnisse werden nicht automatisch gespeichert.",
            es: "Comprueba cada elemento con el original. Los resultados con baja confianza, sin asignar o con “< / >” no se guardan automáticamente.", pt: "Confira cada item com o original. Resultados de baixa confiança, não mapeados ou com “< / >” não são salvos automaticamente.", fr: "Vérifiez chaque élément avec l’original. Les résultats peu fiables, non associés ou comportant « < / > » ne sont pas enregistrés automatiquement.",
            ja: "各項目を原本と照合してください。信頼度が低い、未対応、または「< / >」付きの結果は自動保存されません。", ko: "각 항목을 원본과 대조하세요. 신뢰도가 낮거나 매핑되지 않았거나 ‘< / >’가 있는 결과는 자동 저장되지 않습니다.", it: "Confronta ogni voce con l’originale. I risultati poco affidabili, non associati o con “< / >” non vengono salvati automaticamente."
        ),
        .truncationTitle: AppLocalizedText(
            zh: "识别结果不完整，已阻止保存", en: "Recognition is incomplete; saving is blocked", de: "Erkennung ist unvollständig; Speichern ist gesperrt",
            es: "El reconocimiento está incompleto; no se puede guardar", pt: "O reconhecimento está incompleto; o salvamento foi bloqueado", fr: "La reconnaissance est incomplète ; l’enregistrement est bloqué",
            ja: "認識結果が不完全なため保存できません", ko: "인식 결과가 불완전하여 저장이 차단되었습니다", it: "Il riconoscimento è incompleto; il salvataggio è bloccato"
        ),
        .truncationDetail: AppLocalizedText(
            zh: "报告超过本次可安全复核的行数或项目数。请把报告拆成更小批次重新扫描，避免遗漏指标。", en: "The report exceeded the rows or results that can be reviewed safely in one batch. Scan it again in smaller batches to avoid missing metrics.", de: "Der Bericht überschreitet die sicher prüfbare Anzahl an Zeilen oder Werten. Bitte in kleineren Abschnitten erneut scannen.",
            es: "El informe supera el número de filas o resultados que se pueden revisar con seguridad de una vez. Vuelve a escanearlo en lotes más pequeños para no omitir métricas.", pt: "O relatório excede o número de linhas ou resultados que podem ser revisados com segurança de uma vez. Digitalize-o novamente em lotes menores para não omitir métricas.", fr: "Le rapport dépasse le nombre de lignes ou de résultats pouvant être vérifiés en toute sécurité en une fois. Scannez-le à nouveau par lots plus petits pour éviter d’omettre des mesures.",
            ja: "報告書が1回で安全に確認できる行数または項目数を超えています。指標の見落としを防ぐため、小分けにして再スキャンしてください。", ko: "보고서가 한 번에 안전하게 검토할 수 있는 행 또는 결과 수를 초과했습니다. 지표 누락을 방지하려면 더 작은 묶음으로 다시 스캔하세요.", it: "Il referto supera il numero di righe o risultati verificabili in sicurezza in una volta. Scansionalo di nuovo in gruppi più piccoli per non tralasciare valori."
        ),
        .chooseAnotherReport: AppLocalizedText(
            zh: "重新选择报告", en: "Choose Another Report", de: "Anderen Bericht wählen",
            es: "Elegir otro informe", pt: "Escolher outro relatório", fr: "Choisir un autre rapport",
            ja: "別の報告書を選択", ko: "다른 보고서 선택", it: "Scegli un altro referto"
        ),
        .saveFailureTitle: AppLocalizedText(
            zh: "保存失败，复核内容已保留", en: "Save failed; review kept", de: "Speichern fehlgeschlagen; Prüfung bleibt erhalten",
            es: "No se pudo guardar; se conservó la revisión", pt: "Falha ao salvar; a revisão foi mantida", fr: "Échec de l’enregistrement ; la vérification est conservée",
            ja: "保存できませんでした。確認内容は保持されています", ko: "저장에 실패했지만 검토 내용은 유지되었습니다", it: "Salvataggio non riuscito; la verifica è stata conservata"
        ),
        .personalSaveFailure: AppLocalizedText(
            zh: "需要 Ohana Personal 才能保存扫描结果；复核内容仍会保留。", en: "Ohana Personal is required to save scanned results. Your review is still preserved.", de: "Zum Speichern gescannter Ergebnisse ist Ohana Personal erforderlich. Deine Prüfung bleibt erhalten.",
            es: "Se necesita Ohana Personal para guardar resultados escaneados. Tu revisión se conserva.", pt: "É necessário o Ohana Personal para salvar resultados digitalizados. Sua revisão será mantida.", fr: "Ohana Personal est requis pour enregistrer les résultats scannés. Votre vérification reste conservée.",
            ja: "スキャン結果を保存するには Ohana Personal が必要です。確認内容は保持されます。", ko: "스캔 결과를 저장하려면 Ohana Personal이 필요합니다. 검토 내용은 그대로 유지됩니다.", it: "Ohana Personal è necessario per salvare i risultati scansionati. La revisione resta conservata."
        ),
        .genericSaveFailure: AppLocalizedText(
            zh: "请检查内容后重试。不会产生部分导入记录。", en: "Review the content and try again. No partial import was created.", de: "Inhalte prüfen und erneut versuchen. Es wurde kein Teilimport erstellt.",
            es: "Revisa el contenido e inténtalo de nuevo. No se creó una importación parcial.", pt: "Revise o conteúdo e tente novamente. Nenhuma importação parcial foi criada.", fr: "Vérifiez le contenu et réessayez. Aucune importation partielle n’a été créée.",
            ja: "内容を確認して再試行してください。一部だけがインポートされることはありません。", ko: "내용을 확인한 후 다시 시도하세요. 일부만 가져온 기록은 생성되지 않았습니다.", it: "Controlla il contenuto e riprova. Non è stata creata alcuna importazione parziale."
        ),
        .reportDetails: AppLocalizedText(
            zh: "报告信息", en: "Report Details", de: "Berichtsdetails",
            es: "Detalles del informe", pt: "Detalhes do relatório", fr: "Détails du rapport",
            ja: "報告書情報", ko: "보고서 정보", it: "Dettagli del referto"
        ),
        .reportDate: AppLocalizedText(
            zh: "检测日期", en: "Report Date", de: "Berichtsdatum",
            es: "Fecha del informe", pt: "Data do relatório", fr: "Date du rapport",
            ja: "検査日", ko: "검사 날짜", it: "Data del referto"
        ),
        .conclusion: AppLocalizedText(
            zh: "报告结论", en: "Conclusion", de: "Ergebnis",
            es: "Conclusión", pt: "Conclusão", fr: "Conclusion",
            ja: "報告書の結論", ko: "보고서 결론", it: "Conclusione"
        ),
        .choose: AppLocalizedText(
            zh: "请选择", en: "Choose", de: "Auswählen",
            es: "Seleccionar", pt: "Selecionar", fr: "Choisir",
            ja: "選択", ko: "선택", it: "Scegli"
        ),
        .conclusionRequiredDetail: AppLocalizedText(
            zh: "请对照原报告，明确选择整份报告的结论后再保存。", en: "Check the original and explicitly choose the report conclusion before saving.", de: "Original prüfen und das Gesamtergebnis vor dem Speichern ausdrücklich auswählen.",
            es: "Comprueba el original y elige explícitamente la conclusión del informe antes de guardar.", pt: "Confira o original e escolha explicitamente a conclusão do relatório antes de salvar.", fr: "Vérifiez l’original et choisissez explicitement la conclusion du rapport avant d’enregistrer.",
            ja: "原本と照合し、報告書全体の結論を明確に選択してから保存してください。", ko: "원본을 확인하고 보고서 전체 결론을 명확히 선택한 후 저장하세요.", it: "Controlla l’originale e scegli esplicitamente la conclusione del referto prima di salvare."
        ),
        .normalConclusionWarning: AppLocalizedText(
            zh: "已选项目含偏高或偏低标记；若结论仍为正常，保存时需要再次确认。", en: "Selected items include high or low flags; saving a Normal conclusion requires confirmation.", de: "Ausgewählte Werte enthalten Hoch-/Niedrig-Markierungen; „Normal“ muss beim Speichern bestätigt werden.",
            es: "Los elementos seleccionados incluyen marcas altas o bajas; guardar una conclusión Normal requiere confirmación.", pt: "Os itens selecionados incluem marcações altas ou baixas; salvar uma conclusão Normal exige confirmação.", fr: "Les éléments sélectionnés comportent des indicateurs hauts ou bas ; enregistrer une conclusion Normale nécessite une confirmation.",
            ja: "選択項目に高値または低値の印があります。結論を「正常」として保存するには確認が必要です。", ko: "선택한 항목에 높음 또는 낮음 표시가 있습니다. 결론을 정상으로 저장하려면 확인이 필요합니다.", it: "Le voci selezionate includono indicatori alti o bassi; salvare una conclusione Normale richiede conferma."
        ),
        .hospitalOptional: AppLocalizedText(
            zh: "医院（可选）", en: "Hospital (optional)", de: "Klinik (optional)",
            es: "Centro médico (opcional)", pt: "Hospital (opcional)", fr: "Établissement (facultatif)",
            ja: "医療機関（任意）", ko: "병원(선택 사항)", it: "Struttura sanitaria (facoltativa)"
        ),
        .hospitalName: AppLocalizedText(
            zh: "医院名称", en: "Hospital name", de: "Name der Klinik",
            es: "Nombre del centro", pt: "Nome do hospital", fr: "Nom de l’établissement",
            ja: "医療機関名", ko: "병원 이름", it: "Nome della struttura"
        ),
        .doctorOptional: AppLocalizedText(
            zh: "医生（可选）", en: "Doctor (optional)", de: "Ärztin/Arzt (optional)",
            es: "Profesional médico (opcional)", pt: "Profissional de saúde (opcional)", fr: "Médecin (facultatif)",
            ja: "医師（任意）", ko: "의사(선택 사항)", it: "Medico (facoltativo)"
        ),
        .doctorName: AppLocalizedText(
            zh: "医生姓名", en: "Doctor name", de: "Name",
            es: "Nombre del profesional", pt: "Nome do profissional", fr: "Nom du médecin",
            ja: "医師名", ko: "의사 이름", it: "Nome del medico"
        ),
        .summaryOptional: AppLocalizedText(
            zh: "报告摘要（可选）", en: "Summary (optional)", de: "Zusammenfassung (optional)",
            es: "Resumen (opcional)", pt: "Resumo (opcional)", fr: "Résumé (facultatif)",
            ja: "報告書の要約（任意）", ko: "보고서 요약(선택 사항)", it: "Riepilogo (facoltativo)"
        ),
        .summaryPlaceholder: AppLocalizedText(
            zh: "只保存你确认的摘要", en: "Only your confirmed summary is saved", de: "Nur die bestätigte Zusammenfassung wird gespeichert",
            es: "Solo se guarda el resumen que confirmes", pt: "Somente o resumo confirmado por você será salvo", fr: "Seul le résumé que vous confirmez est enregistré",
            ja: "確認した要約だけが保存されます", ko: "확인한 요약만 저장됩니다", it: "Viene salvato solo il riepilogo che confermi"
        ),
        .notesOptional: AppLocalizedText(
            zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)",
            es: "Notas (opcional)", pt: "Observações (opcional)", fr: "Notes (facultatif)",
            ja: "メモ（任意）", ko: "메모(선택 사항)", it: "Note (facoltative)"
        ),
        .notesPlaceholder: AppLocalizedText(
            zh: "仅保存在本机", en: "Saved only on this device", de: "Nur auf diesem Gerät gespeichert",
            es: "Se guarda solo en este dispositivo", pt: "Salvo somente neste dispositivo", fr: "Enregistré uniquement sur cet appareil",
            ja: "このデバイスにのみ保存", ko: "이 기기에만 저장", it: "Salvato solo su questo dispositivo"
        ),
        .recognizedResults: AppLocalizedText(
            zh: "识别结果", en: "Recognized Results", de: "Erkannte Ergebnisse",
            es: "Resultados reconocidos", pt: "Resultados reconhecidos", fr: "Résultats reconnus",
            ja: "認識結果", ko: "인식 결과", it: "Risultati riconosciuti"
        ),
        .deselectAll: AppLocalizedText(
            zh: "取消全选", en: "Deselect All", de: "Alle abwählen",
            es: "Deseleccionar todo", pt: "Desmarcar tudo", fr: "Tout désélectionner",
            ja: "すべて選択解除", ko: "모두 선택 해제", it: "Deseleziona tutto"
        ),
        .includeInImport: AppLocalizedText(
            zh: "纳入导入", en: "Include in import", de: "In Import aufnehmen",
            es: "Incluir en la importación", pt: "Incluir na importação", fr: "Inclure dans l’importation",
            ja: "インポートに含める", ko: "가져오기에 포함", it: "Includi nell’importazione"
        ),
        .unmappedMetric: AppLocalizedText(
            zh: "未映射指标", en: "Unmapped metric", de: "Nicht zugeordneter Wert",
            es: "Métrica sin asignar", pt: "Métrica não mapeada", fr: "Mesure non associée",
            ja: "未対応の指標", ko: "매핑되지 않은 지표", it: "Valore non associato"
        ),
        .needsReview: AppLocalizedText(
            zh: "需复核", en: "Review", de: "Prüfen",
            es: "Revisar", pt: "Revisar", fr: "À vérifier",
            ja: "要確認", ko: "검토 필요", it: "Da verificare"
        ),
        .openItemReview: AppLocalizedText(
            zh: "打开逐项复核编辑", en: "Opens item review", de: "Öffnet die Einzelprüfung",
            es: "Abre la revisión del elemento", pt: "Abre a revisão do item", fr: "Ouvre la vérification de l’élément",
            ja: "項目の確認画面を開きます", ko: "항목 검토 화면을 엽니다", it: "Apre la verifica della voce"
        ),
        .noValue: AppLocalizedText(
            zh: "未识别数值", en: "No value", de: "Kein Wert",
            es: "Sin valor", pt: "Sem valor", fr: "Aucune valeur",
            ja: "値を認識できません", ko: "인식된 값 없음", it: "Nessun valore"
        ),
        .normal: AppLocalizedText(
            zh: "正常", en: "Normal", de: "Normal",
            es: "Normal", pt: "Normal", fr: "Normal",
            ja: "正常", ko: "정상", it: "Normale"
        ),
        .low: AppLocalizedText(
            zh: "偏低", en: "Low", de: "Niedrig",
            es: "Bajo", pt: "Baixo", fr: "Bas",
            ja: "低値", ko: "낮음", it: "Basso"
        ),
        .high: AppLocalizedText(
            zh: "偏高", en: "High", de: "Hoch",
            es: "Alto", pt: "Alto", fr: "Élevé",
            ja: "高値", ko: "높음", it: "Alto"
        ),
        .chooseReportSource: AppLocalizedText(
            zh: "选择报告来源", en: "Choose a report source", de: "Quelle des Berichts wählen",
            es: "Elige el origen del informe", pt: "Escolha a origem do relatório", fr: "Choisissez la source du rapport",
            ja: "報告書の取り込み元を選択", ko: "보고서 출처 선택", it: "Scegli l’origine del referto"
        ),
        .sourceGuidance: AppLocalizedText(
            zh: "最多 6 页。请使用完整清晰的 PDF，或让表格完整入镜、避免反光，并保留原报告用于核对。", en: "Up to 6 pages. Use a complete, clear PDF or keep the table in frame without glare, and retain the original for review.", de: "Bis zu 6 Seiten. Eine vollständige, klare PDF verwenden oder die Tabelle ohne Spiegelungen ganz aufnehmen und das Original zum Prüfen behalten.",
            es: "Hasta 6 páginas. Usa un PDF completo y nítido o encuadra toda la tabla sin reflejos, y conserva el original para revisarlo.", pt: "Até 6 páginas. Use um PDF completo e nítido ou enquadre toda a tabela sem reflexos, e guarde o original para conferência.", fr: "Jusqu’à 6 pages. Utilisez un PDF complet et net ou cadrez tout le tableau sans reflet, et conservez l’original pour vérification.",
            ja: "最大6ページです。完全で鮮明なPDFを使用するか、表全体を反射なく撮影し、照合用に原本を保管してください。", ko: "최대 6페이지입니다. 완전하고 선명한 PDF를 사용하거나 표 전체를 빛 반사 없이 촬영하고 검토를 위해 원본을 보관하세요.", it: "Fino a 6 pagine. Usa un PDF completo e nitido oppure inquadra tutta la tabella senza riflessi, e conserva l’originale per la verifica."
        ),
        .medicalDisclaimer: AppLocalizedText(
            zh: "识别只辅助录入，不提供诊断，也不能替代原始报告、医生解读或紧急医疗判断。", en: "Recognition only assists data entry. It does not diagnose or replace the original report, professional interpretation, or urgent medical judgment.", de: "Die Erkennung hilft nur bei der Eingabe. Sie ersetzt weder Diagnose noch Originalbericht, fachliche Einordnung oder medizinische Notfallbeurteilung.",
            es: "El reconocimiento solo ayuda a introducir datos. No diagnostica ni sustituye el informe original, la interpretación profesional o una valoración médica urgente.", pt: "O reconhecimento apenas auxilia a entrada de dados. Ele não diagnostica nem substitui o relatório original, a interpretação profissional ou uma avaliação médica urgente.", fr: "La reconnaissance aide uniquement à saisir les données. Elle ne pose aucun diagnostic et ne remplace ni le rapport original, ni l’interprétation d’un professionnel, ni un avis médical urgent.",
            ja: "認識機能は入力を補助するだけで、診断は行いません。原本、医療専門家の説明、緊急時の医学的判断に代わるものではありません。", ko: "인식 기능은 데이터 입력만 돕습니다. 진단을 제공하지 않으며 원본 보고서, 전문가 해석 또는 긴급 의료 판단을 대신할 수 없습니다.", it: "Il riconoscimento assiste solo l’inserimento dei dati. Non formula diagnosi e non sostituisce il referto originale, l’interpretazione professionale o una valutazione medica urgente."
        ),
        .scanPaperReport: AppLocalizedText(
            zh: "拍摄纸质报告", en: "Scan Paper Report", de: "Papierbericht scannen",
            es: "Escanear informe en papel", pt: "Digitalizar relatório em papel", fr: "Scanner le rapport papier",
            ja: "紙の報告書をスキャン", ko: "종이 보고서 스캔", it: "Scansiona referto cartaceo"
        ),
        .choosePhotos: AppLocalizedText(
            zh: "从照片选择", en: "Choose Photos", de: "Fotos auswählen",
            es: "Elegir fotos", pt: "Escolher fotos", fr: "Choisir des photos",
            ja: "写真から選択", ko: "사진 선택", it: "Scegli foto"
        ),
        .choosePDF: AppLocalizedText(
            zh: "选择 PDF", en: "Choose PDF", de: "PDF auswählen",
            es: "Elegir PDF", pt: "Escolher PDF", fr: "Choisir un PDF",
            ja: "PDFを選択", ko: "PDF 선택", it: "Scegli PDF"
        ),
        .privacyTitle: AppLocalizedText(
            zh: "PDF、照片与文字不会上传", en: "PDFs, photos, and text are not uploaded", de: "PDFs, Fotos und Text werden nicht hochgeladen",
            es: "Los PDF, las fotos y el texto no se suben", pt: "PDFs, fotos e textos não são enviados", fr: "Les PDF, les photos et le texte ne sont pas téléversés",
            ja: "PDF、写真、テキストはアップロードされません", ko: "PDF, 사진과 텍스트는 업로드되지 않습니다", it: "PDF, foto e testo non vengono caricati"
        ),
        .privacyDetail: AppLocalizedText(
            zh: "Ohana 在此设备上完成识别；确认或取消后会释放原始页面与完整识别文本。", en: "Ohana recognizes the report on this device and releases source pages and full recognized text after confirmation or cancellation.", de: "Ohana erkennt den Bericht auf diesem Gerät und verwirft Quellseiten sowie den vollständigen Erkennungstext nach Bestätigung oder Abbruch.",
            es: "Ohana reconoce el informe en este dispositivo y libera las páginas originales y todo el texto reconocido tras confirmar o cancelar.", pt: "O Ohana reconhece o relatório neste dispositivo e libera as páginas originais e todo o texto reconhecido após confirmar ou cancelar.", fr: "Ohana reconnaît le rapport sur cet appareil et libère les pages sources ainsi que l’intégralité du texte reconnu après confirmation ou annulation.",
            ja: "Ohanaはこのデバイス上で報告書を認識し、確定またはキャンセル後に元のページと認識された全文を破棄します。", ko: "Ohana는 이 기기에서 보고서를 인식하며 확인하거나 취소한 뒤 원본 페이지와 전체 인식 텍스트를 해제합니다.", it: "Ohana riconosce il referto su questo dispositivo e rilascia le pagine originali e l’intero testo riconosciuto dopo la conferma o l’annullamento."
        ),
        .recognizingTitle: AppLocalizedText(
            zh: "正在本机识别报告", en: "Recognizing on this device", de: "Erkennung auf diesem Gerät",
            es: "Reconociendo en este dispositivo", pt: "Reconhecendo neste dispositivo", fr: "Reconnaissance sur cet appareil",
            ja: "このデバイスで報告書を認識中", ko: "이 기기에서 보고서 인식 중", it: "Riconoscimento su questo dispositivo"
        ),
        .recognizingDetail: AppLocalizedText(
            zh: "正在查找指标、数值、单位和报告参考范围。多页报告可能需要一点时间。", en: "Looking for metrics, values, units, and the report's reference ranges. Multi-page reports may take a moment.", de: "Messwerte, Einheiten und Referenzbereiche werden gesucht. Mehrseitige Berichte können etwas dauern.",
            es: "Buscando métricas, valores, unidades e intervalos de referencia del informe. Los informes de varias páginas pueden tardar un poco.", pt: "Buscando métricas, valores, unidades e faixas de referência do relatório. Relatórios com várias páginas podem levar um momento.", fr: "Recherche des mesures, valeurs, unités et intervalles de référence du rapport. Les rapports de plusieurs pages peuvent prendre un moment.",
            ja: "指標、値、単位、報告書の基準範囲を探しています。複数ページの報告書には少し時間がかかる場合があります。", ko: "지표, 값, 단위와 보고서 참고 범위를 찾고 있습니다. 여러 페이지인 보고서는 시간이 조금 걸릴 수 있습니다.", it: "Ricerca di valori, unità e intervalli di riferimento del referto. I referti di più pagine possono richiedere qualche istante."
        ),
        .cancelRecognition: AppLocalizedText(
            zh: "取消识别", en: "Cancel Recognition", de: "Erkennung abbrechen",
            es: "Cancelar reconocimiento", pt: "Cancelar reconhecimento", fr: "Annuler la reconnaissance",
            ja: "認識をキャンセル", ko: "인식 취소", it: "Annulla riconoscimento"
        ),
        .recognitionFailureTitle: AppLocalizedText(
            zh: "没有得到可复核的结果", en: "No reviewable results found", de: "Keine prüfbaren Ergebnisse gefunden",
            es: "No se encontraron resultados revisables", pt: "Nenhum resultado revisável foi encontrado", fr: "Aucun résultat vérifiable trouvé",
            ja: "確認可能な結果が見つかりませんでした", ko: "검토할 수 있는 결과를 찾지 못했습니다", it: "Nessun risultato verificabile trovato"
        ),
        .genericRecognitionFailure: AppLocalizedText(
            zh: "请换一张更清晰、表格完整且没有反光的照片后重试。", en: "Try again with a clearer photo that shows the complete table without glare.", de: "Mit einem klareren Foto ohne Spiegelungen und mit vollständiger Tabelle erneut versuchen.",
            es: "Inténtalo de nuevo con una foto más nítida que muestre toda la tabla sin reflejos.", pt: "Tente novamente com uma foto mais nítida que mostre a tabela completa sem reflexos.", fr: "Réessayez avec une photo plus nette montrant tout le tableau sans reflet.",
            ja: "表全体が反射なく写った、より鮮明な写真で再試行してください。", ko: "표 전체가 빛 반사 없이 보이는 더 선명한 사진으로 다시 시도하세요.", it: "Riprova con una foto più nitida che mostri tutta la tabella senza riflessi."
        ),
        .pdfTooLarge: AppLocalizedText(
            zh: "这份 PDF 过大或页面过于复杂，无法安全地在本机处理。请拆分为较小且不超过 6 页的 PDF 后重试。", en: "This PDF is too large or detailed to process safely on this device. Split it into a smaller PDF of no more than 6 pages and try again.", de: "Diese PDF ist zu groß oder zu komplex für eine sichere Verarbeitung auf diesem Gerät. Bitte in eine kleinere PDF mit höchstens 6 Seiten aufteilen und erneut versuchen.",
            es: "Este PDF es demasiado grande o detallado para procesarlo con seguridad en este dispositivo. Divídelo en un PDF más pequeño de hasta 6 páginas y vuelve a intentarlo.", pt: "Este PDF é grande ou detalhado demais para ser processado com segurança neste dispositivo. Divida-o em um PDF menor, com até 6 páginas, e tente novamente.", fr: "Ce PDF est trop volumineux ou détaillé pour être traité en toute sécurité sur cet appareil. Divisez-le en un PDF plus petit de 6 pages maximum et réessayez.",
            ja: "このPDFは大きすぎるか複雑すぎるため、このデバイスで安全に処理できません。6ページ以下の小さなPDFに分割して再試行してください。", ko: "이 PDF는 너무 크거나 복잡하여 이 기기에서 안전하게 처리할 수 없습니다. 6페이지 이하의 더 작은 PDF로 나누어 다시 시도하세요.", it: "Questo PDF è troppo grande o dettagliato per essere elaborato in sicurezza sul dispositivo. Dividilo in un PDF più piccolo di massimo 6 pagine e riprova."
        ),
        .unreadablePDF: AppLocalizedText(
            zh: "无法读取或渲染这份 PDF。请确认文件没有加密或损坏，然后重试。", en: "This PDF could not be read or rendered. Make sure it is not encrypted or damaged, then try again.", de: "Diese PDF konnte nicht gelesen oder gerendert werden. Bitte sicherstellen, dass sie nicht verschlüsselt oder beschädigt ist, und erneut versuchen.",
            es: "No se pudo leer o representar este PDF. Comprueba que no esté cifrado ni dañado y vuelve a intentarlo.", pt: "Não foi possível ler ou renderizar este PDF. Verifique se ele não está criptografado ou danificado e tente novamente.", fr: "Ce PDF n’a pas pu être lu ou rendu. Vérifiez qu’il n’est ni chiffré ni endommagé, puis réessayez.",
            ja: "このPDFを読み取るか描画できませんでした。暗号化または破損していないことを確認して、再試行してください。", ko: "이 PDF를 읽거나 렌더링할 수 없습니다. 암호화되거나 손상되지 않았는지 확인한 뒤 다시 시도하세요.", it: "Non è stato possibile leggere o renderizzare questo PDF. Verifica che non sia cifrato o danneggiato e riprova."
        ),
        .noReadablePages: AppLocalizedText(
            zh: "扫描内容中没有可读取的页面。请重新拍摄，并确保页面完整清晰。", en: "The scan did not contain a readable page. Scan it again with the full page in focus.", de: "Der Scan enthielt keine lesbare Seite. Bitte erneut scannen und die ganze Seite scharf aufnehmen.",
            es: "El escaneo no contenía ninguna página legible. Vuelve a escanear con la página completa enfocada.", pt: "A digitalização não continha uma página legível. Digitalize novamente com a página inteira em foco.", fr: "Le scan ne contenait aucune page lisible. Recommencez en cadrant nettement toute la page.",
            ja: "読み取れるページがありませんでした。ページ全体にピントを合わせて再スキャンしてください。", ko: "스캔에 읽을 수 있는 페이지가 없습니다. 페이지 전체에 초점을 맞춰 다시 스캔하세요.", it: "La scansione non conteneva pagine leggibili. Scansiona di nuovo mettendo a fuoco l’intera pagina."
        ),
        .noCandidates: AppLocalizedText(
            zh: "没有找到支持的化验结果行。请确认照片包含清晰完整的结果表格。", en: "No supported lab result rows were found. Make sure the photo clearly shows the complete results table.", de: "Es wurden keine unterstützten Laborwerte gefunden. Bitte die vollständige Ergebnistabelle klar fotografieren.",
            es: "No se encontraron filas de resultados compatibles. Asegúrate de que la foto muestre claramente toda la tabla de resultados.", pt: "Nenhuma linha de resultado compatível foi encontrada. Verifique se a foto mostra claramente a tabela de resultados completa.", fr: "Aucune ligne de résultat prise en charge n’a été trouvée. Vérifiez que la photo montre clairement tout le tableau de résultats.",
            ja: "対応する検査結果の行が見つかりませんでした。結果表全体が鮮明に写っていることを確認してください。", ko: "지원되는 검사 결과 행을 찾지 못했습니다. 사진에 전체 결과 표가 선명하게 보이는지 확인하세요.", it: "Non sono state trovate righe di risultati supportate. Assicurati che la foto mostri chiaramente l’intera tabella dei risultati."
        ),
        .truncatedWithoutCandidates: AppLocalizedText(
            zh: "报告在确认支持的结果前已超过安全复核上限。请拆成更小批次后重新扫描。", en: "The report exceeded the safe review limit before a supported result could be confirmed. Scan it again in smaller batches.", de: "Der Bericht überschritt die sichere Prüfgrenze, bevor ein unterstützter Wert bestätigt werden konnte. Bitte in kleineren Abschnitten erneut scannen.",
            es: "El informe superó el límite de revisión segura antes de poder confirmar un resultado compatible. Vuelve a escanearlo en lotes más pequeños.", pt: "O relatório excedeu o limite de revisão segura antes que um resultado compatível pudesse ser confirmado. Digitalize-o novamente em lotes menores.", fr: "Le rapport a dépassé la limite de vérification sûre avant qu’un résultat pris en charge puisse être confirmé. Scannez-le à nouveau par lots plus petits.",
            ja: "対応する結果を確認できる前に、安全な確認上限を超えました。小分けにして再スキャンしてください。", ko: "지원되는 결과를 확인하기 전에 보고서가 안전 검토 한도를 초과했습니다. 더 작은 묶음으로 다시 스캔하세요.", it: "Il referto ha superato il limite di verifica sicura prima di poter confermare un risultato supportato. Scansionalo di nuovo in gruppi più piccoli."
        ),
        .completedTitle: AppLocalizedText(
            zh: "化验结果已保存", en: "Lab results saved", de: "Laborwerte gespeichert",
            es: "Resultados de laboratorio guardados", pt: "Resultados laboratoriais salvos", fr: "Résultats de laboratoire enregistrés",
            ja: "検査結果を保存しました", ko: "검사 결과를 저장했습니다", it: "Risultati di laboratorio salvati"
        ),
        .reviewResult: AppLocalizedText(
            zh: "复核指标", en: "Review Result", de: "Ergebnis prüfen",
            es: "Revisar resultado", pt: "Revisar resultado", fr: "Vérifier le résultat",
            ja: "結果を確認", ko: "결과 검토", it: "Verifica risultato"
        ),
        .apply: AppLocalizedText(
            zh: "应用", en: "Apply", de: "Übernehmen",
            es: "Aplicar", pt: "Aplicar", fr: "Appliquer",
            ja: "適用", ko: "적용", it: "Applica"
        ),
        .originalLabel: AppLocalizedText(
            zh: "原报告名称", en: "Original label", de: "Originalbezeichnung",
            es: "Etiqueta original", pt: "Rótulo original", fr: "Libellé d’origine",
            ja: "報告書の元の名称", ko: "보고서 원래 이름", it: "Etichetta originale"
        ),
        .metricLabel: AppLocalizedText(
            zh: "指标名称", en: "Metric label", de: "Messwertbezeichnung",
            es: "Nombre de la métrica", pt: "Nome da métrica", fr: "Nom de la mesure",
            ja: "指標名", ko: "지표 이름", it: "Nome del valore"
        ),
        .recognizedRow: AppLocalizedText(
            zh: "识别原文", en: "Recognized row", de: "Erkannte Zeile",
            es: "Fila reconocida", pt: "Linha reconhecida", fr: "Ligne reconnue",
            ja: "認識した原文", ko: "인식된 원문", it: "Riga riconosciuta"
        ),
        .source: AppLocalizedText(
            zh: "来源", en: "Source", de: "Quelle",
            es: "Origen", pt: "Origem", fr: "Source",
            ja: "出典", ko: "출처", it: "Origine"
        ),
        .originalReport: AppLocalizedText(
            zh: "原报告", en: "Original Report", de: "Originalbericht",
            es: "Informe original", pt: "Relatório original", fr: "Rapport original",
            ja: "元の報告書", ko: "원본 보고서", it: "Referto originale"
        ),
        .metric: AppLocalizedText(
            zh: "对应指标", en: "Metric", de: "Messwert",
            es: "Métrica", pt: "Métrica", fr: "Mesure",
            ja: "対応する指標", ko: "해당 지표", it: "Valore"
        ),
        .notMapped: AppLocalizedText(
            zh: "尚未映射", en: "Not mapped", de: "Nicht zugeordnet",
            es: "Sin asignar", pt: "Não mapeado", fr: "Non associé",
            ja: "未対応", ko: "매핑되지 않음", it: "Non associato"
        ),
        .valueQualifier: AppLocalizedText(
            zh: "数值关系", en: "Value qualifier", de: "Wertbeziehung",
            es: "Relación del valor", pt: "Relação do valor", fr: "Relation de la valeur",
            ja: "値の関係", ko: "값 관계", it: "Relazione del valore"
        ),
        .exact: AppLocalizedText(
            zh: "精确值", en: "Exact", de: "Exakter Wert",
            es: "Exacto", pt: "Exato", fr: "Exacte",
            ja: "正確な値", ko: "정확한 값", it: "Esatto"
        ),
        .lessThan: AppLocalizedText(
            zh: "小于（<）", en: "Less than (<)", de: "Kleiner als (<)",
            es: "Menor que (<)", pt: "Menor que (<)", fr: "Inférieur à (<)",
            ja: "未満（<）", ko: "미만(<)", it: "Minore di (<)"
        ),
        .greaterThan: AppLocalizedText(
            zh: "大于（>）", en: "Greater than (>)", de: "Größer als (>)",
            es: "Mayor que (>)", pt: "Maior que (>)", fr: "Supérieur à (>)",
            ja: "超（>）", ko: "초과(>)", it: "Maggiore di (>)"
        ),
        .value: AppLocalizedText(
            zh: "数值", en: "Value", de: "Wert",
            es: "Valor", pt: "Valor", fr: "Valeur",
            ja: "値", ko: "값", it: "Valore"
        ),
        .savedUnit: AppLocalizedText(
            zh: "保存单位", en: "Saved unit", de: "Gespeicherte Einheit",
            es: "Unidad guardada", pt: "Unidade salva", fr: "Unité enregistrée",
            ja: "保存する単位", ko: "저장 단위", it: "Unità salvata"
        ),
        .chooseUnit: AppLocalizedText(
            zh: "选择单位", en: "Choose unit", de: "Einheit wählen",
            es: "Elegir unidad", pt: "Escolher unidade", fr: "Choisir l’unité",
            ja: "単位を選択", ko: "단위 선택", it: "Scegli unità"
        ),
        .originalUnit: AppLocalizedText(
            zh: "报告原单位", en: "Original unit", de: "Originaleinheit",
            es: "Unidad original", pt: "Unidade original", fr: "Unité d’origine",
            ja: "報告書の元の単位", ko: "보고서 원래 단위", it: "Unità originale"
        ),
        .metricAndValue: AppLocalizedText(
            zh: "指标与数值", en: "Metric and Value", de: "Messwert und Wert",
            es: "Métrica y valor", pt: "Métrica e valor", fr: "Mesure et valeur",
            ja: "指標と値", ko: "지표와 값", it: "Valore e misura"
        ),
        .exactValueGuidance: AppLocalizedText(
            zh: "趋势记录只能保存你核对过的精确值。“< / >”边界值会保持未选择，除非你依据原报告确认并改为精确值。", en: "Trends require an exact value you verified. “< / >” limits remain unselected unless you confirm an exact value from the original.", de: "Trends benötigen einen bestätigten exakten Wert. „< / >“-Grenzen bleiben abgewählt, bis ein exakter Wert aus dem Original bestätigt wurde.",
            es: "Las tendencias requieren un valor exacto que hayas verificado. Los límites “< / >” permanecen sin seleccionar hasta que confirmes un valor exacto en el original.", pt: "As tendências exigem um valor exato conferido por você. Limites “< / >” permanecem desmarcados até você confirmar um valor exato no original.", fr: "Les tendances exigent une valeur exacte que vous avez vérifiée. Les limites « < / > » restent désélectionnées tant que vous n’avez pas confirmé une valeur exacte dans l’original.",
            ja: "推移には確認済みの正確な値が必要です。「< / >」の境界値は、原本で正確な値を確認して変更するまで選択されません。", ko: "추세 기록에는 확인한 정확한 값이 필요합니다. ‘< / >’ 경계값은 원본에서 정확한 값을 확인해 변경하기 전까지 선택되지 않습니다.", it: "Le tendenze richiedono un valore esatto verificato. I limiti “< / >” restano deselezionati finché non confermi un valore esatto dall’originale."
        ),
        .reportRangeText: AppLocalizedText(
            zh: "报告参考范围原文", en: "Report range text", de: "Referenzbereich im Bericht",
            es: "Texto del intervalo del informe", pt: "Texto da faixa do relatório", fr: "Texte de l’intervalle du rapport",
            ja: "報告書の基準範囲（原文）", ko: "보고서 참고 범위 원문", it: "Testo dell’intervallo nel referto"
        ),
        .reportRangePlaceholder: AppLocalizedText(
            zh: "如 0.4–4.0", en: "e.g. 0.4–4.0", de: "z. B. 0,4–4,0",
            es: "p. ej., 0,4–4,0", pt: "ex.: 0,4–4,0", fr: "p. ex. 0,4–4,0",
            ja: "例：0.4〜4.0", ko: "예: 0.4~4.0", it: "es. 0,4–4,0"
        ),
        .lowerBound: AppLocalizedText(
            zh: "下限", en: "Low", de: "Untergrenze",
            es: "Límite inferior", pt: "Limite inferior", fr: "Limite basse",
            ja: "下限", ko: "하한", it: "Limite inferiore"
        ),
        .upperBound: AppLocalizedText(
            zh: "上限", en: "High", de: "Obergrenze",
            es: "Límite superior", pt: "Limite superior", fr: "Limite haute",
            ja: "上限", ko: "상한", it: "Limite superiore"
        ),
        .reportFlag: AppLocalizedText(
            zh: "报告标记", en: "Report flag", de: "Berichtsmarkierung",
            es: "Marca del informe", pt: "Marcação do relatório", fr: "Indicateur du rapport",
            ja: "報告書の印", ko: "보고서 표시", it: "Indicatore del referto"
        ),
        .notMarked: AppLocalizedText(
            zh: "未标记", en: "Not marked", de: "Nicht markiert",
            es: "Sin marcar", pt: "Não marcado", fr: "Non indiqué",
            ja: "印なし", ko: "표시 없음", it: "Non indicato"
        ),
        .reportReference: AppLocalizedText(
            zh: "报告参考", en: "Report Reference", de: "Berichtsreferenz",
            es: "Referencia del informe", pt: "Referência do relatório", fr: "Référence du rapport",
            ja: "報告書の基準", ko: "보고서 참고 정보", it: "Riferimenti del referto"
        ),
        .referenceDisclaimer: AppLocalizedText(
            zh: "参考范围因实验室、检测方法和个人情况而异；这里保留报告值，不作诊断。", en: "Ranges vary by laboratory, method, and individual context. These fields preserve the report and do not diagnose.", de: "Referenzbereiche variieren je nach Labor, Methode und Person. Diese Felder bewahren den Bericht und stellen keine Diagnose dar.",
            es: "Los intervalos varían según el laboratorio, el método y la situación individual. Estos campos conservan el informe y no ofrecen un diagnóstico.", pt: "As faixas variam conforme o laboratório, o método e o contexto individual. Estes campos preservam o relatório e não fazem diagnóstico.", fr: "Les intervalles varient selon le laboratoire, la méthode et la situation individuelle. Ces champs conservent les données du rapport et ne posent aucun diagnostic.",
            ja: "基準範囲は検査機関、方法、個人の状況によって異なります。ここでは報告書の値を保持するだけで、診断は行いません。", ko: "참고 범위는 검사실, 검사 방법과 개인 상황에 따라 다릅니다. 이 필드는 보고서 값을 보존할 뿐 진단하지 않습니다.", it: "Gli intervalli variano in base a laboratorio, metodo e situazione individuale. Questi campi conservano i dati del referto e non formulano diagnosi."
        ),
        .includeThisImport: AppLocalizedText(
            zh: "纳入本次导入", en: "Include in this import", de: "In diesen Import aufnehmen",
            es: "Incluir en esta importación", pt: "Incluir nesta importação", fr: "Inclure dans cette importation",
            ja: "今回のインポートに含める", ko: "이번 가져오기에 포함", it: "Includi in questa importazione"
        ),
        .includeRequirements: AppLocalizedText(
            zh: "选择目录指标、有效精确值和匹配单位后才可纳入。", en: "Choose a catalog metric, valid exact value, and matching unit before including it.", de: "Vor der Aufnahme Messwert, gültigen exakten Wert und passende Einheit wählen.",
            es: "Elige una métrica del catálogo, un valor exacto válido y una unidad compatible antes de incluirla.", pt: "Escolha uma métrica do catálogo, um valor exato válido e uma unidade compatível antes de incluir.", fr: "Choisissez une mesure du catalogue, une valeur exacte valide et une unité correspondante avant de l’inclure.",
            ja: "カタログの指標、有効な正確値、一致する単位を選択すると含められます。", ko: "카탈로그 지표, 유효한 정확한 값과 일치하는 단위를 선택해야 포함할 수 있습니다.", it: "Scegli un valore del catalogo, un dato esatto valido e un’unità compatibile prima di includerlo."
        )
    ]
}

nonisolated enum HumanLabImportFailureCopy {
    static func recognition(_ error: Error, l: L10n) -> String {
        if let imageError = error as? HumanLabImagePageProcessingError {
            switch imageError {
            case .noReadablePages, .unreadablePage:
                return HumanLabScanCopy.text(.noReadablePages, l: l)
            case let .pageLimitExceeded(maximum):
                return l.text(HumanLabScanCopy.pageLimitExceeded(maximum: maximum))
            case .sourceTooLarge, .normalizedOutputTooLarge:
                return HumanLabScanCopy.text(.genericRecognitionFailure, l: l)
            }
        }
        if let cameraError = error as? HumanLabDocumentCameraError {
            switch cameraError {
            case .noReadablePages:
                return HumanLabScanCopy.text(.noReadablePages, l: l)
            case let .pageLimitExceeded(maximum):
                return l.text(HumanLabScanCopy.pageLimitExceeded(maximum: maximum))
            }
        }
        if let recognitionError = error as? HumanLabImportRecognitionError {
            switch recognitionError {
            case .noCandidates:
                return HumanLabScanCopy.text(.noCandidates, l: l)
            case .truncatedWithoutCandidates:
                return HumanLabScanCopy.text(.truncatedWithoutCandidates, l: l)
            }
        }
        if let pdfError = error as? HumanLabPDFPageLoadingError {
            switch pdfError {
            case let .pageLimitExceeded(maximum):
                return l.text(HumanLabScanCopy.pageLimitExceeded(maximum: maximum))
            case .fileTooLarge, .renderedOutputTooLarge:
                return HumanLabScanCopy.text(.pdfTooLarge, l: l)
            case .unreadableFile, .noReadablePages, .pageRenderingFailed:
                return HumanLabScanCopy.text(.unreadablePDF, l: l)
            }
        }
        return HumanLabScanCopy.text(.genericRecognitionFailure, l: l)
    }

    static func saving(_ description: String?, l: L10n) -> String {
        if description == "personal.documentScanning.required" {
            return HumanLabScanCopy.text(.personalSaveFailure, l: l)
        }
        return HumanLabScanCopy.text(.genericSaveFailure, l: l)
    }
}
