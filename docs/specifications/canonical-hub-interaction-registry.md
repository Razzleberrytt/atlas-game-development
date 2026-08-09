# Canonical Hub Interaction Registry

**Roadmap ticket:** BA-012

**Lane:** controlled build-ahead

**Status:** definitions complete; authored Main World activation held

**Evidence level:** E1 source/static only

## Decision

Hub and Main World interaction surfaces use stable anchor IDs that are independent of Roblox instance names. An anchor may open a presentation surface or submit narrow intent to an existing canonical owner; it never becomes gameplay authority merely because a prompt or world model points at it.

The machine-readable contract is [`HubInteractionContracts.luau`](../../games/living-kingdoms/src/shared/World/HubInteractionContracts.luau), and the registry is [`HubInteractionConfig.luau`](../../games/living-kingdoms/src/shared/Config/HubInteractionConfig.luau).

BA-012 adds no prompt, remote, bootstrap, geometry, placement, teleport, party policy, vendor transaction, quest transition, crafting mutation, gathering reward or social/session behavior.

## Authority rules

1. A client surface may reveal UI or send bounded intent; it may not author inventory, progression, class, loadout, mission, operation, currency, reward, ownership or session truth.
2. An anchor marked `ExistingCanonical` delegates mutations to the named existing server owner.
3. An anchor marked `PresentationOnly` opens an existing information surface and claims no mutation owner.
4. `DomainContractRequired` and `PolicyRequired` anchors remain disabled and have no mutation owner until their dedicated roadmap work assigns one.
5. Recovered hierarchy names are source evidence and aliases, not gameplay authority.
6. No recovered board, portal or vendor folder is treated as having a prompt unless a new source-managed interaction is explicitly implemented later.
7. Stream-out suspends the local surface only. It does not complete, cancel or mutate the semantic interaction.
8. Preserved legacy `HubTownService`, quest, dungeon, vendor, gathering and other gameplay services remain inert.

## Registry

| Stable anchor ID | Surface | Placement | Presentation owner | Mutation owner | State / dependency |
|---|---|---|---|---|---|
| `hub.anchor.class_assignment` | specialist selection | active Forward Operations bridge | `ClassSelectionController` | `ClassService` | Existing bridge; unchanged |
| `hub.anchor.weapon_loadout` | weapon loadout | active Forward Operations bridge | `WeaponSelectionController` | `WeaponLoadoutService` | Existing bridge; unchanged |
| `hub.anchor.expedition_terminal` | expedition lobby | active Forward Operations bridge | `ExpeditionLobbyController` | `ExpeditionLobbyService` | Existing bridge; unchanged |
| `hub.anchor.character` | character information | unassigned Main World surface | `RPGMenuController` | none | Presentation only; BA-014 placement/evidence |
| `hub.anchor.inventory` | inventory information | unassigned Main World surface | `RPGMenuController` | none | Presentation only; BA-014 placement/evidence |
| `hub.anchor.skills` | skill/run progression information | unassigned Main World surface | `RPGMenuController` | none | Presentation only; BA-014 placement/evidence |
| `hub.anchor.operation_board` | quest/operation board | recovered `Workspace/HubTown/quest_board` | unassigned | unassigned | BA-020 + BA-034 |
| `hub.anchor.vendor.apothecary` | vendor | recovered `Workspace/HubTown/apothecary` | unassigned | unassigned | BA-021 + BA-024 + BA-026 |
| `hub.anchor.vendor.armor_smith` | vendor | recovered `Workspace/HubTown/armor_smith` | unassigned | unassigned | BA-021 + BA-024 + BA-026 |
| `hub.anchor.vendor.weapon_smith` | vendor | recovered `Workspace/HubTown/weapon_smith` | unassigned | unassigned | BA-021 + BA-024 + BA-026 |
| `hub.anchor.vendor.merchant` | vendor | recovered `Workspace/HubTown/merchant` | unassigned | unassigned | BA-021 + BA-024 + BA-026 |
| `hub.anchor.npc.guide` | NPC conversation seam | unassigned Main World surface | unassigned | unassigned | BA-021; no NPC identity/dialogue invented |
| `hub.anchor.crafting` | crafting seam | unassigned Main World surface | unassigned | unassigned | BA-022 + BA-026 |
| `hub.anchor.gathering` | gathering seam | unassigned Main World surface | unassigned | unassigned | BA-023 + BA-026 |
| `hub.anchor.expedition_portal` | authored expedition portal | recovered `Workspace/HubTown/DungeonPortal` | unassigned | `ExpeditionLobbyService` | Presentation held; destination/eligibility contract done ([`PortalDestinationContracts.luau`](../../games/living-kingdoms/src/shared/World/PortalDestinationContracts.luau), unconsumed/`RuntimeEnabled = false`); BA-034 + BA-035 remain |
| `hub.anchor.social` | social/party seam | unassigned Main World surface | unassigned | unassigned | BA-035 dedicated policy required |

The two portal anchors deliberately share `portal.expedition.primary`: the live Forward Operations terminal and the held authored portal are alternate presentation surfaces for one canonical expedition entry concept, not competing launch authorities.

## Stable content aliases

[`WorldContentConfig.luau`](../../games/living-kingdoms/src/shared/Config/WorldContentConfig.luau) now records inactive stable content IDs for the recovered operation board and four vendor groups, plus reserved crafting, gathering, NPC-guide and social station IDs. Recovered aliases (`quest_board`, the four vendor folder names and `DungeonPortal`) resolve to those stable IDs.

Aliases support migration and evidence comparison only. Runtime code should target stable IDs.

## Activation gates

An authored Main World anchor may not activate until:

- its placement is assigned and property/source evidence is accepted;
- its presentation owner is explicit;
- its consequential mutation owner is an accepted canonical server owner, where mutation exists;
- the listed domain/policy dependencies are complete;
- device-neutral prompt/input and denial behavior are specified;
- streaming rebind and no-completion-on-stream-out behavior are tested;
- the dedicated Main World lifecycle/place boundary is ready;
- the relevant v2.7 runtime gates and a rollback checkpoint permit integration;
- Studio evidence verifies distance, visibility, congestion, camera readability and lifecycle cleanup.

## Completion boundary

BA-012 is complete at E1 when the registry, cross-reference validation and focused fixture are green. It does not advance the runtime evidence level and does not authorize Main World activation. BA-013 may now define environment production kits, profile ownership and measured budgets without depending on accidental interaction hierarchy names.
