# P4 — Darkness, limited vision, and squad navigation

**Implementation status:** LK-0401 through LK-0406 complete; LK-0407 is next and remains unstarted.

## Scope and outcome

P4 is the first post-P3 gameplay milestone. It introduces darkness, limited information, and navigation aids that make an operative feel isolated, vulnerable, and reliant on teammates while preserving the information needed to move, regroup, and pursue the current objective. It does not add enemies, enemy AI, fog/shaders, post-processing, particles, objectives, minimaps, or a production HUD beyond the narrowly chosen P4 aids.

This document is the canonical P4 architecture and implementation boundary. It deliberately separates what is rendered from what a player is permitted to know or target.

## Architecture

### Information model

| Concern | Meaning | Authority | P4 rule |
| --- | --- | --- | --- |
| Rendering visibility | What the local renderer draws or brightens. | Client cosmetic layer | Never establishes gameplay knowledge. |
| Gameplay visibility | Whether the server considers an entity presently perceptible to an operative. | Server | Required for disclosure and gameplay interactions that need sight. |
| Targeting visibility | Whether a disclosed hostile is legal for automatic targeting now. | Server combat boundary | Requires gameplay visibility, targeting line of sight, normal P2 eligibility, and revalidation at fire time. |
| Line of sight | A server spatial query between defined origins with an explicit blocker policy. | Server | A fact used by visibility, targeting, revive, and later AI; not a renderer result. |
| Discovery | Server-owned transition that permits a player to learn an entity/objective exists. | Server | May outlive current visibility under a bounded policy. |
| Memory | Deliberately stale, player-specific information about a previously discovered fact. | Server disclosure policy | Must be labelled/represented as stale; never treated as current targeting truth. |

Automatic targeting must never discover an enemy. A hostile is eligible only when the server has already safely disclosed it to that operative, it is currently gameplay-visible, targeting line of sight succeeds, and every existing P2 range/state/ammunition/cadence rule succeeds. Losing any condition clears the target before another shot; remembered, heard, peripheral-only, hidden, or renderer-only hostiles are never candidates. Client prediction may only present an already disclosed server selection and cannot query, infer, or preserve hidden candidates.

## Darkness and lighting contract

Environmental darkness is a level-authored baseline that establishes the intended low-information mood. Ambient light is the broad non-directional readability floor: it preserves terrain silhouette, nearby collision readability, and accessibility, but does not itself disclose enemies. Localized light is an authored, bounded source associated with a fixture, location, or equipped tool. Temporary light is a short-lived localized source such as a future glow stick. Dynamic lighting means a localized source can move, turn on/off, or change intensity; it is not permission to create unbounded shadowed lights.

| Property | Gameplay-affecting? | Canonical treatment |
| --- | --- | --- |
| Environmental darkness and ambient-light tier | Yes, when mapped by the server into a visibility zone/profile. | Server owns the profile; client renders its matching look. |
| Localized/temporary light coverage | Yes, only when a future server visibility query explicitly consumes a server-known light volume/state. | Server owns activation, identity, expiry, and gameplay profile. |
| Dynamic visual intensity, color, flicker, bloom, shadows | Cosmetic only unless a later contract promotes a bounded coverage profile. | Client/level presentation may interpolate but cannot change gameplay visibility. |
| Light asset placement and authored blockers | Gameplay-affecting when used by a server profile/line-of-sight query. | Authored content is validated server-side. |

P4 should begin with a small, explicit set of visibility profiles rather than pixel, luminance, or client-renderer sampling. Lights are represented to gameplay as deterministic bounded volumes/profiles; rendering may be richer but may not add knowledge. Initial Roblox multiplayer budgets are targets to profile, not licenses for unbounded effects: at most 8 active gameplay-relevant localized lights per client view, 2 shadow-casting dynamic lights per client view, 24 cosmetic dynamic lights per client view, 40 simultaneous temporary-light particles per client view, and no per-frame full-squad scans. Any later level must measure representative 1–4 player load before raising a budget.

### Shared gameplay-light contract

LK-0401 defines the pure, unintegrated contract layer in `src/shared/Lighting` and its single configuration home in `src/shared/Config/GameplayLightingConfig.luau`. The frozen stable vocabularies are:

- visibility profiles: `Dark`, `Dim`, `Lit`;
- source types: `AuthoredEnvironmental`, `ApprovedPersonal`, `ApprovedTemporary`;
- activation states: `Inactive`, `Active`, `Expired`;
- coverage kinds: `Radius`, `ForwardCone`, `AuthoredZone`;
- rejection reasons: `InvalidDescriptor`, `InvalidSourceIdentity`, `InvalidSourceType`, `UnknownVisibilityProfile`, `InvalidActivationState`, `InvalidTimestamp`, `InvalidLifetime`, `InvalidCoverage`, `InvalidOwnerIdentity`, `BudgetExceeded`, `StaleTransition`.

`Dark` is the server-known baseline profile with no qualifying gameplay-light contribution. `Dim` is bounded partial gameplay illumination that may support later limited visibility rules. `Lit` is bounded qualifying gameplay illumination; it does not by itself disclose or legalize a target. The source categories distinguish authored environmental declarations, approved operative-owned personal declarations, and approved short-lived temporary declarations without selecting a future tool.

The public types are `VisibilityProfileId`, `GameplayLightSourceTypeId`, `GameplayLightActivationStateId`, `GameplayLightCoverageDescriptor`, `GameplayLightDescriptor`, `GameplayLightActivation`, `GameplayLightValidationResult`, and `GameplayLightRejectionReasonId`. Coverage contains only a bounded radius, bounded forward cone, or nonempty authored-zone profile identity. It contains no spatial runtime object and does not resolve whether a point is covered.

The canonical initial configuration fixes these profile targets and validation bounds:

| Configuration | Value |
| --- | ---: |
| Active gameplay-relevant localized lights per client view | 8 |
| Shadow-casting dynamic lights per client view | 2 |
| Cosmetic dynamic lights per client view | 24 |
| Simultaneous temporary-light particles per client view | 40 |
| Consequential visibility/targeting line-of-sight checks per operative per second | 10 |
| Global four-operative line-of-sight checks per second | 40 |
| Temporary-light lifetime | 1–60 seconds |
| Radius coverage | 0.1–64 studs |
| Forward-cone range | 0.1–64 studs |
| Forward-cone angle | 1–120 degrees |

`GameplayLightDescriptorValidator.validate` is side-effect free and uses this fixture-locked first-failure order: malformed descriptor, invalid source identity, invalid source type, unknown visibility profile, invalid activation state, invalid timestamp, invalid lifetime, invalid coverage, then invalid ownership fields. `BudgetExceeded` and `StaleTransition` are reserved stable rejection vocabulary for later bounded owners; this descriptor-local validator does not inspect runtime state or globally enforce budgets.

Gameplay lighting is exclusively server-authored truth. The server owns light identity, source type, gameplay profile, activation and expiry, and approved coverage descriptors. A client may later submit only narrowly shaped intent. A client never submits authoritative radius, cone, profile, expiry, or visibility outcome. Rendered brightness, pixel luminance, post-processing, client `Lighting` properties, client-created lights, and local raycasts are never sampled for gameplay authority. Cosmetic intensity, flicker, color, bloom, and shadows remain non-authoritative unless a later task promotes one through an explicit bounded contract.

LK-0401 adds no light objects, rendering, runtime ownership, activation resolution, remotes, controllers, spatial queries, discovery, targeting integration, temporary-light spawning, flashlight behavior, squad aids, or P5 behavior. Those concerns remain deferred to their ordered P4 tasks.

### Shared perception, disclosure, and memory contract

LK-0402 defines the pure, unintegrated shared contract layer in `src/shared/Perception` and the frozen `src/shared/Config/PerceptionConfig.luau`. Its stable vocabularies are deliberately separate:

- perception: `Unknown`, `Suspected`, `Observed`;
- disclosure: `Hidden`, `Disclosed`;
- memory: `None`, `Remembered`;
- observation confidence: `Low`, `Medium`, `High`;
- observation source: `DirectSight`, `TeammateInformation`, `AuthoredObjective`;
- rejection reasons: `InvalidRecord`, `InvalidEntity`, `InvalidSource`, `InvalidDisclosure`, `InvalidPerception`, `InvalidMemory`, `InvalidConfidence`, `InvalidStateCombination`, `InvalidTimestamp`, `StaleObservation`.

`Unknown` means no qualifying perception, `Suspected` means a possible presence without confirmed observation, and `Observed` means confirmed observation. `Hidden` and `Disclosed` describe only whether the server permits a recipient to receive the fact. `None` and `Remembered` describe only whether the fact is retained as remembered knowledge. Confidence is categorical rather than numeric. `Unknown` cannot carry `High` confidence or `Remembered` knowledge, and `Remembered` requires `Suspected` or `Observed`; `Hidden` does not by itself erase remembered knowledge. These states do not encode rendering, gameplay visibility, targeting eligibility, or line of sight, and no accepted combination independently grants target eligibility.

Gameplay lighting is not an observation source. Server-known gameplay-light coverage, authoritative spatial facts, and consequential server line of sight are inputs to the later LK-0403 visibility resolver; only an accepted later sight result may produce a `DirectSight` observation. Being inside `Dim` or `Lit` coverage never independently observes, discovers, discloses, or identifies an entity. `TeammateInformation` reports only an approved teammate-provided fact and does not establish direct line of sight or targeting permission. `AuthoredObjective` reports objective disclosure information only and never establishes hostile sight or targeting permission. `DirectSight` is still only a record source: LK-0403 must prove visibility and line of sight before a later owner creates it.

The public types are `PerceptionStateId`, `DisclosureStateId`, `MemoryStateId`, `ObservationConfidenceId`, `ObservationSourceId`, `ObservationRecord`, `PerceptionEvaluation`, and `PerceptionRejectionReasonId`. An `ObservationRecord` contains only an observed entity identity, the four independent state/source IDs, categorical confidence, and its server observation timestamp. It contains no runtime object, transform, rendered state, spatial result, targeting state, or recipient object.

The frozen initial configuration bounds a future owner to 32 remembered observations per operative and defines a 30-second maximum observation-age placeholder. It also repeats the supported perception and confidence IDs as contract values. These numbers are conservative placeholders, not playtested gameplay tuning; forgetting, decay, record ownership, and cleanup are not implemented here.

`PerceptionContractsValidator.validate(record, evaluationServerTimestamp)` is side-effect free. The caller supplies an authoritative server timestamp so age validation requires no clock or timer. Its fixture-locked first-failure order is malformed record, invalid entity, invalid source, invalid disclosure, invalid perception, invalid memory, invalid confidence, invalid state combination, invalid timestamp, then stale observation. An observation is stale only when its age is greater than the configured maximum; the exact boundary remains valid.

The server owns observation creation, entity identity, source classification, disclosure, perception, memory, confidence, and both timestamps supplied to validation. Clients cannot author or refresh an observation. The contract performs no runtime lookup, visibility resolution, discovery transition, memory decay, spatial query, line-of-sight test, raycast, replication, rendering, or targeting decision. Hearing and all enemy-AI perception sources remain deferred.

### Pure visibility resolver

LK-0403 adds the pure, unintegrated `VisibilityResolver.resolve(facts)` boundary in `src/shared/Perception`. Despite its shared location, only authoritative server-derived facts may be supplied. `VisibilityEvaluationFacts` contains observer and candidate string identities, observer perception eligibility, candidate category/presence/life/targetability, relationship, normalized nested illumination facts (environmental visibility profile and qualifying bounded local-light coverage), normalized nested spatial facts (squared distance, a server-derived perceptual region, and consequential line of sight), and current disclosure. It contains no instance, character, humanoid, player, camera, light object, renderer result, raw geometry, client claim, timestamp, observation, memory record, weapon state, or target selection.

The frozen resolver vocabulary adds entity categories `Operative`/`Hostile`/`Objective`, relationships `Friendly`/`Hostile`/`Neutral`, and perceptual regions `Forward`/`Peripheral`/`Outside`. Input rejection is separate from a valid non-visible decision. The fixture-locked rejection order is malformed facts, observer identity, candidate identity, self-evaluation, observer state, candidate state, relationship/category, visibility profile, spatial container, region, illumination fact, squared-distance fact, line-of-sight fact, then disclosure fact. Valid evaluations use `OutsidePerceptualRegion`, `OutsideVisibilityRange`, `InsufficientIllumination`, `NoLineOfSight`, `PeripheralOnly`, `NotDisclosedForTargeting`, `RelationshipNotHostile`, `CandidateUntargetable`, or `ObservedTargetingVisible` as their decision reason.

Initial forward visibility ranges are explicitly prototype perception values, not firearm ranges: 24 studs for `Dark`, 32 for `Dim`, and 64 for `Lit`. `Dark` requires qualifying local-light coverage for forward observation; line of sight alone cannot overcome darkness. `Dim` permits bounded forward observation without an additional local-light contribution. `Lit` permits normal bounded forward observation. All three still require a gameplay-present living candidate, an in-range forward region, and consequential line of sight for `Observed` and `DirectSight` eligibility. The resolver consumes already-resolved light coverage and never evaluates a `GameplayLightDescriptor` volume.

Forward qualifying sight yields `Observed`, gameplay visibility, and eligibility for a later owner to create a `DirectSight` record. `Dim` uses `Medium` confidence; qualifying `Dark` and `Lit` use `High`. Peripheral presence yields at most low-confidence `Suspected`, never gameplay visibility, direct sight, or targeting visibility. Outside-region or out-of-range candidates remain low-confidence `Unknown`. Qualifying light coverage is never an observation source and creates no observation or disclosure record.

Targeting visibility is a narrower output. It requires current gameplay visibility and line of sight, `Disclosed`, the `Hostile` category and relationship, and targetability. Hidden, remembered without current sight, stale, suspected, peripheral-only, teammate-information-only, authored-objective, and renderer-only facts never become target-visible. Even `isTargetingVisible = true` is only an input to the unchanged P2 validator: P2 operative state, range, ammunition, readiness, cadence, selection, firing, obstruction, and damage rules remain independent and authoritative.

The resolver returns a newly frozen `VisibilityResolution` containing validity, gameplay visibility, perception state, confidence, direct-sight observation eligibility, targeting visibility, and exactly one rejection or decision reason as applicable. It creates and mutates no observation, disclosure, memory, candidate, selection, or firing state. Runtime spatial classification, light-coverage ownership, consequential raycasts, replication, client presentation, targeting integration/revalidation, rendering, tools, UI, and enemy perception remain deferred.

### Server discovery and bounded memory runtime

LK-0404 adds the unbootstrapped server-only `DiscoveryMemoryService` in `src/server/Systems`. Its narrow API is `start`, `stop`, `registerRecipient`, `unregisterRecipient`, `applyVisibilityResolution`, `removeObservedEntity`, `readRecipientSnapshot`, `subscribeRecipient`, and the scheduler-facing `evaluateExpiriesAt`. The commit boundary accepts a recipient identity, expected observed identity, authoritative LK-0403 candidate facts and matching accepted resolution, plus a server timestamp. It re-runs the pure resolver only to validate the supplied fact/result pair and identity correlation; it performs no visibility calculation, spatial query, raycast, renderer query, or light lookup. No client route can call the commit boundary.

Each operative has an isolated table keyed by observed entity identity. Qualifying accepted forward sight creates a server-authored `Disclosed`/`Observed`/`None` record with `DirectSight`, resolver confidence, and the authoritative timestamp. Loss of qualifying sight changes an existing current record to explicitly stale `Remembered` information without refreshing its observation timestamp. The record expires only after `PerceptionConfig.MaximumObservationAgeSeconds`; the exact age boundary remains retained. A new qualifying sight result replaces or refreshes it. Peripheral-only `Suspected` results create no entity-specific record because the canonical contracts do not yet represent anonymous suspicion; exact hostile identity remains fail-closed.

Remembered records are position-free: no transform, `Vector3`, location, direction, or invented quantization policy is stored. Each recipient retains at most `MaximumRememberedObservationsPerOperative` remembered records. Expired records are removed first, then the oldest observation, with observed entity ID as the stable tie break. Current observations are not evicted to preserve stale memory. One cancellable earliest-expiry timer owns cleanup, revalidates generation, record identity, revision, and expiry, and is cleared on teardown; there is no task or loop per observation.

Recipient snapshots and subscription changes are defensive copies containing only disclosed record identity, perception/disclosure/memory state, confidence, source, observation/expiry timestamps, and revision. Revisions are monotonic per recipient and advance once only when that recipient-visible state changes. Equivalent replay is silent, older timestamps fail closed, and a cancelled stale expiry cannot delete refreshed sight. Removing a recipient affects only that recipient; removing an observed entity clears it for every recipient; stop clears all records, listeners, and scheduling state. No RemoteEvent or RemoteFunction was added, so replication and client presentation remain deferred. Clients cannot create, refresh, preserve, or upgrade discovery, and records carry no targetability permission.

Production visibility/raycast callers, gameplay-light lookup by coverage, bootstrap integration, replication/presentation, tools, UI, targeting integration, and all enemy AI remain deferred and unstarted.

### Server gameplay-lighting runtime

LK-0405 adds the unbootstrapped server-only `GameplayLightingService` in `src/server/Systems`. Its narrow API is `start`, `stop`, `registerLight`, `activateLight`, `deactivateLight`, `removeLight`, `readSnapshot`, `subscribe`, and the scheduler-facing `evaluateExpiriesAt`. Registration accepts a server-authored LK-0401 descriptor, rejects duplicate light identities, validates the source identity, source type, gameplay profile, inactive initial state, lifetime fields, bounded coverage, and ownership, then copies its definition. Callers cannot mutate the registered definition or authoritative activation state through retained input tables, snapshots, or subscriber payloads.

The public runtime record contains only light ID, source ID, gameplay visibility profile ID, activation state, activation timestamp, expiry timestamp, and revision. It stores no Roblox `Light`, part, attachment, color, brightness, shadow, render, or spatial object. Permanent activation has no expiry. Approved temporary activation requires a configured 1–60 second lifetime; other registered sources may be permanent or use the same bounded timed lifecycle. Manual deactivation clears activation timing, expiration marks the record `Expired`, a later authoritative activation may reactivate it, and removal deletes the registration so the identity can be explicitly replaced. Exact duplicate activation and repeated deactivation are silent. Older or same-timestamp conflicting transitions fail closed as `StaleTransition`.

One cancellable earliest-expiry timer owns all timed lights. It selects equal deadlines by stable light ID, and every callback revalidates the scheduler generation, light identity, record revision, active state, and expected expiry before evaluating expiration. Refreshing or replacing an activation cancels and reschedules that centralized owner, so an old callback cannot expire the refreshed record. Stop cancels scheduling and clears registrations, subscribers, and revisions; restart begins empty.

The runtime applies `GameplayLightingConfig.MaximumActiveGameplayLocalizedLightsPerClientView` as a conservative global active gameplay-light ceiling until a later spatial/client-view owner exists. The ninth active light is rejected deterministically with `BudgetExceeded`; refreshes never consume another slot and there is no overflow path. Registration, activation, deactivation, expiration, refresh/replacement, and removal increment revision only when copied consumer-visible state changes. Equivalent replay, duplicate activation, duplicate deactivation, and repeated expiry cleanup do not advance revisions or notify subscribers.

LK-0405 itself performs no coverage evaluation and does not call LK-0403 or LK-0404. LK-0406 supplies the first narrow production consumer described below; consequential line of sight, discovery, targeting, temporary item spawning, particles, AI, combat, and broader lighting integration remain deferred.

### Approved personal flashlight slice

LK-0406 production-connects exactly one manually toggled personal flashlight. `PersonalFlashlightService` owns operative/player association, eligibility, deterministic `personal-flashlight:<operativeEntityId>` light identity, validation, cooldown, revision, life-state shutdown, and cleanup. It registers one LK-0401 `ApprovedPersonal`/`Lit`/`ForwardCone` descriptor per eligible operative through `GameplayLightingService`; prototype tuning is centralized at 48 studs, 50 degrees, and a 0.25-second toggle cooldown. The only client intent is one boolean requested state. The server derives operative identity, ownership, life state, time, descriptor, light identity, and budget outcome; malformed or extra payloads fail closed.

The server-only coverage helper uses authoritative character-root position and facing plus the canonical descriptor. Its pure point qualification means only “inside the active bounded cone.” It performs no raycast and creates no line of sight, observation, disclosure, discovery, hostile identity, or target eligibility. Rendered beam pixels and camera direction are absent from gameplay authority. VisibilityResolver and DiscoveryMemoryService integration remain deferred.

The owner client predicts presentation immediately on F, gamepad Y, or the readable touch action, then reconciles to an owner-only safe state/revision payload; stale revisions and malformed payloads are ignored, while rejection restores authority without flashing. A local-only attachment and shadow-disabled SpotLight provide restrained cosmetics, an ON/OFF text label avoids color-only communication, and `ReducedPresentationIntensityScale` provides a bounded reduced-intensity path. No other operative state is broadcast because P4 does not yet have disclosure-aware teammate replication; remote-player flashlight cosmetics are deferred.

Incapacitation and death force authoritative deactivation, removal/disconnect and squad failure remove the gameplay light, revival never reactivates it, and teardown disconnects listeners and destroys the local presentation plus the Studio-only read harness. The harness lives only in ServerStorage and has no mutation or client route. Two-client Studio validation directly observed two inactive registrations, Player1-only activation at revision 1, exactly one active gameplay light, Player2 remaining inactive, malformed cross-operative/geometry/target payload rejection without revision change, forced inactive revision 2 on incapacitation, zero active contribution afterward, local ON/OFF presentation, and clean final client/server startup logs. Two live revive attempts missed the P3 completion window and reached Dead; the deterministic fixture, not a claimed live observation, verifies that a valid revival leaves the flashlight off pending a new toggle. Disconnect and replacement cleanup remain fixture-validated in this slice.

## Perception and discovery

Player natural sight is the local operative's forward readable region plus a small, deliberately weaker peripheral region. Darkness narrows reliable hostile identification before it removes basic movement readability. Peripheral awareness may disclose a low-confidence presence or direction, but does not grant a targetable identity. Teammate awareness must retain enough information to regroup: a teammate may be disclosed through an approved proximity, direct-sight, or active squad-tool rule; distant teammate state is not silently global. Objective awareness is deliberately independent: the current objective may provide a server-approved direction/marker policy even if the objective actor is not visible.

Discovery is per operative, not global squad omniscience. A currently seen hostile can be disclosed as current. On loss of sight, the server may retain a short-lived remembered location/status that is explicitly stale, quantized, and expires; it cannot refresh without a new qualifying perception event. P4 must decide the exact memory duration/precision in its perception-contract task, using conservative defaults until playtested. Hidden enemies produce no model, marker, target, event, sound label, or replicated identity merely because they exist.

Enemy perception is a separate later runtime concern and follows this vocabulary: hearing is a server-derived event with source, radius/profile, and time; sight is a server line-of-sight and range/profile result; remembered location is stale server-owned last-known information; investigation is an AI decision to examine a bounded remembered/heard location. Hearing does not imply sight, sight does not imply persistent knowledge, and investigation does not imply an enemy knows an exact player position. P4 may define the contract but does not implement enemy AI.

## Squad-tool decision space

P4 specifies alternatives; implementation selects only the smallest playtested set.

| Tool/policy | Benefit | Cost / information risk |
| --- | --- | --- |
| Flashlight beam | Strong forward navigation and deliberate exposure tradeoff. | Can flatten darkness, demand shadow work, and reveal too much if its gameplay volume is too broad. |
| Shoulder lamp | Keeps teammates readable while moving. | Reduces isolation and may remove the value of formation. |
| Glow stick | Leaves a regroup/trail anchor. | Creates persistent state, visual clutter, and possible navigation trivialization. |
| Laser pointer | Precise cooperative callout without global UI. | Can become a long-range information channel. |
| Ping | Fast accessible callout and recovery from separation. | Must be rate-limited, expire, and never reveal undiscovered hostiles. |
| Voice indicator | Supports speaking players and direction finding. | Requires a non-voice equivalent; must not disclose remote teammate positions globally. |
| Minimap | Familiar orientation. | Default policy: absent in P4; it would strongly undermine uncertainty unless separately designed. |
| Compass | Direction without map revelation. | Candidate fallback for objective/squad orientation; needs an accessible visual alternative. |

The default implementation choice is not decided by this plan. Every selected tool needs an information-disclosure rule, a server-owned state if it affects gameplay, rate/placement/lifetime limits, and an equivalent non-audio cue where necessary.

## Ownership, synchronization, and security

The server owns visibility profiles, authored gameplay-light state, light activation/expiry, line-of-sight facts used for consequential decisions, per-operative discovery and memory, target eligibility, and any later enemy perception. It replicates only the minimum recipient-specific disclosed snapshot: current/stale classification, quantized permitted location/direction, expiry where presentation requires it, and approved tool state. It never replicates a hidden enemy's identity, exact transform, light membership, targeting candidacy, or perception state to an ineligible client.

Clients may predict only local cosmetic beam motion, toggles pending acknowledgement, local rendering, and presentation of already disclosed data. Cosmetic light flicker and animation may be client-local. A client request may express a narrowly shaped intent (for example, toggle an owned approved tool or place a bounded ping); the server derives sender identity and validates state, cooldown, inventory/operation eligibility, position, line of sight where required, and expiry. Client rendering changes, brightness changes, modified light instances, local raycasts, removed darkness, and fabricated discovery data cannot make a target legal, reveal an enemy, or alter server perception.

## Performance and accessibility

Server work is event-driven or bounded-rate. Initial targets are no more than 10 consequential visibility/targeting line-of-sight raycasts per operative per second, plus immediate revalidation on a requested consequential action; a global cap of 40 such raycasts per second for four operatives is the initial profile target. Discovery updates should be coalesced and sent only on state changes, with bounded memory records and cleanup on expiry/operation teardown. Raycast, light, and disclosure budgets must be measured against representative P5 hostile load before P5 expands them.

Accessibility settings are optional presentation aids, not ways to acquire new game facts: brightness/gamma adjustment, high-contrast friendly/objective/tool outlines only after permitted disclosure, colorblind-safe palettes with shape/icon redundancy, subtitles and direction indicators for already audible/approved events, reduced flicker, and configurable non-audio ping/voice equivalents. Settings must not increase gameplay visibility range, disclose hidden enemies, turn stale memory current, bypass line of sight, or enable targeting.

## Roadmap and dependency graph

`LK-P4-PLAN-001` is this completed planning task. The implementation sequence is intentionally narrow and reviewable:

```text
P4-PLAN-001
 ├─ 0401 lighting contracts ─┐
 ├─ 0402 perception contracts ├─ 0403 visibility resolver ─ 0404 discovery runtime ─ 0408 security validation
 │                            └─ 0405 lighting runtime ─ 0406 chosen flashlight/tool ─ 0407 squad navigation tools ─ 0408
 └─ P2 targeting compatibility ────────────────────────────────────────────────────────────────────────────────────┘
```

Execution order: contracts first, then the pure visibility resolver, then independent lighting/discovery runtime owners, then exactly the selected tool slices, then adversarial and integration validation. `0406` and `0407` may proceed after their respective contracts/runtime dependencies, but no task may add an unapproved tool category or P5 enemy behavior.

## Acceptance outline and exclusions

P4 is complete only when a 1–4 player representative operation demonstrates readable navigation and regrouping under darkness; server-owned visibility/discovery prevents hidden-information targeting; selected aids have bounded, accessible disclosures; performance budgets are measured; and P1–P3 movement, life, and P2 targeting regress cleanly. Each roadmap task owns fixtures or a documented manual validation path appropriate to its scope.

P4 explicitly excludes implementation of lighting, flashlights, fog, shaders, enemy AI, perception, discovery, rendering, UI, networking, particles, post-processing, raycasts, performance optimizations, Studio prototypes, and P5 work in this planning PR. Future implementation tasks may introduce only their stated slice after review.
