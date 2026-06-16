import Foundation

struct CareDerivationToken {
    fileprivate init() {}
}

struct CareWriteOutcome {
    enum Kind: Equatable {
        case active
        case noOp
    }

    struct RevisionPayload: Equatable {
        let command: DomainCommand
        let affectedEntityIDs: Set<UUID>
        let note: String?

        init(command: DomainCommand, affectedEntityIDs: Set<UUID>, note: String? = nil) {
            self.command = command
            self.affectedEntityIDs = affectedEntityIDs
            self.note = note
        }
    }

    struct FactPayload: Equatable {
        let subjectID: UUID?
        let logIDs: [UUID]
        let factDate: Date?
        let operationDate: Date

        init(
            subjectID: UUID?,
            logIDs: [UUID] = [],
            factDate: Date?,
            operationDate: Date
        ) {
            self.subjectID = subjectID
            self.logIDs = logIDs
            self.factDate = factDate
            self.operationDate = operationDate
        }
    }

    struct RewardPayload: Equatable {
        let humanDelta: Int
        let petDelta: Int

        var coconutDelta: Int {
            max(0, humanDelta) + max(0, petDelta)
        }
    }

    struct LedgerPayload: Equatable {
        let eventIDs: [UUID]
    }

    struct ReminderPayload: Equatable {
        let reminderIDs: [UUID]
    }

    struct StockPayload: Equatable {
        let affectedPetID: UUID
        let reminderIDs: [UUID]
    }

    struct FeedbackPayload: Equatable {
        let cardID: UUID?
        let title: String?
        let subtitle: String?
        let coconutDelta: Int
    }

    struct SharedSessionPayload: Equatable {
        let sessionID: UUID?
        let sourcePetID: UUID?
        let targetPetIDs: [UUID]
    }

    struct SelectionMemoryPayload: Equatable {
        let sourcePetID: UUID
        let selectedPetIDs: [UUID]
    }

    let kind: Kind
    let disposition: CareFactWriteDisposition
    let fact: FactPayload?
    let revision: RevisionPayload?
    let reward: RewardPayload?
    let ledger: LedgerPayload?
    let reminders: ReminderPayload?
    let stock: StockPayload?
    let feedback: FeedbackPayload?
    let sharedSession: SharedSessionPayload?
    let selectionMemory: SelectionMemoryPayload?
    let noopNote: String?
    let effectPlans: [AuthorizedDomainEffectWrite]

    init(
        kind: Kind,
        disposition: CareFactWriteDisposition,
        fact: FactPayload? = nil,
        revision: RevisionPayload? = nil,
        reward: RewardPayload? = nil,
        ledger: LedgerPayload? = nil,
        reminders: ReminderPayload? = nil,
        stock: StockPayload? = nil,
        feedback: FeedbackPayload? = nil,
        sharedSession: SharedSessionPayload? = nil,
        selectionMemory: SelectionMemoryPayload? = nil,
        noopNote: String? = nil,
        effectPlans: [AuthorizedDomainEffectWrite] = []
    ) {
        self.kind = kind
        self.disposition = disposition
        self.fact = fact
        self.revision = revision
        self.reward = reward
        self.ledger = ledger
        self.reminders = reminders
        self.stock = stock
        self.feedback = feedback
        self.sharedSession = sharedSession
        self.selectionMemory = selectionMemory
        self.noopNote = noopNote
        self.effectPlans = effectPlans
    }

    var didWriteFact: Bool {
        disposition.didWriteFact
    }

    var allowsDerivedEffects: Bool {
        kind == .active && disposition.allowsDerivedEffects
    }

    static func noOp(command: DomainCommand, affectedEntityIDs: Set<UUID>, note: String) -> CareWriteOutcome {
        CareWriteOutcome(
            kind: .noOp,
            disposition: .noOp,
            revision: RevisionPayload(command: command, affectedEntityIDs: affectedEntityIDs, note: note),
            noopNote: note
        )
    }

    static func active(
        disposition: CareFactWriteDisposition,
        fact: FactPayload,
        revision: RevisionPayload,
        reward: RewardPayload? = nil,
        ledger: LedgerPayload? = nil,
        reminders: ReminderPayload? = nil,
        stock: StockPayload? = nil,
        feedback: FeedbackPayload? = nil,
        sharedSession: SharedSessionPayload? = nil,
        selectionMemory: SelectionMemoryPayload? = nil,
        noopNote: String? = nil
    ) -> CareWriteOutcome {
        CareWriteOutcome(
            kind: disposition.allowsDerivedEffects ? .active : .noOp,
            disposition: disposition,
            fact: fact,
            revision: revision,
            reward: reward,
            ledger: ledger,
            reminders: reminders,
            stock: stock,
            feedback: feedback,
            sharedSession: sharedSession,
            selectionMemory: selectionMemory,
            noopNote: noopNote
        )
    }

    static func derivedMutation(
        command: DomainCommand,
        effectPlan: AuthorizedDomainEffectWrite,
        additionalRevisionEntityIDs: Set<UUID> = [],
        note: String? = nil
    ) -> CareWriteOutcome {
        derivedMutation(
            command: command,
            effectPlans: [effectPlan],
            additionalRevisionEntityIDs: additionalRevisionEntityIDs,
            note: note
        )
    }

    static func derivedMutation(
        command: DomainCommand,
        effectPlans: [AuthorizedDomainEffectWrite],
        additionalRevisionEntityIDs: Set<UUID> = [],
        note: String? = nil
    ) -> CareWriteOutcome {
        var affectedEntityIDs = additionalRevisionEntityIDs
        affectedEntityIDs = effectPlans.reduce(into: affectedEntityIDs) { ids, plan in
            ids.formUnion(plan.mutationPlan.subject.affectedEntityIDs)
        }
        return CareWriteOutcome(
            kind: .active,
            disposition: .active,
            revision: RevisionPayload(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                note: note
            ),
            noopNote: note,
            effectPlans: effectPlans
        )
    }
}

struct CareDerivationResult: Equatable {
    let didWriteFact: Bool
    let allowsDerivedEffects: Bool
    let didPublishRevision: Bool
    let coconutDelta: Int

    var isUserVisibleSuccess: Bool {
        didWriteFact && allowsDerivedEffects
    }
}

@MainActor
struct CareDerivationExecutor {
    private let revisions: DomainRevisionPublishing

    init() {
        revisions = SharedDomainRevisionPublisher()
    }

    init(revisions: DomainRevisionPublishing) {
        self.revisions = revisions
    }

    @discardableResult
    func derive(_ outcome: CareWriteOutcome) -> CareDerivationResult {
        let token = CareDerivationToken()
        guard outcome.allowsDerivedEffects else {
            recordNoop(outcome, token: token)
            return CareDerivationResult(
                didWriteFact: outcome.didWriteFact,
                allowsDerivedEffects: false,
                didPublishRevision: false,
                coconutDelta: 0
            )
        }
        if !outcome.effectPlans.isEmpty {
            var didAuthorizeEffects = true
            for effectPlan in outcome.effectPlans {
                let didRun = DomainEffectDispatcher.run(plan: effectPlan) { _ in }
                didAuthorizeEffects = didAuthorizeEffects && didRun
            }
            guard didAuthorizeEffects else {
                recordNoop(outcome, token: token)
                return CareDerivationResult(
                    didWriteFact: outcome.didWriteFact,
                    allowsDerivedEffects: false,
                    didPublishRevision: false,
                    coconutDelta: 0
                )
            }
        }

        let didPublishRevision = publishRevisionIfNeeded(outcome.revision, token: token)
        return CareDerivationResult(
            didWriteFact: outcome.didWriteFact,
            allowsDerivedEffects: true,
            didPublishRevision: didPublishRevision,
            coconutDelta: outcome.reward?.coconutDelta ?? 0
        )
    }

    private func publishRevisionIfNeeded(
        _ payload: CareWriteOutcome.RevisionPayload?,
        token: CareDerivationToken
    ) -> Bool {
        guard let payload else { return false }
        revisions.publish(
            DomainMutationResult(
                command: payload.command,
                affectedEntityIDs: payload.affectedEntityIDs,
                wroteBusinessFact: true,
                note: payload.note
            ),
            token: token
        )
        return true
    }

    private func recordNoop(_ outcome: CareWriteOutcome, token _: CareDerivationToken) {
        guard let note = outcome.noopNote ?? outcome.revision?.note else { return }
        AppPerformanceMonitor.shared.record(
            "domain_command_noop",
            valueMS: 0,
            note: note
        )
    }
}
