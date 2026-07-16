# Decision 0002 — Automatic Combat Targeting

**Status:** Accepted

**Date:** 2026-07-15

## Context

The cooperative-survival pivot established one-operative control, scarce ammunition, limited visibility, and server-authoritative combat, but the initial roadmap assumed manual pointer-to-world aiming. That assumption would make precise cursor execution a central responsibility alongside movement, positioning, reload timing, class abilities, interaction, and resource management.

The intended player focus is tactical survival and squad coordination. Combat should reward positioning and resource decisions while remaining readable, difficult, and secure.

## Decision

Operatives automatically acquire and fire on valid hostile targets within weapon range.

Players directly control:

- Movement and positioning
- Interaction
- Reload timing
- Class abilities
- Resource decisions

Automatic target acquisition requires:

- Gameplay-valid visibility
- Line of sight
- A valid operative combat state
- Available ammunition
- Weapon readiness
- A living, targetable, hostile candidate within range

Initial target priority is:

1. The closest valid hostile actively threatening the operative.
2. Otherwise, the closest valid hostile in range.

Target acquisition, automatic fire, ammunition consumption, cadence, hit validation, damage, and target legality are server-authoritative. The client may provide immediate targeting and firing presentation, but it cannot establish ammunition truth, legal hits, or damage.

## Architecture consequence

The intended MVP architecture no longer includes an `AimController`. Local firearm responsibility is limited to player-directed reload input and non-authoritative target/firing presentation. The server combat boundary owns target validation, priority selection, automatic fire, and all consequential results.

## Deferred option

A lightweight manual priority-target override may be added later if playtesting shows that automatic priority prevents necessary tactical expression. It is not required for the first combat implementation and must not be scaffolded speculatively.

## Consequences

- Position, range, visibility, obstruction, hostile pressure, reload timing, and ammunition become the main combat decisions.
- P2 is reordered around candidate legality, deterministic priority, automatic cadence, server hit resolution, and responsive presentation.
- The definition of an actively threatening hostile and target-switch/tie behavior must be specified before implementation.
- Automatic combat must not reveal hidden hostiles through replicated or client-predicted presentation.
- LK-0101 remains the first implementation task and is unaffected by this decision.

## Relationship to Decision 0001

This is a focused amendment to the combat-control model, not a rewrite of the cooperative-survival pivot. Decision 0001 remains the historical record of why the project changed direction and what foundation was preserved.
