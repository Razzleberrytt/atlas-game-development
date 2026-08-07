# Atlas Version 2.7 Rollout Quality Audit

**Release date:** 2026-08-07

## What changed from v2.3

Version 2.7 keeps the v2.3 product/authority principles but advances the active roadmap from broad integration guidance to a staged active-place cutover with explicit observability and compatibility-removal gates.

Added or tightened:

- R0–R5 rollout stages;
- producer/consumer cutover ledger;
- semantic-key and mutation-derived change-token contract;
- pre-ready retention by player + remote + semantic key;
- publisher/delivery counters that distinguish producer noise from readiness problems;
- one shared Highlight ownership path;
- route/landmark migration completion criteria;
- named reset/respawn/late-join/soak baselines;
- delayed-ready and two-player matrices;
- 100-play animation-listener leak test;
- compatibility removal per accepted ledger row;
- Tickets 331–360.

## Reference-package static evidence

The separately assembled Runtime Observability v1.0 reference package reported:

| Check | Result |
|---|---:|
| Blocking static issues | 0 |
| Luau files | 124 |
| Definitions | 33 |
| Remotes | 22 |
| Services | 21 |
| Required State listeners | 6 / 6 |
| Direct State sends outside publisher | 0 |
| Direct server Highlight creation | 0 |
| Shared Highlight registry constructors | 1 |
| `any` tokens | 272 |

These figures describe the **reference migration package**, not a claim that the active Atlas repository or current `.rbxl` already matches that implementation. Repository CI and active-place evidence remain independently authoritative.

## Current repository reality boundary

Adopting this roadmap changes documentation and execution authority. It does not by itself prove:

- the exact active-place `HordeNetwork.State` producer list;
- the exact effective client listener count/lifetime;
- the current messages/sec or whether rate grows after reset;
- the exact scripts creating the escaped Highlight presentation;
- the active bad `Adornee` target;
- that the current `.rbxl` contains only repository-tracked scripts;
- accepted steady-state connection/presentation baselines;
- delayed-ready or late-join correctness;
- five-reset or three-respawn stability;
- device/performance acceptance;
- E2, E3, E4, or E5 status.

Those remain runtime evidence tasks.

## Required static roadmap checks

| Check | Expected |
|---|---|
| Active roadmap index names v2.7 | PASS after adoption |
| Root README points to v2.7 authority | PASS after adoption |
| Root AGENTS points agents to v2.7 docs | PASS after adoption |
| v2.3/v2.0/v1.9 docs explicitly historical | PASS after adoption |
| Active queue is 331–360 | PASS |
| Compatibility removal is gated, not immediate | PASS |
| Runtime evidence outranks prose | PASS |
| `HordeNetwork.State` symptom is not declared fixed | PASS |
| Highlight symptom is not declared fixed | PASS |
| Semantic current-state ownership is explicit | PASS |
| Presentation primitive ownership is explicit | PASS |

## Promotion requirements

The rollout is not accepted until captured evidence shows:

```text
producer/consumer inventory complete
intended compatibility listener count understood
pre-ready state intentionally gated/retained
semantic sends bounded by real mutation
unchanged state suppressed
0 queue/discard warnings in accepted normal play
route/landmark/highlight ownership centralized
0 broad production Highlight targets
streaming rebind preserves semantic truth
five-reset gauges return to baseline
three-respawn gauges return to baseline
late join reconstructs current state
100 animation plays do not multiply listeners
two-player reset/disconnect cleanup passes
closure packet accepted
```

## Quality conclusion

Version 2.7 is a stronger roadmap because it gives the active migration a measurable end state and an explicit removal path. It is still a roadmap and static architecture adoption. The next quality increase must come from Studio evidence, not another roadmap version.
