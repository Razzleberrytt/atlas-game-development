# Definition of Done

A roadmap task is complete only when every applicable requirement below is satisfied.

**Current execution authority:** `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` and `docs/roadmap/PRODUCTION-CORE-V2.7.md`. Accepted runtime evidence and current Roblox platform behavior outrank authored roadmap prose.

A source change may be complete as source work while a Studio/runtime gate remains incomplete. Do not collapse those two facts into one status.

## 1. Scope

- The task has one clear objective and an identified roadmap ticket or maintenance reason.
- Changes remain within the task’s stated boundaries.
- Any necessary scope adjustment is documented before implementation.
- No blocked persistence, broad visual/content expansion, or later vertical-slice work is smuggled into a v2.7 rollout task.
- Existing working systems are reconciled rather than duplicated by a parallel authority path.

## 2. Implementation

- The intended behavior is implemented.
- Names and module boundaries follow current architecture and the nearest applicable specification.
- Consequential game state remains server-authoritative.
- Clients submit intent rather than authoritative outcomes.
- Balance values are configuration-driven where appropriate.
- No unrelated cleanup or speculative framework work is included.
- Stable IDs and explicit versions are preserved where state can survive code changes.

## 3. Runtime-state and presentation ownership

When the task touches replicated current state, presentation, lifecycle, or active-place migration:

- mechanical owner is explicit;
- replication owner/path is explicit;
- presentation owner is explicit;
- the connection/object lifetime is classified as application, character, or operation scope;
- current-state payloads use a stable semantic key;
- change tokens/revisions are derived from mutation, not wall-clock/frame/random publish time;
- unchanged current state is not repeatedly sent merely because time passed;
- pre-ready retention keeps independent current facts independent;
- production Highlight creation routes through one accepted ownership path;
- broad production Highlight targets are rejected or reported;
- stream-out does not falsely erase authoritative semantic truth;
- stale asynchronous work cannot mutate a newer character/run/target after its scope ends.

## 4. v2.7 cutover discipline

For Tickets 331–360 or equivalent active-place rollout work:

- the applicable producer/consumer/Highlight row is recorded in the cutover ledger;
- baseline counters are captured before behavioral cutover where feasible;
- the rollout stage (`R0`–`R5`) is named;
- temporary feature flags have an owner, expected metric change, rollback trigger, and removal gate;
- one known-good rollback commit/build or flag configuration is recorded;
- compatibility is removed only per accepted ledger row;
- no compatibility path is removed merely because a replacement exists in source.

## 5. Automated validation

- Repository layout validation passes.
- StyLua passes.
- Selene passes.
- New deterministic logic has focused tests where feasible.
- Applicable Lune fixtures pass.
- Rojo build passes.
- Tests/security checks are not weakened merely to make CI green.
- Any intentional warning/debt change is explained and does not silently worsen an established ratchet.

## 6. Studio and runtime validation

- Manual verification steps are written clearly.
- Roblox Studio results are reported honestly; unperformed checks are explicitly listed.
- No Studio-only result is inferred from a successful source build.
- No new unexplained Living Kingdoms console errors or warnings are introduced.
- Existing v2.7 stop-condition warnings remain blockers until a closure packet proves otherwise.
- Build/commit/place identity is recorded for evidence-bearing runs.

When applicable, evidence covers the relevant cases:

- cold start / client readiness;
- five-reset stability;
- three-respawn stability;
- delayed-ready and late-join reconstruction;
- two-player ownership/reset/disconnect;
- stream-out/rebind;
- animation marker/listener repetition;
- active network/presentation soak;
- representative performance/device checks.

## 7. Baseline and cleanup acceptance

For lifecycle-sensitive work:

- connection counts are measured at the appropriate named baseline;
- network attempt/send rates are bounded and do not monotonically grow across resets;
- Highlight leases and transient presentation objects return to accepted baseline after cleanup;
- viewmodel/camera/animation ownership returns to accepted baseline after respawn;
- no broad Highlight violation remains in an accepted normal-play run;
- queue/discard warnings are zero for any run claimed as incident-closure evidence.

A screen that looks correct once is not sufficient evidence of lifecycle correctness.

## 8. Evidence level

Use the project scale honestly:

```text
E0 design only
E1 source/static acceptance
E2 Studio initialization
E3 single-player integrated behavior
E4 multiplayer/adversarial behavior
E5 device/performance/reliability
E6 outside-player fun
E7 live telemetry
```

- Code existing is not E3.
- One desktop run is not E5.
- A roadmap/documentation commit does not promote evidence level.
- Promotion requires an accepted evidence packet supporting the claimed level.

## 9. Documentation

- Related specifications or architecture notes are updated.
- The active roadmap reflects accurate task status.
- The cutover ledger is updated for migration work.
- Evidence packet location is linked for accepted runtime gates.
- New limitations or technical debt are recorded.
- Historical documents are not rewritten to pretend they were current authority at the time.

## 10. Integration and rollback

- The project still builds, synchronizes, or launches according to the current milestone’s capabilities.
- The change is reviewable as one coherent pull request.
- Rollback is possible through normal Git history or an explicitly documented rollout flag/configuration.
- A rollback does not require manually reversing a pile of unrelated Studio edits.
- The known-good rollback point is preserved while an active cutover is still reversible.

## Evidence required in the pull request

At minimum:

- roadmap ticket / rollout stage;
- summary of behavior changed;
- authority/ownership changes;
- exact validation commands and results;
- manual test checklist;
- evidence packet or explicit statement that Studio/runtime validation was not run;
- before/after counters when the task changes state delivery or presentation ownership;
- screenshots/video/profile captures when central to the claim and available;
- rollback checkpoint and trigger for rollout work;
- known limitations and unverified claims;
- evidence level before and after.

A task must not be marked complete merely because code was written, a warning disappeared, or the screen looked correct once.
