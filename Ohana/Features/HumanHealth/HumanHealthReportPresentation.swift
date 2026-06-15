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
}
