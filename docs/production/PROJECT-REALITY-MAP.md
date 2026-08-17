# Living Kingdoms — Project Reality Map

**Status:** GENERATED DERIVED VIEW — NOT AN INDEPENDENT AUTHORITY  
**Registry refreshed:** 2026-08-16  
**Canonical source:** `config/coverage/living-kingdoms-development.json`  
**Generate:** `python scripts/project_reality.py sync`

This report answers a narrower execution question: **what kind of work does current evidence imply?** It does not replace product authority, the execution dashboard, the patch roadmap, or the 300-area coverage registry.

## Reality vocabulary

- **KEEP** — preserve accepted/proven substantial implementation; do not casually rewrite it.
- **HARDEN** — substantial source exists, but stronger validation/reliability evidence is still needed.
- **COMPLETE** — partial implementation exists; finish the coherent player/system path before adding breadth.
- **PROVE** — runtime/player-experience truth is unknown or unsupported; measure it instead of inventing more code.
- **LATER** — not-started/deferred concern; it is not evidence that the current slice needs a new system.
- **CUT** — intentionally absent here. Product-level cuts/non-goals belong to `docs/bible/00-current-product-authority.md`, not an inferred coverage heuristic.

## Portfolio summary

| Action | Concerns |
|---|---:|
| **KEEP** | 3 |
| **HARDEN** | 71 |
| **COMPLETE** | 195 |
| **PROVE** | 20 |
| **LATER** | 11 |

## Section reality

| Section | Range | Coverage | Evidence | Derived action |
|---|---:|---|---|---|
| A. World & Simulation | 1–10 | `partial` | `section-inferred` | **COMPLETE** |
| B. Exploration & Traversal | 11–15 | `partial` | `section-inferred` | **COMPLETE** |
| C. Combat | 16–24 | `substantial` | `source-mapped` | **HARDEN** |
| D. Enemies & Creatures | 25–29 | `partial` | `section-inferred` | **COMPLETE** |
| E. Player Identity & Builds | 30–38 | `partial` | `section-inferred` | **COMPLETE** |
| F. Loot & Items | 39–48 | `partial` | `section-inferred` | **COMPLETE** |
| G. Quests & Content | 49–56 | `partial` | `section-inferred` | **COMPLETE** |
| H. Dungeons & Instanced Content | 57–63 | `partial` | `section-inferred` | **COMPLETE** |
| I. Multiplayer & Social Systems | 64–73 | `partial` | `section-inferred` | **COMPLETE** |
| J. Settlements & NPC Society | 74–80 | `partial` | `section-inferred` | **COMPLETE** |
| K. Economy & Professions | 81–89 | `partial` | `section-inferred` | **COMPLETE** |
| L. Housing & Ownership | 90–93 | `not-started` | `section-inferred` | **LATER** |
| M. Rewards & Retention | 94–100 | `partial` | `section-inferred` | **COMPLETE** |
| N. Monetization | 101–107 | `not-started` | `section-inferred` | **LATER** |
| O. User Experience | 108–115 | `partial` | `section-inferred` | **COMPLETE** |
| P. Art, Audio & Presentation | 116–124 | `partial` | `section-inferred` | **COMPLETE** |
| Q. Technical Architecture | 125–135 | `substantial` | `source-mapped` | **HARDEN** |
| R. Performance | 136–142 | `partial` | `section-inferred` | **COMPLETE** |
| S. Security & Reliability | 143–148 | `substantial` | `source-mapped` | **HARDEN** |
| T. Testing & Quality | 149–156 | `substantial` | `source-mapped` | **HARDEN** |
| U. Balance | 157–164 | `partial` | `section-inferred` | **COMPLETE** |
| V. Analytics & Intelligence | 165–171 | `partial` | `section-inferred` | **COMPLETE** |
| W. Development Infrastructure | 172–180 | `substantial` | `source-mapped` | **HARDEN** |
| X. Production & Project Management | 181–190 | `partial` | `section-inferred` | **COMPLETE** |
| Y. Launch & Live Operations | 191–200 | `partial` | `section-inferred` | **COMPLETE** |
| Z. Roblox-Specific Development | 201–210 | `substantial` | `source-mapped` | **HARDEN** |
| AA. Advanced Living Kingdoms Systems | 211–220 | `partial` | `section-inferred` | **COMPLETE** |
| AB. Procedural & Algorithmic World Systems | 221–240 | `partial` | `section-inferred` | **COMPLETE** |
| AC. Player Psychology & Game Feel | 241–260 | `unknown` | `none` | **PROVE** |
| AD. Polish | 261–280 | `partial` | `section-inferred` | **COMPLETE** |
| AE. Meta-System Auditing | 281–300 | `substantial` | `source-mapped` | **HARDEN** |

## Highest-value unresolved reality

The rows below are ordered to surface unknown player truth first, then partial P0/P1 implementation. This is still a diagnostic view; the execution dashboard decides NOW/NEXT.

| ID | Concern | Section | Priority | Coverage | Evidence | Action |
|---|---|---|---|---|---|---|
| LK-241 | Core Fantasy Clarity | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-242 | Moment-to-Moment Responsiveness | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-243 | Combat Satisfaction | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-244 | Movement Feel | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-245 | Exploration Curiosity | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-246 | Reward Anticipation | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-247 | Loot Excitement | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-248 | Risk-Reward Tension | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-249 | Mastery Feedback | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-250 | Challenge Fairness | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-251 | Co-op Belonging | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-252 | Social Friction Reduction | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-253 | Player Agency | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-254 | Choice Clarity | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-255 | Progress Visibility | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-256 | Loss & Failure Recovery | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-257 | Session Pacing | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-258 | Replay Motivation | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-259 | Cognitive Load | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-260 | Player Trust | AC | P2 | `unknown` | `none` | **PROVE** |
| LK-001 | World State Model | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-002 | Region Topology | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-003 | Biome System | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-004 | Terrain & Traversal Surface | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-005 | Weather System | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-006 | Time & Lighting Cycle | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-007 | Environmental Hazards | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-008 | World Events | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-009 | World Persistence Boundaries | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-010 | World Simulation Observability | A | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-011 | Landmark Discovery | B | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-012 | Route Readability | B | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-013 | Traversal Mechanics | B | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-014 | Fast Travel & Return Paths | B | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-015 | Secrets & Exploration Rewards | B | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-025 | Enemy Archetypes | D | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-026 | Enemy Navigation & Targeting | D | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-027 | Enemy Attacks & Abilities | D | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-028 | Elite & Boss Framework | D | P1 | `partial` | `section-inferred` | **COMPLETE** |
| LK-029 | Enemy Population & Spawn Control | D | P1 | `partial` | `section-inferred` | **COMPLETE** |

## AI/session routing rule

Before changing code, an agent should resolve the target LK concern and use this decision order:

```text
KEEP     → reuse the canonical owner; change only for a demonstrated defect/accepted migration
HARDEN   → strengthen reliability/evidence before redesigning
COMPLETE → close the smallest coherent missing path
PROVE    → obtain runtime/play evidence before speculative expansion
LATER    → backlog unless the dashboard/product authority explicitly activates it
CUT      → obey product authority; do not resurrect implicitly
```

## Anti-forever-project rule

A low coverage score is **not** permission to implement everything. The project advances when the current playable slice meets its exit condition. Coverage identifies blind spots; it does not become the task queue.
