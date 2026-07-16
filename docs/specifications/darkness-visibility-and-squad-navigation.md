# P4 — Darkness, limited vision, and squad navigation

**Implementation status:** LK-0401 and LK-0402 complete; LK-0403 is next and remains unstarted.

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
- observation source: `DirectSight`, `TeammateInformation`, `AuthoredObjective`, `ApprovedGameplayLight`;
- rejection reasons: `InvalidRecord`, `InvalidEntity`, `InvalidSource`, `InvalidDisclosure`, `InvalidPerception`, `InvalidMemory`, `InvalidConfidence`, `InvalidTimestamp`, `StaleObservation`.

`Unknown` means no qualifying perception, `Suspected` means a possible presence without confirmed observation, and `Observed` means confirmed observation. `Hidden` and `Disclosed` describe only whether the server permits a recipient to receive the fact. `None` and `Remembered` describe only whether the fact is retained as remembered knowledge. Confidence is categorical rather than numeric. These states do not encode rendering, gameplay visibility, targeting eligibility, or line of sight, and none implies another without a later explicit resolver or runtime policy.

The public types are `PerceptionStateId`, `DisclosureStateId`, `MemoryStateId`, `ObservationConfidenceId`, `ObservationSourceId`, `ObservationRecord`, `PerceptionEvaluation`, and `PerceptionRejectionReasonId`. An `ObservationRecord` contains only an observed entity identity, the four independent state/source IDs, categorical confidence, and its server observation timestamp. It contains no runtime object, transform, rendered state, spatial result, targeting state, or recipient object.

The frozen initial configuration bounds a future owner to 32 remembered observations per operative and defines a 30-second maximum observation-age placeholder. It also repeats the supported perception and confidence IDs as contract values. These numbers are conservative placeholders, not playtested gameplay tuning; forgetting, decay, record ownership, and cleanup are not implemented here.

`PerceptionContractsValidator.validate(record, evaluationServerTimestamp)` is side-effect free. The caller supplies an authoritative server timestamp so age validation requires no clock or timer. Its fixture-locked first-failure order is malformed record, invalid entity, invalid source, invalid disclosure, invalid perception, invalid memory, invalid confidence, invalid timestamp, then stale observation. An observation is stale only when its age is greater than the configured maximum; the exact boundary remains valid.

The server owns observation creation, entity identity, source classification, disclosure, perception, memory, confidence, and both timestamps supplied to validation. Clients cannot author or refresh an observation. The contract performs no runtime lookup, visibility resolution, discovery transition, memory decay, spatial query, line-of-sight test, raycast, replication, rendering, or targeting decision. Hearing and all enemy-AI perception sources remain deferred. LK-0403 is next and remains unstarted.

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
