# Release Candidate 1.0 — Remote Surface Review

This is a release-hardening inventory, not a claim that the game is exploit-proof.

## Trust law

All client messages are requests. The server owns consequential truth: target legality, fire cadence, ammunition, damage, life state, class consequences, equipment/progression consequences, expedition state, rewards and persistence.

A new client-to-server remote is not release-ready merely because it works. Before merge it must have:

1. one named server owner/listener;
2. a bounded payload shape;
3. server-derived identity/timestamp/state wherever possible;
4. eligibility validation against current authoritative state;
5. bounded request frequency appropriate to the action;
6. no client authority over reward, damage, health, inventory, progression or persistence facts;
7. focused source/runtime evidence for malformed and repeated requests;
8. cleanup on player leave and owner shutdown.

## Current intent families

- Combat: `FireIntent`, `ReloadIntent`
- Flashlight: `ToggleIntent`
- Squad ping: `Intent`
- Class: `SelectionIntent`, `ActionIntent`
- Weapon loadout: `SelectionIntent`
- Progression: `ChooseUpgrade`
- Run build: `SubmitRelicChoice`, `SubmitRelicReplacement`

`State`, `Result`, and `CombatPresentation` are disclosure surfaces, not client authority.

## RC gate

Any new intent family must update the source audit and this inventory in the same PR. Runtime exploit/abuse verification remains required before final release acceptance; this document cannot satisfy that human/Studio/device gate by itself.
