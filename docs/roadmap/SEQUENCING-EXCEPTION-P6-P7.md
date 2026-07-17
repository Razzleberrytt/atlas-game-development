# Temporary P6/P7 Sequencing Exception

## Status

Approved temporary exception while the required Roblox Studio/Codex-assisted validation workflow is unavailable.

This exception changes sequencing only. It does **not** convert missing evidence into a passing result.

Current exception state:

- `P7-0101` shared contracts and configuration are complete through PR #71.
- `P7-0102` class selection and assignment are permitted as the next independent runtime slice.
- All class effects remain blocked.

## P6 status

- `P6-0108` controlled one-, two-, and four-operative Studio evidence is **deferred**.
- `P6-0109` scarcity tuning and P6 sign-off remain **blocked** because the evidence matrix is empty.
- Current starting ammunition, reserve cap, cache grants, and cache placement remain provisional.
- No claim may be made that scarcity is balanced, fair, generous, or unavoidable until the deferred runs are completed.

## Narrow P7 exception

`P7-0101` was permitted because it contains declarations and invariant fixtures only.

`P7-0102` is also permitted because class selection and assignment are independent of P6 balance:

- the three starting classes are already universally available;
- duplicate roles remain legal;
- the server may own a temporary insertion selection window, deterministic fallback assignment, lock state, revisions, and safe roster disclosure;
- the client may submit only a bounded request ID and known class ID;
- no class action is activated;
- no health, revive, combat, ammunition, objective, resource, cooldown, or persistence state is mutated;
- the Engineer's provisional resupply numbers are not read by selection runtime.

The current mission has no separate Briefing phase. Until P10 introduces the final match shell, the bounded 20-second `Insertion` phase is the temporary selection window. The server locks assignment at the exact authoritative insertion deadline.

## Still blocked

The following remain blocked until P6 evidence and sign-off resume or a separately documented evidence-independent exception is approved:

- `P7-0103` Combat Specialist Brace runtime;
- `P7-0104` Medic treatment/revive runtime;
- `P7-0105` Engineer Field Resupply runtime;
- all later P7 class-effect integration, tuning, and Studio balance validation.

In particular, Engineer Field Resupply must not be implemented while its scarcity relationship remains unvalidated.

## Resume rule

When the Studio validation workflow becomes available:

1. Resume `P6-0108` from the existing run sheet.
2. Populate comparable one-, two-, and four-operative evidence.
3. Complete or explicitly decline evidence-supported tuning in `P6-0109`.
4. Revisit Engineer Field Resupply charges and rounds before any ammunition-grant runtime is implemented.
5. Remove or close this exception when normal milestone sequencing is restored.

This document temporarily overrides only the blanket statement that no P7 work may begin before P6 exit. The exception currently applies to `P7-0101` and `P7-0102`; all consequential class-effect work remains gated.
