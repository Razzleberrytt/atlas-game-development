--!strict

--[[
	BA-033 authored reward-decision data for the first repeatable dungeon.

	This module bridges BA-030/BA-032 room reward references to the canonical
	operation-bound Run Relic choice vocabulary. The boss decision is consumed by
	the existing authoritative expedition/run-build owners when the expedition
	advances from Boss into Rewards. The elite decision remains declarative here:
	generic confirmed elite deaths already use the canonical EliteKill reward
	source, and the authored room must not double-pay that path.

	Nothing in this module mutates inventory, persists equipment, or grants power.
]]

local FirstDungeonContentConfig = require(script.Parent.FirstDungeonContentConfig)
local RunRpgConfig = require(script.Parent.RunRpgConfig)
local RoomAssemblyContracts = require(script.Parent.Parent.Expeditions.RoomAssemblyContracts)
local RunRpgContracts = require(script.Parent.Parent.RPG.RunRpgContracts)

local ImplementationStateIds = RunRpgContracts.ImplementationStateIds
local RewardSourceIds = RunRpgContracts.RewardSourceIds
local RoomRewardSourceIds = RoomAssemblyContracts.RoomRewardSourceIds

local function implementationStateForRewardSource(sourceId: string): string
	for _, definition in RunRpgConfig.RewardSourceCatalog do
		if definition.sourceId == sourceId then
			return definition.implementationStateId
		end
	end
	error("unknown canonical run reward source: " .. sourceId)
end

local function rewardDecision(
	decisionId: string,
	roomId: string,
	roomRewardSourceId: string,
	runRewardSourceId: string,
	runtimeConsumptionEnabled: boolean
)
	return table.freeze({
		DecisionId = decisionId,
		RoomId = roomId,
		RoomRewardSourceId = roomRewardSourceId,
		RunRewardSourceId = runRewardSourceId,
		RewardKind = "RunRelicChoice",
		ChoiceCount = RunRpgConfig.Limits.relicChoiceCountPerReward,
		SourceImplementationStateId = implementationStateForRewardSource(runRewardSourceId),
		RuntimeConsumptionEnabled = runtimeConsumptionEnabled,
		PersistentEquipmentEligible = false,
	})
end

local EliteDecision = rewardDecision(
	"first-descent.elite-relic-choice",
	"warden-threshold",
	RoomRewardSourceIds.Elite,
	RewardSourceIds.EliteKill,
	false
)

local BossDecision = rewardDecision(
	"first-descent.boss-relic-choice",
	"keeper-core",
	RoomRewardSourceIds.Boss,
	RewardSourceIds.BossMilestone,
	true
)

local OrderedDecisions = table.freeze({ EliteDecision, BossDecision })
local DecisionByRoomId = table.freeze({
	[EliteDecision.RoomId] = EliteDecision,
	[BossDecision.RoomId] = BossDecision,
})

local FirstDungeonRewardDecisionConfig = {
	Version = "BA-033-v2-boss-live",
	SequenceId = FirstDungeonContentConfig.SequenceId,
	SequenceVersion = FirstDungeonContentConfig.SequenceVersion,
	RewardKind = "RunRelicChoice",
	ChoiceCount = RunRpgConfig.Limits.relicChoiceCountPerReward,
	RuntimeConsumptionEnabled = true,
	PersistentEquipmentEligible = false,
	OrderedDecisions = OrderedDecisions,
	DecisionByRoomId = DecisionByRoomId,
}

assert(
	FirstDungeonContentConfig.Encounters[EliteDecision.RoomId].RewardSourceId == EliteDecision.RoomRewardSourceId,
	"elite reward decision must target the authored BA-032 elite reward room"
)
assert(
	FirstDungeonContentConfig.Encounters[BossDecision.RoomId].RewardSourceId == BossDecision.RoomRewardSourceId,
	"boss reward decision must target the authored BA-032 boss reward room"
)
assert(
	EliteDecision.SourceImplementationStateId == ImplementationStateIds.Implemented,
	"elite relic source must remain backed by the currently implemented run-RPG source"
)
assert(
	BossDecision.SourceImplementationStateId == ImplementationStateIds.Implemented,
	"boss milestone must remain implemented while the live First Descent boss transition consumes it"
)
assert(
	FirstDungeonRewardDecisionConfig.ChoiceCount == 2,
	"the first dungeon reward decisions must preserve the canonical two-choice Run Relic decision"
)
assert(
	FirstDungeonRewardDecisionConfig.RuntimeConsumptionEnabled == true,
	"BA-033 must disclose that at least one authored reward decision is live"
)
assert(
	EliteDecision.RuntimeConsumptionEnabled == false,
	"the authored elite room must not double-pay generic elite rewards"
)
assert(BossDecision.RuntimeConsumptionEnabled == true, "the authored boss reward decision must remain live")
assert(
	FirstDungeonRewardDecisionConfig.PersistentEquipmentEligible == false,
	"BA-033 must not choose or expand the unresolved persistent-equipment reward authority"
)

return table.freeze(FirstDungeonRewardDecisionConfig)
