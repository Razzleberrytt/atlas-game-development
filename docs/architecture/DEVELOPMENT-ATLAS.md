# Living Kingdoms — Development Atlas

**Status:** GENERATED ENGINE/COVERAGE MAP  
**Registry refreshed:** 2026-08-16  
**Source:** `config/coverage/living-kingdoms-development.json`  
**Regenerate:** `python scripts/development_coverage.py sync`

The Development Atlas answers: **which canonical engine should absorb a development concern?** It prevents the 300-area taxonomy from becoming 300 bespoke systems.

## Engine chain

```text
World Engine → Kingdom Engine → Simulation Engine → Encounter Engine → Combat Engine → Progression Engine → Loot Engine → Economy Engine → Social Engine → Content Engine → Persistence Engine → Analytics Engine
```

These are conceptual responsibility engines. The real implementation owners remain the existing server/shared/client modules, registries, configs, tests, and tools.

## Engine → taxonomy sections

| Engine | Primary/related sections |
|---|---|
| World Engine | A (1–10), B (11–15), H (57–63), P (116–124), Z (201–210), AA (211–220), AB (221–240), AD (261–280), AE (281–300) |
| Kingdom Engine | J (74–80), L (90–93), AA (211–220) |
| Simulation Engine | A (1–10), D (25–29), J (74–80), R (136–142), AA (211–220), AB (221–240) |
| Encounter Engine | C (16–24), D (25–29), H (57–63), AB (221–240) |
| Combat Engine | C (16–24), D (25–29), E (30–38), P (116–124), U (157–164), AC (241–260), AD (261–280) |
| Progression Engine | E (30–38), F (39–48), G (49–56), M (94–100), U (157–164), AC (241–260) |
| Loot Engine | F (39–48), K (81–89) |
| Economy Engine | F (39–48), K (81–89), N (101–107), U (157–164), Y (191–200) |
| Social Engine | I (64–73), J (74–80), L (90–93), O (108–115), Z (201–210), AC (241–260) |
| Content Engine | B (11–15), G (49–56), H (57–63), J (74–80), M (94–100), O (108–115), P (116–124), Q (125–135), T (149–156), W (172–180), X (181–190), Y (191–200), AA (211–220), AB (221–240), AC (241–260), AD (261–280), AE (281–300) |
| Persistence Engine | E (30–38), F (39–48), H (57–63), I (64–73), K (81–89), L (90–93), N (101–107), Q (125–135), S (143–148), W (172–180), Y (191–200), Z (201–210), AE (281–300) |
| Analytics Engine | A (1–10), B (11–15), C (16–24), M (94–100), N (101–107), O (108–115), Q (125–135), R (136–142), S (143–148), T (149–156), U (157–164), V (165–171), W (172–180), X (181–190), Y (191–200), Z (201–210), AB (221–240), AC (241–260), AD (261–280), AE (281–300) |

## Section → owner map

| Section | Coverage | Evidence | Owner hints |
|---|---|---|---|
| A. World & Simulation | `partial` | `section-inferred` | games/living-kingdoms/src/shared/World<br>games/living-kingdoms/src/shared/Config<br>games/living-kingdoms/src/server<br>scripts/main_world_metrics.py |
| B. Exploration & Traversal | `partial` | `section-inferred` | games/living-kingdoms/src/shared/World<br>games/living-kingdoms/src/server<br>docs/specifications |
| C. Combat | `substantial` | `source-mapped` | games/living-kingdoms/src/server/Domain<br>games/living-kingdoms/src/server/Systems<br>games/living-kingdoms/src/client<br>games/living-kingdoms/tests |
| D. Enemies & Creatures | `partial` | `section-inferred` | games/living-kingdoms/src/server/Systems<br>games/living-kingdoms/src/server/Domain<br>games/living-kingdoms/src/shared/Config<br>games/living-kingdoms/tests |
| E. Player Identity & Builds | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared<br>games/living-kingdoms/tests |
| F. Loot & Items | `partial` | `section-inferred` | games/living-kingdoms/src/shared/Equipment<br>games/living-kingdoms/src/server<br>games/living-kingdoms/tests |
| G. Quests & Content | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared/Config<br>docs/specifications |
| H. Dungeons & Instanced Content | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared<br>games/living-kingdoms/tests |
| I. Multiplayer & Social Systems | `partial` | `section-inferred` | games/living-kingdoms/src/server/Networking<br>games/living-kingdoms/src/server<br>games/living-kingdoms/src/client |
| J. Settlements & NPC Society | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared/Config<br>docs/specifications |
| K. Economy & Professions | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared/Config<br>docs/roadmap/MASTER-ROADMAP.md |
| L. Housing & Ownership | `not-started` | `section-inferred` | docs/roadmap/MASTER-ROADMAP.md |
| M. Rewards & Retention | `partial` | `section-inferred` | games/living-kingdoms/src/server<br>games/living-kingdoms/src/shared<br>games/living-kingdoms/tests |
| N. Monetization | `not-started` | `section-inferred` | docs/roadmap/MASTER-ROADMAP.md<br>docs/bible/00-current-product-authority.md |
| O. User Experience | `partial` | `section-inferred` | games/living-kingdoms/src/client<br>games/living-kingdoms/tests<br>docs/specifications |
| P. Art, Audio & Presentation | `partial` | `section-inferred` | games/living-kingdoms/src/client<br>games/living-kingdoms/src/server<br>games/living-kingdoms/assets |
| Q. Technical Architecture | `substantial` | `source-mapped` | games/living-kingdoms/src<br>games/living-kingdoms/default.project.json<br>games/living-kingdoms/main-world.project.json<br>games/living-kingdoms/AGENTS.md |
| R. Performance | `partial` | `section-inferred` | games/living-kingdoms/src<br>games/living-kingdoms/tests<br>scripts |
| S. Security & Reliability | `substantial` | `source-mapped` | games/living-kingdoms/src/server<br>games/living-kingdoms/tests<br>docs/production |
| T. Testing & Quality | `substantial` | `source-mapped` | games/living-kingdoms/tests<br>scripts/validate.py<br>docs/production |
| U. Balance | `partial` | `section-inferred` | games/living-kingdoms/src/shared/Config<br>games/living-kingdoms/tests<br>docs/specifications |
| V. Analytics & Intelligence | `partial` | `section-inferred` | scripts<br>games/living-kingdoms/src<br>docs/production |
| W. Development Infrastructure | `substantial` | `source-mapped` | scripts<br>config/efficiency<br>.github |
| X. Production & Project Management | `partial` | `section-inferred` | AGENTS.md<br>docs/roadmap<br>docs/decisions<br>docs/production |
| Y. Launch & Live Operations | `partial` | `section-inferred` | docs/production<br>.github<br>docs/roadmap/MASTER-ROADMAP.md |
| Z. Roblox-Specific Development | `substantial` | `source-mapped` | games/living-kingdoms/default.project.json<br>games/living-kingdoms/main-world.project.json<br>games/living-kingdoms/src<br>scripts/roblox |
| AA. Advanced Living Kingdoms Systems | `partial` | `section-inferred` | games/living-kingdoms/src<br>docs/roadmap/MASTER-ROADMAP.md<br>docs/specifications |
| AB. Procedural & Algorithmic World Systems | `partial` | `section-inferred` | games/living-kingdoms/src/shared/World<br>games/living-kingdoms/src/server<br>scripts<br>games/living-kingdoms/tests |
| AC. Player Psychology & Game Feel | `unknown` | `none` | docs/bible/00-current-product-authority.md<br>docs/specifications<br>games/living-kingdoms/tests |
| AD. Polish | `partial` | `section-inferred` | games/living-kingdoms/src/client<br>games/living-kingdoms/src/server<br>games/living-kingdoms/tests |
| AE. Meta-System Auditing | `substantial` | `source-mapped` | scripts<br>config<br>docs/production<br>games/living-kingdoms/tests |

## Routing rule

For any new feature, bug, metric, or polish request:

1. classify the relevant `LK-###` concern(s);
2. route through the listed engine(s);
3. locate the existing real owner using `owner_hints`, capability/extension registries, tests, and source search;
4. extend that owner or its stable data seam;
5. create a new owner only when no canonical responsibility exists and the new boundary is explicit;
6. attach evidence back to the registry instead of creating another status document.

The Atlas is intentionally many-to-many: one owner can satisfy many taxonomy concerns, and one concern may cross several engines.
