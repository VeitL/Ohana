# Onboarding Logic

- Status: active product behavior specification.
- Owner: `docs/specs/product-foundation.md` D17 and D29.
- Last verified: 2026-07-23 against the shared two-task starter journey.
- Validation status: owned by `docs/testing-progress.md`; source review is not a
  substitute for the required targeted tests and clean-Simulator journeys below.

## First-Release Promise

Ohana starts without an account or an up-front permission request. A clean install
first selects Standard or Zen, then creates the first local Human using only a name.

The Standard branch continues:

1. Create the first local Human by entering only a name.
2. Choose whether to create a Pet now or later.
3. If creating now, enter Pet name, species, breed and sex; coat remains optional.
   Then optionally choose personality or customize the theme before the final avatar step.
4. Return Home only after its read model contains the newly saved cards; saving
   a Pet never switches the selected top-level tab to Tasks.
5. After onboarding ends, Task Center shows the shared welcome gift first. The
   user explicitly claims 50 coconuts and unlocks the Lv0 coconut tree. A Pet is
   not required.

The Zen branch binds that first Human as the owner and enters the three-tab Zen
shell immediately. Home shows a compact two-step starter card: claim the shared
50-coconut welcome gift, then complete the owner Human profile to 75% and
explicitly claim 100 coconuts. Pet and Plant creation remain entirely optional.
Before the gift is claimed, the always-present Zen Oasis tab shows a dormant seed
that links to the same starter sheet.

An existing installation defaults to Standard and sees one dismissible Zen
introduction. It is never forced through mode choice or member creation again.

Standard and Zen consume the same gift and Human-profile eligibility, progress,
receipts and transaction keys. Standard additionally surfaces the five
Pet-dependent growth tasks after a Pet exists. The six Household Starter tasks
still total 400 coconuts, so Standard remains 50 + 400 = 450; Zen exposes only the
shared 50 + 100 = 150.

Choosing Later completes the blocking onboarding immediately. Home then contains
the Human card and Task Center exposes the welcome gift plus current Human-profile
progress. A separate first-Pet suggestion may be dismissed, has no reward, does
not count as a task or badge, and cannot block Oasis or later progress.

## Required And Optional Data

- A clean install requires a mode choice and one Human name. The first Human becomes the local
  owner, is visible on Home, and becomes `currentActiveHumanId`.
- Pet creation is optional during onboarding. Name, species, breed and sex are
  required. Species and breed both offer an Other choice whose custom text is
  persisted. Coat and other profile fields remain optional for later editing.
- Personality is optional, limited to three creation choices. The same compact
  page exposes an optional native color picker as a clearly separate choice. Without
  a coat, a stable theme is assigned from the Pet profile; with a coat, the theme
  follows its color. An explicit user-selected theme always overrides either result.
  Avatar is the final step and always has a usable default.
- Initial onboarding never requests location or notification permission. Camera
  or photo access is requested only after the user explicitly chooses that source.
- Existing installations are not forced back into Human creation solely because
  an older local dataset has no Human.

## State Machine

```text
needs experience choice
  -> Standard -> Human name -> Pet choice
  -> Pet creation or Later -> Home -> shared starter gift task ready
  -> tap claim task -> reward presentation -> explicit idempotent claim
  -> Oasis / Lv0 tree visible immediately after transaction commit
  -> Human profile reaches 75% -> explicit idempotent +100 claim
  -> optional Pet suggestion / later Pet-only growth tasks
  -> Zen -> Human name / owner binding -> Zen Home
       -> shared two-task card -> explicit +50 gift claim -> full shared Oasis
       -> Human profile reaches 75% -> explicit +100 claim
```

SwiftData Human/Pet facts remain authoritative. Lightweight defaults may persist
the journey choice and presentation checkpoint, but cannot fabricate a member or
reward transaction.

## Starter Gift Invariants

- The first living Human makes the gift ready. Pet, Plant, first check-in, care
  and weight facts do not affect eligibility.
- Pet creation itself never opens the reward presentation and never awards the
  gift. Standard Task Center and Zen starter sheet are presentations of the same
  household fact.
- The user-facing claim button performs the transaction. Eligibility evaluation
  must never mint the reward by itself.
- The one-time 50-coconut gift is credited to `system:island`, never to a Human or Pet.
- The ledger event and wallet mutation share one atomic SwiftData transaction and
  a deterministic transaction key. Double taps, repeated evaluation and relaunch
  can produce only one credit.
- If the wallet receipt commits before a local presentation checkpoint, relaunch
  reconstructs the claimed state from the durable transaction and does not mint
  again. A missing paired CareLedger projection must not cause a second grant.
- A committed gift transaction immediately unlocks Oasis and the Lv0 tree. The
  ceremony or completion animation is presentation-only. The gift adds no energy
  or growth XP; five separate 10-coconut injections are required to reach Lv1.
- Existing handled users receive no retroactive gift. An older pending journey
  with an active Pet but no Human keeps its narrow recovery path; it is not
  interrupted with an unsolicited presentation.
- Completing the owner Human profile to 75% is the second shared task. Its
  existing +100 transaction key and four 25% steps are identical in both modes.
  Birthday must be entered and gender/identity must be selected; “Prefer not to
  say” is a valid gender/identity choice. Those two required steps cannot be
  replaced by skip resolutions. The shared editor displays the same live
  completion percentage while each step is changed.
- The remaining Pet growth tasks are Standard-only presentation. Their existing
  facts and keys persist while Zen hides them.

## Interruption And Recovery

- No Human fact: resume the name step.
- Human exists but the Standard Pet choice is unfinished: resume the optional choice.
- Pet creation was abandoned: persist the deferred state and enter Home; the
  optional suggestion can be dismissed.
- Pet commit succeeds: complete the Home snapshot handoff and keep Home selected.
  It does not change gift eligibility or open a reward presentation.
- Claim fails: keep the reward presentation open with retry; never unlock Oasis early.
- Switching Standard/Zen closes current task presentation but preserves shared
  progress. Repeated relaunch, mode changes or revision events must not duplicate
  Human, Pet, reward or task state.

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

- Unit: Human-only eligibility in both modes, immediate/deferred Pet routes,
  island-reserve claim, wallet-only recovery, transaction-time Oasis unlock and
  idempotent gift/Human-profile recovery.
- Unit: the optional create-Pet suggestion has zero reward and is excluded from
  task counts, badges, reward totals and Calendar; claim-gift remains a real
  system journey item.
- UI smoke: verify both `Zen -> Human -> claim 50 -> Oasis -> profile 75% -> claim 100`
  and `Standard -> Human -> Later -> claim 50 -> dismiss Pet suggestion -> profile`
  on iPhone 17; then switch modes and confirm no shared task repeats.
  confirm required/custom species and breed, compact personality/theme layout,
  Home card counts, task visibility, reward amount and progressive tabs.
- Accessibility: Chinese/English, Dynamic Type, VoiceOver, dark mode and RTL remain usable.
- Physical device remains required for final camera/photo permission, touch latency,
  energy and iCloud Drive backup behavior.
