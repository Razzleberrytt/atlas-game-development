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

## Batch 1 — Production storage must fail closed (#1–#10) — ACTIVE

1. **[ACTIVE]** Remove live-server volatile fallback when production DataStore construction fails.
2. **[ACTIVE]** Add a fail-closed unavailable-store adapter for production construction failure.
3. **[ACTIVE]** Prove unavailable-store reads exhaust the configured retry budget and disclose failure.
4. **[ACTIVE]** Prove unavailable-store updates fail without mutating durable state.
5. **[ACTIVE]** Prove unavailable-store saves fail without accepting a blank/new record.
6. **[ACTIVE]** Preserve the existing per-key failed-load write guard when the live store is unavailable.
7. **[ACTIVE]** Preserve Studio-only volatile isolation for play/evidence sessions.
8. **[ACTIVE]** Prove Studio construction never calls production `GetDataStore`.
9. **[ACTIVE]** Prove a healthy live environment still binds the real DataStore and persists normally.
10. **[ACTIVE]** Add one focused resolver-mode fixture covering Studio, healthy live, and unavailable live modes.

## Batch 2 — Explicit read/write outcomes + reconciliation (#11–#20)

11. Add an explicit storage read result contract (`Found` / `Missing` / `Failed`).
12. Migrate inventory load logic off ambiguous bare `nil` read semantics.
13. Return a dedicated `LoadFailed` persistence reason instead of treating outages as corrupt/missing data.
14. Add an explicit storage update result contract with committed value identity.
15. Add an explicit storage save result contract instead of bare boolean-only diagnostics.
16. Record per-key last successful read generation/epoch for reconciliation.
17. Reject writes derived from a state generation older than the latest successful read.
18. Add successful reread reconciliation that clears only the matching key's uncertainty state.
19. Add a fixture for failure → recovery → safe mutation with no stale overwrite.
20. Add a fixture proving uncertainty on player A cannot block or contaminate player B.

## Batch 3 — Session ownership + lease robustness (#21–#30)

21. Add lease record structural validation before acquire/renew decisions.
22. Fail closed on malformed live rival lease records instead of silently replacing them.
23. Add lease owner generation identity to distinguish recycled server/job identities.
24. Add deterministic acquire contention fixture with two simulated servers.
25. Add deterministic renew/lost-lease contention fixture.
26. Add deterministic release-after-loss fixture.
27. Add lease-expiry boundary tests at `expiry - ε`, `expiry`, and `expiry + ε` semantics.
28. Add shutdown release result aggregation so unresolved durable leases are observable.
29. Add bounded retry/reconciliation behavior for failed shutdown lease release.
30. Add automated multi-player lease isolation fixture across many keys.

## Batch 4 — Valuable mutation idempotency (#31–#40)

31. Define one canonical durable mutation transaction-id contract.
32. Require transaction identity for every valuable reward grant path.
33. Persist equip transaction identity or prove equip is naturally idempotent under exact replay.
34. Strengthen dismantle transaction ledger validation with complete outcome shape checks.
35. Reject transaction-id reuse with conflicting payload/content identity.
36. Add reward retry fixture for same grant + different instance GUID.
37. Add reward conflict fixture for same transaction + different content signature.
38. Add dismantle retry fixture across release/rejoin.
39. Add mutation ledger retention policy and bound.
40. Add cross-mutation ledger audit proving reward/equip/dismantle cannot erase each other's replay protection.

## Batch 5 — Migration, quarantine, and recovery (#41–#50)

41. Define current-to-next schema migration authoring contract.
42. Require sequential migration steps rather than arbitrary direct jumps.
43. Add migration step identity/version diagnostics.
44. Add malformed-record quarantine result that never rewrites the source record.
45. Add recoverable-vs-unrecoverable corruption classification.
46. Add recovery copy/backup contract before any destructive repair.
47. Add migration write-back compare/reconciliation protection against concurrent newer data.
48. Add migration failure fixture at every supported source schema.
49. Add future-schema downgrade protection fixture with unknown extra fields.
50. Add automated migration matrix runner used by the canonical full validator.

## Batch 6 — Capacity, overflow, and retention (#51–#60)

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
79. Add shutdown partial-DataStore-outage fixture.
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