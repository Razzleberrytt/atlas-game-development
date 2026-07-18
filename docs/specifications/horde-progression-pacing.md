# Horde Pressure and Run Progression Pacing v1

## Evidence

After progression, upgrades, and loot were consolidated into single authoritative owners, the unattended solo Studio sample produced a clean pacing signal:

- the operative was overwhelmed and the squad failed quickly;
- automatic combat still secured four confirmed kills;
- canonical Field XP reached `80 / 100` without producing the first upgrade;
- the original opening combined the baseline `EnemyDirectorService` wave with an additive five-enemy horde injection after only eight seconds.

The problem was not missing reward ownership. It was that likely-wipe pressure arrived slightly before the first run decision.

## Coupled target curve

The pressure and XP configurations are tuned as one curve:

1. Baseline EnemyDirector contact still begins in roughly nine seconds.
2. The additive horde injector waits 24 seconds, then begins with three enemies rather than five.
3. Four ordinary confirmed deaths award the first upgrade: `4 × 20 = 80 XP`.
4. A representative first-upgrade checkpoint at 45 seconds, 16 living enemies, and four kills remains below the `RISING` threat threshold of 25.
5. Later success raises threat more strongly through kill throughput, so the gentler opening still grows into severe and catastrophic pressure.
6. Later upgrade thresholds grow by `1.4×` so high-density combat does not produce choices faster than players can read and select them.

## Production tuning

### Additive horde pressure

| Value | Previous | Retuned |
| --- | ---: | ---: |
| Warmup | 8 s | 24 s |
| Base interval | 7 s | 10 s |
| Minimum interval | 2.4 s | 3.25 s |
| Base burst | 5 | 3 |
| Maximum burst | 16 | 12 |
| Threat per minute | 11 | 9 |
| Threat per living enemy | 0.55 | 0.40 |
| Threat per confirmed kill | 0.08 | 0.30 |

The canonical EnemyDirector remains unchanged. This pass removes opening pressure overlap rather than weakening enemy combat, health, speed, damage, population ceilings, special roles, or server authority.

### Run progression

| Value | Previous | Retuned |
| --- | ---: | ---: |
| XP per confirmed death | 20 | 20 |
| First threshold | 100 XP / 5 kills | 80 XP / 4 kills |
| Later threshold growth | 1.30× | 1.40× |

Field Intel remains a rare 40-XP physical reward and may accelerate the first choice. No additional XP source or pity award is introduced.

## Acceptance targets

A synchronized solo Studio run should confirm:

- first contact still occurs within 10–15 seconds;
- the player can usually secure four kills and receive one upgrade offer before the likely-wipe phase;
- the upgrade overlay has a readable selection window under active pressure;
- an unattended operative remains expected to fail rather than survive indefinitely;
- a participating solo player is not routinely wiped before seeing the first upgrade;
- pressure reaches severe territory around the middle of the run and approaches catastrophic territory during the late holdout;
- special-enemy behavior, ammunition scarcity, recovery loot, health, mission, and extraction contracts remain unchanged.

## Regression coverage

`HordeProgressionPacing.test.luau` loads both production configs and locks:

- four-kill first-upgrade pacing;
- the bounded 20–30 second additive-horde warmup;
- the three-enemy opening pulse;
- a pre-`RISING` first-upgrade checkpoint;
- mid-run escalation beyond the opening burst;
- late-run ten-plus-enemy pulses near the minimum cadence.

This is a first evidence-based retune, not final balance. Future changes should be based on synchronized solo and two-client playthrough measurements rather than isolated config edits.
