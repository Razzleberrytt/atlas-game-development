# Bounded pressure pacing (P5-0105)

P5-0105 adds explicit pacing rules between the existing authored Blackwater Relay waves. It does not add procedural hordes, endless spawning, adaptive difficulty, new enemy archetypes, loot, or ammunition scarcity.

## Goal

Create readable pressure and recovery beats while preserving the existing mission, enemy lifecycle, and server-authority boundaries.

## First slice

The first slice is a pure decision domain. At one deterministic server evaluation boundary it decides whether an authored wave may release from already-authoritative facts:

- mission resolution state
- requested and completed wave indices
- active production enemy count
- concurrent pressure budget
- current server timestamp
- last accepted wave timestamp
- minimum interval between waves
- optional recovery deadline

The domain owns no Roblox instances, scheduler, mission mutation, spawn request, enemy health, or client disclosure.

## Stable rejection precedence

A wave is withheld in this order:

1. invalid facts
2. mission resolved
3. wave already released
4. concurrent enemy budget reached
5. recovery window active
6. minimum inter-wave interval active

Otherwise the release is accepted.

Exact deadlines are open boundaries: a recovery window or interval no longer blocks at its exact deadline.

## Runtime follow-up

A later integration slice will consume this domain inside the production operation integration service. That slice must:

- retain authored wave identities and fair-spawn validation
- cap simultaneous pressure below the global enemy capacity
- release no wave after mission resolution
- record accepted release timestamps server-side
- create explicit recovery windows after meaningful pressure clears
- use the existing single bounded operation update connection
- expose no new client authority remote

## Validation boundary

This slice is complete when the pure domain and fixture pass StyLua, Selene, all Lune fixtures, and the Rojo build. It does not claim that final encounter pacing feels good; that requires later Studio playtesting after runtime integration.
