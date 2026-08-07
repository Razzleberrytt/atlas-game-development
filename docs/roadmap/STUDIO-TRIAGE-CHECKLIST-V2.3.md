# Roblox Studio Runtime Triage Checklist — Version 2.3

Use this before broad refactors when the active place shows networking or presentation instability.

## A. Cold start

- [ ] Clear Output.
- [ ] Start one client and server.
- [ ] Record build/version identity.
- [ ] Verify only one client bootstrap and one server bootstrap.
- [ ] Record presentation-ready transition.
- [ ] Record snapshot revision.
- [ ] Confirm zero queue/discard warnings.

## B. `HordeNetwork.State`

- [ ] Search all `FireClient` / `FireAllClients` sites for the remote.
- [ ] Search all `OnClientEvent` bindings.
- [ ] Give each producer a diagnostic source name.
- [ ] Count messages/sec by producer.
- [ ] Confirm listener exists before recurring traffic.
- [ ] Confirm round reset does not add another producer.
- [ ] Confirm respawn does not add another listener.
- [ ] Replace unchanged recurring state with semantic deltas.

## C. Highlights

- [ ] Enumerate all `Highlight` instances.
- [ ] Record `Adornee`, parent, `DepthMode`, fill/outline transparency.
- [ ] Record creating controller or lease.
- [ ] Reject Workspace and broad region roots.
- [ ] Confirm character/tool cannot be selected accidentally.
- [ ] Disable route, landmark, mark, objective, and debug channels independently.
- [ ] Migrate production creation to central lease registry.
- [ ] Confirm reset returns count to baseline.

## D. Restart / respawn

Run encounter reset five times and respawn three times.

- [ ] permanent connection count stable;
- [ ] character-scoped count returns to expected baseline;
- [ ] Highlight leases return to expected baseline;
- [ ] temporary VFX return to baseline;
- [ ] marker listener counts stable;
- [ ] camera modifiers return to zero/idle baseline;
- [ ] reliable messages/sec do not grow.

## E. Streaming

- [ ] stream a landmark/route target out;
- [ ] world-bound effect releases;
- [ ] semantic state remains;
- [ ] no false completion;
- [ ] rebind occurs when target streams in;
- [ ] fallback HUD state is sane.

## F. Animation

- [ ] play fire/reload or enemy attack 100 times;
- [ ] marker callback count per play remains exactly expected;
- [ ] no persistent marker listeners accumulate;
- [ ] destroying character/viewmodel removes tracks and listeners.

## G. Exit gate

- [ ] zero remote queue/discard warnings in a ten-minute soak;
- [ ] zero broad production highlight adornees;
- [ ] stable connection/effect baselines;
- [ ] late join receives correct snapshot;
- [ ] two clients see correct individual attribution;
- [ ] low graphics/mobile preserve critical cues;
- [ ] evidence record saved.
