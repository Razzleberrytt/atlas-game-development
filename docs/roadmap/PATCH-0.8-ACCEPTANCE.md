# Patch 0.8 — Co-op / Social / Session Expansion Acceptance

**Status:** SOURCE COMPLETE — CONSOLIDATED STUDIO/DEVICE VERIFICATION PENDING  
**Accepted source baseline:** 2026-08-14  
**Patch exit question:** Is playing with other people easier, clearer and more fun than before without compromising authority or lifecycle stability?

## Decision

Yes at the source/architecture layer. Patch 0.8 now has a coherent server-authoritative co-op session boundary, explicit active-run membership policy, immutable reward identity, reconnect handling, readable squad coordination primitives, robust revive ownership, and deterministic terminal return consensus. No later-patch breadth is required to answer the exit question.

This document does **not** claim Studio/device verification. Runtime, input-device, multi-client presentation, and representative performance evidence remain part of the consolidated STOP / PLAY / FIX pass. A failure in that pass reopens Patch 0.8 immediately.

## Acceptance matrix

| Candidate scope | Disposition | Source authority / reason |
| --- | --- | --- |
| proper party formation / invites | DEFERRED | The current 1–4 player same-server lobby is sufficient for the proven loop. Cross-server invites would introduce teleport/session infrastructure before evidence justifies it. |
| friend join | DEFERRED | Requires product/session policy beyond the current same-server MVP. Late join is explicitly closed rather than ambiguously supported. |
| readiness | SATISFIED | `ExpeditionLobbyService` owns ready state, idempotent reconciliation, launch pending state, and monotonic revisions. |
| activity selection | NOT YET APPLICABLE | Only First Descent is an eligible activity. Adding a selector for one activity would be decorative architecture. |
| public/private session policy | DEFERRED | No cross-server matchmaking/teleport layer exists yet. Current policy is same-server lobby membership plus frozen launch roster. |
| matchmaking where justified | DEFERRED | Not justified by play evidence yet; building it now would expand operational complexity without improving the tested core loop. |
| late join / reconnect policy | SATISFIED | Non-participant late join is rejected; frozen launch participants may reconnect without changing reward identity. |
| squad state and pings | SATISFIED | Class squad presentation and server-approved bounded squad pings already exist with device-aware input and server-owned recipient/revision rules. |
| revive / co-op interaction refinement | SATISFIED | `OperativeReviveSessionService` owns identity, distance, LOS, hold continuity, interruption, completion, health restoration, and cooperative modifiers. |
| difficulty / scaling policy | DEFERRED TO PLAY EVIDENCE | Party size is frozen into expedition runtime identity. Further scaling changes require multi-client play evidence rather than speculative tuning. |
| reward isolation / shared-credit rules | SATISFIED | `ExpeditionRunRosterService` freezes exact launch participants and reward distribution fails closed when roster identity is missing or inconsistent. |
| deterministic return-to-hub behavior | SATISFIED | Terminal return now uses `ExpeditionPartyDecisionService`; one player cannot tear down the squad run, disconnected voters cannot strand it, and clients see quorum progress. |
| abuse / security boundaries | SATISFIED | Client intents remain narrow; server owners derive identity, roster, timing, eligibility, reward recipients, ping recipients, revive validity, and teardown authority. |

## Patch 0.8 merged increments

- PR #503 — co-op session reconciliation and immutable run roster authority.
- PR #504 — explicit late-join and reconnect policy.
- PR #505 — deterministic connected-party terminal return consensus.
- PR #506 — visible return-vote progress and duplicate-vote suppression.

## Exit-gate rationale

The deferred rows are intentionally not counted as missing implementation. The roadmap labels Patch 0.8 items as **candidate scope**, and specifically says matchmaking is only appropriate "where justified." Cross-server invites, friend routing, public/private queues, and matchmaking all depend on a session/teleport product decision that the current playable evidence has not earned. Building them now would violate the global patch law by increasing breadth and operational risk without closing a known co-op failure.

Difficulty scaling is also deliberately evidence-gated. The correct next input is multi-client play: completion rate, revive pressure, enemy density/readability, boss duration, and whether adding players makes the run trivial or chaotic. Tuning before that evidence would encode guesses as policy.

## Verification still required

The consolidated Patch 0.8 runtime pass should prove at minimum:

1. 2–4 players can join the lobby, reconcile readiness, and launch exactly once.
2. A non-participant cannot join an active expedition.
3. A disconnected launch participant can reconnect without changing the frozen reward roster.
4. Squad class cues and pings remain readable on keyboard, controller, and touch.
5. Revive begin/interrupt/complete behavior remains authoritative with two real clients.
6. A completed run cannot be torn down by one connected squad member; return quorum progress is visible and disconnect cannot deadlock return.
7. Rewards are distributed only to the frozen run roster.
8. Replay/return leaves the next lobby/run in a clean state.
9. Representative 4-player combat does not reveal a scaling, network, or readability blocker.

Until that pass runs, Patch 0.8 is **SOURCE COMPLETE — VERIFICATION PENDING**, not runtime-verified.

## Next source lane

With no known Patch 0.8 source blocker remaining, dependency-safe work may advance to **Patch 0.9 — Content Expansion + Production Pipeline** under the existing build-through policy. Any Patch 0.8 failure discovered by Studio/device evidence immediately preempts 0.9 work.
