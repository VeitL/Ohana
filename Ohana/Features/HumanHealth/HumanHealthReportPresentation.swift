import SwiftUI

extension ReportConclusion {
    var color: Color {
        switch self {
        case .normal: .goTeal
        case .attention: .goYellow
        case .abnormal: .goOrange
        case .critical: .goRed
        }
    }

    func localizedTitle(_ l: L10n) -> String {
        switch self {
        case .normal:
            l.tr(zh: "正常", en: "Normal", de: "Normal")
        case .attention:
            l.tr(zh: "注意", en: "Watch", de: "Beachten")
        case .abnormal:
            l.tr(zh: "异常", en: "Abnormal", de: "Auffällig")
        case .critical:
            l.tr(zh: "危急", en: "Critical", de: "Kritisch")
        }
    }
}

extension HealthReportType {
    func localizedTitle(_ l: L10n) -> String {
        switch self {
        case .bloodTest:
            l.tr(zh: "血液检测", en: "Blood Test", de: "Bluttest")
        case .urineTest:
            l.tr(zh: "尿液检测", en: "Urine Test", de: "Urintest")
        case .physical:
            l.tr(zh: "全身体检", en: "Physical Exam", de: "Ganzkörpercheck")
        case .vision:
            l.tr(zh: "视力检查", en: "Vision Check", de: "Sehtest")
        case .dental:
            l.tr(zh: "口腔检查", en: "Dental Check", de: "Zahncheck")
        case .cardiac:
            l.tr(zh: "心脏检查", en: "Cardiac Check", de: "Herzcheck")
        case .imaging:
            l.tr(zh: "影像检查", en: "Imaging", de: "Bildgebung")
        case .allergy:
            l.tr(zh: "过敏检测", en: "Allergy Test", de: "Allergietest")
        case .other:
            l.tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }
}
