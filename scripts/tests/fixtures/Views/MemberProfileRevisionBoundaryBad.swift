import Foundation

struct MemberProfileRevisionBoundaryBad {
    let appServices: AppServices
    let result: MemberProfileCommandResult

    func save() {
        appServices.domainRevisions.publishMemberProfile(result, note: "fixture.bad")
    }
}
