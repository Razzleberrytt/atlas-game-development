# Studio reconciliation source — 2026-08-10

This directory preserves reviewable evidence from the user-supplied `livingkingdoms.rbxl` revision without mapping the binary or its embedded legacy runtime into the active Rojo project.

## Source

- SHA-256: `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b`
- Bytes: `1,808,699`
- Declared instances: `2,342`
- Workspace instances: `1,775`
- Embedded scripts: `367`

The historical 2026-08-07 authored-world import (`e00fc74d...`) also contained 1,775 Workspace instances with the same aggregate Workspace class distribution, while this revision contains 84 more declared instances and 77 more scripts. That is strong reconciliation evidence that the authored world survived while additional repo/runtime material was synced into the place. It is **not** a claim that every Workspace property is byte-for-byte identical between revisions.

## Merge authority

The latest repository source remains authoritative for gameplay, networking, persistence, expedition lifecycle, presentation ownership, and bootstraps. Embedded place scripts are evidence only when they overlap current source. Do not wholesale activate legacy `RPGServerBootstrap` or overlapping legacy services.

The authored world may be admitted incrementally from checksum-pinned evidence. `CentralFountain` has already been promoted into the dormant held reconstruction contract `RecoveredCentralFountainConfig`; no runtime mapping was enabled.

## Preserved evidence

- `central-fountain.review.json` — exact bounded evidence used by the held CentralFountain reconstruction.
- `hub-civic-geometry-summary.json` — exact supported geometry/light evidence for `GrandStaircase`, `HubArchway`, and the current-revision `DungeonPortal` subtree. These entries are preserved for later one-group-at-a-time admission and are not active runtime content.
- `revision-manifest.json` — source fingerprint, inventory counts, historical comparison, and merge policy.

## Safety

This import directory is intentionally outside `default.project.json`. The `.rbxl` itself is not committed. Generated place/build artifacts remain non-source. Any future promotion from this directory must preserve `authored-overworld` coordinates, retain stable semantic ownership, add focused parity tests, and remain held until the Main World activation gates are satisfied.
