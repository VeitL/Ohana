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

    @Test func visibleNotesHideLegacyRelationshipMetadata() {
        let notes = "性别:female｜关系:妈妈｜喜欢周末遛狗"

        #expect(HumanProfileOptions.visibleNoteParts(from: notes) == ["喜欢周末遛狗"])
        #expect(HumanProfileOptions.genderMetadata(from: notes) == "女")
    }
}
