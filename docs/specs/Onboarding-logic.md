# Onboarding Logic

- Status: active product behavior specification.
- Owner: `docs/specs/product-foundation.md` D17.
- Last verified: 2026-07-11 against the Pet-first implementation and targeted tests.

## First-Release Promise

Ohana Solo must reach its first useful care loop without an account or a Human
profile:

1. Introduce the local island.
2. Create the first active Pet.
3. Save one real care fact for that Pet.
4. Grant the one-time starter coconut gift.
5. Show the Lv0 Oasis seed/sprout surface.

The median completion time across ten clean-install runs must be 90 seconds or
less. Permission and household-preference choices may be skipped and must not
block this path.

## Required And Optional Data

- The first Pet is required to complete onboarding. Its creation rules remain
  owned by the member-creation domain service.
- A Human profile is optional during and after onboarding. Absence of a Human
  must not present a blocking replacement-profile route.
- If a user later creates a Human, display name/nickname is required. Gender
  identity and birthday are optional and default to absent, not to a guessed
  value or “prefer not to say.”
- “Not set” and “prefer not to say” are different states. The former means no
  value was supplied; the latter is an explicit user choice.

## State Machine

```text
pre-onboarding
  -> needs first Pet
  -> needs first care fact
  -> starter gift transaction pending
  -> starter gift ceremony
  -> Oasis Lv0 visible
  -> complete
```

The state machine derives Pet and care progress from persisted facts. UserDefaults
may retain presentation/checkpoint state, but a Boolean alone must not fabricate
a Pet, care record, or reward transaction.

## Starter Gift Invariants

- The gift is claimed only after an active Pet and a persisted care fact exist.
- If an active Human exists, the legacy Human wallet remains the recipient. If
  no Human exists, the first active Pet wallet is the recipient.
- The gift ledger event and wallet mutation save in one SwiftData transaction.
- The wallet transaction key is deterministic. A persisted `starterGift` event
  recovers presentation defaults after interruption and prevents a second mint.
- Existing users without a pending first-run journey are marked handled and do
  not receive a retroactive gift.

## Interruption And Recovery

- The first-run checkpoint starts before member creation.
- If the App is terminated after the first Pet commits but before the onboarding
  presentation completes, the earliest active Pet resumes the journey.
- If the first care fact commits while its sheet is visible, the Home coordinator
  may evaluate in the background; the ceremony is shown only when presentation
  state permits it.
- Repeated evaluation, relaunch, or revision events must not duplicate the Pet,
  care fact, gift ledger entry, or wallet credit.

## Future Apple Or Google Sign-In

Authentication is outside the Solo first-release path. A future provider login
must remain separate from the Human domain model:

- Use the provider's stable subject identifier, never email, as account identity.
- Provider data may prefill a proposed display name or avatar only when supplied.
- Gender and birthday are never inferred from login and remain optional.
- The user confirms before creating or claiming a Human profile.
- Login must not silently merge, overwrite, or auto-claim an existing Human.
- Account-to-Human claim and conflict rules require a separate Online/Family
  specification before implementation. This rule does not authorize adding an
  account schema, CloudKit capability, Google SDK, or server dependency now.

## Required Proof

- Unit: clean state transitions, Pet-only wallet claim, Human-recipient
  compatibility, interruption recovery, and idempotent reward recovery.
- Unit: Human draft defaults and last-Human deletion remain non-blocking.
- UI smoke: a clean install reaches first Pet, first care, reward ceremony, and
  Oasis Lv0 without creating a Human.
- Stability: repeat the clean-install UI path ten times with relaunch isolation;
  record duration and require median <= 90 seconds.
- Physical device remains required for final touch latency, Reduce Motion,
  VoiceOver traversal, energy, and permission-dialog acceptance.
