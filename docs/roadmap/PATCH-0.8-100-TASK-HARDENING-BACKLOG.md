# Patch 0.8 — Co-op / Social / Session: 100-task hardening backlog

**Relationship to `PATCH-0.8-ACCEPTANCE.md`:** that document is the authority on whether Patch 0.8 answered its exit question at the source layer. It says yes, and records which candidate scope was DEFERRED and why. **This document does not re-decide any of that.** It ranks the hardening, verification, and deferral-closing work that sits underneath it.

**Cadence:** exact 10-task batches, one implementation PR per batch, merged only on `python scripts/validate.py full`.

**A note on speculative rows.** Patch 0.7 showed that pre-writing rows produces work that turns out not to be worth doing — an overflow bucket for a capacity that does not exist, durable records for facts already derived. Every row below names a module, contract, or path that exists today. A row that turns out to be wrong should be marked **DEFERRED with its reason**, never quietly completed.

**What cannot be automated:** the exit question — *is playing with other people easier, clearer and more fun?* — is experiential. Rows touching feel, readability, or ergonomics are labelled **UNMEASURED**, which is a boundary, not a gap.

## Batch 1 — Lobby state machine completeness (#1–#10)

1. Add a lobby fixture for every reason id `join` can return, asserting membership is unchanged on each refusal.
2. Add the same for `leave`, `setReady`, and `consumeLaunch`.
3. Prove lobby snapshot revisions increase monotonically across every accepted mutation.
4. Prove a snapshot is immutable at every depth, including the `Members` array and each member entry.
5. Prove `readSnapshot` never discloses a member field the network layer does not sanitize.
6. Add a bounded-party fixture at `MinimumPlayers` and `MaximumPlayers` exactly.
7. Prove a lobby constructed with invalid bounds fails closed at construction.
8. Prove `destroy` is idempotent and refuses every subsequent request.
9. Add a fixture proving repeated identical `setReady` calls do not churn the revision.
10. Add a source audit proving the lobby holds no Roblox service reference.

## Batch 2 — Launch handoff integrity (#11–#20)

11. Prove `attemptLaunch` cannot run reentrantly under a synchronous re-broadcast.
12. Prove a launch that fails roster binding stops the expedition and leaves no armed pressure.
13. Prove `OperationLifecycleService.prepareForLaunch` rejection leaves the lobby launchable again.
14. Prove `applyDurableStartingLoadouts` failure for one member does not abort the launch for the rest.
15. Add a fixture for a member disconnecting between `consumeLaunch` and `startExpedition`.
16. Prove the party size handed to the runtime always matches the consumed snapshot.
17. Prove the canonical seed is server-selected on every launch path.
18. Add a launch fixture asserting `launchInFlight` is false after every terminal branch.
19. Prove a second `attemptLaunch` during an active expedition is refused without side effects.
20. Add a source audit proving no client input reaches `startExpedition` options.

## Batch 3 — Run roster immutability (#21–#30)

21. Prove `ExpeditionRunRosterService.bind` refuses a second bind for the same run id.
22. Prove a roster is immutable at every depth once bound.
23. Prove roster read fails closed for an unknown run id rather than returning an empty roster.
24. Prove a disconnect never mutates a bound roster.
25. Prove a reconnecting participant matches the frozen roster by user id, not by session.
26. Prove a non-participant can never be added to a bound roster.
27. Add a roster fixture across the full bounded party size.
28. Prove roster identity survives a run id reuse attempt.
29. Prove reward distribution refuses to run when roster identity is missing.
30. Add a source audit proving only the launch path binds a roster.

## Batch 4 — Reward isolation across a party (#31–#40)

31. Prove a co-op reward grant reaches exactly one durable record.
32. Prove two members earning from the same source get distinct grant identities.
33. Prove a member's grant cannot be replayed onto a different member.
34. Add a full-party reward fixture asserting per-member durable isolation.
35. Prove a departed member receives no credit for work after departure.
36. Prove a late-joining non-participant receives no credit at all.
37. Prove reward distribution is idempotent under a repeated terminal outcome.
38. Prove a reward grant failure for one member does not roll back another's.
39. Add a shared-credit conflict fixture for the same run and source across members.
40. Add a source audit proving reward recipients derive from the frozen roster only.

## Batch 5 — Terminal return consensus (#41–#50)

41. Prove one member cannot tear down a squad run alone.
42. Prove a disconnected voter cannot strand the decision.
43. Prove the quorum threshold is server-owned and not client-supplied.
44. Prove a vote is idempotent per member.
45. Prove a vote from a non-participant is refused.
46. Add a consensus fixture at quorum minus one, exactly quorum, and above.
47. Prove consensus state is destroyed with the run it belongs to.
48. Prove a new run cannot inherit a previous run's consensus state.
49. Prove consensus progress disclosed to clients contains no private member state.
50. Add a source audit proving teardown authority has one owner.

## Batch 6 — Squad ping and coordination bounds (#51–#60)

51. Prove a ping payload beyond the bounded shape is refused.
52. Prove ping rate bounds hold per member independently.
53. Prove ping recipients are server-derived, never client-listed.
54. Prove a ping cannot disclose a position the recipient could not already observe.
55. Prove ping revisions increase monotonically per member.
56. Add a ping fixture across a full party asserting no cross-member leakage.
57. Prove a departed member's pings stop being delivered.
58. Prove ping state is cleared on run teardown.
59. **UNMEASURED** — ping readability and on-screen legibility during play.
60. Add a source audit proving no client authors a ping recipient set.

## Batch 7 — Revive ownership and continuity (#61–#70)

61. Prove revive requires server-verified distance.
62. Prove revive requires server-verified line of sight.
63. Prove hold continuity is server-tracked, not client-reported.
64. Prove an interrupted revive restores no health.
65. Prove a completed revive cannot be replayed into a second revive.
66. Prove a downed member's state is owned by `OperativeLifeService` alone.
67. Prove cooperative revive modifiers cannot stack beyond their authored bound.
68. Prove a revive in progress is cancelled when either participant leaves.
69. Add a revive fixture across every terminal branch of the resolver.
70. **UNMEASURED** — whether revive timing feels fair to both participants.

## Batch 8 — Squad failure and difficulty policy (#71–#80)

71. Prove squad failure cannot be triggered by a single client.
72. Add failure-evaluation fixtures across partial and total party loss.
73. Prove failure evaluation reads life state from the authoritative owner only.
74. Prove a failure outcome is committed exactly once.
75. Prove failure state cannot survive into the next run.
76. Prove party-size scaling reads size from the frozen run identity, not the live player count.
77. Prove scaling is deterministic for a given party size and seed.
78. Add a scaling fixture across every supported party size.
79. **UNMEASURED** — whether the resulting difficulty curve is fair across party sizes.
80. Add a source audit proving no client establishes squad-consequential state.

## Batch 9 — Co-op abuse surface (#81–#90)

81. Inventory every co-op remote and record its client-authored surface.
82. Prove no co-op remote accepts another player's identity.
83. Prove every co-op remote that mutates shared state carries a rate bound.
84. Prove a malformed co-op payload fails closed rather than partially applying.
85. Prove no co-op remote discloses another member's private state.
86. Prove owner identity on every co-op remote derives from the invoking player.
87. Prove a rate-limited co-op request leaves no partial mutation behind.
88. Add an abuse-resistance matrix binding each remote to its fixtures.
89. Prove the matrix cannot claim a remote that does not exist.
90. Add a source audit proving no co-op remote is reachable before its owner starts.

## Batch 10 — Closing deferrals and acceptance (#91–#100)

91. Re-evaluate **party formation / invites** — deferred pending cross-server session infrastructure.
92. Re-evaluate **friend join** — deferred pending session policy beyond same-server.
93. Re-evaluate **public/private session policy** — deferred pending a teleport layer.
94. Re-evaluate **matchmaking** — deferred pending play evidence that justifies it.
95. Re-evaluate **activity selection** — not yet applicable while First Descent is the only activity.
96. Re-evaluate **difficulty scaling** — deferred to multi-client play evidence.
97. Bind every SATISFIED row in `PATCH-0.8-ACCEPTANCE.md` to at least one automated fixture.
98. Add a validator that fails when an acceptance row names a fixture that does not exist or is not run.
99. Run the full canonical validation with every non-deferred row satisfied.
100. **UNMEASURED** — the exit question itself, answerable only by multi-client play.

## Rules

- Implement in exact 10-task batches; merge only after `python scripts/validate.py full` is green.
- After merge, mark the completed ten **DONE**, promote the next ten to **ACTIVE**.
- A row that should not be built is **DEFERRED with its reason**, never silently marked done.
- **UNMEASURED** rows do not hold source progression and must never be claimed from automation.
