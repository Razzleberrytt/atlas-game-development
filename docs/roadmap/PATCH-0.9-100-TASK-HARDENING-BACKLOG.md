# Patch 0.9 — Content Expansion + Production Pipeline: 100-task hardening backlog

**Relationship to `PATCH-0.9-ACCEPTANCE.md` and `PATCH-0.9-CONTENT-PIPELINE.md`:** those documents are the authority on Patch 0.9's disposition and its production gate. **This document does not re-decide either.** It ranks the hardening and validation work that makes added content safe to keep adding.

**The failure mode this patch actually has.** Content expansion does not break loudly. It breaks by admitting a row that references something absent, by drifting a config away from the fixture that pins it, or by growing a validator's blind spot until nothing checks the new thing. Patch 0.9 already demonstrated it: expanding the affix roster and the weapon roster left five fixtures broken and seventeen files unformatted, and every subsequent merge landed on a red gate. Most rows below exist to make that class loud.

**Cadence:** exact 10-task batches, merged only on `python scripts/validate.py full`.

## Batch 1 — Content reference integrity (#1–#10)

1. Prove every `EquipmentRewardConfig` weapon link resolves through `FirearmConfig.isKnownWeaponId`.
2. Prove every affix `RequiredTags` entry is carried by at least one reward definition.
3. Prove every reward definition's slot matches the affix rows that may target it.
4. Prove no reward definition references a rarity absent from `EquipmentRewardContracts`.
5. Prove every `FirstDungeonContentConfig` encounter references an authored room.
6. Prove every authored room references an encounter slot the assembler knows.
7. Prove every `VisualAssetConfig` row's owner path resolves to a real module.
8. Prove no `sourceReference` in the visual registry contains a raw asset id.
9. Add a single validator that fails when any content row references an absent target.
10. Bind that validator into `scripts/validate.py`.

## Batch 2 — Config-to-fixture drift (#11–#20)

11. Prove every pinned config version in a fixture matches its config.
12. Prove every pinned definition count matches the config it counts.
13. Replace exact-count pins with range or derivation where the count is expected to grow.
14. Add a drift report listing every fixture that pins a config constant.
15. Prove a config version bump without a fixture update fails the gate loudly.
16. Prove a fixture cannot stub a config it is meant to constrain.
17. Audit every fixture that stubs `EquipmentRewardConfig` and require the real roster.
18. Audit every fixture that stubs `EquipmentAffixConfig` and require the real roster.
19. Audit every fixture that stubs `FirearmConfig` and require the real roster.
20. Add a source audit forbidding new stubs of those three configs.

## Batch 3 — Weapon roster completeness (#21–#30)

21. Prove every discoverable weapon id has a durable reward definition.
22. Prove every durable weapon has at least one role-aware affix.
23. Prove no two weapons share a weapon id.
24. Prove every weapon's role tags exist in the authored tag vocabulary.
25. Prove weapon stat bounds stay inside their contract ranges.
26. Add a coverage report of weapons by slot and role.
27. Prove a weapon added without a reward definition fails the gate.
28. Prove a weapon removed while still referenced fails the gate.
29. **UNMEASURED** — whether the weapon roster feels distinct in play.
30. Add a source audit proving the roster has one authoring owner.

## Batch 4 — Gear archetype coverage (#31–#40)

31. Prove every armor archetype has affixes that can target it.
32. Prove every relic archetype has affixes that can target it.
33. Prove no archetype is unreachable from any reward source.
34. Prove archetype power bounds stay inside their contract ranges.
35. Add a coverage report of archetypes by slot and rarity.
36. Prove rarity affix counts match `AffixCountByRarity` for every rarity.
37. Prove no affix can roll on a slot its tags exclude.
38. Prove affix rolls are deterministic for a given seed and definition.
39. **UNMEASURED** — whether archetypes read as meaningfully different.
40. Add a source audit proving archetype authoring has one owner.

## Batch 5 — Dungeon and room content (#41–#50)

41. Prove every room kit entry resolves to a placeable model.
42. Prove every room's encounter intensity is inside the authored pressure range.
43. Prove every authored wave references archetypes that exist.
44. Prove no room is unreachable in a generated sequence.
45. Prove the boss room appears exactly once per sequence.
46. Add a room coverage report by role and kit.
47. Prove a room added without an encounter fails the gate.
48. Prove room content changes cannot silently alter the canonical seed's route.
49. **UNMEASURED** — whether room variety reads during play.
50. Add a source audit proving room authoring has one owner.

## Batch 6 — Enemy family coverage (#51–#60)

51. Prove every enemy archetype referenced by content exists in config.
52. Prove every enemy family has bounded spawn counts.
53. Prove no enemy references a presentation owner that does not exist.
54. Prove enemy scaling is deterministic for a given seed and party size.
55. Prove no enemy config change can retroactively invalidate a saved run seed.
56. Add an enemy coverage report by family and role.
57. Prove an enemy added without a presentation binding fails the gate.
58. Prove enemy removal fails the gate while still referenced.
59. **UNMEASURED** — whether enemy families read as distinct threats.
60. Add a source audit proving enemy authoring has one owner.

## Batch 7 — Presentation registry discipline (#61–#70)

61. Prove every registry row has a `statusId` and an owner path.
62. Prove no registry row declares a gameplay owner.
63. Prove every registered asset id was verified to load before admission.
64. Prove a registry row cannot be admitted without a source audit.
65. Prove presentation content cannot establish consequential state.
66. Add a registry coverage report by family and status.
67. Prove an admitted row bumped to `TemporaryPresentation` has a dedicated owner.
68. Prove no client-local presentation owner writes to a server folder.
69. **UNMEASURED** — visual quality and readability of admitted content.
70. Add a source audit proving the registry stays presentation-only.

## Batch 8 — Production pipeline gates (#71–#80)

71. Prove the content production gate runs on every content change.
72. Prove the gate fails when a new content family arrives without validation.
73. Add a content authoring checklist bound to the gate rather than to prose.
74. Prove content validators run before expensive fixtures so failures surface early.
75. Prove a content change cannot bypass the gate through an unmapped directory.
76. Add a coverage report of which content families have validators.
77. Prove every content family named in the pipeline doc has a validator.
78. Prove the pipeline doc cannot name a validator that does not exist.
79. Measure and record the gate's runtime so growth stays visible.
80. Add a validator that fails when gate runtime crosses a recorded budget.

## Batch 9 — Repository health under growth (#81–#90)

81. Add a formatting gate that cannot be merged around.
82. Prove `stylua --check` failure blocks a merge rather than being reported after it.
83. Add a red-main detector that reports when `main` fails its own gate.
84. Prove a fixture added without being run by any profile fails the gate.
85. Prove a profile that runs a fixture no acceptance row claims fails the gate.
86. Audit every fixture for a stale exact-spelling pin and rewrite it to hold its guarantee.
87. Add a report of audits that pin comments or exact call shapes.
88. Prove no audit pins a source comment.
89. Measure fixture-suite runtime and record a budget.
90. Add a validator that fails when suite runtime crosses that budget.

## Batch 10 — Acceptance binding (#91–#100)

91. Bind every SATISFIED row in `PATCH-0.9-ACCEPTANCE.md` to at least one automated fixture.
92. Add a validator that checks that binding in both directions.
93. Prove a deferred row carries its reason or fails the gate.
94. Re-evaluate every Patch 0.9 deferral against current evidence.
95. Prove content breadth added since acceptance is covered by the same validators.
96. Add a content inventory report by family, count, and validator.
97. Prove the inventory cannot overstate what exists.
98. Run the full canonical validation with every non-deferred row satisfied.
99. **UNMEASURED** — whether added content improves the loop rather than diluting it.
100. **UNMEASURED** — the exit question: can substantial content be added without destabilizing the proven loop?

## Rules

- Implement in exact 10-task batches; merge only after `python scripts/validate.py full` is green.
- A row that should not be built is **DEFERRED with its reason**, never silently marked done.
- **UNMEASURED** rows do not hold source progression and must never be claimed from automation.
