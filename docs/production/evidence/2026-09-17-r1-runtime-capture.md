# R1 pinned CI runtime capture — incomplete gameplay acceptance

**Status: BUILT — VERIFICATION PENDING. Packet result: PARTIAL.**

Source/artifact identity is pinned in [the build packet](2026-09-15-r1-current-main-ci-capture.md): source `fcaab2c9244a3fafa6014b815992e507398ca4cf`, artifact `10427820756`, CI run `35047062601`. After Rojo was stopped and the artifact reopened, all 432 loaded script paths, source byte lengths and Adler-32 checksums matched the downloaded XML, with no missing/extra scripts. This resolves the prior [source mismatch](2026-09-15-r1-studio-source-mismatch.md). No source or flags were altered during capture.

Studio `0.739.0.7390687`, one server / one desktop client. Codex cleared Output, started a cold Play session, and executed the complete unmodified capture helper in the client context through Studio MCP. This is equivalent client Luau execution, not a manually pasted Command Bar action. Server and client bootstrap messages were observed and the HUD rendered. Graphics quality was not measured. The settings UI reported full shake, blood, flash and floating combat text.

| Gauge | First (Unix 1789526708) | Intermediate (+47s) | Final recorded snapshot (+99s) |
|---|---:|---:|---:|
| Listener bound | true | true | true |
| Messages received | 40 | 134 | 236 |
| Invalid messages | 0 | 0 | 0 |
| Last revision | 40 | 134 | 236 |
| Broad guard active | true | true | true |
| Broad targets rejected | 0 | 0 | 0 |
| Enabled / total Highlights | 14 / 14 | 14 / 14 | 14 / 14 |
| Still-enabled broad targets | 0 | 0 | 0 |

All three helper snapshots reported passable. The +47-second intermediate snapshot is preserved and is not used as the required >=60-second comparison. Queue/discard warnings in the retained Output: zero. No script errors were present. No exact disabled-broad-Highlight warnings occurred; last rejected target was absent, not a known path. All inspected Highlights belonged to loot chests. No broad world wash appeared in the sampled viewport screenshots. This does not establish enemy feedback, active combat, continuous visual coverage, broad rejection behavior, resets, multiplayer, streaming, or soak acceptance.

The operator attempted movement, a primary attack, navigation to the expedition terminal, and E interactions through Studio input tools. Movement was observed; an expedition launch was not. The HUD remained `Regroup. Something in the forest has heard you.` with a field hatchet and no active combat. No source-injected enemies, forced damage, remote calls, or forced mission transitions were used.

On 2026-09-17 the user reported no enemies, weapons not firing, the same stuck objective, poor campfire appearance, and indistinguishable weapon models, and requested fixes and saved progress. Narrow enemy hit/kill Highlight behavior remains **UNMEASURED**. The missing combat experience is a concrete follow-up defect, not a passing R1 visual gate. Output explicitly reports Studio volatile in-memory inventory storage; durable saving was not verified.

Acceptance: PARTIAL; no ledger updates, evidence promotion, compatibility removal, or publication. Prior accepted historical evidence is preserved. Resume R1 visual/combat acceptance on a newly pinned build after the gameplay defects are fixed. The historical evaluator has not been repinned or used to mislabel this run.

## Retained Output

```text
[AtlasPersistence] Studio session detected; using volatile in-memory storage instead of DataStore AtlasPlayerInventoryV1. Progress will not persist across Studio sessions.
[Living Kingdoms] Studio environment preview ready — toggle Workspace.LK_EnvironmentPreviewEnabled and set LK_EnvironmentPreviewIntensity from 0 to 1
[Living Kingdoms] Read-only operative progression network mounted
[Living Kingdoms] Expedition reward/result owner mounted
[Living Kingdoms] Expedition live runtime mounted
[Living Kingdoms] Expedition diagnostics mounted
[Living Kingdoms] Outdoor discovery runtime mounted
[Living Kingdoms] Expedition run development harness mounted
[Living Kingdoms] Melee input runtime mounted
[Living Kingdoms] Inventory network and lease lifecycle mounted
[Living Kingdoms] Expedition lobby mounted
[Living Kingdoms] World foundation ready: MVP-0.1-v4-forest-clarity
[Living Kingdoms] Mission director started: Operation Blackwater Relay
[Living Kingdoms] Server bootstrap started
[Living Kingdoms] Expedition run lifecycle mounted
[Living Kingdoms] Environment physical ambience ready: ambience-v2 / biome-vfx-v1
[Living Kingdoms] World visual dressing ready: readability-v1 / environment-models-v4-hierarchical-packing / gaussian-fields-hierarchical-poisson-v2
[Living Kingdoms] Modular enemy asset presentation integration ready
[Living Kingdoms] Modular environment dressing ready: modular-field-dressing-v1 / 18 props
[Living Kingdoms] Environment presentation budget OK: 89 models / 516 parts / 12 emitters / 0 lights
[Living Kingdoms] First-person camera activated
[SurvivorController] Native Roblox character controls enabled
[Living Kingdoms] Client bootstrap started
LK_V27_R1_CAPTURE {"highlightScan":{"enabled":14,"total":14,"rejectedInstances":[],"stillEnabledBroad":[]},"unixTime":1789526708,"listener":{"messagesReceived":40,"bound":true,"invalidMessages":0,"lastRevision":40},"schema":"LK_V27_R1_CAPTURE_V1","highlightGuard":{"rejectedCount":0,"active":true}}
LK_V27_R1_CAPTURE_SNAPSHOT_PASSABLE true
LK_V27_R1_CAPTURE {"highlightScan":{"enabled":14,"total":14,"rejectedInstances":[],"stillEnabledBroad":[]},"unixTime":1789526755,"listener":{"messagesReceived":134,"bound":true,"invalidMessages":0,"lastRevision":134},"schema":"LK_V27_R1_CAPTURE_V1","highlightGuard":{"rejectedCount":0,"active":true}}
LK_V27_R1_CAPTURE_SNAPSHOT_PASSABLE true
LK_V27_R1_CAPTURE {"highlightScan":{"enabled":14,"total":14,"rejectedInstances":[],"stillEnabledBroad":[]},"unixTime":1789526807,"listener":{"messagesReceived":236,"bound":true,"invalidMessages":0,"lastRevision":236},"schema":"LK_V27_R1_CAPTURE_V1","highlightGuard":{"rejectedCount":0,"active":true}}
LK_V27_R1_CAPTURE_SNAPSHOT_PASSABLE true
```
