import Foundation
import Testing
@testable import Ohana

@MainActor
struct ActorUXDefaultPolicyTests {
    @Test func settingsSelectionUsesOnlyLivingHumansAndRepairsOnlyUnambiguousBinding() {
        let remembered = makeHuman(name: "Remembered", hasPassedAway: true)
        let onlyLiving = makeHuman(name: "Only living")
        let anotherLiving = makeHuman(name: "Another living")

        #expect(
            SettingsActiveHumanSelectionPolicy.selectableHumans(
                from: [remembered, onlyLiving]
            ).map(\.id) == [onlyLiving.id]
        )
        #expect(
            SettingsActiveHumanSelectionPolicy.resolvedHumanID(
                currentHumanID: remembered.id,
                humans: [remembered, onlyLiving]
            ) == onlyLiving.id
        )
        #expect(
            SettingsActiveHumanSelectionPolicy.resolvedHumanID(
                currentHumanID: remembered.id,
                humans: [remembered, onlyLiving, anotherLiving]
            ) == nil
        )
        #expect(
            SettingsActiveHumanSelectionPolicy.resolvedHumanID(
                currentHumanID: anotherLiving.id,
                humans: [remembered, onlyLiving, anotherLiving]
            ) == anotherLiving.id
        )
    }

    @Test func rewardDraftStaysCollapsedWithoutRewardAndClosingItAlwaysClearsValue() {
        #expect(!FamilyTaskRewardDraftPolicy.isExpanded(existingReward: 0))
        #expect(FamilyTaskRewardDraftPolicy.isExpanded(existingReward: 12))
        #expect(FamilyTaskRewardDraftPolicy.suggestedReward(availableBalance: 100) == 20)
        #expect(FamilyTaskRewardDraftPolicy.suggestedReward(availableBalance: 8) == 8)
        #expect(FamilyTaskRewardDraftPolicy.suggestedReward(availableBalance: 0) == 0)
        #expect(FamilyTaskRewardDraftPolicy.effectiveReward(isEnabled: false, draftReward: 50) == 0)
        #expect(FamilyTaskRewardDraftPolicy.effectiveReward(isEnabled: true, draftReward: 50) == 50)
    }

    @Test func expensePayerStaysSelectableAndRewardEditorKeepsAdvancedChoicesScoped() throws {
        let rootURL = repositoryRootURL()
        let expense = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheet.swift",
            rootURL: rootURL
        )
        let expenseSections = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheet+Sections.swift",
            rootURL: rootURL
        )
        let expenseLogic = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheet+LogicAndReceipts.swift",
            rootURL: rootURL
        )
        let expenseCommands = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheet+Commands.swift",
            rootURL: rootURL
        )
        let taskEditor = try source(
            "Ohana/Features/FamilyTasks/Views/FamilyTaskEditorPanel.swift",
            rootURL: rootURL
        )

        #expect(expense.contains("var activeExpenseHumans: [Human]"))
        #expect(expense.contains("humans.filter { !$0.hasPassedAway }"))
        #expect(expense.contains("@State var selectedPayerIDs: [String] = []"))
        #expect(expense.contains("payerContributionsForSave"))
        #expect(expenseSections.contains("if !activeExpenseHumans.isEmpty"))
        #expect(!expenseSections.contains("if activeExpenseHumans.count > 1"))
        #expect(expenseSections.contains("ForEach(activeExpenseHumans)"))
        #expect(expenseSections.contains("payerContributionRow(human)"))
        #expect(expenseSections.contains("expense-payer-equal-split-action"))
        #expect(expenseLogic.contains("guard !activeExpenseHumans.isEmpty"))
        #expect(expenseLogic.contains("activeExpenseHumans.count > 1"))
        #expect(expenseLogic.contains("resetPayerAmountsToEqual()"))
        #expect(expenseLogic.contains("ExpensePayerContributionPolicy.equalSplit"))
        #expect(expenseCommands.contains("activeExpenseHumans.contains"))
        #expect(expenseCommands.contains("payerContributions: payerContributions"))

        #expect(taskEditor.contains("@State private var includesReward: Bool"))
        #expect(taskEditor.contains("Toggle(isOn: $includesReward)"))
        #expect(taskEditor.contains("if includesReward {"))
        #expect(taskEditor.contains("reward = 0"))
        #expect(taskEditor.contains("effectiveReward"))
        #expect(!taskEditor.contains("Without a reward, the task finishes"))
    }

    @Test func expenseCreationIsPetSubjectOnlyWhileHumanPayerHistoryStaysReadOnly() throws {
        let rootURL = repositoryRootURL()
        let commands = try source(
            "Ohana/Features/Expenses/ExpenseCommands.swift",
            rootURL: rootURL
        )
        let humanExpenseDetail = try source(
            "Ohana/Features/Expenses/Views/HumanExpenseDetailView.swift",
            rootURL: rootURL
        )
        let humanRouteContainer = try source(
            "Ohana/Features/Members/HumanDetailSheetRouteContainer.swift",
            rootURL: rootURL
        )
        let humanQuickDefaults = try source(
            "Ohana/Features/Home/ExpandedQuickActionDefaults.swift",
            rootURL: rootURL
        )
        let humanQuickStore = try source(
            "Ohana/Features/Home/ExpandedQuickActionStore.swift",
            rootURL: rootURL
        )

        #expect(commands.contains("throw ExpenseSubjectPolicyError.humanSubjectNotSupported"))
        #expect(!humanExpenseDetail.contains("QuickHumanExpenseSheet("))
        #expect(!humanRouteContainer.contains("QuickHumanExpenseSheet("))
        #expect(!humanQuickDefaults.contains("actionType: \"humanExpense\""))
        #expect(humanQuickStore.contains("$0.actionType != \"humanExpense\""))
    }

    private func makeHuman(
        id: UUID = UUID(),
        name: String,
        hasPassedAway: Bool = false
    ) -> SettingsHumanSnapshot {
        SettingsHumanSnapshot(
            id: id,
            name: name,
            avatarEmoji: "👤",
            themeColorHex: "FF7600",
            appleUserIdentifier: "",
            hasPasscode: false,
            hasPassedAway: hasPassedAway
        )
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
