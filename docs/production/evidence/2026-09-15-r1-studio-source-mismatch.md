# Blueprint v2.7 R1 — Connected Studio artifact preflight

**Status: BLOCKED — loaded Studio source differs from the pinned CI artifact.**

**Packet result: INVALID.** This records an artifact-identity preflight, not a gameplay run. It follows the [CI pin and connection attempt](2026-09-15-r1-current-main-ci-capture.md). The Studio connection is now working; the earlier connection blocker no longer describes the current session.

## Identity and method

- Date: 2026-09-15, approximately 22:42 America/New_York.
- Operator: Codex. Rollout stage R1; documentation risk R0.
- Studio ID: `bb6ee36c-fd21-482a-8e15-4014991bb536`.
- Connected filename: `LivingKingdoms.rbxlx`; DataModel name: `LivingKingdoms`.
- Studio version reported by `version()`: `0.739.0.7390687`.
- Studio mode: Edit.
- Expected source SHA: `fcaab2c9244a3fafa6014b815992e507398ca4cf`.
- Expected artifact: `10427820756`, CI run `35047062601`; archive digest and extracted SHA-256 remain as recorded in the linked pin packet.
- Compared script paths, UTF-8 source byte lengths, and Adler-32 checksums between the downloaded artifact XML and read-only inspection of loaded `LuaSourceContainer` instances. Checksums detect drift; they are not cryptographic artifact authentication.

## Observations

- Artifact contains 432 scripts; Studio contains 418.
- 14 artifact script paths are absent in Studio.
- 82 paths present in both have different byte lengths and/or checksums.
- No additional script paths were found in Studio.
- Loaded rollout config source sets `EnableRuntimeCounters`, `EnableEarlyStateListener`, and `RejectBroadHighlightTargets` to true, and `EnableReadyGatedStatePublisher` to false.
- The user reported Rojo running. Sync from another checkout is a possible explanation, not an established cause.

| Script | Artifact source bytes | Studio source bytes |
|---|---:|---:|
| `ReplicatedStorage.Shared.Combat.EnemyContracts` | 5876 | 5051 |
| `ReplicatedStorage.Shared.Config.EnemyConfig` | 8779 | 5778 |
| `ReplicatedStorage.Shared.Config.FirearmConfig` | 9949 | 7054 |
| `ReplicatedStorage.Shared.Config.MainWorldBootstrapAllowlistConfig` | 2693 | 1805 |
| `ReplicatedStorage.Shared.Config.WeaponPatternConfig` | 5047 | 4666 |

The nonzero length differences alone establish source mismatch; a matching filename does not establish artifact identity. No attempt was made to overwrite loaded source to make it resemble the artifact.

## Procedure boundary and gauges

Studio Output was cleared successfully during preflight. Play was not started after the identity mismatch was discovered. No capture helper was run. First/final listener counts, invalid-message counts, revisions, guard activity/rejections, Highlight scans, queue/discard warnings, startup behavior, visual feedback, and elapsed capture time are all **UNMEASURED**. No zero values or passing results are inferred from Edit-mode inspection.

## Decision and recovery

- The packet's exact-artifact precondition fails, so this attempt is INVALID.
- Cutover ledger and historical accepted evidence remain unchanged; no evidence-level promotion or compatibility removal.
- No gameplay, authority, data, lifecycle, rollout flag, or publication change was performed. No rollback was performed.
- Disconnect Rojo in the artifact's Studio window, then reopen the downloaded `C:/Users/Will/atlas-r1-capture/35047062601/LivingKingdoms.rbxlx` without saving the altered session over it. Keep MCP enabled and Rojo disconnected for the capture.
- Repeat artifact preflight, clear Output again, and run the unchanged cold-start/two-snapshot/visual-and-warning procedure only on the confirmed artifact. Record the actual run in a new packet.
