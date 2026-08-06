# Roblox Cooperative FPS RPG — Unified Master Roadmap

**Status:** Active source of truth  
**Blueprint version:** 1.0  
**Current phase:** Vertical-slice convergence  
**Primary rule:** Build one polished, replayable expedition before expanding into a large world.

---

## 1. Product vision

A cooperative first-person action RPG on Roblox where players explore dangerous regions, uncover hidden routes, enter procedurally assembled dungeons, discover randomized gear, develop distinct builds, and push into an expanding world with friends.

### Core promise

Every meaningful session provides:

- **Discovery** — something the player did not fully expect.
- **Growth** — power, options, access, knowledge, mastery, collection, or social progress.
- **Story** — a memorable moment worth retelling.

### Strategic edge

Development prioritizes systems that multiply content:

- combat framework;
- modular enemy framework;
- dungeon assembly engine;
- loot and affix engine;
- encounter director;
- elite modifier framework;
- quest-situation engine;
- world-event engine;
- content-definition pipeline.

One new enemy, room, affix, or event component should combine with existing components to produce many possible adventures.

---

## 2. Design laws

1. Every major feature supports at least two design pillars.
2. Friends should usually be able to play together.
3. Randomness changes situations, not basic rules.
4. Old areas retain future value.
5. Skill and decisions determine survival; statistics shape options and efficiency.
6. Failure teaches something understandable.
7. Reusable engines come before mountains of content.
8. No idea is sacred when evidence says it should change.
9. A feature without a clear player-facing purpose does not ship.
10. A larger map is not automatically a better world.
11. The server owns valuable game truth.
12. The first polished loop outranks the eventual feature list.

---

## 3. Core loops

### Moment-to-moment

**Observe → Aim → Move → Attack → Dodge → Use ability → React → Defeat → Collect**

### Adventure

**Prepare → Choose goal → Explore → Discover → Decide → Overcome → Collect → Return → Customize → Unlock → Repeat**

### Long-term

**Unlock regions → Develop builds → Chase rare effects → Master difficult encounters → Discover hidden systems → Help others → Prepare for new regions**

---

## 4. Vertical-slice definition

The first shippable product is a five-to-ten-minute expedition with:

- one preparation room;
- one outdoor approach route;
- one optional secret;
- one short procedurally assembled dungeon;
- three enemy families;
- one elite;
- one boss;
- randomized equipment rewards;
- equipment management;
- persistent saving;
- solo and cooperative play.

### Slice success test

The slice is not complete because all boxes are checked. It is complete when outside testers:

- understand the immediate goal without developer coaching;
- can explain why they took damage or failed;
- notice at least one meaningful difference between two runs;
- receive a reward that changes a decision;
- voluntarily begin another run.

---

## 5. Active sprint — VS-01 Expedition Foundation

### Objective

Create one server-owned expedition state machine that can drive preparation, approach, dungeon rooms, elite, boss, rewards, results, and replay without hard-coding the entire sequence into one script.

### Deliverables

- [x] `VS-0101` Adopt the unified cooperative FPS RPG vision as repository source of truth.
- [x] `VS-0102` Define bounded expedition contracts and configuration.
- [ ] `VS-0103` Implement server-owned expedition runtime state.
- [ ] `VS-0104` Implement deterministic room-sequence assembly from a seed.
- [ ] `VS-0105` Connect existing encounter owners to expedition phases.
- [ ] `VS-0106` Add one secret-room branch with bounded reward value.
- [ ] `VS-0107` Add one elite reward and one boss reward through the equipment pipeline.
- [ ] `VS-0108` Add operation result, reward summary, and replay prompt.
- [ ] `VS-0109` Add persistence for equipped items and account-safe progression.
- [ ] `VS-0110` Validate security, performance, and 1/2/4-player behavior in Studio.

### Definition of Done

- server authority is maintained;
- all client requests are validated and rate-bounded;
- the same seed produces the same room plan;
- a run cannot grant completion rewards twice;
- disconnect/rejoin behavior is explicitly defined;
- no numeric playtest result is claimed without captured evidence;
- `main` remains playable;
- tests or deterministic validation cover pure logic.

---

## 6. Milestone roadmap

### VS-02 Combat readability and class identity

- [ ] Preserve responsive first-person aiming, movement, hit feedback, and damage readability.
- [ ] Establish three initial class identities with one weapon preference, one active ability, one utility contribution, and one build hook each.
- [ ] Ensure useful non-damage contributions exist.
- [ ] Prevent level scaling from erasing build identity.
- [ ] Add readable enemy telegraphs and fair recovery windows.

### VS-03 Loot, equipment, and buildcraft

- [ ] Define item schema: base item, rarity, power band, affixes, unique effect, provenance, and version.
- [ ] Add a small deterministic affix pool with compatibility rules.
- [ ] Add inventory and equipment slots with server validation.
- [ ] Add compare/equip/dismantle flow.
- [ ] Add duplicate protection or pity where appropriate.
- [ ] Ensure rewards change decisions rather than only increasing numbers.

### VS-04 Modular dungeon assembly

- [ ] Build room contracts for entry, exits, tags, encounter sockets, secrets, and validation metadata.
- [ ] Assemble a bounded route from handcrafted modules.
- [ ] Guarantee entry-to-boss connectivity.
- [ ] Prevent impossible door alignment, overlaps, and invalid loops.
- [ ] Add one optional branch and one run modifier.
- [ ] Add seed logging for bug reproduction.

### VS-05 Enemy families, elite, and boss

- [ ] Ship three enemy families with distinct readable jobs.
- [ ] Add reusable elite modifiers that obey compatibility rules.
- [ ] Build one boss with clear phases, counterplay, and class-neutral completion.
- [ ] Connect difficulty changes to behavior and composition before raw health inflation.

### VS-06 Persistence and return loop

- [ ] Save equipped gear, inventory, unlocks, and critical account state.
- [ ] Add schema versions and migrations.
- [ ] Make saves idempotent and failure-tolerant.
- [ ] Add preparation-room loadout and next-goal presentation.
- [ ] Make the next temptation visible after every completed or failed run.

### VS-07 External playtest gate

- [ ] Conduct first-time-user test without live coaching.
- [ ] Conduct 1-player, 2-player, and 4-player tests.
- [ ] Capture completion, failure reason, replay choice, reward choice, and confusion points.
- [ ] Fix top onboarding, readability, pacing, and reward problems.
- [ ] Do not expand world scope until replay intent is demonstrated.

---

## 7. Post-slice expansion roadmap

Expansion is allowed only after the vertical slice passes its replay gate.

### Phase A — Regional foundation

- preparation hub;
- first explorable region;
- reusable expedition entrance framework;
- traversal and locked-route progression;
- basic factions and reputation;
- repeatable public events.

### Phase B — Build depth

- additional weapon families;
- class branches;
- item sets and unique effects;
- crafting operations;
- targeted loot pursuits;
- difficulty modifiers;
- social build roles.

### Phase C — World multiplication

- additional regions;
- world-state events;
- dynamic quests;
- old-area revisitation hooks;
- secrets requiring later knowledge or traversal;
- cross-region resource relationships.

### Phase D — Live operations

- seasonal additions that preserve permanent player value;
- new rooms, enemies, affixes, events, bosses, and regions;
- analytics-informed tuning;
- fair monetization that does not sell combat dominance;
- content retirement only with explicit migration plans.

---

## 8. Multiplayer and progression-gap laws

- Party members should have meaningful reasons to play together despite different account levels.
- Scaling should protect encounter readability and contribution without making progression feel fake.
- Lower-level players must retain agency.
- Higher-level players should gain breadth, build expression, mastery, and convenience—not permission to trivialize every shared encounter.
- Revives, control, support, objectives, discovery, and utility should matter alongside damage.
- Ordinary failure should not permanently destroy valuable progress.

---

## 9. Monetization principles

Allowed monetization should primarily support identity, expression, convenience, and continued production.

- cosmetics;
- emotes;
- non-combat personalization;
- carefully bounded convenience;
- optional content presentation upgrades;
- transparent passes with durable value.

Do not sell direct combat dominance, deceptive scarcity, required random purchases, or paid solutions to intentionally manufactured frustration.

---

## 10. Technical architecture rules

- Roblox server owns damage, rewards, inventory, progression, run state, and completion truth.
- Client owns input, camera, local presentation, prediction where safe, and responsive feedback.
- Remote events are treated as untrusted requests.
- Pure configuration and deterministic logic should be testable outside live scene state.
- Content definitions use stable IDs and explicit versions.
- Save data uses schema versions, validation, migrations, and idempotent writes.
- Random generation records seeds and selected components for reproduction.
- Runtime systems have explicit ownership boundaries; do not create parallel authoritative services.

---

## 11. Analytics and validation

Track only data that can change a decision:

- expedition start, completion, abandonment, and replay;
- phase reached and failure reason;
- damage source and avoidability;
- reward offered and reward selected;
- equipment changes after rewards;
- room and encounter seed;
- party size and progression spread;
- time to understand first objective;
- secret discovery;
- performance and remote rejection rates.

Analytics must not replace observation. Watch real players, especially new players and mixed-skill parties.

---

## 12. Scope protection

Before adding a feature, answer:

1. Which pillars does it support?
2. What player decision does it create?
3. Which existing systems does it connect to?
4. Does it multiply possibilities or only add maintenance?
5. Can a new player understand its purpose?
6. Does it damage the current milestone?
7. Can an existing system achieve the same goal more cheaply?
8. What is the acceptance test?
9. What is deliberately excluded from version one?

Ideas that are valuable but not part of the active milestone belong in the backlog, not in active implementation.

---

## 13. Current highest-ROI task

**Implement `VS-0103`: a server-owned expedition runtime state machine using the new shared contracts and configuration.**

It should expose a small authoritative API for starting a run, advancing validated phases, reading a sanitized snapshot, completing/failing once, and destroying run state. It should not yet generate rooms, award permanent loot, or depend on UI.
