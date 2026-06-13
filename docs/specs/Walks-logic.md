# Walks Logic

## Purpose

Walks is the dog-only outdoor walk feature for the first-release care loop. It
may use foreground and background location only while a user has an active dog
walk in progress. Historical walk data remains available through archive and
memorial surfaces, but active Walks routes, cards, stats, and rewards must only
operate on living, non-recycled dogs.

## Launch Semantics

- Active GPS walks are dog-only.
- A pet that is not a dog, has passed away, or is in the recycle bin cannot
  enter the active Walks route and cannot start a walk through the service
  boundary.
- Running walk state is the only app state allowed to keep continuous location
  delivery or promote delivery to the background.
- Short walks below `CoconutWalkRewardPolicy`'s distance threshold are saved as
  facts but receive no walk reward.
- Walk and in-walk potty rewards must go through the normal quest/economy
  budget and cooldown pipeline with the executor id. Walks must not write a
  system wallet or mutate balances directly.
- Active Walks stats, summaries, maps, banners, and cards read only active
  recycle-bin items. Recycled `PetWalkLog` and `PetPottyLog` records are
  historical/recovery data and must not affect active Walks UI.

## Collected Surfaces

### Route And Start Boundary

- `Ohana/Features/Walks/WalkRouteContainer.swift`: the typed route must fetch
  only non-recycled pets and must reject non-dog or deceased pets before mounting
  `WalkTrackingFullScreen`.
- `Ohana/Features/Walks/PetWalkingManager.swift`: `start(pet:)` is the hard
  service boundary. It must no-op for non-dog, deceased, or recycled pets before
  changing phase or starting location.
- `Ohana/Features/Walks/WalkingLocationAdapters.swift`: the app-facing walking
  protocol delegates to the same manager boundary and must not add a second
  product decision point.

### Location Lifecycle

- `Ohana/App/AppLifecycleCoordinator.swift`: background and foreground handoffs
  call the walking manager only; the manager decides whether an active location
  walk exists.
- `Ohana/Features/Walks/LocationManager.swift`: continuous and background
  location delivery is tied to an active walk session. No setting, demo surface,
  or route may keep location alive outside running Walks.

### Walk Facts And Rewards

- `Ohana/Features/Walks/PetWalkingManager.swift`: stopping a walk writes one
  `PetWalkLog` per eligible dog target, then awards through `QuestManager` only
  if the distance is rewardable.
- `Ohana/Domain/Services/CareEventService.swift` and
  `Ohana/Domain/Services/SharedPetActionRecorder.swift`: shared walk recording
  remains the domain implementation for multi-dog walks. Walks callers use an
  instance adapter instead of static service calls.
- In-walk poop markers are official `PetPottyLog` facts. Each persisted potty
  log must also produce a `CareLedgerEvent` with `legacyModelName ==
  "PetPottyLog"` and receive any potty reward through `QuestManager` with the
  selected executor id.

### Active Walks Read Models And UI

- `Ohana/Features/Walks/WalkTrackingSupport.swift`: snapshot building reads only
  active walk and potty logs.
- `Ohana/Features/Walks/Views/DogActivityCard.swift`: today's walk count and
  weekly progress ignore recycled walk logs.
- `Ohana/Features/Walks/Views/WalkSummarySheet.swift`: totals, weekly progress,
  fresh-walk mood card, and history list ignore recycled walk logs.
- `Ohana/Features/Walks/Views/WalkDetailView.swift`: route poop markers ignore
  recycled potty logs.
- `Ohana/Features/Walks/Views/GlobalWalkBanner.swift`: latest completed walk
  fallback ignores recycled walk logs.

### Summary And Sync Metadata

- `Ohana/Features/Members/MemberInteractionCommands.swift`: weekly goal changes
  mark the pet modified; walk mood/notes changes mark the edited `PetWalkLog`
  modified before saving.
- Walk route snapshots, in-walk potty logs, and shared-walk child logs must mark
  CloudSync mutation state even though first release keeps CloudKit disabled.

## Future Unlock And Scope

Walks is not tied to `OnlineFeatureGate` or `PlantFeatureGate`. The feature is
available locally for eligible dogs in the first release.

If future releases add non-dog walking-like activities, they must introduce a
separate product rule rather than weakening the dog-only Walks gate. If future
paid or social features add shared live location, the entitlement decision must
be added outside the local Walks eligibility policy and must not enable CloudKit
or online collaboration from this module.
