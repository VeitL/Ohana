//
//  HumanLabScanCatalogLocalization.swift
//  Ohana
//
//  Scan-scoped names for catalogs shown while reviewing recognized results.
//

import Foundation

@MainActor
enum HumanLabScanCatalogCopy {
    static func categoryName(_ category: HealthMetricCategory, l: L10n) -> String {
        guard let resource = categoryResources[category.rawValue] else {
            assertionFailure("Missing lab scan category localization: \(category.rawValue)")
            return category.displayName(l)
        }
        return l.text(resource)
    }

    static func metricName(_ metric: HealthMetric, l: L10n) -> String {
        guard let resource = metricResources[metric.key] else {
            assertionFailure("Missing lab scan metric localization: \(metric.key)")
            return metric.displayName(l)
        }
        return l.text(resource)
    }

    static func conclusionTitle(_ conclusion: ReportConclusion, l: L10n) -> String {
        l.text(conclusionResources[conclusion]!)
    }

    static var coverageResources: [AppLocalizedText] {
        Array(categoryResources.values)
            + Array(metricResources.values)
            + Array(conclusionResources.values)
    }

    static var currentCatalogIsFullyCovered: Bool {
        Set(categoryResources.keys) == Set(HealthMetricCategory.allCases.map(\.rawValue))
            && Set(metricResources.keys) == Set(HealthMetricCatalog.all.map(\.key))
            && Set(conclusionResources.keys) == Set(ReportConclusion.allCases)
    }

    private static let categoryResources: [String: AppLocalizedText] = [
        "thyroid": AppLocalizedText(
            zh: "甲状腺", en: "Thyroid", de: "Schilddrüse",
            es: "Tiroides", pt: "Tireoide", fr: "Thyroïde",
            ja: "甲状腺", ko: "갑상선", it: "Tiroide"
        ),
        "glucose": AppLocalizedText(
            zh: "血糖", en: "Glucose", de: "Blutzucker",
            es: "Glucosa", pt: "Glicose", fr: "Glycémie",
            ja: "血糖", ko: "혈당", it: "Glicemia"
        ),
        "lipid": AppLocalizedText(
            zh: "血脂", en: "Lipids", de: "Blutfette",
            es: "Lípidos", pt: "Lipídios", fr: "Lipides",
            ja: "脂質", ko: "지질", it: "Lipidi"
        ),
        "liver": AppLocalizedText(
            zh: "肝功能", en: "Liver", de: "Leber",
            es: "Hígado", pt: "Fígado", fr: "Foie",
            ja: "肝機能", ko: "간 기능", it: "Fegato"
        ),
        "kidney": AppLocalizedText(
            zh: "肾功能", en: "Kidney", de: "Niere",
            es: "Riñón", pt: "Rim", fr: "Reins",
            ja: "腎機能", ko: "신장 기능", it: "Rene"
        ),
        "blood_count": AppLocalizedText(
            zh: "血常规", en: "Blood Count", de: "Blutbild",
            es: "Hemograma", pt: "Hemograma", fr: "Numération sanguine",
            ja: "血球検査", ko: "혈구 검사", it: "Emocromo"
        ),
        "inflammation_vitamin": AppLocalizedText(
            zh: "炎症与维生素", en: "Inflammation & Vitamins", de: "Entzündung & Vitamine",
            es: "Inflamación y vitaminas", pt: "Inflamação e vitaminas", fr: "Inflammation et vitamines",
            ja: "炎症・ビタミン", ko: "염증 및 비타민", it: "Infiammazione e vitamine"
        ),
        "electrolyte": AppLocalizedText(
            zh: "电解质", en: "Electrolytes", de: "Elektrolyte",
            es: "Electrolitos", pt: "Eletrólitos", fr: "Électrolytes",
            ja: "電解質", ko: "전해질", it: "Elettroliti"
        ),
        "vitals": AppLocalizedText(
            zh: "生命体征", en: "Vitals", de: "Vitalwerte",
            es: "Signos vitales", pt: "Sinais vitais", fr: "Signes vitaux",
            ja: "バイタルサイン", ko: "활력 징후", it: "Parametri vitali"
        )
    ]

    private static let conclusionResources: [ReportConclusion: AppLocalizedText] = [
        .normal: AppLocalizedText(
            zh: "正常", en: "Normal", de: "Normal",
            es: "Normal", pt: "Normal", fr: "Normal",
            ja: "正常", ko: "정상", it: "Normale"
        ),
        .attention: AppLocalizedText(
            zh: "注意", en: "Watch", de: "Beachten",
            es: "Atención", pt: "Atenção", fr: "À surveiller",
            ja: "要注意", ko: "주의", it: "Attenzione"
        ),
        .abnormal: AppLocalizedText(
            zh: "异常", en: "Abnormal", de: "Auffällig",
            es: "Anormal", pt: "Anormal", fr: "Anormal",
            ja: "異常", ko: "이상", it: "Anomalo"
        ),
        .critical: AppLocalizedText(
            zh: "危急", en: "Critical", de: "Kritisch",
            es: "Crítico", pt: "Crítico", fr: "Critique",
            ja: "緊急", ko: "위급", it: "Critico"
        )
    ]

    private static let metricResources: [String: AppLocalizedText] = {
        var resources = curatedMetricResources
        for catalogMetric in HealthMetricCatalog.all
        where standardizedFallbackMetricKeys.contains(catalogMetric.key) {
            resources[catalogMetric.key] = metric(
                zh: catalogMetric.nameZh,
                en: catalogMetric.nameEn,
                de: catalogMetric.nameDe,
                es: catalogMetric.nameEn,
                pt: catalogMetric.nameEn,
                fr: catalogMetric.nameEn,
                ja: catalogMetric.nameEn,
                ko: catalogMetric.nameEn,
                it: catalogMetric.nameEn
            )
        }
        return resources
    }()

    /// Explicit allowlist for standardized laboratory names added with the
    /// multi-column importer. Chinese, English, and German are authored; the
    /// remaining registered languages use the internationally recognizable
    /// scientific name until professional terminology review replaces it.
    private static let standardizedFallbackMetricKeys: Set<String> = [
        "glucose", "ldh", "alp", "amylase", "total_protein", "urea",
        "quick", "inr", "aptt", "hct", "mcv", "mch", "mchc", "rdw_cv", "rdw_sd", "mpv",
        "neut_pct", "neut_abs", "lymph_pct", "lymph_abs", "mono_pct", "mono_abs",
        "eos_pct", "eos_abs", "baso_pct", "baso_abs",
        "b_cells_abs", "b_cells_pct", "t_cells_abs", "t_cells_pct",
        "cd4_abs", "cd4_pct", "cd8_abs", "cd8_pct", "nk_cells_abs", "nk_cells_pct",
        "cytotoxic_t_cells_abs", "cytotoxic_t_cells_pct",
        "activated_t_cells_abs", "activated_t_cells_pct", "cd4_cd8_ratio", "hiv_rna"
    ]

    private static let curatedMetricResources: [String: AppLocalizedText] = [
        "tsh": metric(
            zh: "促甲状腺激素", en: "TSH", de: "TSH",
            es: "TSH", pt: "TSH", fr: "TSH", ja: "TSH", ko: "TSH", it: "TSH"
        ),
        "ft4": metric(
            zh: "游离 T4", en: "Free T4", de: "Freies T4",
            es: "T4 libre", pt: "T4 livre", fr: "T4 libre", ja: "遊離 T4", ko: "유리 T4", it: "T4 libero"
        ),
        "ft3": metric(
            zh: "游离 T3", en: "Free T3", de: "Freies T3",
            es: "T3 libre", pt: "T3 livre", fr: "T3 libre", ja: "遊離 T3", ko: "유리 T3", it: "T3 libero"
        ),
        "tpo_ab": metric(
            zh: "TPO 抗体", en: "TPO Antibody", de: "TPO-Antikörper",
            es: "Anticuerpos anti-TPO", pt: "Anticorpos anti-TPO", fr: "Anticorps anti-TPO", ja: "TPO 抗体", ko: "TPO 항체", it: "Anticorpi anti-TPO"
        ),
        "fbg": metric(
            zh: "空腹血糖", en: "Fasting Glucose", de: "Nüchternblutzucker",
            es: "Glucosa en ayunas", pt: "Glicose em jejum", fr: "Glycémie à jeun", ja: "空腹時血糖", ko: "공복 혈당", it: "Glicemia a digiuno"
        ),
        "ppg2h": metric(
            zh: "餐后 2h 血糖", en: "Postprandial 2h Glucose", de: "2h-Blutzucker postprandial",
            es: "Glucosa 2 h posprandial", pt: "Glicose 2 h pós-prandial", fr: "Glycémie 2 h postprandiale", ja: "食後 2 時間血糖", ko: "식후 2시간 혈당", it: "Glicemia 2 h postprandiale"
        ),
        "hba1c": metric(
            zh: "糖化血红蛋白", en: "HbA1c", de: "HbA1c",
            es: "Hemoglobina glucosilada (HbA1c)", pt: "Hemoglobina glicada (HbA1c)", fr: "Hémoglobine glyquée (HbA1c)", ja: "ヘモグロビン A1c", ko: "당화혈색소(HbA1c)", it: "Emoglobina glicata (HbA1c)"
        ),
        "fasting_insulin": metric(
            zh: "空腹胰岛素", en: "Fasting Insulin", de: "Nüchterninsulin",
            es: "Insulina en ayunas", pt: "Insulina em jejum", fr: "Insuline à jeun", ja: "空腹時インスリン", ko: "공복 인슐린", it: "Insulina a digiuno"
        ),
        "tc": metric(
            zh: "总胆固醇", en: "Total Cholesterol", de: "Gesamtcholesterin",
            es: "Colesterol total", pt: "Colesterol total", fr: "Cholestérol total", ja: "総コレステロール", ko: "총 콜레스테롤", it: "Colesterolo totale"
        ),
        "tg": metric(
            zh: "甘油三酯", en: "Triglycerides", de: "Triglyceride",
            es: "Triglicéridos", pt: "Triglicerídeos", fr: "Triglycérides", ja: "中性脂肪", ko: "중성지방", it: "Trigliceridi"
        ),
        "hdl": metric(
            zh: "高密度脂蛋白 HDL-C", en: "HDL-C", de: "HDL-C",
            es: "HDL-C", pt: "HDL-C", fr: "HDL-C", ja: "HDL-C", ko: "HDL-C", it: "HDL-C"
        ),
        "ldl": metric(
            zh: "低密度脂蛋白 LDL-C", en: "LDL-C", de: "LDL-C",
            es: "LDL-C", pt: "LDL-C", fr: "LDL-C", ja: "LDL-C", ko: "LDL-C", it: "LDL-C"
        ),
        "alt": metric(
            zh: "谷丙转氨酶 ALT", en: "ALT", de: "ALT (GPT)",
            es: "ALT (GPT)", pt: "ALT (TGP)", fr: "ALAT", ja: "ALT（GPT）", ko: "ALT(GPT)", it: "ALT (GPT)"
        ),
        "ast": metric(
            zh: "谷草转氨酶 AST", en: "AST", de: "AST (GOT)",
            es: "AST (GOT)", pt: "AST (TGO)", fr: "ASAT", ja: "AST（GOT）", ko: "AST(GOT)", it: "AST (GOT)"
        ),
        "ggt": metric(
            zh: "谷氨酰转肽酶 GGT", en: "GGT", de: "GGT",
            es: "GGT", pt: "GGT", fr: "GGT", ja: "γ-GTP", ko: "GGT", it: "GGT"
        ),
        "tbil": metric(
            zh: "总胆红素", en: "Total Bilirubin", de: "Gesamtbilirubin",
            es: "Bilirrubina total", pt: "Bilirrubina total", fr: "Bilirubine totale", ja: "総ビリルビン", ko: "총 빌리루빈", it: "Bilirubina totale"
        ),
        "alb": metric(
            zh: "白蛋白", en: "Albumin", de: "Albumin",
            es: "Albúmina", pt: "Albumina", fr: "Albumine", ja: "アルブミン", ko: "알부민", it: "Albumina"
        ),
        "creatinine": metric(
            zh: "肌酐", en: "Creatinine", de: "Kreatinin",
            es: "Creatinina", pt: "Creatinina", fr: "Créatinine", ja: "クレアチニン", ko: "크레아티닌", it: "Creatinina"
        ),
        "bun": metric(
            zh: "尿素氮", en: "BUN", de: "Harnstoff (BUN)",
            es: "Nitrógeno ureico (BUN)", pt: "Nitrogênio ureico (BUN)", fr: "Urée sanguine (BUN)", ja: "尿素窒素（BUN）", ko: "요소질소(BUN)", it: "Azoto ureico (BUN)"
        ),
        "egfr": metric(
            zh: "eGFR", en: "eGFR", de: "eGFR",
            es: "eGFR", pt: "eGFR", fr: "DFGe", ja: "eGFR", ko: "eGFR", it: "eGFR"
        ),
        "uric_acid": metric(
            zh: "尿酸", en: "Uric Acid", de: "Harnsäure",
            es: "Ácido úrico", pt: "Ácido úrico", fr: "Acide urique", ja: "尿酸", ko: "요산", it: "Acido urico"
        ),
        "hgb": metric(
            zh: "血红蛋白", en: "Hemoglobin", de: "Hämoglobin",
            es: "Hemoglobina", pt: "Hemoglobina", fr: "Hémoglobine", ja: "ヘモグロビン", ko: "헤모글로빈", it: "Emoglobina"
        ),
        "wbc": metric(
            zh: "白细胞", en: "WBC", de: "Leukozyten",
            es: "Leucocitos (WBC)", pt: "Leucócitos (WBC)", fr: "Leucocytes", ja: "白血球（WBC）", ko: "백혈구(WBC)", it: "Leucociti"
        ),
        "rbc": metric(
            zh: "红细胞", en: "RBC", de: "Erythrozyten",
            es: "Eritrocitos (RBC)", pt: "Hemácias (RBC)", fr: "Érythrocytes", ja: "赤血球（RBC）", ko: "적혈구(RBC)", it: "Eritrociti"
        ),
        "plt": metric(
            zh: "血小板", en: "Platelets", de: "Thrombozyten",
            es: "Plaquetas", pt: "Plaquetas", fr: "Plaquettes", ja: "血小板", ko: "혈소판", it: "Piastrine"
        ),
        "hscrp": metric(
            zh: "高敏 C 反应蛋白", en: "hs-CRP", de: "hs-CRP",
            es: "PCR ultrasensible (hs-CRP)", pt: "PCR ultrassensível (hs-CRP)", fr: "CRP ultrasensible", ja: "高感度 CRP", ko: "고감도 CRP", it: "PCR ad alta sensibilità"
        ),
        "esr": metric(
            zh: "血沉", en: "ESR", de: "BSG",
            es: "VSG", pt: "VHS", fr: "VS", ja: "赤血球沈降速度", ko: "적혈구 침강속도", it: "VES"
        ),
        "vitamin_d": metric(
            zh: "25-羟维生素 D", en: "Vitamin D (25-OH)", de: "Vitamin D (25-OH)",
            es: "Vitamina D (25-OH)", pt: "Vitamina D (25-OH)", fr: "Vitamine D (25-OH)", ja: "25-ヒドロキシビタミンD", ko: "25-하이드록시 비타민 D", it: "Vitamina D (25-OH)"
        ),
        "vitamin_b12": metric(
            zh: "维生素 B12", en: "Vitamin B12", de: "Vitamin B12",
            es: "Vitamina B12", pt: "Vitamina B12", fr: "Vitamine B12", ja: "ビタミン B12", ko: "비타민 B12", it: "Vitamina B12"
        ),
        "ferritin": metric(
            zh: "铁蛋白", en: "Ferritin", de: "Ferritin",
            es: "Ferritina", pt: "Ferritina", fr: "Ferritine", ja: "フェリチン", ko: "페리틴", it: "Ferritina"
        ),
        "na": metric(
            zh: "钠", en: "Sodium", de: "Natrium",
            es: "Sodio", pt: "Sódio", fr: "Sodium", ja: "ナトリウム", ko: "나트륨", it: "Sodio"
        ),
        "k": metric(
            zh: "钾", en: "Potassium", de: "Kalium",
            es: "Potasio", pt: "Potássio", fr: "Potassium", ja: "カリウム", ko: "칼륨", it: "Potassio"
        ),
        "ca": metric(
            zh: "钙", en: "Calcium", de: "Kalzium",
            es: "Calcio", pt: "Cálcio", fr: "Calcium", ja: "カルシウム", ko: "칼슘", it: "Calcio"
        ),
        "mg": metric(
            zh: "镁", en: "Magnesium", de: "Magnesium",
            es: "Magnesio", pt: "Magnésio", fr: "Magnésium", ja: "マグネシウム", ko: "마그네슘", it: "Magnesio"
        ),
        "sbp": metric(
            zh: "收缩压", en: "Systolic BP", de: "Systolischer Blutdruck",
            es: "Presión arterial sistólica", pt: "Pressão arterial sistólica", fr: "Pression artérielle systolique", ja: "収縮期血圧", ko: "수축기 혈압", it: "Pressione sistolica"
        ),
        "dbp": metric(
            zh: "舒张压", en: "Diastolic BP", de: "Diastolischer Blutdruck",
            es: "Presión arterial diastólica", pt: "Pressão arterial diastólica", fr: "Pression artérielle diastolique", ja: "拡張期血圧", ko: "이완기 혈압", it: "Pressione diastolica"
        ),
        "hr": metric(
            zh: "心率", en: "Heart Rate", de: "Herzfrequenz",
            es: "Frecuencia cardíaca", pt: "Frequência cardíaca", fr: "Fréquence cardiaque", ja: "心拍数", ko: "심박수", it: "Frequenza cardiaca"
        ),
        "temp": metric(
            zh: "体温", en: "Body Temperature", de: "Körpertemperatur",
            es: "Temperatura corporal", pt: "Temperatura corporal", fr: "Température corporelle", ja: "体温", ko: "체온", it: "Temperatura corporea"
        ),
        "spo2": metric(
            zh: "血氧饱和度", en: "SpO₂", de: "SpO₂",
            es: "SpO₂", pt: "SpO₂", fr: "SpO₂", ja: "SpO₂", ko: "SpO₂", it: "SpO₂"
        ),
        "rr": metric(
            zh: "呼吸率", en: "Respiratory Rate", de: "Atemfrequenz",
            es: "Frecuencia respiratoria", pt: "Frequência respiratória", fr: "Fréquence respiratoire", ja: "呼吸数", ko: "호흡수", it: "Frequenza respiratoria"
        )
    ]

    private static func metric(
        zh: String,
        en: String,
        de: String,
        es: String,
        pt: String,
        fr: String,
        ja: String,
        ko: String,
        it: String
    ) -> AppLocalizedText {
        AppLocalizedText(
            zh: zh, en: en, de: de, es: es, pt: pt,
            fr: fr, ja: ja, ko: ko, it: it
        )
    }
}
