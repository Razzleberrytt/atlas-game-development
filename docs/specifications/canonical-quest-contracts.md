# BA-020 — Canonical Quest Contracts

**Status:** contract/resolver complete; runtime dormant  
**Lane:** controlled build-ahead  
**Evidence level:** E1 source/static only  
**Machine-readable contract:** `games/living-kingdoms/src/shared/Quest/QuestContracts.luau`

## Decision

Living Kingdoms now has one canonical quest definition shape and one deterministic quest-state resolver without activating a quest runtime.

BA-020 exists to make future operation-board, NPC, reward, and persistence work target stable semantic quest data rather than reviving the preserved legacy quest stack or letting a client screen become quest authority.

## Canonical definition

A quest definition contains:

- `QuestId` — stable semantic quest identifier;
- `Version` — bounded schema/content version string;
- `PrerequisiteQuestIds` — stable prerequisite quest references;
- `Objectives` — stable objective IDs, progress-source references, and required counts;
- `RewardRefs` — stable reward references paired with the canonical authority expected to own eventual fulfillment;
- `RuntimeEnabled` — explicit activation flag.

The BA-020 contract validates individual definitions only. Cross-catalog unknown IDs, dependency cycles, impossible prerequisite graphs, and orphaned reward references remain BA-025 work as required by the roadmap.

## State model

The deterministic state IDs are:

`Locked → Available → Active → ReadyToTurnIn → Completed`

Resolution order is intentional:

1. if the quest ID is already in `CompletedQuestIds`, state is `Completed`;
2. otherwise any incomplete prerequisite produces `Locked`;
3. otherwise an unaccepted quest is `Available`;
4. otherwise all objective thresholds satisfied produces `ReadyToTurnIn`;
5. otherwise the accepted quest is `Active`.

Completed state therefore wins over stale accepted/progress data. Objective progress at or above the required count is equivalent for state resolution; excess counts do not produce another state.

## Transition graph

| Transition | From | To | Trigger class |
|---|---|---|---|
| `PrerequisitesSatisfied` | `Locked` | `Available` | Derived |
| `Accept` | `Available` | `Active` | Request |
| `ObjectivesSatisfied` | `Active` | `ReadyToTurnIn` | Derived |
| `Complete` | `ReadyToTurnIn` | `Completed` | Request |

`evaluateTransition` is a pure graph check. It does not mutate a player snapshot, award a reward, persist state, or authorize a client request.

## Reward-reference boundary

BA-020 defines the shape of a reward reference but does not create a quest reward catalog or grant path.

A reward reference records:

- `RewardRefId` — semantic reference only;
- `RewardAuthorityOwnerId` — the canonical future/existing owner expected to fulfill it.

The resolver never interprets or grants the reward. This prevents quest-state code from becoming a second inventory, loot, currency, progression, or economy authority.

## Operation-board boundary

The recovered `quest_board` is already represented by stable Main World content/interaction IDs through BA-004/BA-012. BA-020 does **not** activate that board.

The intended future seam remains:

`hub.anchor.operation_board → presentation owner → bounded quest intent → accepted canonical server quest owner`

That owner is intentionally not invented by this ticket. The preserved legacy quest service stays inert.

## Non-authority boundary

BA-020 does not:

- create a `QuestService`;
- create remotes or bind network intent;
- create or mutate GUI;
- bind the operation board;
- read or write DataStore state;
- grant items, currency, XP, unlocks, or Run Relics;
- start legacy quest code;
- modify mission/expedition runtime;
- resolve party/session ownership;
- validate cross-domain catalog references or dependency cycles;
- claim Studio/runtime acceptance.

## Validation

`games/living-kingdoms/tests/QuestContracts.test.luau` pins:

- the five canonical states;
- the four canonical transitions and trigger classes;
- locked, available, active, ready-to-turn-in, and completed resolution;
- completion precedence over stale accepted/progress state;
- strict definition validation;
- rejection of self-prerequisites, duplicate objectives, duplicate rewards, empty objective lists, and unknown fields;
- absence of runtime/service/network/persistence primitives from the contract module.

The quest IDs, objective IDs, progress references, and reward references used in the fixture are test data only. BA-020 does not publish them as live game content.

## Completion boundary

BA-020 is complete at E1 when the contract, deterministic resolver, focused fixture, and repository CI are green.

Completion makes BA-020 available as a dependency for later domain work. It does not activate quests and does not unblock BA-025 until BA-021 through BA-024 are also complete.
