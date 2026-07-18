# Enemy recovery and Field Intel loot

## Goal

Make confirmed enemy deaths occasionally create an immediate, readable battlefield reward without weakening Living Kingdoms' hard ammunition economy or adding client authority.

## Production tuning

| Reward | Chance per confirmed death | Grant | Lifetime |
| --- | ---: | ---: | ---: |
| Salvaged Rounds | 7% | 8 reserve rounds | 16 seconds |
| Heavy Ammo Case | 1% | 20 reserve rounds | 24 seconds |
| Field Dressing | 5% | up to 30 canonical health | 18 seconds |
| Field Intel | 2% | 40 shared Field XP | 18 seconds |
| No physical reward | 85% | — | — |

Ammunition remains an eight-percent event with an expected return of 0.76 reserve rounds per kill before reserve-cap clamping. Recovery and Intel are separate tactical rewards; they do not increase ammunition sustain.

## Collection behavior

- The existing ammunition pickups remain automatic and retain their current 7%/1% scarcity tuning.
- Recovery loot uses one server-owned death scan and one global prompt listener.
- The companion recovery layer is capped at eight active pickups.
- Field Dressings and Field Intel each expire after 18 seconds.
- A collecting player must still be alive, within eight studs, and mapped to the authoritative drop.
- Field Dressings heal up to 30 canonical operative health and cannot revive an incapacitated operative.
- Field Intel awards exactly 40 shared Field XP once.

## Authority

Clients send no reward type, amount, health, ammunition, XP, position, or outcome.

- healing commits through `OperativeHealingResolver` and `OperativeLifeService`
- Field Intel commits through `RunProgressionService`
- death truth comes from server-authored enemy life-state attributes
- every drop has one server-owned identity and one claimed flag
- no client RemoteEvent, touch collection, DataStore, permanent inventory, or paid power is added

## Studio acceptance

1. Confirm the existing orange/cyan ammunition behavior and 7%/1% tuning remain unchanged.
2. Kill enough walkers to observe red Field Dressings and teal Field Intel drops.
3. Confirm both are readable from the isometric camera and disappear after 18 seconds.
4. Take damage, collect a Field Dressing, and confirm canonical HUD health increases by at most 30.
5. Confirm a Field Dressing cannot revive an incapacitated or dead operative.
6. Collect Field Intel and confirm shared Field XP increases by exactly 40 once.
7. Confirm a player outside eight studs cannot collect through the prompt.
8. Confirm the recovery world never exceeds eight active pickups.
