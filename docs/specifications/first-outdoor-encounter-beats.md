# BA-051 — First Outdoor Encounter Beats

**Status:** DATA-ONLY / DORMANT  
**Runtime activation:** No  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstOutdoorEncounterBeatConfig.luau`

## Purpose

BA-051 binds readable combat pacing to the three route-local encounter slots authored by BA-050 without creating a second combat, spawning, horde, elite, reward, or recovery authority.

The first outdoor approach now has an intentional escalation:

1. **Logging Road — orientation contact**
   - two Basic Exclusion Walkers;
   - one short authored wave;
   - ordinary/non-elite pacing intent;
   - short post-clear breather target.
2. **Campground — mixed mobility pressure**
   - one Basic, one Runner, one Crawler;
   - one readable mixed wave;
   - ordinary/non-elite pacing intent;
   - slightly longer post-clear breather target.
3. **Military Roadblock — pre-dungeon gate**
   - wave one: Basic + Runner;
   - wave two after a five-second authoring delay: Basic + Blight Spitter;
   - sole late-route elite-candidate pacing intent;
   - longest recovery target before the First Descent handoff.

Every authored wave remains capped at three enemies so the outdoor approach teaches and escalates rather than becoming a second dungeon.

## Canonical ownership

BA-051 reuses:

- `EnemyContracts.EnemyArchetypeIds` for enemy identity;
- `EnemyContracts.EnemySpawnSourceIds.AuthoredWave` as the existing authored-spawn vocabulary;
- `HordeExperienceConfig.Roles` for walker-role identity;
- `FirstOutdoorRouteConfig.EncounterSlotIds` for route attachment.

The data is intentionally not consumed by runtime yet.

### Elite placement boundary

The Military Roadblock is tagged only as a **late-route resolver candidate**. That is pacing intent, not an affix assignment.

BA-051 does not import, call, replace, or bypass `EliteAffixResolver`. The canonical server resolver remains responsible for deciding whether a legal enemy becomes elite and which compatible deterministic affix it receives. The first two outdoor encounters remain ordinary by authored intent.

### Recovery boundary

`PostClearRecoverySeconds` and `RecoveryIntentId` are authoring targets only. They describe the breathing room the route should preserve when it is integrated.

BA-051 does not:

- heal operatives;
- refill ammunition;
- spawn caches or pickups;
- pause or resume the EnemyDirector/HordeExperienceService;
- own clocks or encounter completion;
- grant rewards.

A later integration task must map these targets onto existing canonical runtime systems without creating a second recovery authority.

## Pacing targets

| Beat | Target duration | Post-clear recovery | Purpose |
|---|---:|---:|---|
| Logging Road | 20–35 s | 8 s | establish basic threat readability |
| Campground | 30–50 s | 10 s | teach mixed movement pressure |
| Military Roadblock | 45–70 s | 15 s | ranged/special escalation and reset before dungeon |

These values are content targets, not runtime guarantees. They intentionally leave substantial room inside the MVP's broader 5–10 minute first-run target for traversal, discovery, dungeon rooms, elite/boss resolution, rewards, and return flow.

## Validation

`games/living-kingdoms/tests/FirstOutdoorEncounterBeatConfig.test.luau` verifies:

- exactly one beat binds to each BA-050 encounter slot, in route order;
- all waves use the canonical `AuthoredWave` source vocabulary;
- every walker uses a canonical horde role;
- no boss content appears outdoors;
- the opening beat remains simple;
- the campground introduces Basic/Runner/Crawler mixed pressure;
- the roadblock introduces the Blight Spitter and remains the sole late-route elite candidate;
- per-wave population remains at or below three;
- duration targets escalate toward First Descent;
- the pre-dungeon beat keeps the longest recovery target;
- no raw Workspace path or reward source is authored.

Studio/manual verification is not required for this dormant content-definition task. Runtime pacing and feel remain part of the later integration/consolidated MVP Studio acceptance pass.
