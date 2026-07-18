# Horde-Horror Vertical Slice — Studio Playtest

## Launch

From the repository root:

```powershell
cd games/living-kingdoms
rojo serve
```

In Roblox Studio:

1. Open the Living Kingdoms place.
2. Connect the Rojo plugin to `localhost:34872`.
3. Confirm the Output window shows both horde bootstrap messages without red errors.
4. Run a one-player Play test first.
5. Run a two-client local server test after the solo pass.

## Opening-curve acceptance

The first-upgrade and first-wipe curve is tuned as one system. Record timestamps rather than relying only on general feel.

- first meaningful enemy contact: **8–12 seconds**;
- first horde-layer reinforcement: no earlier than **12 seconds**;
- first upgrade: exactly **four ordinary confirmed deaths / 80 Field XP**;
- active solo target: first upgrade appears roughly **45–75 seconds** into representative combat;
- an attentive solo player should normally have time to read and select the first upgrade before the opening pressure becomes lethal;
- an unattended automatic-combat smoke test should reach the first upgrade before wipe, but is not expected to complete the operation;
- after the opening minute, pressure must continue climbing toward the unchanged 24-enemy solo ceiling and severe late horde pulses.

Fail the tuning pass when first contact is late, when the player reaches 80 XP only as the wipe resolves, or when the opening becomes so gentle that multiple-threat combat disappears.

## Ten-minute evaluation

Do not judge individual features in isolation. Play the route from insertion through extraction and answer these questions immediately afterward.

### First 60 seconds

- Do enemies arrive quickly enough that the opening no longer feels empty?
- Is there enough time to understand movement, reload, health, XP, and objective information?
- Does the squad start close enough to regroup naturally?
- Does the first upgrade arrive early enough to influence survival rather than appearing during the wipe?
- Does pressure build in readable steps instead of jumping immediately to the solo cap?

### Combat feel

- Are there usually multiple visible threats rather than one isolated target?
- Do hit particles, death pools, kill text, and camera impact make kills readable?
- Does automatic targeting still feel understandable with a large crowd?
- Does manually choosing reload timing create tension?
- Do corpses and effects clean up without obvious buildup?

### Reward loop

- Does the XP bar move often enough to make ordinary kills matter?
- Do level-up choices create a meaningful decision rather than three cosmetic options?
- Are loot drops visible and tempting without covering the ground?
- Do massacre streaks encourage aggressive movement?
- Do health/ammunition rewards relieve pressure without eliminating scarcity?
- Does the second upgrade take noticeably longer than the first instead of creating immediate upgrade spam?

### Horror and variety

- Can Runner, Crawler, Screamer, Bloater, and Brute roles be recognized quickly?
- Does the Screamer create a panic moment when reinforcements appear?
- Is the Bloater death burst readable before it causes unfair damage?
- Does the Brute second phase feel surprising rather than broken?
- Does the world still feel threatening during brief gaps between hordes?

### Mission and climax

- Is the relay objective easy to find without a long dead walk?
- Does activating the relay create a noticeable escalation?
- Is the run to extraction pressured from behind and ahead?
- Does the two-minute holdout feel like a climax?
- Does success feel earned and failure understandable?

## Performance evidence

During the solo and two-client tests, record:

- timestamp of first contact;
- timestamp and kill count of first upgrade;
- timestamp and cause of first incapacitation or wipe;
- peak active hostile count;
- lowest observed client frame rate;
- highest server frame time visible in MicroProfiler;
- whether enemy movement stalls or bunches permanently;
- whether automatic combat stops acquiring targets;
- whether loot prompts remain responsive;
- whether any server or client errors appear;
- whether memory continues rising after corpses and effects should clean up.

## Immediate failure conditions

Do not merge when any of these occur:

- server bootstrap error;
- client bootstrap error;
- upgrade request can select an option not currently offered;
- client can create XP, loot, damage, health, ammunition, or enemies;
- four ordinary confirmed deaths do not produce exactly one first upgrade;
- ordinary active solo pressure wipes the player before the first upgrade can be selected;
- extraction becomes impossible because the enemy cap blocks required wave behavior;
- sustained severe frame collapse at ordinary solo pressure;
- blood/effect instances do not clean up;
- death, revive, reload, mission, or squad-failure regressions;
- the run still feels empty for long stretches.

## Tuning order

Tune in this order only:

1. time until first meaningful contact;
2. time to first upgrade versus time to first wipe;
3. visible concurrent enemy count;
4. kill feedback;
5. later XP cadence;
6. ammunition and healing drop rate;
7. role readability;
8. final holdout intensity;
9. performance caps.

Do not expand the map until the compact operation consistently produces an enjoyable full run.
