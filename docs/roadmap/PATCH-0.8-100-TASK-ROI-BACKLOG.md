# Patch 0.8 — Co-op / Social / Session: ranked task backlog

**Status:** active task authority for Patch 0.8
**Cadence:** exact 10-task batches, one implementation PR per batch, merged only on `python scripts/validate.py full`.

## What this patch can and cannot decide

Patch 0.8's exit question is *"is playing with other people easier, clearer and more fun?"* — which is experiential and cannot be automated. This backlog therefore ranks the **authority, lifecycle, and session-correctness** half of the patch: the part where real defects live and where automation is the right instrument.

Rows that turn on feel, readability, or ergonomics are labelled **UNMEASURED** rather than claimed. That is not a gap in the work; it is the honest boundary of what a fixture can answer.

The Patch 0.7 discipline carries forward: no row is marked DONE without an automated gate, and a row that should not be built is marked **DEFERRED with its reason** rather than quietly completed.

## Baseline before this backlog

Co-op already has real infrastructure: `ExpeditionLobbyService` (join/leave/ready/launch), `ExpeditionPartyDecisionService`, `SquadPingService`, `SquadFailureService`/`SquadFailureEvaluator`, `OperativeReviveSessionService`/`OperativeReviveResolver`, `MatchResultService`, and the inventory session lease hardened through Patch 0.7.

## Batch 1 — Launch and lobby lifecycle safety (#1–#10) — DONE

1. **[DONE]** Release the launch latch on every path, including an unhandled error.
2. **[DONE]** Arm mission and horde pressure only once a run is actually live.
3. **[DONE]** Add a launch-sequence source audit pinning both.
4. **[DONE]** Add lobby membership lifecycle fixtures for join/leave/ready across the bounded party size.
5. **[DONE]** Add a launch-pending fixture proving no second launch can start while one is in flight.
6. **[DONE]** Prove a member leaving during launch-pending cannot strand the lobby unlaunchable.
7. **[DONE]** Prove ready state is reset by a consumed launch so a stale ready cannot relaunch.
8. **[DONE]** Add a lobby fixture for a full party rejecting further joins.
9. **[DONE]** Prove the lobby refuses ready changes while an expedition is active.
10. **[DONE]** Add a source audit proving only the lobby decides launchability.

## Batch 2 — Session membership and reconnect (#11–#20) — ACTIVE

11. Define the canonical party-membership contract separate from lobby readiness.
12. Add a late-join policy contract with an explicit accept/refuse decision.
13. Add a reconnect-window contract for a disconnected member.
14. Prove a disconnected member's slot is released deterministically.
15. Prove a reconnecting member cannot duplicate their own membership.
16. Add a party-size reconciliation fixture between lobby and live runtime.
17. Prove a launch cannot use a party size the lobby no longer has.
18. Add a member-departure-during-run fixture proving the run stays coherent.
19. Prove return-to-hub is deterministic for every member.
20. Add a source audit proving membership has one owner.

## Batch 3 — Shared credit and reward isolation (#21–#30)

21. Define the canonical shared-credit contract for co-op rewards.
22. Prove one player's reward cannot land in another player's durable record.
23. Prove shared credit cannot double-grant to the same player.
24. Add a reward-isolation fixture across a full party.
25. Prove a departed member cannot receive credit for work after departure.
26. Prove a late-joining member cannot receive credit for work before joining.
27. Add a per-member grant identity contract for co-op rewards.
28. Prove co-op reward grants remain replay-safe per member.
29. Add a shared-credit conflict fixture for the same run and source.
30. Add a source audit proving reward distribution passes through one owner.

## Batch 4 — Squad interaction authority (#31–#40)

31. Prove squad pings cannot be authored by a client beyond a bounded shape.
32. Prove ping rate bounds hold per member.
33. Prove revive requires server-verified proximity and state.
34. Prove revive cannot be replayed into multiple revives.
35. Prove a downed member's state is server-owned.
36. Add squad-failure evaluation fixtures across partial and total party loss.
37. Prove squad failure cannot be triggered by a single client.
38. Add difficulty/scaling policy contract bound to party size.
39. Prove scaling reads party size from the authoritative owner only.
40. Add a source audit proving no client establishes squad-consequential state.

## Batch 5 — Abuse and security boundaries (#41–#50)

41. Inventory every co-op remote and its client-authored surface.
42. Prove no co-op remote accepts another player's identity.
43. Add rate bounds for every co-op remote that mutates shared state.
44. Prove a malformed co-op payload fails closed rather than partially applying.
45. Prove a co-op remote cannot be used to observe another player's private state.
46. Add a co-op remote source audit proving owner derivation from the invoking player.
47. Prove session policy (public/private) is server-decided.
48. Prove an unauthorised member cannot consume a launch.
49. Add a co-op abuse-resistance matrix.
50. Bind the matrix rows to automated fixtures.

## Batches 6–10 (#51–#100)

Deliberately not enumerated yet. Patch 0.7 showed that pre-writing fifty rows produces work that turns out to be speculative — an overflow bucket for a capacity that does not exist, durable records for derived facts. Rows #51–#100 will be ranked from what Batches 1–5 actually expose, so they describe defects and boundaries that are real rather than imagined.

## Rules

- Implement in exact 10-task batches; merge only after `python scripts/validate.py full` is green.
- After merge, mark the completed ten **DONE**, promote the next ten to **ACTIVE**.
- Do not create `GATED — manual testing` rows. Experiential facts are labelled **UNMEASURED** and do not hold source progression.
- A row that should not be built is **DEFERRED with its reason**, never silently marked done.
