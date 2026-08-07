--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0108 expedition result assertion failed", 2)
	end
end

local EQUIPMENT_TOKEN = {}
local EXPEDITION_TOKEN = {}
local RESULT_TOKEN = {}

local equipmentContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	injectGlobals = true,
})()
local expeditionContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionContracts.luau"), {
	debugName = "ExpeditionContracts",
	injectGlobals = true,
})()
local resultContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionResultContracts.luau"), {
	debugName = "ExpeditionResultContracts",
	environment = {
		script = {
			Parent = {
				ExpeditionContracts = EXPEDITION_TOKEN,
				Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == EQUIPMENT_TOKEN then
				return equipmentContracts
			end
			if token == EXPEDITION_TOKEN then
				return expeditionContracts
			end
			error("unexpected result contracts dependency")
		end,
	},
	injectGlobals = true,
})()

local replicatedStorage = {
	Shared = {
		Expeditions = {
			ExpeditionContracts = EXPEDITION_TOKEN,
			ExpeditionResultContracts = RESULT_TOKEN,
		},
	},
}
local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionResultService.luau"), {
	debugName = "ExpeditionResultService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == EXPEDITION_TOKEN then
				return expeditionContracts
			end
			if token == RESULT_TOKEN then
				return resultContracts
			end
			error("unexpected result service dependency")
		end,
	},
	injectGlobals = true,
})()

local OutcomeIds = expeditionContracts.OutcomeIds
local PhaseIds = expeditionContracts.PhaseIds
local ReplayDecisionIds = resultContracts.ReplayDecisionIds

local snapshot = {
	RunId = "run-result-0001",
	DefinitionId = "first-expedition",
	DefinitionVersion = "1.0.0",
	Seed = 12345,
	PhaseId = PhaseIds.Results,
	PhaseIndex = 7,
	OutcomeId = OutcomeIds.Completed,
	StartedAtUnix = 100,
	PhaseStartedAtUnix = 500,
	PartySize = 3,
	SecretDiscovered = true,
}
local eliteReward = {
	InstanceId = "run-result-0001:Elite:1",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = equipmentContracts.SlotIds.Primary,
	Rarity = equipmentContracts.RarityIds.Uncommon,
	Power = 14,
	SourceId = equipmentContracts.SourceIds.Elite,
	RunId = snapshot.RunId,
	Seed = 12346,
}
local bossReward = {
	InstanceId = "run-result-0001:Boss:1",
	DefinitionId = "keeper-relic",
	DefinitionVersion = "1.0.0",
	DisplayName = "Keeper Relic",
	Slot = equipmentContracts.SlotIds.Relic,
	Rarity = equipmentContracts.RarityIds.Rare,
	Power = 19,
	SourceId = equipmentContracts.SourceIds.Boss,
	RunId = snapshot.RunId,
	Seed = 12347,
}

local service = serviceModule.new()
assert(service:getSummary() == nil, "summary must not exist before finalization")
assert(not service:recordReplayDecision(ReplayDecisionIds.Replay).Accepted, "decision before finalization must fail")

local inProgress = table.clone(snapshot)
inProgress.OutcomeId = OutcomeIds.InProgress
assert(not service:finalize({ Snapshot = inProgress, FinishedAtUnix = 520, Rewards = {} }).Accepted, "active run must not finalize")

local finalized = service:finalize({
	Snapshot = snapshot,
	FinishedAtUnix = 550,
	Rewards = { eliteReward, bossReward },
})
assert(finalized.Accepted, "terminal expedition should finalize")
assert(finalized.Summary ~= nil and finalized.Summary.DurationSeconds == 450, "duration must be derived server-side")
assert(finalized.Summary.SecretDiscovered, "secret status must be preserved")
assert(#finalized.Summary.Rewards == 2, "both rewards must be summarized once")
assert(finalized.Summary.ReplayDecisionId == ReplayDecisionIds.Undecided, "decision starts undecided")
assert(not service:finalize({ Snapshot = snapshot, FinishedAtUnix = 551, Rewards = {} }).Accepted, "duplicate finalization must fail")

local decision = service:recordReplayDecision(ReplayDecisionIds.Replay)
assert(decision.Accepted, "first valid replay decision should succeed")
assert(decision.Summary ~= nil and decision.Summary.ReplayDecisionId == ReplayDecisionIds.Replay, "replay choice must be stored")
assert(not service:recordReplayDecision(ReplayDecisionIds.ReturnToPreparation).Accepted, "second replay decision must fail")

local mismatchService = serviceModule.new()
local wrongReward = table.clone(eliteReward)
wrongReward.RunId = "another-run"
assert(not mismatchService:finalize({ Snapshot = snapshot, FinishedAtUnix = 550, Rewards = { wrongReward } }).Accepted, "foreign reward must fail")

local duplicateService = serviceModule.new()
assert(not duplicateService:finalize({ Snapshot = snapshot, FinishedAtUnix = 550, Rewards = { eliteReward, eliteReward } }).Accepted, "duplicate reward instance must fail")

service:destroy()
service:destroy()
assert(service:getSummary() == nil, "destroyed service must disclose no summary")
assert(not service:recordReplayDecision(ReplayDecisionIds.Replay).Accepted, "destroyed service must reject decisions")

print("ExpeditionResultService.test.luau: PASS")
