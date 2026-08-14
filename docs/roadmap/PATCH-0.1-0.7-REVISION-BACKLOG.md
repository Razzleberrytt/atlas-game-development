# Patches 0.1 – 0.7 — revision backlog

**Why this exists.** Every earlier patch was accepted at the source layer and then built upon. That is the right way to move, and it leaves a residue: rows deferred with a reason that may no longer hold, evidence never run, and invariants pinned by audits that have since drifted. This document ranks that residue so it stays visible instead of dissolving into "already done".

**This is not a re-litigation.** No accepted patch is reopened here. Each row either closes something explicitly left open, or hardens something later work has since put under more load than it was designed for.

**Cadence:** exact 10-task batches, merged only on `python scripts/validate.py full`.

## Batch 1 — MVP 0.1 first-run truth (#1–#10)

1. Prove the safe-arrival boundary still holds now that pressure arms after launch.
2. Prove a first-run player reaches the lobby with no armed pressure.
3. Prove the opening weapon path resolves for a player with no durable record.
4. Prove a durable weapon overrides the opening path exactly once.
5. Prove melee input remains reachable on every supported device.
6. Prove the first-run route is reproducible from the canonical seed.
7. Add a first-run fixture asserting every bootstrap owner started.
8. **UNMEASURED** — the first-run experience end to end in Studio.
9. Prove no first-run path depends on an unbounded `WaitForChild`.
10. Re-verify the `PlayerModule` bounded-wait fix still holds.

## Batch 2 — 0.2 combat and readability (#11–#20)

11. Prove every weapon shot effect resolves through its authoritative presenter.
12. Prove no presenter establishes damage or hit truth.
13. Prove hit confirmation is server-derived on every path.
14. Prove enemy impact presentation cannot desync from server death state.
15. Prove elite readability markers derive from server state only.
16. Add a coverage report of combat presentation owners by surface.
17. Prove no combat presenter caches a destroyed instance across a replay.
18. **UNMEASURED** — combat readability during play.
19. Prove combat audio owners hold no authority.
20. Re-verify the `EnemyEntities` folder identity rule across a replay.

## Batch 3 — 0.3 loot and build replayability (#21–#30)

21. Prove every loot source routes through `EnemyLootService` alone.
22. Prove ammunition loot cannot be granted by a second owner.
23. Prove affix rolls are deterministic for a given seed after the 0.9 expansion.
24. Prove a saved item from before the affix expansion still loads.
25. Prove relic modifiers cannot stack beyond their authored bound.
26. Prove run build state never reaches durable storage.
27. Add a fixture proving a run build is fully cleared on replay reset.
28. **UNMEASURED** — whether build variety reads during play.
29. Prove no loot path can double-grant under a repeated death event.
30. Re-verify loot ownership after the Patch 0.9 roster expansion.

## Batch 4 — 0.4 RPG progression (#31–#40)

31. Prove operative rank derives only from the durable grant ledger.
32. Prove no second authority writes rank or unlocks.
33. Prove the ledger-shape regression still holds after any ledger change.
34. Prove unlock entitlements are a pure projection of rank.
35. Prove a rank threshold change cannot retroactively remove an earned unlock.
36. Add a progression fixture across every authored rank boundary.
37. Prove progression disclosure is owner-only.
38. **UNMEASURED** — whether progression pacing feels earned.
39. Prove `RunProgressionHUDController` remains unstarted while it exists.
40. Add a source audit proving the single progression owner rule.

## Batch 5 — 0.5 Main World and BA-014 (#41–#50)

41. Re-derive the BA-014 acceptance scope against the current build.
42. Prove the run record cannot be recorded without matching build identity.
43. Prove the divergent local Studio place cannot be mistaken for the artifact.
44. **UNMEASURED** — the BA-014 run against the exact built artifact.
45. Prove environment breadth admission stays gated behind that evidence.
46. Prove the recovered world remains unmapped by the operation project.
47. Prove no imported legacy manager boots alongside the modern runtime.
48. Prove the Main World build stays runtime-disabled until authorized.
49. Prove materialized model groups stay gitignored build output.
50. Add a validator failing when an evidence packet's identity is absent.

## Batch 6 — 0.6 systemic replayability (#51–#60)

51. Re-evaluate rank 98 — show the run modifier on the player HUD.
52. Re-evaluate rank 99 — show the optional objective variation on the HUD.
53. Re-evaluate rank 100 — show a post-run variation recap.
54. Prove the terminal run summary carries everything those three surfaces need.
55. Build a pure resolver deciding what a variation HUD should display.
56. Prove that resolver is testable without a GUI.
57. **UNMEASURED** — whether the variation surfaces read clearly on screen.
58. Prove composition identity remains stable across a config change.
59. Prove the heartbeat catch-up cap still holds under the current step cost.
60. Re-verify the terminal run summary is committed exactly once.

## Batch 7 — 0.7 deferred rows, first half (#61–#70)

61. Re-evaluate the durable overflow bucket (#54–#57) — deferred for want of a capacity limit.
62. Decide whether a durable inventory capacity limit is wanted at all.
63. If it is, define it from measured record size rather than a guess.
64. Re-evaluate separate durable progression records (#64–#65).
65. Re-evaluate separate durable unlock records.
66. Re-evaluate a durable currency contract (#66) against current gameplay.
67. Re-evaluate atomic progression, unlock, and currency mutation identity (#67–#69).
68. Prove the cross-domain projection binding still detects a stale projection.
69. Prove no deferral silently became a dependency of later work.
70. Record each re-evaluation's outcome in the acceptance matrix.

## Batch 8 — 0.7 deferred rows, second half (#71–#80)

71. Re-evaluate latency injection (#84) — deferred for want of a timed path.
72. Re-evaluate the persistence diagnostic snapshot (#86).
73. Re-evaluate persistence outcome counters (#87) — deferred for want of a consumer.
74. Build the operator surface those counters would feed, or keep them deferred.
75. Re-evaluate randomised multi-server stress (#88) against the deterministic matrix.
76. Prove the deterministic fault matrix still covers what a random sweep would.
77. Add unknown-field preservation across a same-schema deploy, or record why not.
78. Prove a field added without a schema bump is either preserved or refused.
79. Prove the quarantine path is reachable and its keys discoverable.
80. Prove every persistence deferral still carries a current reason.

## Batch 9 — Cross-patch invariant drift (#81–#90)

81. Audit every source audit for a pin on an exact call shape.
82. Rewrite each to hold its guarantee rather than its spelling.
83. Prove no audit pins a source comment.
84. Prove no audit pins a version or count that is expected to grow.
85. Add a report of audits by what they pin and how brittle it is.
86. Prove every single-owner rule in CLAUDE.md has an audit enforcing it.
87. Prove every owner named in a single-owner rule still exists.
88. Prove no responsibility gained a second live owner since its rule was written.
89. Add a validator failing when a documented owner path no longer resolves.
90. Reconcile CLAUDE.md's stated counts against the layout validator's output.

## Batch 10 — Documentation and evidence truth (#91–#100)

91. Reconcile every roadmap status line against the current gate result.
92. Prove no document claims VERIFIED without an evidence packet.
93. Prove every evidence packet names its exact build and commit identity.
94. Prove no packet was edited to fit a later result.
95. Add a validator failing when a status line contradicts the acceptance matrix.
96. Reconcile the deferral registers across 0.6, 0.7, 0.8, and 0.9.
97. Prove every deferral is reachable from one index rather than scattered.
98. Retire roadmap documents superseded by a later authority.
99. Prove no retired document is still referenced as authority.
100. **UNMEASURED** — the consolidated STOP / PLAY / FIX pass across every patch.

## Rules

- Implement in exact 10-task batches; merge only after `python scripts/validate.py full` is green.
- A re-evaluation may legitimately conclude **still deferred**. Record the current reason; do not mark it done.
- **UNMEASURED** rows do not hold source progression and must never be claimed from automation.
- No accepted patch is reopened by this document. A row that would reopen one must say so and justify it.
