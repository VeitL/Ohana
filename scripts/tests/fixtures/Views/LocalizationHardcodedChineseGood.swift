import SwiftUI

struct LocalizationHardcodedChineseGood: View {
    private let title = L10n("fixture.title").tr(zh: "中文", en: "Localized")

    var body: some View {
        VStack {
            Text(title)
            Button(L10n("fixture.confirm").tr(zh: "确认", en: "Confirm")) {}
        }
    }
}
