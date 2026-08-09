--!strict

--[[
	BA-033 authored reward-decision data for the first repeatable dungeon.

	This module bridges BA-030/BA-032 room reward references to the canonical
	operation-bound Run Relic choice vocabulary. It does not grant rewards, open
	an offer, mutate inventory, persist equipment, or activate a boss reward
	source. Runtime consumption is deliberately disabled until a later integration
	ticket adapts these decisions into the existing authoritative run-build owner.
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
	false
)

local OrderedDecisions = table.freeze({ EliteDecision, BossDecision })
local DecisionByRoomId = table.freeze({
	[EliteDecision.RoomId] = EliteDecision,
	[BossDecision.RoomId] = BossDecision,
})

local FirstDungeonRewardDecisionConfig = {
	Version = "BA-033-v1",
	SequenceId = FirstDungeonContentConfig.SequenceId,
	SequenceVersion = FirstDungeonContentConfig.SequenceVersion,
	RewardKind = "RunRelicChoice",
	ChoiceCount = RunRpgConfig.Limits.relicChoiceCountPerReward,
	RuntimeConsumptionEnabled = false,
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
	BossDecision.SourceImplementationStateId == ImplementationStateIds.Planned,
	"boss milestone must stay declarative until its canonical runtime source is intentionally wired"
)
assert(
	FirstDungeonRewardDecisionConfig.ChoiceCount == 2,
	"the first dungeon reward decisions must preserve the canonical two-choice Run Relic decision"
)
assert(
	FirstDungeonRewardDecisionConfig.RuntimeConsumptionEnabled == false,
	"BA-033 is authored data only and must not activate reward runtime consumption"
)
assert(
	FirstDungeonRewardDecisionConfig.PersistentEquipmentEligible == false,
	"BA-033 must not choose or expand the unresolved persistent-equipment reward authority"
)

return table.freeze(FirstDungeonRewardDecisionConfig)
