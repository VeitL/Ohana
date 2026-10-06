//
//  HumanHealthMetricEditCopy.swift
//  Ohana
//
//  Localized copy kept separate from the metric edit view's state and command orchestration.
//

import Foundation

nonisolated struct HumanHealthMetricEditCopy {
    let l: L10n

    var editTitle: String {
        l.tr(
            zh: "编辑指标", en: "Edit Metric", de: "Wert bearbeiten",
            es: "Editar métrica", pt: "Editar métrica", fr: "Modifier la mesure",
            ja: "指標を編集", ko: "지표 편집", it: "Modifica parametro"
        )
    }

    var saveTitle: String {
        l.tr(
            zh: "保存", en: "Save", de: "Speichern",
            es: "Guardar", pt: "Salvar", fr: "Enregistrer",
            ja: "保存", ko: "저장", it: "Salva"
        )
    }

    var valueTitle: String {
        l.tr(
            zh: "数值", en: "Value", de: "Wert",
            es: "Valor", pt: "Valor", fr: "Valeur",
            ja: "値", ko: "값", it: "Valore"
        )
    }

    var unitTitle: String {
        l.tr(
            zh: "单位", en: "Unit", de: "Einheit",
            es: "Unidad", pt: "Unidade", fr: "Unité",
            ja: "単位", ko: "단위", it: "Unità"
        )
    }

    var dateTitle: String {
        l.tr(
            zh: "日期与时间", en: "Date and Time", de: "Datum und Uhrzeit",
            es: "Fecha y hora", pt: "Data e hora", fr: "Date et heure",
            ja: "日時", ko: "날짜 및 시간", it: "Data e ora"
        )
    }

    var notesTitle: String {
        l.tr(
            zh: "备注", en: "Notes", de: "Notizen",
            es: "Notas", pt: "Observações", fr: "Notes",
            ja: "メモ", ko: "메모", it: "Note"
        )
    }

    var sourceTitle: String {
        l.tr(
            zh: "来源", en: "Source", de: "Quelle",
            es: "Origen", pt: "Origem", fr: "Source",
            ja: "出典", ko: "출처", it: "Fonte"
        )
    }

    var sourceItemTitle: String {
        l.tr(
            zh: "报告项目", en: "Report Item", de: "Berichtsposition",
            es: "Elemento del informe", pt: "Item do relatório", fr: "Élément du rapport",
            ja: "レポート項目", ko: "보고서 항목", it: "Voce del referto"
        )
    }

    var importedTitle: String {
        l.tr(
            zh: "来自已复核的化验单", en: "From a reviewed lab report", de: "Aus einem geprüften Laborbericht",
            es: "De un informe de laboratorio revisado", pt: "De um relatório laboratorial revisado", fr: "Issu d’un compte rendu de laboratoire vérifié",
            ja: "確認済みの検査報告書から", ko: "검토한 검사 보고서에서 가져옴", it: "Da un referto di laboratorio verificato"
        )
    }

    var provenanceMessage: String {
        l.tr(
            zh: "原报告、参考范围和录入人信息会继续保留；修正数值会清除原打印标记，并按参考范围重新判断。",
            en: "The original report, reference range, and recorder stay linked. Correcting the value clears the printed flag and re-evaluates it against the range.",
            de: "Originalbericht, Referenzbereich und erfassende Person bleiben verknüpft. Eine Wertkorrektur entfernt die gedruckte Markierung und bewertet anhand des Bereichs neu.",
            es: "El informe original, el rango de referencia y quien lo registró siguen vinculados. Corregir el valor borra la marca impresa y vuelve a evaluarlo según el rango.",
            pt: "O relatório original, o intervalo de referência e quem registrou continuam vinculados. Corrigir o valor apaga o indicador impresso e o reavalia pelo intervalo.",
            fr: "Le rapport d’origine, la plage de référence et la personne ayant saisi la donnée restent liés. Corriger la valeur efface l’indicateur imprimé et relance l’évaluation selon la plage.",
            ja: "元の報告書、基準範囲、入力者情報との関連は保持されます。値を修正すると印刷されたフラグが消去され、基準範囲で再評価されます。",
            ko: "원본 보고서, 참고 범위 및 기록자 정보의 연결은 유지됩니다. 값을 수정하면 인쇄된 플래그가 지워지고 참고 범위에 따라 다시 평가됩니다.",
            it: "Il referto originale, l’intervallo di riferimento e chi ha registrato il dato restano collegati. Correggere il valore cancella l’indicatore stampato e lo rivaluta rispetto all’intervallo."
        )
    }

    var saveFailureTitle: String {
        l.tr(
            zh: "未能保存指标", en: "Metric Not Saved", de: "Wert nicht gespeichert",
            es: "Métrica no guardada", pt: "Métrica não salva", fr: "Mesure non enregistrée",
            ja: "指標を保存できませんでした", ko: "지표를 저장하지 못함", it: "Parametro non salvato"
        )
    }

    var saveFailureMessage: String {
        l.tr(
            zh: "修改内容仍保留在此页面，请重试。",
            en: "Your changes remain on this screen. Try again.",
            de: "Deine Änderungen bleiben auf diesem Bildschirm. Versuche es erneut.",
            es: "Tus cambios permanecen en esta pantalla. Inténtalo de nuevo.",
            pt: "Suas alterações permanecem nesta tela. Tente novamente.",
            fr: "Vos modifications restent sur cet écran. Réessayez.",
            ja: "変更内容はこの画面に保持されています。もう一度お試しください。",
            ko: "변경 내용은 이 화면에 유지됩니다. 다시 시도하세요.",
            it: "Le modifiche restano in questa schermata. Riprova."
        )
    }

    var okTitle: String {
        l.tr(
            zh: "知道了", en: "OK", de: "OK",
            es: "Aceptar", pt: "OK", fr: "OK",
            ja: "OK", ko: "확인", it: "OK"
        )
    }
}
