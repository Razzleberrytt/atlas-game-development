# Living Kingdoms — Development Coverage Report

**Status:** GENERATED CURRENT-SNAPSHOT REPORT  
**Registry refreshed:** 2026-08-16  
**Source:** `config/coverage/living-kingdoms-development.json`  
**Regenerate:** `python scripts/development_coverage.py sync`

**Coverage health index:** **46.5/100** across **300** taxonomy concerns.

The index is a prioritization signal, not a release-readiness score. It intentionally discounts section-level inference and rewards attached evidence.

## State distribution

| State | Items |
|---|---:|
| `complete` | 0 |
| `substantial` | 74 |
| `partial` | 195 |
| `not-started` | 11 |
| `unknown` | 20 |
| `deferred` | 0 |
| `blocked` | 0 |
| `not-applicable` | 0 |

## Evidence distribution

| Evidence | Items |
|---|---:|
| `studio` | 0 |
| `automated` | 3 |
| `source-mapped` | 71 |
| `section-inferred` | 206 |
| `none` | 20 |

## Section health

| Section | Range | Coverage | Evidence | Health | Engines |
|---|---:|---|---|---:|---|
| A. World & Simulation | 1–10 | `partial` | `section-inferred` | 42.5 | World Engine, Simulation Engine, Analytics Engine |
| B. Exploration & Traversal | 11–15 | `partial` | `section-inferred` | 42.5 | World Engine, Content Engine, Analytics Engine |
| C. Combat | 16–24 | `substantial` | `source-mapped` | 74.0 | Combat Engine, Encounter Engine, Analytics Engine |
| D. Enemies & Creatures | 25–29 | `partial` | `section-inferred` | 42.5 | Encounter Engine, Combat Engine, Simulation Engine |
| E. Player Identity & Builds | 30–38 | `partial` | `section-inferred` | 42.5 | Progression Engine, Combat Engine, Persistence Engine |
| F. Loot & Items | 39–48 | `partial` | `section-inferred` | 42.5 | Loot Engine, Progression Engine, Economy Engine, Persistence Engine |
| G. Quests & Content | 49–56 | `partial` | `section-inferred` | 42.5 | Content Engine, Progression Engine |
| H. Dungeons & Instanced Content | 57–63 | `partial` | `section-inferred` | 42.5 | Content Engine, Encounter Engine, World Engine, Persistence Engine |
| I. Multiplayer & Social Systems | 64–73 | `partial` | `section-inferred` | 42.5 | Social Engine, Persistence Engine |
| J. Settlements & NPC Society | 74–80 | `partial` | `section-inferred` | 42.5 | Kingdom Engine, Social Engine, Content Engine, Simulation Engine |
| K. Economy & Professions | 81–89 | `partial` | `section-inferred` | 42.5 | Economy Engine, Loot Engine, Persistence Engine |
| L. Housing & Ownership | 90–93 | `not-started` | `section-inferred` | 14.5 | Kingdom Engine, Persistence Engine, Social Engine |
| M. Rewards & Retention | 94–100 | `partial` | `section-inferred` | 42.5 | Progression Engine, Analytics Engine, Content Engine |
| N. Monetization | 101–107 | `not-started` | `section-inferred` | 14.5 | Economy Engine, Analytics Engine, Persistence Engine |
| O. User Experience | 108–115 | `partial` | `section-inferred` | 42.5 | Content Engine, Analytics Engine, Social Engine |
| P. Art, Audio & Presentation | 116–124 | `partial` | `section-inferred` | 42.5 | Content Engine, World Engine, Combat Engine |
| Q. Technical Architecture | 125–135 | `substantial` | `source-mapped` | 74.0 | Persistence Engine, Analytics Engine, Content Engine |
| R. Performance | 136–142 | `partial` | `section-inferred` | 42.5 | Simulation Engine, Analytics Engine |
| S. Security & Reliability | 143–148 | `substantial` | `source-mapped` | 74.0 | Persistence Engine, Analytics Engine |
| T. Testing & Quality | 149–156 | `substantial` | `source-mapped` | 74.0 | Analytics Engine, Content Engine |
| U. Balance | 157–164 | `partial` | `section-inferred` | 42.5 | Analytics Engine, Combat Engine, Progression Engine, Economy Engine |
| V. Analytics & Intelligence | 165–171 | `partial` | `section-inferred` | 42.5 | Analytics Engine |
| W. Development Infrastructure | 172–180 | `substantial` | `source-mapped` | 74.0 | Analytics Engine, Persistence Engine, Content Engine |
| X. Production & Project Management | 181–190 | `partial` | `section-inferred` | 42.5 | Analytics Engine, Content Engine |
| Y. Launch & Live Operations | 191–200 | `partial` | `section-inferred` | 42.5 | Analytics Engine, Economy Engine, Persistence Engine, Content Engine |
| Z. Roblox-Specific Development | 201–210 | `substantial` | `source-mapped` | 74.0 | Persistence Engine, World Engine, Social Engine, Analytics Engine |
| AA. Advanced Living Kingdoms Systems | 211–220 | `partial` | `section-inferred` | 42.5 | Kingdom Engine, Simulation Engine, World Engine, Content Engine |
| AB. Procedural & Algorithmic World Systems | 221–240 | `partial` | `section-inferred` | 44.5 | World Engine, Simulation Engine, Encounter Engine, Content Engine, Analytics Engine |
| AC. Player Psychology & Game Feel | 241–260 | `unknown` | `none` | 0.0 | Analytics Engine, Content Engine, Combat Engine, Progression Engine, Social Engine |
| AD. Polish | 261–280 | `partial` | `section-inferred` | 42.5 | Content Engine, Analytics Engine, World Engine, Combat Engine |
| AE. Meta-System Auditing | 281–300 | `substantial` | `source-mapped` | 74.8 | Analytics Engine, Persistence Engine, World Engine, Content Engine |

## Highest-evidence gaps

The first gaps below are the lowest-health concerns after priority tie-breaking. They are **audit candidates**, not automatic implementation orders; dashboard dependencies and player value still decide execution.

| ID | Concern | Section | Priority | Coverage | Evidence |
|---|---|---|---|---|---|
| LK-241 | Core Fantasy Clarity | AC | P2 | `unknown` | `none` |
| LK-242 | Moment-to-Moment Responsiveness | AC | P2 | `unknown` | `none` |
| LK-243 | Combat Satisfaction | AC | P2 | `unknown` | `none` |
| LK-244 | Movement Feel | AC | P2 | `unknown` | `none` |
| LK-245 | Exploration Curiosity | AC | P2 | `unknown` | `none` |
| LK-246 | Reward Anticipation | AC | P2 | `unknown` | `none` |
| LK-247 | Loot Excitement | AC | P2 | `unknown` | `none` |
| LK-248 | Risk-Reward Tension | AC | P2 | `unknown` | `none` |
| LK-249 | Mastery Feedback | AC | P2 | `unknown` | `none` |
| LK-250 | Challenge Fairness | AC | P2 | `unknown` | `none` |
| LK-251 | Co-op Belonging | AC | P2 | `unknown` | `none` |
| LK-252 | Social Friction Reduction | AC | P2 | `unknown` | `none` |
| LK-253 | Player Agency | AC | P2 | `unknown` | `none` |
| LK-254 | Choice Clarity | AC | P2 | `unknown` | `none` |
| LK-255 | Progress Visibility | AC | P2 | `unknown` | `none` |
| LK-256 | Loss & Failure Recovery | AC | P2 | `unknown` | `none` |
| LK-257 | Session Pacing | AC | P2 | `unknown` | `none` |
| LK-258 | Replay Motivation | AC | P2 | `unknown` | `none` |
| LK-259 | Cognitive Load | AC | P2 | `unknown` | `none` |
| LK-260 | Player Trust | AC | P2 | `unknown` | `none` |
| LK-090 | Player Housing | L | P3 | `not-started` | `section-inferred` |
| LK-091 | Housing Placement & Decoration | L | P3 | `not-started` | `section-inferred` |
| LK-092 | Ownership Permissions | L | P3 | `not-started` | `section-inferred` |
| LK-093 | Housing Persistence | L | P3 | `not-started` | `section-inferred` |
| LK-101 | Monetization Principles | N | P3 | `not-started` | `section-inferred` |

## Current interpretation

- The registry is deliberately conservative: section-level inference must be replaced with row-level source/evidence mapping over time.
- Active Main World topology/metrics work is represented in AB/AE without turning every metric into a new gameplay authority.
- Current combat, architecture, security, testing, Roblox, infrastructure, and auditing surfaces are mapped as substantial but are not declared universally complete.
- Player-psychology/game-feel rows remain unknown until play evidence supports stronger claims.
- Housing and monetization remain not-started at taxonomy level rather than being inferred from roadmap prose.

## Update discipline

When a coherent change materially moves one or more LK rows, add an item override with the stronger/weaker state, evidence level, owner hints, and a short note. Do not mass-upgrade a section because one implementation exists.
