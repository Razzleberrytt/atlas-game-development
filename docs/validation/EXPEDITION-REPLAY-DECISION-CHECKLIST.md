# Expedition Replay Decision Validation

Use a completed fixed-seed expedition with two players.

1. Confirm neither player can vote before a terminal result.
2. Have Player A vote Replay and Player B vote Return; verify the run remains stopped at debrief and vote counts show 1/1.
3. Change Player B to Replay; verify exactly one new expedition starts with a new server-generated run ID and seed.
4. Complete another run and vote Return unanimously; verify the active expedition is cleaned up and preparation/lobby becomes available.
5. Verify a non-participant cannot cast a vote.
6. Verify no client payload can set run ID, seed, party size, or another player's vote.
7. Disconnect one participant during voting; verify no silent replacement occurs and the remaining party can use the terminal return path.

Record all observed failures as `EXP-###` defects. No pass is claimed until captured in Studio.
