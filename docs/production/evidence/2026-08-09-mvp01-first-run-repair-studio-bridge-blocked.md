# MVP 0.1 First-Run Repair — Studio Bridge Blocked

## 1. Identity

- Date/time: 2026-08-09, America/New_York
- Tester/operator: Codex
- Roadmap ticket(s): MVP 0.1 First Complete Run / STOP-PLAY-FIX
- Rollout stage: R1
- Git branch: `codex/mvp01-first-run-repair`
- Source commit before working-tree changes: `8fcac50acbd1e31760c8c238ad086f370206dd90`
- Tools: Rojo 7.7.0; Lune 0.10.4; StyLua 2.5.2; Selene 0.31.0
- Roblox Studio version: `0.733.0.7330989`
- Place: `LivingKingdoms-mvp01-first-run-repair.rbxlx`
- Reproducible artifact: SHA-256 `D9DE60CC1504C889FE516B127C9362A2C342A7C2ECC686E3BC96EA093B3351DD`
- Intended server/client count: one local server / one client
- Feature flags: `NightCorruptionConfig.RuntimeEnabled = false`
- Known-good rollback source: `8fcac50acbd1e31760c8c238ad086f370206dd90`

## 2. Claim under test

The exact build allows keyboard/cursor run choices, creates responsive first-person firearm feedback, presents purposeful mixed Stalker/Spitter pressure, and renders a colorful, detailed morning biome without console or representative-performance regressions.

## 3. Preconditions and baseline

- Source synchronized: yes; exact Rojo artifact built from the working tree.
- Static baseline: layout, import, migration, roadmap, formatting, lint, 208 Lune tests, and Rojo build passed.
- Output cleared: not reached.
- Runtime diagnostics: not reached.
- Baseline counters: not captured; no play session was established.

## 4. Procedure

1. Built `%TEMP%\LivingKingdoms-mvp01-first-run-repair.rbxlx` with Rojo 7.7.0.
2. Queried the Roblox Studio MCP instance list.
3. Found only the older `LivingKingdoms-mvp01-9b1e2ff.rbxlx` session, marked disconnected.
4. Opened the exact repair artifact in Roblox Studio version `0.733.0.7330989`.
5. Re-queried the Studio MCP instance list; the exact artifact did not register and the older disconnected session remained the only advertised instance.
6. Attempted the bundled Windows-control fallback; its nested execution context could list the exact Studio window but could not capture or control it.
7. Stopped without claiming visual, gameplay, console, lifecycle, or performance evidence.

## 5. Observations

- The exact artifact built successfully and opened in a responsive Studio window.
- No MCP-accessible Edit, Server, or Client DataModel became available.
- No gameplay started; no screenshots, console output, counters, profiles, reset/respawn cases, or soak data were captured.
- The failure is evidence-transport/tooling failure, not evidence that the build passed or failed at runtime.

## 6. Defects found

| Severity | Defect | Reproduction | Owner | Blocking? |
|---|---|---|---|---|
| Blocker | Exact Studio window does not register with the enabled Studio MCP proxy | Open exact artifact, then call Studio instance list/state | Studio MCP connection | Yes |

## 7. Performance and matrix result

- Required gameplay matrix: not run.
- Server/client performance: not captured.
- Runtime counters and before/after rates: not captured.
- Sufficient for E5: no.

## 8. Rollback and acceptance decision

- Rollback trigger occurred: no runtime observation was possible.
- Rollback performed: no.
- Packet result: `INVALID`
- MVP 0.1 gate: `STOP / PLAY / FIX` remains open.
- Evidence level before/after: unchanged.
- Compatibility removal eligible: no.
- Required next action: reconnect the exact Studio instance, then rerun the full first-run path and representative performance capture before promotion.

## 9. Attachments

- Exact artifact: `%TEMP%\LivingKingdoms-mvp01-first-run-repair.rbxlx`
- Screenshots/video/output/profiler: none; Studio bridge was unavailable.

> This packet records a blocked attempt only. It is not runtime validation.
