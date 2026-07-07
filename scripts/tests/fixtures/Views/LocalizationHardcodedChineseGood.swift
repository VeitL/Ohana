import SwiftUI

struct LocalizationHardcodedChineseGood: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private let title = L10n("fixture.title").tr(zh: "中文", en: "Localized")

    var body: some View {
        VStack {
            Text(title)
            Button(L10n("fixture.confirm").tr(zh: "确认", en: "Confirm")) {}
            GoDraftTextField(
                L10n("fixture.milestone.title").tr(zh: "里程碑标题", en: "Milestone title"),
                text: .constant("")
            )
            OhanaTextField(
                placeholder: L10n("fixture.name").tr(zh: "输入名字", en: "Enter name"),
                text: .constant("")
            )
            CrewRosterEditorTextField(
                title: L10n("fixture.notes").tr(zh: "备注", en: "Notes"),
                text: .constant(""),
                icon: "note.text"
            )
        }
    }
}
