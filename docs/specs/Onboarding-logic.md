# Onboarding Logic

- Status: active product behavior specification.
- Owner: `docs/specs/product-foundation.md` D17.
- Last verified: 2026-07-15 against the Human-first, optional-Pet and local-only boundary.
- Validation status: owned by `docs/testing-progress.md`; source review is not a
  substitute for the required targeted tests and clean-Simulator journeys below.

## First-Release Promise

Ohana Solo starts without an account or an up-front permission request:

1. Create the first local Human by entering only a name.
2. Choose whether to create a Pet now or later.
3. If creating now, enter Pet name, species and breed; then optionally choose
   personality and a theme color before the final avatar step.
4. Return Home only after its read model contains the newly saved cards.
5. Open Task Center, tap the first-Pet reward item, then claim the one-time
   50-coconut island gift and unlock Oasis.

After that blocking journey completes, Task Center may surface the separate
six-item household starter growth plan from D28. Its 400 coconuts are optional,
claimed into the current Human wallet, and never delay Home or Oasis entry.

Choosing Later completes the blocking onboarding immediately. Home then contains
the Human card, Oasis remains hidden, and Task Center exposes one system journey
item for creating the first Pet. The first-Pet path must still complete within
90 seconds on a clean install.

## Required And Optional Data

- A clean install requires one Human name. The first Human becomes the local
  owner, is visible on Home, and becomes `currentActiveHumanId`.
- Pet creation is optional during onboarding. Name, species and breed are
  required. Species and breed both offer an Other choice whose custom text is
  persisted. Sex, coat and other profile fields remain unset/defaulted for later editing.
- Personality is optional, limited to three creation choices. The same compact
  page exposes an optional native color picker as a clearly separate choice. If
  the user does not pick a color, a stable color is derived from the Pet profile.
  Avatar is the final step and always has a usable default.
- Initial onboarding never requests location or notification permission. Camera
  or photo access is requested only after the user explicitly chooses that source.
- Existing installations are not forced back into Human creation solely because
  an older local dataset has no Human.

## State Machine

```text
needs Human name
  -> Pet choice
  -> Pet creation -> starter gift task ready
  -> awaiting Pet -> create-Pet task -> Pet creation -> starter gift task ready
  -> tap claim task -> reward presentation -> explicit idempotent claim
  -> Oasis visible
  -> complete
```

SwiftData Human/Pet facts remain authoritative. Lightweight defaults may persist
the journey choice and presentation checkpoint, but cannot fabricate a member or
reward transaction.

## Starter Gift Invariants

- The first active Pet makes the gift ready; a care or weight record is not required.
- Pet creation itself never opens the reward presentation. Task Center replaces
  the create-Pet journey with a dedicated claim item, and only tapping that item
  requests the presentation.
- The user-facing claim button performs the transaction. Eligibility evaluation
  must never mint the reward by itself.
- The one-time 50-coconut gift is credited to `system:island`, never to a Human or Pet.
- The ledger event and wallet mutation share one atomic SwiftData transaction and
  a deterministic transaction key. Double taps, repeated evaluation and relaunch
  can produce only one credit.
- If the ledger commits before the ceremony checkpoint, relaunch reconstructs the
  claimed state from the persisted ledger and does not mint again.
- Oasis stays hidden while awaiting a Pet and while the gift is ready but unclaimed.
- Existing handled users receive no retroactive gift. An older pending journey
  with an active Pet proceeds to the Task Center claim item; it does not interrupt
  the user with an unsolicited presentation.
- The later 400-coconut household growth plan is not part of the starter-gift
  transaction. Its six member-owned rewards have independent household-stable
  keys and are claimed only from their own Task Center rows.

## Interruption And Recovery

- No Human fact: resume the name step.
- Human exists but Pet choice is unfinished: resume the choice step.
- Pet creation was abandoned: persist the deferred state and show the system task.
- Pet commit succeeds: complete Home snapshot handoff, navigate to Task Center
  and show the claim item without opening the reward presentation.
- Claim fails: keep the reward presentation open with retry; never unlock Oasis early.
- Repeated relaunch or revision events must not duplicate Human, Pet, reward or task state.

## Deferred Account Or Cross-Platform Identity

The current product has no Ohana login or account. Its optional iCloud Drive
backup uses the system iCloud identity and is not app authentication. A Human
remains a local care-content profile: name is required when explicitly creating
one, while gender and birthday are optional.

Any future Apple/Google login or provider-neutral account must first be approved
under `docs/planning/account-backend-extension.md`. It must not silently create,
merge, claim, or upload a Human. That planning document preserves the future
boundary but does not authorize an onboarding or Settings account surface now.
If activated later, the first-run page may emphasize Apple login only while a
clear local continuation remains available. A signed-in user explicitly confirms
one-tap Human-card creation; optional profile decisions may earn an idempotent
member-owned reward, including when the user chooses Later or Prefer not to say.

## Required Proof

- Unit: Human-first state transitions, immediate/deferred Pet routes, island-reserve
  claim, legacy recovery, Oasis locking and idempotent reward recovery.
- Unit: the create-Pet and claim-gift system items are list-only, ignore the
  default member filter, replace one another at the Pet boundary, and never enter Calendar.
- UI smoke: verify both `Human -> Later` and
  `Human -> Pet -> Task Center -> reward presentation -> claim` on iPhone 17;
  confirm required/custom species and breed, compact personality/theme layout,
  Home card counts, task visibility, reward amount and progressive tabs.
- Accessibility: Chinese/English, Dynamic Type, VoiceOver, dark mode and RTL remain usable.
- Physical device remains required for final camera/photo permission, touch latency,
  energy and iCloud Drive backup behavior.
