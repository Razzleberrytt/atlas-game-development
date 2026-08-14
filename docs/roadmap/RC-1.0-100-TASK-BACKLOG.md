# Release Candidate 1.0 — 100-task readiness backlog

**Goal:** convert the proven, repeatedly upgraded game into a release candidate.

**What makes RC different from every patch before it.** Patches 0.1–0.9 could be answered at the source layer, because their exit questions were about whether a system exists and holds its invariants. **RC 1.0 cannot.** Its exit question is whether real players on real devices against real infrastructure have an acceptable experience — and no fixture answers that.

So this backlog is deliberately shaped differently: roughly half its rows are automatable readiness work, and the rest are **evidence rows that stay UNMEASURED until a run actually happens**. A green gate is a precondition for RC, never a substitute.

**Nothing here may be claimed from CI.** The evidence ladder is `E0 design → E1 source/static → E2 Studio init → E3 single-player → E4 multiplayer → E5 device/perf → E6 outside-player fun → E7 live telemetry`. Automation reaches E1. Everything above it needs a run.

**Cadence:** exact 10-task batches, merged only on `python scripts/validate.py full`.

## Batch 1 — Publishing and place identity (#1–#10)

1. Define the canonical published place inventory and its intended universe layout.
2. Record every place id the build expects, with none invented.
3. Prove no place id or universe id is hard-coded outside the canonical config.
4. Prove the build refuses to run against an unexpected place identity.
5. Add a place-identity preflight that names what it observed versus expected.
6. Prove the Main World build and the operation build cannot be confused for one another.
7. **UNMEASURED** — first publish of the operation place.
8. **UNMEASURED** — first publish of the dedicated Main World place.
9. Prove teleport policy is absent until authorized place ids exist.
10. Add a source audit proving no transport path activates without an authorized id.

## Batch 2 — DataStore quota and production limits (#11–#20)

11. Measure per-server DataStore read and write budget under a full party.
12. Record the measured budget as a validator-enforced expectation.
13. Prove the inventory lease renewal cadence stays inside that budget.
14. Prove no path issues an unbounded number of writes per player action.
15. Prove the durable record size budget holds against the largest realistic record.
16. Add a quota simulation across a full server of players.
17. Prove throttling degrades to refusal rather than to silent loss.
18. Prove a quota refusal is diagnosable from its reason id alone.
19. **UNMEASURED** — live DataStore behaviour under real load.
20. Add a validator binding measured quota expectations to fixtures.

## Batch 3 — Multi-server correctness at scale (#21–#30)

21. Extend the multi-server harness to more servers than a party size.
22. Prove lease contention resolves deterministically under many contenders.
23. Prove no player can be resident on two servers simultaneously.
24. Prove a server crash during contention leaves exactly one eventual owner.
25. Prove lease expiry cannot be observed as two overlapping ownership windows.
26. Add a seeded soak simulation across many players and servers.
27. Prove the soak simulation is reproducible from its seed.
28. Prove the invariant checker finds no violation after a soak run.
29. **UNMEASURED** — real cross-server behaviour on live infrastructure.
30. Add a validator running a bounded soak inside the canonical gate.

## Batch 4 — Performance budgets (#31–#40)

31. Define a server step-time budget and record it.
32. Define a client frame-time budget and record it.
33. Define a memory budget for a full session.
34. Prove no server system exceeds its per-step allocation in a fixture.
35. Prove the heartbeat catch-up cap prevents a frame spiral under load.
36. Add an instrumentation surface that reports per-owner step cost.
37. Prove instrumentation is server-only and carries no client authority.
38. **UNMEASURED** — measured frame time on representative hardware.
39. **UNMEASURED** — measured memory across a long session.
40. **UNMEASURED** — measured server step time under a full server.

## Batch 5 — Device and input readiness (#41–#50)

41. Inventory every input path by device family.
42. Prove every gameplay action is reachable on every supported device.
43. Prove no action requires an input a supported device lacks.
44. Prove device-adaptive hints resolve for every device family.
45. Add a device coverage report by action and family.
46. **UNMEASURED** — touch ergonomics on a real phone.
47. **UNMEASURED** — gamepad ergonomics on a real controller.
48. **UNMEASURED** — readability at small screen sizes.
49. Prove no device path is gated behind an unbounded `WaitForChild`.
50. Add a source audit proving every controller bounds its waits.

## Batch 6 — Client bootstrap resilience (#51–#60)

51. Prove the client bootstrap survives one controller failing to start.
52. Add per-controller isolation so one failure cannot halt the rest.
53. Prove every controller's `start` is bounded in time.
54. Add a bootstrap health probe reporting which controllers started.
55. Prove a stalled controller is reported rather than silently absent.
56. Prove `PlayerGui` reaches its expected child count on a healthy start.
57. Add a fixture asserting the controller start order's documented meaning.
58. Prove no controller establishes consequential state.
59. **UNMEASURED** — observed client health in a real session.
60. Add a source audit proving the bootstrap has one owner.

## Batch 7 — Security and abuse hardening (#61–#70)

61. Inventory every remote in the build and its client-authored surface.
62. Prove no remote accepts an identity from its payload.
63. Prove every mutating remote carries a rate bound.
64. Prove every remote fails closed on a malformed payload.
65. Prove no remote discloses another player's private state.
66. Add an exploit-resistance matrix binding each remote to fixtures.
67. Prove no remote is reachable before its owner has started.
68. Prove no client can select a durable owner, value, or schema field.
69. **UNMEASURED** — adversarial testing by a real attacker.
70. Add a validator failing when a remote exists with no matrix row.

## Batch 8 — Telemetry and operability (#71–#80)

71. Define the minimum telemetry needed to operate a live server.
72. Prove telemetry is server-only and carries no client authority.
73. Add counters for durable read, write, retry, and quarantine outcomes.
74. Prove counters are consumed by an operator surface rather than merely recorded.
75. Add a diagnostic snapshot answerable without attaching a debugger.
76. Prove diagnostics cannot mutate the state they report.
77. Prove a quarantined record is discoverable from a player id alone.
78. Add an operator runbook for the failure classes the code already names.
79. **UNMEASURED** — live telemetry from a real session.
80. Prove every reason id an operator may see is classified and documented.

## Batch 9 — Content and world acceptance (#81–#90)

81. Close the BA-014 Main World evidence run against the exact built artifact.
82. Prove the run record's build identity matches the artifact it observed.
83. Re-derive the acceptance scope and record what the mapped build can answer.
84. **UNMEASURED** — the BA-014 run itself, in Studio against the built place.
85. Prove no acceptance verdict can be recorded without matching build identity.
86. Prove environment breadth admission stays gated behind that evidence.
87. Prove the imported preservation material never becomes a second authority.
88. Prove the operation project maps no recovered whole world.
89. **UNMEASURED** — visual acceptance of the mapped world.
90. Add a validator binding world acceptance rows to their evidence packets.

## Batch 10 — Release gate (#91–#100)

91. Assemble a machine-readable RC acceptance matrix across every patch.
92. Bind every automatable row to at least one fixture.
93. Prove the matrix cannot claim a fixture that does not exist or is not run.
94. Prove every UNMEASURED row is labelled and carries no automated claim.
95. Re-evaluate every deferral from Patches 0.6 through 0.9 against RC needs.
96. Prove no patch's deferred row silently became a release blocker.
97. Run the full canonical validation with every automatable row satisfied.
98. **UNMEASURED** — the consolidated STOP / PLAY / FIX pass.
99. **UNMEASURED** — outside-player evidence that the game is worth playing.
100. **UNMEASURED** — the release decision, which is a human judgement and not a gate output.

## Rules

- Implement in exact 10-task batches; merge only after `python scripts/validate.py full` is green.
- **UNMEASURED** rows cannot be satisfied by automation and must never be claimed from CI.
- A row that should not be built is **DEFERRED with its reason**, never silently marked done.
- Roughly forty rows here are evidence rows. A green gate makes RC *possible*; it does not make RC *true*.
