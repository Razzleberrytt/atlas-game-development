# Atlas Cross-System Traceability — Version 2.7

This matrix answers four questions for every critical player-facing fact: **who owns the gameplay truth, who transports it, who presents it, and what evidence proves the whole row works?**

A row is not accepted because one column works in isolation.

| Promise / state | Mechanical owner | Replication / semantic state | Presentation owner | Rollout / evidence gate |
|---|---|---|---|---|
| Player health/life | Health/life-state server owner | health/life current state + committed events | HUD / combat feedback | E3 damage, incapacitation/death/recovery; respawn gauges return to baseline |
| Weapon fire/ammo/reload | authoritative weapon/combat owner | weapon current state + committed fire result | weapon/viewmodel + HUD | E3 cadence/ammo/reload truth; three-respawn viewmodel ownership stable |
| Enemy life/target/pressure | enemy director/domain owner | enemy/encounter semantic state | enemy presentation | E3 target/attack readability; E4 attribution/cleanup |
| Encounter/round phase | operation/encounter lifecycle owner | `round.phase` semantic key | objective/HUD presentation | before/after rate diff; five-reset state rate/gauges return to baseline |
| Objective | mission/objective domain owner | `objective.current` semantic key | objective controller | unchanged publishes suppress; late join reconstructs current objective |
| Route guidance | mission/route semantic owner | `route.target` semantic key | `RouteGuidePresentationController` via shared Highlight registry | one owner; stream-out/rebind; no broad target |
| Landmark accent | world/mission semantic owner | `landmark.active_set` semantic key | `LandmarkAccentPresentationController` via shared Highlight registry | one owner; route/landmark priority resolved centrally; no broad target |
| Horde/threat state | horde/enemy pressure owner | dedicated semantic key(s), not frame replay | threat/HUD presentation | producer rate bounded by mutation; no queue/discard warnings |
| Status/mark outline | ability/status owner | keyed status current state | status presentation via shared Highlight registry | delayed-ready/late-join reconstructs; expiry/death/reset cleanup |
| Support/shield relationship | modifier/support owner | keyed source-target state | support-link presentation | source/target/reset cleanup; no competing Highlight primitive |
| Secret/discovery clue | discoverable/objective owner | eligible semantic state/event | secret presentation | audience correct; stream-out does not equal completion; expiry/reset cleanup |
| Match/result outcome | terminal result owner | committed result snapshot | debrief/result UI | exactly one committed outcome; E4 disconnect/race matrix |
| Run-build/relic state | run-build server owner | bounded owner-specific snapshot/delta | relic/build UI | owner isolation; replay/reset teardown; no client-authored grant |
| Item/reward ownership | transaction/inventory/profile owner | owner-only inventory/reward state | reward/inventory UI | deterministic/idempotent grant; replay returns same result |
| Highlight Instance | none | none | **shared Highlight lease registry only** | registry constructor count = 1; direct server Highlight creation = 0; broad violations = 0 |
| Viewmodel | none | weapon semantic/current state only | one viewmodel owner | three-respawn owner count stable; old model destroyed |
| Camera effect | none | none | one named camera modifier stack | reset/respawn modifiers return to baseline |
| Animation marker listener | none | none | owning animation/track scope | 100 plays do not increase marker-listener count; mechanics remain server-owned |
| Streaming rebind | gameplay semantic owner remains authoritative | stable semantic ID | relevant presentation controller | local Instance loss suspends visual only; returning Instance rebinds correctly |

## Legacy `HordeNetwork.State` migration mapping

Every remaining legacy producer must map to a semantic row before it is removed.

Minimum initial keys:

```text
round.phase
objective.current
route.target
landmark.active_set
horde.pressure
```

If a field has no current consumer or gameplay/presentation owner, prove it is dead and delete it rather than migrating it.

## Ownership laws

1. Mechanical truth remains server-owned even when a client effect is predictive.
2. One physical `RemoteEvent` may transport multiple facts temporarily, but each current fact requires a semantic key.
3. Current state is not an event history. It is reconstructed from authoritative present facts.
4. Presentation primitives have one owner. Domain controllers request presentation from the owner instead of allocating competing primitives.
5. Streaming changes local availability, not gameplay truth.
6. Reset/respawn/operation teardown must release the scope that created connections, viewmodels, camera modifiers, leases, marker listeners, and transient effects.

## Acceptance rule

A row is accepted only when:

```text
mechanical owner produces correct authoritative fact
+ replication preserves the required current state/audience
+ presentation communicates the fact without conflicting ownership
+ cleanup returns to baseline
+ applicable late-join/streaming/multiplayer cases pass
+ evidence is recorded at the claimed E-level
```

A beautiful cue over incorrect mechanics is a failure. Correct mechanics behind stale or contradictory presentation are also a failure.
