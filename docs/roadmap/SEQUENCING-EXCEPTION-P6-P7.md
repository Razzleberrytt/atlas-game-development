# Temporary P6/P7 Sequencing Exception

## Status

Closed on 2026-07-21 after owner-directed P6 prototype sign-off.

This exception changes sequencing only. It does **not** convert missing evidence into a passing result.

Final exception state:

- `P7-0101` shared contracts and configuration are complete through PR #71.
- `P7-0102` class selection and assignment are complete through PR #72.
- The exception is retired; class effects now follow normal P7 sequencing.

## P6 status

- The project owner reported that the requested local multiplayer tests ran fine and directed the milestone to be marked done for now.
- `P6-0108` and `P6-0109` are complete for the current prototype without an unsupported tuning change.
- Raw routed telemetry was not retained. That limitation is recorded for measured P12 balance validation, and no precise scarcity claim is inferred from it.

## Narrow P7 exception

`P7-0101` was permitted because it contains declarations and invariant fixtures only.

`P7-0102` was also permitted because class selection and assignment are independent of P6 balance:

- the three starting classes are already universally available;
- duplicate roles remain legal;
- the server owns a temporary insertion selection window, deterministic fallback assignment, lock state, revisions, and safe roster disclosure;
- the client submits only a bounded request ID and known class ID;
- no class action is activated;
- no health, revive, combat, ammunition, objective, resource, cooldown, or persistence state is mutated;
- the Engineer's provisional resupply numbers are not read by selection runtime.

The current mission has no separate Briefing phase. Until P10 introduces the final match shell, the bounded 20-second `Insertion` phase is the temporary selection window. The server locks assignment at the exact authoritative insertion deadline.

## Normal sequencing restored

The following are no longer blocked by P6 and proceed through the normal P7 order:

- `P7-0103` Combat Specialist Brace runtime;
- `P7-0104` Medic treatment/revive runtime;
- `P7-0105` Engineer Field Resupply runtime;
- all later P7 class-effect integration, tuning, and Studio balance validation.

Engineer Field Resupply must still use bounded configuration and receive focused validation when implemented.

## Resume rule

The exception closed with this disposition:

1. Accept the owner's qualitative local test result for prototype progression.
2. Apply no scarcity tuning without retained evidence.
3. Revisit Engineer Field Resupply charges and rounds before its ammunition-grant runtime is finalized.
4. Repeat measured scarcity validation in P12.

This document is retained as sequencing history only. `P7-0101` and `P7-0102` remain complete; consequential P7 work now follows the canonical execution roadmap.
