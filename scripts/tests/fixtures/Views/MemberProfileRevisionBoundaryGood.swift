import Foundation

struct MemberProfileRevisionBoundaryGood {
    let executor: MemberCommandExecutor
    let human: Human
    let input: HumanProfileCommandInput

    func save() {
        executor.updateHumanProfile(human, input: input, note: "fixture.good")
    }
}
