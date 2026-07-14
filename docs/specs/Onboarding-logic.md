# Onboarding Logic

- Status: active product behavior specification.
- Owner: `docs/specs/product-foundation.md` D17.
- Last verified: 2026-07-12 against the Pet-first flow and local-only/no-account boundary.

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
- The one-time 50-coconut gift is a system-created island grant. It is credited
  to the `system:island` reserve and is never owned by a Human or Pet.
- The formal island total is the island reserve plus all active member wallets.
  Oasis tree injection may atomically spend that whole pool, using the island
  reserve first and then active member wallets. `system:legacy` is excluded.
- The gift ledger event and wallet mutation save in one SwiftData transaction.
- The wallet transaction key is deterministic. A persisted `starterGift` event
  recovers presentation defaults after interruption and prevents a second mint.
- A legacy v2 gift already credited to a Human or Pet is reclassified once with
  paired wallet transfer facts plus an idempotent marker. The migration preserves
  the total balance and never mints a second gift.
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
island reward, including when the user chooses Later or Prefer not to say.

## Required Proof

- Unit: clean state transitions, island-reserve claim, legacy member-gift
  reclassification, interruption recovery, and idempotent reward recovery.
- Unit: Human draft defaults and last-Human deletion remain non-blocking.
- UI smoke: a clean install reaches first Pet, first care, reward ceremony, and
  Oasis Lv0 without creating a Human, then five 10-coconut injections reach Lv1.
- Stability: repeat the clean-install UI path ten times with relaunch isolation;
  record duration and require median <= 90 seconds.
- Physical device remains required for final touch latency, Reduce Motion,
  VoiceOver traversal, energy, permission-dialog acceptance, and iCloud Drive
  backup failure/recovery behavior.
