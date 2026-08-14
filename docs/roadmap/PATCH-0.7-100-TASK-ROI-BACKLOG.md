# Atlas — Patch 0.7 Durable Persistence + Valuable State Hardening — 100-Task ROI Backlog

**Status:** CURRENT PATCH 0.7 TASK AUTHORITY  
**Created:** 2026-08-13  
**Execution unit:** exactly 10 ranked tasks per implementation batch unless a concrete safety defect forces a smaller emergency fix.  
**Required gate:** automated repository validation. Manual Studio/device/play testing is optional evidence and never blocks task progression by itself.

## Optimization law

Tasks are ordered by **expected player-value loss prevented × dependency leverage ÷ implementation/verification cost**.

Priority order:

1. prevent durable data loss or blank overwrite;
2. prevent duplication/replay and ambiguous writes;
3. harden session ownership and multi-server lifecycle;
4. make migrations/recovery fail closed and reversible;
5. bound capacity/overflow before valuable-state breadth grows;
6. expand durable domains only after the storage core is trustworthy;
7. automate chaos/recovery evidence so humans are not required as a development gate.

A real reproducible safety failure may preempt the queue. Missing manual evidence may not.

## Existing Patch 0.7 foundation already merged

Before this 100-task queue began, Patch 0.7 already had: symmetric resident-record release, committed-update lease decisions, supported-schema migration/recovery invariants, single live inventory ownership, and no-blank-overwrite protection after exhausted reads. Those are baseline prerequisites and are not re-counted as tasks below.

## Batch 1 — Storage resolution policy (#1–#10) — DONE

1. **[DONE]** Define explicit `StudioVolatile`, `LiveDurable`, and `LiveUnavailable` storage resolution modes.
2. **[DONE]** Provide isolated volatile storage for Studio sessions.
3. **[DONE]** Prove Studio resolution never calls the live DataStore opener.
4. **[DONE]** Prove separate Studio resolutions cannot share process-local values accidentally.
5. **[DONE]** Bind healthy live resolution to the exact durable store returned by the opener.
6. **[DONE]** Prove the live opener executes exactly once per resolution.
7. **[DONE]** Convert live store-open failure into explicit `LiveUnavailable` mode with a diagnosable reason.
8. **[DONE]** Make unavailable-store reads reject rather than return a value that can masquerade as missing data.
9. **[DONE]** Make unavailable-store updates reject without invoking the caller transform.
10. **[DONE]** Add one deterministic fixture covering Studio, healthy live, unavailable live, nil-store, and malformed-resolution inputs.

## Batch 2 — Integrate fail-closed storage + explicit outcomes (#11–#20) — DONE

11. **[DONE]** Route `RobloxInventoryDataStoreAdapter` store selection through `InventoryDataStoreResolutionPolicy`.
12. **[DONE]** Remove duplicated Studio/live resolution logic from the adapter after integration.
13. **[DONE]** Add a source audit proving the live inventory adapter consumes the canonical resolution policy.
14. **[DONE]** Add an explicit storage read result contract (`Found` / `Missing` / `Failed`).
15. **[DONE]** Migrate inventory persistence load logic off ambiguous bare `nil` read semantics.
16. **[DONE]** Return a dedicated `LoadFailed` persistence reason with no new-record/migration write after read failure.
17. **[DONE]** Add an explicit storage update result contract with committed value identity.
18. **[DONE]** Add an explicit storage save result contract instead of bare boolean-only diagnostics.
19. **[DONE]** Add a failure → recovery → safe mutation fixture proving stale/blank state never wins.
20. **[DONE]** Add a fixture proving uncertainty/recovery for player A cannot block or contaminate player B.

## Batch 3 — Session ownership + lease robustness (#21–#30) — DONE

21. **[DONE]** Add lease record structural validation before acquire/renew decisions.
22. **[DONE]** Fail closed on malformed live rival lease records instead of silently replacing them.
23. **[DONE]** Add lease owner generation identity to distinguish recycled server/job identities.
24. **[DONE]** Add deterministic acquire contention fixture with two simulated servers.
25. **[DONE]** Add deterministic renew/lost-lease contention fixture.
26. **[DONE]** Add deterministic release-after-loss fixture.
27. **[DONE]** Add lease-expiry boundary tests at `expiry - ε`, `expiry`, and `expiry + ε` semantics.
28. **[DONE]** Add shutdown release result aggregation so unresolved durable leases are observable.
29. **[DONE]** Add bounded retry/reconciliation behavior for failed shutdown lease release.
30. **[DONE]** Add automated multi-player lease isolation fixture across many keys.

## Batch 4 — Valuable mutation idempotency (#31–#40) — DONE

31. **[DONE]** Define one canonical durable mutation transaction-id contract.
32. **[DONE]** Require transaction identity for every valuable reward grant path.
33. **[DONE]** Persist equip transaction identity or prove equip is naturally idempotent under exact replay.
34. **[DONE]** Strengthen dismantle transaction ledger validation with complete outcome shape checks.
35. **[DONE]** Reject transaction-id reuse with conflicting payload/content identity.
36. **[DONE]** Add reward retry fixture for same grant + different instance GUID.
37. **[DONE]** Add reward conflict fixture for same transaction + different content signature.
38. **[DONE]** Add dismantle retry fixture across release/rejoin.
39. **[DONE]** Add mutation ledger retention policy and bound.
40. **[DONE]** Add cross-mutation ledger audit proving reward/equip/dismantle cannot erase each other's replay protection.

## Batch 5 — Migration, quarantine, and recovery (#41–#50) — DONE

41. **[DONE]** Define current-to-next schema migration authoring contract.
42. **[DONE]** Require sequential migration steps rather than arbitrary direct jumps.
43. **[DONE]** Add migration step identity/version diagnostics.
44. **[DONE]** Add malformed-record quarantine result that never rewrites the source record.
45. **[DONE]** Add recoverable-vs-unrecoverable corruption classification.
46. **[DONE]** Add recovery copy/backup contract before any destructive repair.
47. **[DONE]** Add migration write-back compare/reconciliation protection against concurrent newer data.
48. **[DONE]** Add migration failure fixture at every supported source schema.
49. **[DONE]** Add future-schema downgrade protection fixture with unknown extra fields.
50. **[DONE]** Add automated migration matrix runner used by the canonical full validator.

## Batch 6 — Capacity, overflow, and retention (#51–#60) — ACTIVE

51. Define durable inventory capacity contract from measured serialized-size budget.
52. Add deterministic record-size estimator for inventory payloads.
53. Reject writes that exceed hard safe record size before DataStore submission.
54. Add durable overflow/recovery bucket contract for excess rewards.
55. Make reward grant atomic between inventory capacity and overflow destination.
56. Add overflow replay/idempotency ledger.
57. Add overflow claim/recovery mutation path under session lease.
58. Add capacity-edge fixtures at below/equal/above thresholds.
59. Add ledger compaction policy that preserves replay safety.
60. Add archival policy for obsolete transaction history without permitting replay.

## Batch 7 — Expand valuable durable state safely (#61–#70)

61. Inventory all player-value domains that currently survive only in memory.
62. Rank those domains by player loss impact and product value.
63. Define canonical account-vs-character ownership boundary.
64. Add durable progression record contract using the hardened storage primitives.
65. Add durable unlock record contract.
66. Add durable currency contract only for currencies already proven necessary by gameplay.
67. Add atomic progression mutation transaction identity.
68. Add atomic unlock mutation transaction identity.
69. Add atomic currency mutation transaction identity.
70. Add cross-domain snapshot/version contract so inventory/progression/unlocks cannot silently diverge.

## Batch 8 — Disconnect, rejoin, crash, and shutdown correctness (#71–#80)

71. Add disconnect-during-reward-write deterministic simulation.
72. Add disconnect-during-dismantle-write deterministic simulation.
73. Add disconnect-during-migration deterministic simulation.
74. Add server-crash-before-memory-commit simulation.
75. Add server-crash-after-durable-commit simulation.
76. Add rejoin-after-unknown-client-response reconciliation fixture.
77. Add same-player rapid server-hop lease/reload fixture.
78. Add shutdown with many resident players fixture.
79. Add shutdown partial-storage-outage fixture.
80. Add restart/rejoin invariant suite proving durable truth wins over stale process memory.

## Batch 9 — Automated chaos, diagnostics, and recovery evidence (#81–#90)

81. Add deterministic fault-injection store wrapper for read failures.
82. Add deterministic fault-injection store wrapper for update failures.
83. Add transform-retry fault injection with state changes between invocations.
84. Add configurable latency injection without real wall-clock waiting.
85. Add persistence reason-id/schema audit so failures remain machine diagnosable.
86. Add server-only persistence diagnostic snapshot with no client authority.
87. Add counters for read/write/retry/reconcile/quarantine outcomes.
88. Add automated seedable multi-server persistence stress simulation.
89. Add invariant checker for duplicate items, missing ledgers, invalid equips, and ownership drift.
90. Add one canonical `persistence-hardening` validation profile consumed by `scripts/validate.py full`.

## Batch 10 — Automated Patch 0.7 acceptance + release hardening (#91–#100)

91. Define machine-readable Patch 0.7 acceptance matrix.
92. Bind every acceptance row to at least one automated fixture/audit.
93. Add source audit proving all valuable mutations pass through the canonical persistence owner.
94. Add source audit proving clients cannot choose durable owner/value/schema fields.
95. Add source audit proving Studio cannot touch production inventory namespaces.
96. Add automated downgrade/rollback compatibility fixture across supported schemas.
97. Add automated duplicate/replay resistance matrix across valuable mutation types.
98. Add automated lifecycle matrix across join/leave/rejoin/server-hop/shutdown paths.
99. Run full canonical validation with all 100 task acceptance rows satisfied or explicitly superseded by a stronger automated invariant.
100. Mark Patch 0.7 **AUTOMATED ACCEPTANCE COMPLETE** when the machine-readable matrix is green; manual play/Studio evidence may remain optional product evidence and cannot hold source progression.

## Batch progression rule

- Work only the current 10-task batch unless a concrete data/security defect preempts it.
- Merge only after `python scripts/validate.py full` / equivalent CI is green.
- After merge, mark the completed 10 **DONE**, promote the next 10 to **ACTIVE**, and continue.
- Do not create `GATED — manual testing` tasks.
- Do not claim experiential facts (feel, readability, real-device ergonomics) from automation; label those facts **UNMEASURED** when relevant, but continue source work.
