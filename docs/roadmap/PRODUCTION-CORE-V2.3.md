# Roblox Cooperative FPS RPG
## Production Core — Version 2.3 Refined

**Purpose:** Daily-use canonical reference. If this file conflicts with an older checkpoint, this file controls unless accepted runtime evidence says otherwise.  
**Release date:** 2026-08-07  
**Full history:** `Willie_Roblox_RPG_Master_Blueprint_v2.3.md` (196 chapters, ~100,800 words) — held outside the repository in the `Roblox_RPG_Refined_v2.3` package; its chapters 181–196 are summarized in [`BLUEPRINT-V2.3-EXECUTION.md`](BLUEPRINT-V2.3-EXECUTION.md)  
**Runtime status:** E1 source baseline exists; active Studio runtime has unresolved queue/highlight symptoms; E2–E4 acceptance is not yet complete.

# 1. North Star

Build a cooperative first-person action RPG where curiosity, readable combat, randomized equipment, build identity, and friendship produce personal adventure stories.

The smallest product that can prove it:

```text
prepare
→ choose weapon
→ follow outdoor route
→ fight Pursuer / Shooter / Warden
→ use Pulse Mark for danger + optional clue
→ enter short procedural Underroot run
→ defeat elite
→ receive and equip randomized item
→ defeat Gatekeeper
→ return
→ voluntarily begin another run
```

# 2. Current Authority

Use this precedence:

```text
accepted runtime evidence / current platform behavior
→ Production Core v2.3 + Master Chapters 181–196
→ latest specialist bible
→ canonical architecture Chapters 33–63
→ earlier design
→ historical checkpoints
```

Historical closing directives remain context, not orders.

# 3. Product Laws

1. Curiosity is a mechanic.
2. Combat is intense but readable.
3. Enemies create different tactical questions.
4. Gear changes decisions, not only numbers.
5. Cooperation adds interactions, not only enemy health.
6. The server owns valuable truth.
7. Procedural content combines authored pieces under understandable rules.
8. Critical information never depends on color or one transient effect alone.
9. Runtime state and presentation have explicit owners and cleanup.
10. One polished repeatable expedition outranks broad unfinished scope.

# 4. Current Creative Direction

```text
Setting: The Shatterwake
Hub: Emberwatch
First biome: Verdant Scar
First dungeon: Underroot Vault
First story boss: Gatekeeper
```

Visual identity:

```text
Emberwatch       warm / improvised / layered / stable
Verdant Scar     organic sweep / green-gold depth / cyan wayline seams
Meridian         pale vertical slabs / dark frames / precise cool light
Gleaners         patched salvage / asymmetry / practical scavenger shapes
Altered wildlife organic mass / directional anatomy / luminous contamination
```

Readability order:

```text
threat or objective
→ route and cover
→ landmark
→ interaction or secret clue
→ story detail
→ decoration
```

# 5. Core Gameplay Numbers — Provisional Until Measured

Player:

```text
Health 100
Walk 16
Sprint 23
Dodge cooldown 1.25 s
Low-health threshold 25%
```

Frontier Rifle:

```text
Damage 18
Fire interval 0.15 s
Magazine 24
Reload 1.8 s
Range 300
Falloff start 140
Minimum damage multiplier 0.65
Weak point 1.5×
```

Pulse Mark:

```text
Cooldown 18 s
Cast 0.25 s
Recovery 0.35 s
Enemy radius 55 studs
Secret radius 28 studs
Mark duration 6 s
Marked weak-point bonus 8%
Enemy cap 12
Secret cap 6
```

# 6. Enemy Questions

- **Pursuer:** can I maintain space while still dealing damage?
- **Shooter:** can I control exposure and use cover?
- **Warden:** can I identify and solve the support relationship?

A mixed encounter fails if players describe it only as “too many enemies.”

# 7. Loot and Durable Value Boundary

The proof baseline contains two weapons, four rarity tiers, twelve affixes, two executable legendary rules, personal rewards, equip, dismantle, and Salvaged Components.

Exactly-once reward chain:

```text
encounter completion
→ eligible player
→ deterministic transaction id
→ deterministic loot candidate
→ inventory mutation
→ stored completed result
→ retries replay result without reroll/regrant
```

Persistence remains gated until in-memory mutations, retries, multiplayer ownership, and recovery behavior are accepted.

# 8. Server Authority

Server owns damage, health, enemy state, encounter completion, ability legality/cooldowns/targets/statuses, loot, item instances, inventory, equipment, dungeon seed/layout, quests, progression, persistence, and commerce grants.

Client owns input collection, camera, HUD, local animation/VFX, and prediction that can be corrected without granting authority.

# 9. Runtime Presentation Contract

```text
client constructs controllers
→ binds listeners
→ ClientReady
→ one authoritative RuntimeSnapshot
→ revisioned semantic RuntimeDelta messages
→ unreliable channel only for disposable high-frequency cosmetic signals
```

Do not send unchanged state because a frame elapsed. Do not put every presentation concern back into one generic state remote.

Current release blockers visible in Studio:

1. `ReplicatedStorage.HordeNetwork.State` queue-exhaustion warnings.
2. escaped broad blue/yellow highlight presentation.

The screenshot proves symptoms, not exact causes. Instrument before attributing.

# 10. Presentation Ownership

One owner per primitive:

```text
Highlight → HighlightLeaseRegistry
route guide → RouteGuidePresentationController
landmark accent → LandmarkAccentPresentationController
Pulse Mark → MarkPresentationController through highlight registry
viewmodel → Viewmodel/Weapon presentation owner
camera effects → one modifier stack
temporary VFX → effect scope/pool
animation markers → owning track/controller scope
```

Production highlights may not target Workspace or broad region roots. Stable semantic IDs survive streaming; local instances may come and go.

# 11. Visual and Animation Core

Project metrics:

```text
base grid 4 studs
route 10–14 studs
combat lane 16–24 studs
major arena 48–80 studs
door 7×10 studs minimum
low cover 3–4 studs
full cover 6.5–8 studs
wall module 12 or 16 studs high
```

Animation law: animation communicates intent; the server owns the result.

Stable markers:

```text
Foot_L Foot_R Muzzle ShellEject MagOut MagIn Chamber
Commit HitboxOn HitboxOff AbilityRelease InteractContact RecoveryStart
```

First proof timing:

```text
Pursuer lunge tell 0.45–0.65 s
Pursuer active 0.08–0.14 s
Shooter aim tell 0.40–0.65 s
Shooter burst spacing 0.12–0.18 s
Warden link open 0.45–0.70 s
Pulse Mark cast 0.25 s
Pulse Mark recovery 0.35 s
```

# 12. Graphics and Accessibility Ladder

Full, Reduced, and Minimum Readable modes may change density and spectacle. They may not remove route truth, cover truth, major enemy tells, objective identity, Pulse Mark state, Warden link state, or essential shot/damage confirmation.

Reduced-motion mode reduces camera shake, roll, FOV pumping, bob, and secondary viewmodel kick before it removes essential gameplay feedback.

# 13. Evidence Scale

```text
E0 design only
E1 source assembled/static review
E2 Studio starts and systems initialize
E3 single-player integrated behavior demonstrated
E4 multiplayer/adversarial demonstrated
E5 device/performance/reliability demonstrated
E6 outside-player fun demonstrated
E7 live telemetry demonstrated
```

Do not report E3 because code exists. Do not report E5 because a desktop test ran once.

# 14. Immediate Critical Path

1. Search every producer and listener of `HordeNetwork.State`.
2. Add producer send-rate and client listener counters.
3. Establish listeners-before-ready startup.
4. Replace recurring generic state with snapshot + semantic deltas.
5. Run five encounter resets and verify message/connection rates do not grow.
6. Enumerate every Highlight and its producing controller/Adornee.
7. Migrate production highlights to centralized lease ownership.
8. Verify reset, respawn, and stream-out return presentation to baseline.
9. Capture clean ten-minute soak: zero queue/discard warnings.
10. Build neutral visual validation scene.
11. Integrate Frontier Rifle FP blockout and Pursuer lunge blockout.
12. Prove single-player loop three times, then two-player adversarial behavior.
13. Only after runtime stability, implement accepted durable persistence or the next dependency-complete slice system.

# 15. Stop Conditions

Stop and fix before adding scope when:

- remote queue/discard warnings occur in supported normal play;
- connections or transient presentation objects grow across reset/respawn;
- a broad highlight hides gameplay;
- damage/loot/cooldown/ownership can be client-authored;
- attack presentation lies about a hit window;
- cover art and collision disagree;
- reward retries duplicate or reroll;
- fresh testers cannot explain enemy roles or next goal;
- low-graphics/mobile presentation loses critical information.

# 16. Daily Review Checklist

```text
What changed?
Which owner changed it?
What evidence level changed?
Did network rate change?
Did connection/effect baseline change?
Did low-quality/mobile readability change?
Did server authority change?
Did reset/respawn/late join still pass?
Which provisional number was measured?
What is the smallest next dependency?
```

> Clean runtime truth first. Then visual polish. Then content expansion.
