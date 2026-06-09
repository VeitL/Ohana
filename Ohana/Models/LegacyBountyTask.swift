//
//  LegacyBountyTask.swift
//  Ohana
//
//  Legacy UserDefaults-backed bounty task model and command adapter.
//

import Foundation

struct BountyTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var reward: Int
    var creatorId: String
    var creatorName: String
    var creatorEmoji: String
    var assigneeId: String?
    var assigneeName: String?
    var assignedToId: String?
    var assignedToName: String?
    var assignedToEmoji: String?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var emoji: String

    init(
        title: String,
        description: String,
        reward: Int,
        creatorId: String,
        creatorName: String,
        creatorEmoji: String,
        emoji: String,
        assignedToId: String? = nil,
        assignedToName: String? = nil,
        assignedToEmoji: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.reward = reward
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.creatorEmoji = creatorEmoji
        self.emoji = emoji
        self.assignedToId = assignedToId
        self.assignedToName = assignedToName
        self.assignedToEmoji = assignedToEmoji
        self.isCompleted = false
        self.createdAt = Date()
    }

    static func loadAll() -> [BountyTask] {
        guard let raw = UserDefaults.standard.string(forKey: "bountyTasks"),
              !raw.isEmpty
        else { return [] }
        return decode(raw)
    }

    static func decode(_ raw: String) -> [BountyTask] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([BountyTask].self, from: data)
        else { return [] }
        return decoded
    }

    static func encode(_ tasks: [BountyTask]) -> String? {
        guard let data = try? JSONEncoder().encode(tasks) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func pendingAssignedCount(for humanIdString: String) -> Int {
        guard !humanIdString.isEmpty else { return 0 }
        return loadAll().filter {
            !$0.isCompleted && $0.assignedToId == humanIdString
        }.count
    }
}

@MainActor
struct LegacyBountyCommandExecutor {
    func createTask(_ task: BountyTask, in tasks: [BountyTask]) -> String? {
        var current = tasks
        current.insert(task, at: 0)
        return persist(
            current,
            command: .legacyBounty(taskID: task.id, action: "create"),
            affected: [task.id],
            note: "legacy.bounty.create"
        )
    }

    func deleteTask(id: UUID, in tasks: [BountyTask]) -> String? {
        let current = tasks.filter { $0.id != id }
        return persist(
            current,
            command: .legacyBounty(taskID: id, action: "delete"),
            affected: [id],
            note: "legacy.bounty.delete"
        )
    }

    func completeTask(
        id: UUID,
        in tasks: [BountyTask],
        activeHumanId: String,
        currentHuman: Human?
    ) -> String? {
        var current = tasks
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return nil }
        var task = current[idx]

        task.isCompleted = true
        task.completedAt = Date()
        task.assigneeId = activeHumanId
        task.assigneeName = currentHuman?.name
        current[idx] = task

        QuestManager.shared.addCoconuts(
            task.reward,
            emoji: "📋",
            title: "完成家庭任务",
            actorId: activeHumanId.isEmpty ? nil : activeHumanId,
            actorName: currentHuman?.name
        )

        return persist(
            current,
            command: .legacyBounty(taskID: id, action: "complete"),
            affected: [id],
            note: "legacy.bounty.complete"
        )
    }

    private func persist(
        _ tasks: [BountyTask],
        command: DomainCommand,
        affected: Set<UUID>,
        note: String
    ) -> String? {
        guard let raw = BountyTask.encode(tasks) else { return nil }
        ReadModelRevisionCenter.shared.publishDomainMutation(
            command: command,
            affectedEntityIDs: affected,
            wroteBusinessFact: true,
            note: note
        )
        return raw
    }
}
