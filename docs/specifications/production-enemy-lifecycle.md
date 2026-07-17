# Production enemy lifecycle (P5-0104)

P5-0104 replaces the Studio-only stationary hostile fixtures used by Operation Blackwater Relay with the smallest production-connected ordinary enemy lifecycle. The milestone establishes one server-owned enemy archetype that can spawn fairly, acquire an operative, pursue, attack through the existing operative-life authority boundary, receive authoritative firearm damage through the existing P2 combat boundary, die, and clean itself up.

This is a vertical slice, not the final horde director. It must prove that one to four players can face real moving pressure during the existing operation without introducing P6 scarcity, P7 classes, P8 multi-objective content, P9 special enemies, or P10 replay/results work.

## Scope

Implement exactly one ordinary enemy archetype, provisionally named `Shambler`.

The production slice owns:

- stable enemy lifecycle/state contracts and authored tuning
- a server-only enemy registry
- bounded fair spawning from mission-authored definitions
- deterministic target selection
- bounded pursuit and path refresh
- server-authoritative contact attacks
- authoritative firearm-damage integration
- death, removal, and teardown
- replacement of Blackwater Relay's Studio-only escalation dependency
- representative one-, two-, and four-player validation

The slice does not own:

- bosses or special enemies
- loot or ammunition drops
- hearing, scent, group tactics, flanking, or stealth AI
- procedural operation generation
- unlimited hordes or pooled streaming architecture
- polished animation, audio, gore, or final models
- persistence, rewards, matchmaking, replay, or progression

## Authority and trust boundary

The server is authoritative for every enemy fact:

- identity and archetype
- lifecycle state
- spawn acceptance and spawn transform
- health and death
- selected target
- navigation destination
- movement intent
- attack readiness and cadence
- attack range and damage
- cleanup and removal

No client remote may create an enemy, select its target, move it, declare a hit, set health, apply damage, accelerate cadence, or remove it.

Client-visible Roblox instances are presentation and physics adapters only. Their attributes may disclose bounded state, but editing those attributes or Humanoid properties must not alter domain truth.

## Stable vocabulary

### Archetype

- `Shambler`

### Lifecycle state

- `Spawning`
- `Active`
- `Dead`
- `Removed`

Legal transitions:

`Spawning` → `Active` → `Dead` → `Removed`

`Spawning` may transition directly to `Removed` only when creation fails or the service stops before activation.

No transition leaves `Dead` except cleanup to `Removed`.

### Activity state

Activity is separate from lifecycle:

- `Idle`
- `Pursuing`
- `Attacking`

Only an `Active` enemy may hold an activity state.

### Spawn rejection precedence

Validate in this stable order:

1. `ServiceStopped`
2. `InvalidDefinition`
3. `DuplicateEntityId`
4. `CapacityExceeded`
5. `OutsidePlayableBounds`
6. `TooCloseToLivingOperative`
7. `VisibleToLivingOperative`
8. `BlockedSpawnVolume`
9. `CreationFailed`

All failures leave registry and world state unchanged.

## Configuration

Create one shared configuration home for the ordinary enemy. Initial prototype values may be tuned during Studio validation, but must remain explicit and fixture-covered.

Recommended starting values:

- maximum health: 100
- walk speed: 9 studs/second
- acquisition radius: 150 studs
- target-loss radius: 190 studs
- attack range: 4.5 studs
- attack damage: 20
- attack cadence: 1.35 seconds
- path refresh interval: 0.75 seconds
- direct-move refresh interval: 0.2 seconds
- stuck evaluation window: 2.5 seconds
- minimum fair spawn distance: 55 studs from every admitted living operative
- maximum active enemies: 24
- corpse lifetime: 5 seconds
- server simulation tick: no faster than 10 Hz

The maximum active count is a hard server budget, not a target population.

## Enemy registry

Implement one focused `EnemyLifecycleService` as the production owner.

For every enemy, store a private record containing at least:

- entity ID
- archetype ID
- lifecycle state
- activity state
- current health
- selected operative entity ID, if any
- spawn timestamp
- last attack timestamp
- last path request timestamp
- current path generation
- model/reference adapter, if created
- cleanup deadline, if dead
- monotonic revision

Public read APIs return copied snapshots only.

Registry requirements:

- duplicate IDs are rejected
- active-enemy capacity is enforced before world creation
- partial creation is rolled back
- stale path completions cannot replace a newer path generation
- stale attacks cannot commit after target/lifecycle invalidation
- death commits exactly once
- stop destroys every owned model and connection
- player disconnect does not destroy enemies or leave stale target references

## Spawn definitions and fair spawning

Mission-authored escalation supplies candidate definitions containing only trusted server data:

- entity ID
- archetype ID
- authored candidate position
- optional facing direction
- operation/wave correlation ID

The lifecycle service revalidates every definition.

A spawn is fair only when:

- the point is inside the authored playable bounds
- it is at least the configured minimum distance from every admitted `Alive` operative
- it is not directly visible to an admitted living operative under a conservative server check
- a bounded overlap check finds adequate free volume
- active-enemy capacity remains available

The first implementation may use a conservative ray/visibility adapter and authored fallback candidates. If no candidate is fair, the wave records a bounded failed spawn rather than forcing an unfair enemy into existence.

Do not spawn directly behind a player merely because darkness hides the renderer. Gameplay fairness uses server spatial facts.

## Target selection

Only admitted `Alive` operatives are legal targets.

At each bounded evaluation:

1. retain the current target when it remains legal and within target-loss radius
2. otherwise select the closest legal operative inside acquisition radius
3. break equal-distance ties by stable operative entity ID
4. clear the target when no candidate is legal

Clients cannot influence candidate ordering.

`Incapacitated` and `Dead` operatives are not selected by this ordinary archetype. Finishing behavior remains excluded.

## Pursuit

Pursuit must be bounded and resilient rather than sophisticated.

- Use Roblox pathfinding or an injected navigation adapter on the server.
- Refresh paths no faster than the configured interval.
- Increment a path generation for every new request.
- Ignore completions from older generations.
- Follow a bounded number of waypoints.
- Repath when the target moves materially, the path ends, or the enemy is stuck.
- Fall back to direct `Humanoid:MoveTo` only when the target is close and the direct route is accepted by the navigation adapter.
- Never teleport an active enemy to repair navigation.
- If no path is available, remain active, clear unsafe movement, and retry after the bounded interval.

The service must not create one scheduler per enemy. Use one service-owned heartbeat/update connection with budgeted work.

## Contact attack

An attack may commit only when all conditions are true at the same server evaluation boundary:

- enemy lifecycle is `Active`
- enemy activity/target correlation is current
- target is registered and `Alive`
- both positions are readable from server-owned adapters
- distance is within configured attack range
- cadence deadline has elapsed
- line of contact is not blocked under the attack adapter

Accepted attacks call the existing production operative ordinary-damage entry point with a server-generated correlation/event ID. The enemy service never mutates operative health directly.

The attack event ID must be unique and deterministic enough for the existing processed-event protection. A rejected or duplicate damage commit does not consume a second attack automatically within the same cadence window.

## Receiving firearm damage

P2 remains the authority for firearm legality, ammunition, cadence, obstruction, and hit resolution.

The enemy lifecycle service exposes a server-only damage adapter that:

- accepts an already-authorized P2 hit correlation
- verifies the enemy exists and is `Active`
- verifies the expected enemy revision/correlation when supplied
- rejects duplicate processed shot IDs
- subtracts finite positive damage with clamping
- commits `Dead` at exactly zero
- invalidates targeting and movement on death
- schedules bounded corpse cleanup

No client can call this adapter.

P2 must stop using the Studio fixture health table for production mission enemies. The smallest bridge should preserve all existing P2 fixtures and development-harness behavior outside production mission enemies.

## Roblox model adapter

Use a primitive placeholder model suitable for Studio playtesting:

- one Model
- Humanoid
- HumanoidRootPart
- simple visible body parts
- server network ownership where possible
- collisions configured to avoid launching operatives
- attributes for entity ID, archetype, lifecycle, activity, and revision as disclosure only

Final authored model, rig, animation, audio, and effects are deferred.

The adapter must fail closed when required instances are missing or replaced. Domain state remains authoritative.

## Blackwater Relay integration

Replace `MissionDirectorService`'s production escalation dependency on `AutomaticCombatDevelopmentHarness.spawnMissionHostile` with the production enemy lifecycle API.

Keep the three existing authored waves and entity IDs unless a configuration defect requires a minimal correction.

Requirements:

- every wave is requested exactly once
- every requested definition is independently validated
- partial wave acceptance is allowed and recorded
- mission flow never blocks forever because one spawn candidate is unfair
- mission resolution stops new wave requests
- already-spawned enemies are cleaned up when the mission/service tears down
- the Studio development harness remains available only for its original isolated P2 fixtures and must not duplicate production mission enemies

## Scheduling and performance

Use one service-owned update connection.

Budget work explicitly:

- no more than 10 simulation evaluations per second
- path requests rate-limited per enemy
- target selection may be staggered across enemies
- maximum active count enforced before creation
- dead models removed after bounded corpse lifetime
- no per-enemy Heartbeat connections
- no per-enemy task loops
- no client remotes required for authority

Representative measurements must record at minimum:

- active enemies
- total owned models/base parts
- service connections
- scheduler/update connections
- path requests per second
- target evaluations per second
- attacks per second
- cleanup counts

Measure one-, two-, and four-player operation runs with representative wave pressure.

## Failure and cleanup

The service must handle:

- target death/incapacitation
- target disconnect
- character replacement
- enemy model deletion or corruption
- path failure and stale completion
- mission resolution
- service stop/restart in fixtures
- duplicate spawn definitions
- duplicate damage correlations
- capacity overflow

At teardown:

- disconnect the single update connection
- cancel/ignore pending path generations
- destroy all owned models
- clear all registry records and processed correlations
- leave zero owned enemies, connections, or timers

## Validation

Add focused fixtures for:

- frozen vocabulary and configuration bounds
- legal and illegal lifecycle transitions
- spawn rejection precedence
- fair-distance and visibility rejection
- duplicate IDs and capacity
- deterministic target selection and ties
- target retention and loss
- path-generation stale-result rejection
- attack range, cadence, obstruction, life-state, and stale-target rejection
- ordinary-damage adapter correlation
- firearm damage, duplicate shot rejection, exact-zero death, overkill, and immutable inputs
- corpse cleanup and stop cleanup
- Blackwater Relay wave integration without the Studio mission-hostile API
- source audit proving no client enemy-authority remote
- source audit proving no per-enemy scheduler/Heartbeat connection

Run all existing fixtures plus:

- StyLua check
- Selene
- Rojo sourcemap
- Rojo build
- one-client Studio operation path
- two-client Studio operation path
- representative four-player performance session when available

Manual Studio observations must include:

- whether pursuit reads clearly from the isometric camera
- whether spawn distance feels fair
- whether enemies navigate the forest routes without constant stalls
- whether contact attacks are readable and avoid unavoidable damage
- whether the three waves create escalation and recovery windows
- whether automatic combat can kill production enemies
- whether incapacitation, revive, squad failure, and extraction still work

## Acceptance boundary

P5-0104 is complete only when Operation Blackwater Relay uses production ordinary enemies from spawn through death and cleanup, with server-owned pursuit and attack, and all automated/build checks pass.

Do not claim completion based only on contracts or fixtures. A live Studio playthrough is mandatory because navigation and attack fairness cannot be established from repository analysis alone.

## Next P5 work

After P5-0104, decompose remaining P5 work into small milestones for authored horde-pressure scaling, recovery windows, and full security/performance validation. Do not begin P6 ammunition scarcity until P5 exit criteria are met.