import Testing
@testable import Ohana

struct HumanProfileOptionsTests {
    @Test func normalizesLegacyPermissionRolesToMember() {
        #expect(HumanProfileOptions.normalizedRole("owner") == "owner")
        #expect(HumanProfileOptions.normalizedRole("member") == "member")
        #expect(HumanProfileOptions.normalizedRole("editor") == "member")
        #expect(HumanProfileOptions.normalizedRole("viewer") == "member")
        #expect(HumanProfileOptions.normalizedRole("unknown") == "member")
    }

    @Test func roleTextDisplaysNeutralHouseholdLabels() {
        let owner = Human(name: "Owner", role: "owner")
        let member = Human(name: "Member", role: "member")
        let oldEditor = Human(name: "Editor", role: "editor")
        oldEditor.role = "editor"
        let oldViewer = Human(name: "Viewer", role: "viewer")
        oldViewer.role = "viewer"

        #expect(owner.roleText == "主要成员")
        #expect(member.roleText == "家庭成员")
        #expect(oldEditor.roleText == "家庭成员")
        #expect(oldViewer.roleText == "家庭成员")
    }

    @Test func normalizesGenderIdentityValues() {
        #expect(HumanProfileOptions.normalizedGender("female") == "女")
        #expect(HumanProfileOptions.normalizedGender("male") == "男")
        #expect(HumanProfileOptions.normalizedGender("女") == "女")
        #expect(HumanProfileOptions.normalizedGender("男") == "男")
        #expect(HumanProfileOptions.normalizedGender("non-binary") == "非二元")
        #expect(HumanProfileOptions.normalizedGender("非二元") == "非二元")
        #expect(HumanProfileOptions.normalizedGender("unknown") == "不透露")
        #expect(HumanProfileOptions.normalizedGender("不透露") == "不透露")
    }

    @Test func storesGenderIdentityAsCanonicalKeys() {
        #expect(HumanProfileOptions.genderOptions.map(\.key) == ["", "female", "male", "nonbinary", "private"])
        #expect(HumanProfileOptions.storedGenderIdentity("女") == "female")
        #expect(HumanProfileOptions.storedGenderIdentity("male") == "male")
        #expect(HumanProfileOptions.storedGenderIdentity("非二元") == "nonbinary")
        #expect(HumanProfileOptions.storedGenderIdentity("prefer not to say") == "private")
        #expect(HumanProfileOptions.storedGenderIdentity("") == nil)
    }

    @Test func localizedHumanOptionTitlesAcceptLegacyAndCanonicalValues() {
        let zh = L10n("zh")
        let en = L10n("en")

        #expect(HumanProfileOptions.localizedRoleTitle("owner", l: en) == "Primary member")
        #expect(HumanProfileOptions.localizedRoleTitle("viewer", l: zh) == "家庭成员")
        #expect(HumanProfileOptions.localizedGenderTitle("女", l: en) == "Female")
        #expect(HumanProfileOptions.localizedGenderTitle("female", l: zh) == "女")
        #expect(HumanProfileOptions.localizedGenderTitle("private", l: en) == "Prefer not to say")
    }

    @Test func humanRoleAndGenderLabelsCoverEveryRegisteredLanguage() {
        let english = L10n("en")
        let englishLabels = [
            HumanProfileOptions.localizedRoleTitle("owner", l: english),
            HumanProfileOptions.localizedRoleTitle("member", l: english),
            HumanProfileOptions.localizedGenderTitle("female", l: english),
            HumanProfileOptions.localizedGenderTitle("male", l: english),
            HumanProfileOptions.localizedGenderTitle("nonbinary", l: english),
            HumanProfileOptions.localizedGenderTitle("private", l: english)
        ]

        for languageCode in ["es", "pt", "fr", "ja", "ko", "it"] {
            let localization = L10n(languageCode)
            let labels = [
                HumanProfileOptions.localizedRoleTitle("owner", l: localization),
                HumanProfileOptions.localizedRoleTitle("member", l: localization),
                HumanProfileOptions.localizedGenderTitle("female", l: localization),
                HumanProfileOptions.localizedGenderTitle("male", l: localization),
                HumanProfileOptions.localizedGenderTitle("nonbinary", l: localization),
                HumanProfileOptions.localizedGenderTitle("private", l: localization)
            ]
            #expect(labels.allSatisfy { !$0.isEmpty })
            #expect(labels != englishLabels)
        }
    }

    @Test func humanProfileStaticCopyDoesNotFallBackToEnglish() {
        let englishFallback = "__human_profile_english_fallback__"
        let keys = [
            "基础资料", "家庭与位置", "身体资料", "性别/身份", "家庭角色",
            "椰子资产与心愿", "相处天数", "纪念模式", "离世日期", "撤销离世标记",
            "人类驾驶舱", "成员摘要", "健康照护", "资料与家庭角色", "身份、资料与本地隐私",
            "成员资料", "称呼与可选资料", "地区", "现居国家", "个性与身体",
            "打开中", "2.5D 头像开关", "不满1岁", "资料已更新", "输入名字后才能继续"
        ]

        for languageCode in ["es", "pt", "fr", "ja", "ko", "it"] {
            let localization = L10n(languageCode)
            for key in keys {
                #expect(localization.tr(zh: key, en: englishFallback) != englishFallback)
            }
        }
    }

    @Test func backupStorageGenderFallsBackToLegacyMetadataAsCanonicalKey() {
        #expect(HumanProfileOptions.storedGenderIdentity(raw: "女", notes: "") == "female")
        #expect(HumanProfileOptions.storedGenderIdentity(raw: "female", notes: "性别:男｜memo") == "female")
        #expect(HumanProfileOptions.storedGenderIdentity(raw: nil, notes: "性别:男｜memo") == "male")
        #expect(HumanProfileOptions.storedGenderIdentity(raw: "", notes: "memo") == nil)
    }

    @Test func memberCreationDraftDoesNotInferHumanGender() {
        #expect(MemberCreationDraft(kind: .human).humanGender == "")
    }

    @Test func visibleNotesHideLegacyRelationshipMetadata() {
        let notes = "性别:female｜关系:妈妈｜喜欢周末遛狗"

        #expect(HumanProfileOptions.visibleNoteParts(from: notes) == ["喜欢周末遛狗"])
        #expect(HumanProfileOptions.genderMetadata(from: notes) == "女")
    }
}
