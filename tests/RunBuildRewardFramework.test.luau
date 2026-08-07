--!strict

-- RPG-0107 relic reward / slot / replacement framework: bounded queue, equip
-- into the first empty slot, explicit full-slot replacement, replay and
-- reconnect continuity, stale/teardown rejection, and copied-state isolation.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local function loadWithReplicatedStorage(path: string, debugName: string, modulesByToken)
	local R_CONTRACTS = {}
	local R_CONFIG = {}
	local R_RESOLVER = {}
	local R_MODIFIER = {}
	-- Placeholder for dependencies the module under test never exercises here.
	local R_UNUSED = {}
	local replicatedStorage = {
		Shared = {
			RPG = {
				RunRpgContracts = R_CONTRACTS,
				RelicModifierResolver = R_MODIFIER,
				RelicRewardResolver = R_RESOLVER,
			},
			Config = { RunRpgConfig = R_CONFIG, RelicRuntimeConfig = R_UNUSED },
			Progression = { RunModifierResolver = R_UNUSED },
		},
	}
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					assertThat(serviceName == "ReplicatedStorage", debugName .. " may only require replicated modules")
					return replicatedStorage
				end,
			},
			require = function(token: unknown)
				if token == R_CONTRACTS then
					return contracts
				elseif token == R_CONFIG then
					return config
				elseif token == R_RESOLVER then
					return modulesByToken.resolver
				elseif token == R_MODIFIER then
					return modulesByToken.modifierResolver
				elseif token == R_UNUSED then
					return {}
				end
				error("unexpected " .. debugName .. " dependency", 2)
			end,
		},
		injectGlobals = true,
	})()
end

local resolver = loadWithReplicatedStorage(
	"games/living-kingdoms/src/shared/RPG/RelicRewardResolver.luau",
	"RelicRewardResolver",
	{}
)
-- The store delegates counted-relic arithmetic to the pure shared resolver.
local modifierResolver = loadWithReplicatedStorage(
	"games/living-kingdoms/src/shared/RPG/RelicModifierResolver.luau",
	"RelicModifierResolver",
	{}
)
local storeModule = loadWithReplicatedStorage(
	"games/living-kingdoms/src/server/Systems/RunBuildStateStore.luau",
	"RunBuildStateStore",
	{ resolver = resolver, modifierResolver = modifierResolver }
)

local Rejections = contracts.RunRpgRejectionReasonIds
local SourceIds = contracts.RewardSourceIds
local RelicIds = contracts.RelicIds
local SlotStates = contracts.RelicSlotStateIds
local ReplacementStates = contracts.ReplacementStateIds

local EMPTY_LOADOUT = {}

local store = storeModule.new()
local generation = store:startOperation()
assertThat(generation == 1, "first generation must be positive")
assertThat(store:registerOperative("operative-a"), "operative registration failed")
assertThat(store:registerOperative("operative-b"), "second operative registration failed")

-- Enqueue one reward and verify a safe, valid pending offer appears.
local okOffer, offerReason, sequenceOne =
	store:enqueueRelicReward(generation, "off:1", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(okOffer and offerReason == nil and sequenceOne == 1, "first reward offer failed")
local snapshot = store:readSafeSnapshot("operative-a")
assertThat(contracts.validateSafeRunBuildSnapshot(snapshot), "offer snapshot must be valid")
assertThat(#snapshot.pendingRewards == 1, "one reward must be pending")
assertThat(#snapshot.pendingRewards[1].offeredRelicIds == 2, "reward must offer two choices")
assertThat(snapshot.replacementStateId == ReplacementStates.None, "empty slots require no replacement")
local offeredRelicId = snapshot.pendingRewards[1].offeredRelicIds[1]
local otherOfferedRelicId = snapshot.pendingRewards[1].offeredRelicIds[2]

-- The offer must not leak into a second operative.
assertThat(#store:readSafeSnapshot("operative-b").pendingRewards == 0, "rewards must be per-operative")

-- Replaying the offer request must not create a second reward.
local replayOffer, replayReason =
	store:enqueueRelicReward(generation, "off:1", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(not replayOffer and replayReason == Rejections.DuplicateRequest, "offer replay must be rejected")
assertThat(#store:readSafeSnapshot("operative-a").pendingRewards == 1, "offer replay created a duplicate reward")

-- Choosing an un-offered relic is rejected.
local unofferedRelicId = RelicIds.SecondWind
if unofferedRelicId == offeredRelicId or unofferedRelicId == otherOfferedRelicId then
	unofferedRelicId = RelicIds.GraveMomentum
end
local badChoice, badReason = store:chooseRelic(generation, "ch:bad", "operative-a", sequenceOne, unofferedRelicId)
assertThat(not badChoice and badReason == Rejections.RelicNotOffered, "un-offered relic must be rejected")

-- Choosing an offered relic equips it into the first empty slot and resolves it.
local okChoice = store:chooseRelic(generation, "ch:1", "operative-a", sequenceOne, offeredRelicId)
assertThat(okChoice, "valid relic choice failed")
snapshot = store:readSafeSnapshot("operative-a")
assertThat(#snapshot.pendingRewards == 0, "resolved reward must leave the queue")
assertThat(
	snapshot.relicSlots[1].slotStateId == SlotStates.Equipped and snapshot.relicSlots[1].relicId == offeredRelicId,
	"chosen relic must occupy the first slot"
)

-- RPG-0108 counted relics: the equipped slot's counterValue is the only home for
-- relic progress, and the pure resolver owns the arithmetic.
local firstAdvance = store:advanceRelicCounter("operative-a", offeredRelicId, 5, 8)
assertThat(
	firstAdvance ~= nil and firstAdvance.counterAfter == 5 and firstAdvance.triggerCount == 0,
	"a partial counter advance must not trigger"
)
assertThat(
	store:readSafeSnapshot("operative-a").relicSlots[1].counterValue == 5,
	"the advanced counter must be stored in the equipped slot"
)
local triggeringAdvance = store:advanceRelicCounter("operative-a", offeredRelicId, 11, 8)
assertThat(
	triggeringAdvance ~= nil and triggeringAdvance.triggerCount == 2 and triggeringAdvance.counterAfter == 0,
	"a counter advance must report every whole trigger and keep the remainder"
)
assertThat(
	store:advanceRelicCounter("operative-a", otherOfferedRelicId, 1, 8) == nil,
	"an unequipped relic must not advance a counter"
)
assertThat(
	store:advanceRelicCounter("ghost-operative", offeredRelicId, 1, 8) == nil,
	"an unknown operative must not advance a counter"
)
local invalidAdvance = store:advanceRelicCounter("operative-a", offeredRelicId, -3, 8)
assertThat(
	invalidAdvance ~= nil and invalidAdvance.triggerCount == 0 and invalidAdvance.counterAfter == 0,
	"an invalid increment must trigger nothing and leave the counter unchanged"
)

-- The resolved reward sequence cannot be replayed.
local replayChoice, replayChoiceReason =
	store:chooseRelic(generation, "ch:2", "operative-a", sequenceOne, otherOfferedRelicId)
assertThat(not replayChoice and replayChoiceReason == Rejections.RewardNotPending, "resolved reward must not reopen")

-- A duplicate request ID is rejected even for a fresh reward.
local okOffer2 = store:enqueueRelicReward(generation, "off:2", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(okOffer2, "second reward offer failed")
local dupRequest, dupReason = store:chooseRelic(
	generation,
	"ch:1",
	"operative-a",
	2,
	store:readSafeSnapshot("operative-a").pendingRewards[1].offeredRelicIds[1]
)
assertThat(not dupRequest and dupReason == Rejections.DuplicateRequest, "replayed request ID must be rejected")

-- Equipped relics are excluded from later offers.
local secondOffer = store:readSafeSnapshot("operative-a").pendingRewards[1]
for _, relicId in secondOffer.offeredRelicIds do
	assertThat(relicId ~= offeredRelicId, "an equipped relic must not be re-offered")
end

-- Fill the remaining two slots so all three are occupied.
store:chooseRelic(generation, "ch:slot2", "operative-a", 2, secondOffer.offeredRelicIds[1])
local okOffer3 = store:enqueueRelicReward(generation, "off:3", "operative-a", SourceIds.HordeClear, EMPTY_LOADOUT)
assertThat(okOffer3, "third reward offer failed")
local thirdOffer = store:readSafeSnapshot("operative-a").pendingRewards[1]
store:chooseRelic(generation, "ch:slot3", "operative-a", 3, thirdOffer.offeredRelicIds[1])
snapshot = store:readSafeSnapshot("operative-a")
local occupiedSlots = 0
for _, slot in snapshot.relicSlots do
	if slot.slotStateId == SlotStates.Equipped then
		occupiedSlots += 1
	end
end
assertThat(occupiedSlots == 3, "all three relic slots must be occupied")

-- With full slots, a new reward demands an explicit replacement.
local okOffer4 = store:enqueueRelicReward(generation, "off:4", "operative-a", SourceIds.BossMilestone, EMPTY_LOADOUT)
assertThat(okOffer4, "fourth reward offer failed")
snapshot = store:readSafeSnapshot("operative-a")
assertThat(snapshot.replacementStateId == ReplacementStates.AwaitingChoice, "full slots must await a replacement")
local fourthOffer = snapshot.pendingRewards[1]
local fourthRelicId = fourthOffer.offeredRelicIds[1]

-- chooseRelic is rejected while slots are full.
local fullChoice, fullReason = store:chooseRelic(generation, "ch:full", "operative-a", 4, fourthRelicId)
assertThat(not fullChoice and fullReason == Rejections.SlotsFull, "a full build must reject a plain choice")

-- Replacing into an invalid slot index is rejected.
local badSlot, badSlotReason = store:replaceRelic(generation, "rp:bad", "operative-a", 4, fourthRelicId, 99)
assertThat(not badSlot and badSlotReason == Rejections.InvalidReplacementSlot, "invalid replacement slot must reject")

-- A valid replacement discards the old relic and equips the new one.
local discardedRelicId = snapshot.relicSlots[1].relicId
local okReplace = store:replaceRelic(generation, "rp:1", "operative-a", 4, fourthRelicId, 1)
assertThat(okReplace, "valid replacement failed")
snapshot = store:readSafeSnapshot("operative-a")
assertThat(snapshot.relicSlots[1].relicId == fourthRelicId, "replacement did not equip the chosen relic")
assertThat(#snapshot.pendingRewards == 0, "replacement must resolve the reward")
assertThat(snapshot.replacementStateId == ReplacementStates.None, "resolved replacement must clear the awaiting state")
local stillEquipped = false
for _, slot in snapshot.relicSlots do
	if slot.relicId == discardedRelicId then
		stillEquipped = true
	end
end
assertThat(not stillEquipped, "the discarded relic must be destroyed for the operation")

-- Replacement is rejected when an empty slot exists (use chooseRelic instead).
store:startOperation()
generation = store:readOperationGeneration()
assertThat(store:registerOperative("operative-a"), "re-registration after reset failed")
store:enqueueRelicReward(generation, "off:reset", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
local resetOffer = store:readSafeSnapshot("operative-a").pendingRewards[1]
local notRequired, notRequiredReason =
	store:replaceRelic(generation, "rp:early", "operative-a", 1, resetOffer.offeredRelicIds[1], 1)
assertThat(
	not notRequired and notRequiredReason == Rejections.ReplacementNotRequired,
	"replacement must require full slots"
)

-- Reconnect returns the stored offer without rerolling it.
local beforeDisconnect = store:readSafeSnapshot("operative-a").pendingRewards[1]
assertThat(store:disconnectOperative("operative-a"), "disconnect failed")
assertThat(store:registerOperative("operative-a"), "reconnect failed")
local afterReconnect = store:readSafeSnapshot("operative-a").pendingRewards[1]
assertThat(
	afterReconnect.rewardSequence == beforeDisconnect.rewardSequence
		and afterReconnect.offeredRelicIds[1] == beforeDisconnect.offeredRelicIds[1]
		and afterReconnect.offeredRelicIds[2] == beforeDisconnect.offeredRelicIds[2],
	"reconnect must return the stored offer, not a reroll"
)

-- The reward queue is bounded.
store:startOperation()
generation = store:readOperationGeneration()
store:registerOperative("operative-a")
local queued = 0
for index = 1, config.Limits.maximumQueuedRelicRewardsPerOperative do
	assertThat(
		store:enqueueRelicReward(generation, "q:" .. index, "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT),
		"queue fill failed"
	)
	queued += 1
end
local overflowOk, overflowReason =
	store:enqueueRelicReward(generation, "q:overflow", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(not overflowOk and overflowReason == Rejections.RewardQueueFull, "reward queue ceiling was exceeded")
assertThat(#store:readSafeSnapshot("operative-a").pendingRewards == queued, "queue ceiling drifted")

-- Copied-state isolation: mutating a snapshot cannot corrupt the owner.
local mutableSnapshot = store:readSafeSnapshot("operative-a")
mutableSnapshot.pendingRewards[1].offeredRelicIds[1] = "forged-relic"
mutableSnapshot.relicSlots[1].relicId = RelicIds.SecondWind
local freshSnapshot = store:readSafeSnapshot("operative-a")
assertThat(
	freshSnapshot.pendingRewards[1].offeredRelicIds[1] ~= "forged-relic",
	"snapshot copy leaked into owned state"
)
assertThat(freshSnapshot.relicSlots[1].relicId == nil, "snapshot slot copy leaked into owned state")

-- Stale generation and unknown source and unknown participant are rejected.
local staleOk, staleReason =
	store:enqueueRelicReward(generation - 1, "stale", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(not staleOk and staleReason == Rejections.StaleOperationGeneration, "stale generation must reject")
local sourceOk, sourceReason =
	store:enqueueRelicReward(generation, "bad-src", "operative-a", "reward-source.fake", EMPTY_LOADOUT)
assertThat(not sourceOk and sourceReason == Rejections.InvalidIntent, "unknown reward source must reject")
local missingOk, missingReason = store:chooseRelic(generation, "missing", "ghost-operative", 1, RelicIds.BloodBattery)
assertThat(not missingOk and missingReason == Rejections.NotParticipant, "unknown operative must reject")

-- Teardown erases every reward and refuses further mutation.
store:stopOperation()
assertThat(store:readSafeSnapshot("operative-a") == nil, "teardown retained a snapshot")
local stoppedOk, stoppedReason =
	store:enqueueRelicReward(generation, "after-stop", "operative-a", SourceIds.EliteKill, EMPTY_LOADOUT)
assertThat(not stoppedOk and stoppedReason == Rejections.ServiceStopped, "stopped owner accepted a reward")

print("RunBuildRewardFramework: bounded queue, slot equip/replace, replay, reconnect, isolation, and teardown passed")
