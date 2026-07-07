import SwiftUI

struct LocalizationHardcodedChineseBad: View {
    @AppStorage("appLanguage") private var appLanguage = "zh"

    var body: some View {
        VStack {
            Text("硬编码中文")
            Button("确认") {}
            GoDraftTextField(
                "里程碑标题",
                text: .constant("")
            )
            OhanaTextField(placeholder: "输入名字", text: .constant(""))
            CrewRosterEditorTextField(title: "备注", text: .constant(""), icon: "note.text")
        }
    }
}
