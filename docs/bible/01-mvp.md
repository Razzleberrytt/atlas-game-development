# Living Kingdoms — Minimum Viable Product

## MVP promise

A player can start a match, gather wood, build a Barracks, train Swordsmen, destroy an enemy Town Hall, and immediately understand why another match could be fun.

## Starting state

- 1 Town Hall
- 3 Workers
- 0 military units
- 0 stored Wood
- Nearby harvestable trees
- 1 enemy base

## MVP content

### Resource

- Wood

### Player units

- Worker
- Swordsman

### Player buildings

- Town Hall
- Barracks

### Enemy content

- Enemy Town Hall
- Basic defending units
- Minimal enemy production or attack behavior

### Victory condition

Destroy the enemy Town Hall.

### Defeat condition

The player loses all production capability and cannot reasonably recover, or the player Town Hall is destroyed according to the final match rules.

## Required gameplay systems

1. Overhead camera
2. Mouse and touch input foundations
3. Single and multi-unit selection
4. Commanded movement
5. Basic formation spacing
6. Resource nodes
7. Worker gathering and return loop
8. Resource counter UI
9. Building placement
10. Construction progress
11. Unit production queue
12. Health and damage
13. Target acquisition and attacks
14. Enemy AI
15. Match state
16. Victory and defeat presentation

## Explicitly deferred

- Persistent progression
- PvP matchmaking
- Multiple factions
- Heroes
- Technology trees
- Fog of war
- Minimap
- Stone, Food, or Gold
- Naval combat
- Guilds and alliances
- Battle passes and monetization
- Detailed final art
- Campaign mode

## Prototype success criteria

The MVP is successful when:

- Unit selection and movement feel responsive.
- The complete loop works without developer intervention.
- A first-time player can understand the objective.
- A match can be completed on desktop.
- The design has a credible path to mobile controls.
- Playtesters voluntarily choose to replay.

## First vertical slice

Before the full MVP, build a gray-box slice containing five Workers on a flat map. The player can pan and zoom the camera, select one or several Workers, issue a movement command, and observe the units move without stacking at exactly one point.
