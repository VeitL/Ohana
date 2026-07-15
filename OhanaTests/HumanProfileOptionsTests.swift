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

    @Test func roleTextDisplaysTwoPermissionLabels() {
        let owner = Human(name: "Owner", role: "owner")
        let member = Human(name: "Member", role: "member")
        let oldEditor = Human(name: "Editor", role: "editor")
        oldEditor.role = "editor"
        let oldViewer = Human(name: "Viewer", role: "viewer")
        oldViewer.role = "viewer"

        #expect(owner.roleText == "管理者")
        #expect(member.roleText == "成员")
        #expect(oldEditor.roleText == "成员")
        #expect(oldViewer.roleText == "成员")
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

        #expect(HumanProfileOptions.localizedRoleTitle("owner", l: en) == "Owner")
        #expect(HumanProfileOptions.localizedRoleTitle("viewer", l: zh) == "成员")
        #expect(HumanProfileOptions.localizedGenderTitle("女", l: en) == "Female")
        #expect(HumanProfileOptions.localizedGenderTitle("female", l: zh) == "女")
        #expect(HumanProfileOptions.localizedGenderTitle("private", l: en) == "Prefer not to say")
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
