# BA-021 — NPC Definition, Conversation, and Interaction Contracts

**Status:** DATA / CONTRACT ONLY  
**Runtime activation:** No  
**Evidence level:** E1 source/static only  
**Primary source:** `games/living-kingdoms/src/shared/NPC/NPCContracts.luau`

## Purpose

BA-021 defines a stable, source-managed vocabulary for future Main World NPCs without creating a second gameplay authority. NPC definitions may identify semantic roles, dialogue references, and presentation/referral capabilities. They do not own quests, vendors, crafting, gathering, progression, inventory, economy, missions, networking, persistence, or session truth.

The contract exists so later authored NPC content can point at stable domain IDs instead of coupling gameplay behavior to Roblox instance names or to preserved legacy scripts.

## Contract shape

Each NPC definition contains:

- a stable `NPCId` and version;
- one or more role IDs from the canonical role vocabulary;
- zero or more stable dialogue references, each with an entry-node reference;
- one or more capabilities;
- an explicit `RuntimeEnabled` flag.

Capabilities contain a stable capability ID, a capability kind, a target reference, an optional dialogue reference, and `MutationAllowed = false`.

## Role vocabulary

BA-021 defines these role categories only:

- `Guide`
- `OperationContact`
- `VendorContact`
- `CraftingContact`
- `GatheringContact`

These are semantic labels, not live NPC identities and not authority assignments. Later authored definitions may combine compatible roles, but BA-025 cross-domain validation must verify referenced domain IDs before activation.

## Capability vocabulary

BA-021 allows three presentation/referral capability kinds:

- `Conversation` — points at a declared dialogue reference;
- `Information` — exposes a stable informational target;
- `DomainReferral` — points toward another domain surface or stable content reference without performing its mutation.

A `Conversation` capability must name one of the NPC definition's declared dialogue references. Every capability is required to keep `MutationAllowed = false`.

## Authority boundary

BA-021 does not:

- spawn NPC models;
- create prompts, GUI, or dialogue presentation;
- bind remotes or network requests;
- create a live conversation state owner;
- accept or complete quests;
- buy, sell, craft, gather, equip, grant, or persist anything;
- choose operation/session ownership;
- activate recovered Main World interactions;
- revive preserved legacy gameplay modules.

A future consumer may use the contract to discover what an NPC can present or refer to, but consequential actions must still be delegated to the accepted canonical owner for that domain.

## Hub/Main World relationship

The canonical hub interaction registry already reserves `hub.anchor.npc.guide` / `station.hub.npc_guide` as a future NPC seam. BA-021 supplies the domain contract that such a surface can eventually reference; it does not assign placement, identity, dialogue content, prompt behavior, or runtime activation to that anchor.

Vendor-facing NPC roles likewise remain referrals only until BA-024 and BA-026 establish catalog/economy boundaries. Crafting and gathering roles remain referrals only until BA-022/BA-023 plus their later integration gates are complete.

## Validation

`games/living-kingdoms/tests/NPCContracts.test.luau` verifies:

- stable role/capability vocabulary;
- duplicate and unknown role rejection;
- unique dialogue/capability references;
- conversation-to-dialogue consistency;
- duplicate NPC rejection across definition sets;
- rejection of mutation-capable NPC definitions;
- absence of runtime GUI, prompt, networking, and persistence ownership.

The fixture uses synthetic `npc.fixture.*`, `dialogue.fixture.*`, and `capability.fixture.*` IDs. They are test data only and are not authored live NPC content.

## Completion boundary

BA-021 is complete at E1 when the contract, fixture, and this specification agree and repository CI is green. Completion does not mean any NPC exists in Studio or can be interacted with in a live build. Runtime NPC content remains a later authored/integration task subject to the Main World and cross-domain gates.
