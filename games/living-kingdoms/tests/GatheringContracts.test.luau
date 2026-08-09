--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-023 gathering contract assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Gathering/GatheringContracts.luau"
local source = fs.readFile(sourcePath)
local Contracts = luau.load(source, {
	debugName = "GatheringContracts",
	injectGlobals = true,
})()

local definition = table.freeze({
	NodeId = "node.fixture.iron-vein",
	Version = "1",
	ResourceRefId = "resource.fixture.iron",
	RequiredToolRefId = "tool.fixture.pickaxe",
	RespawnPolicyRefId = "respawn.fixture.standard",
	RewardRefs = table.freeze({
		table.freeze({ RewardRefId = "reward.fixture.iron-ore", Quantity = 2 }),
		table.freeze({ RewardRefId = "reward.fixture.stone", Quantity = 1 }),
	}),
	RuntimeEnabled = false,
})

assert(Contracts.RuntimeConsumptionActive == false)
assert(Contracts.MutationIntentAllowed == false)
assert(Contracts.validateNodeDefinition(definition) == true)
assert(Contracts.validateNodeSet({ definition }) == true)

local disabled = Contracts.evaluateEligibility(definition, {
	NodeAvailable = true,
	EquippedToolRefId = "tool.fixture.pickaxe",
})
assert(disabled.Eligible == false)
assert(disabled.ReasonId == Contracts.DenialReasonIds.RuntimeDisabled)

local enabled = table.clone(definition)
enabled.RuntimeEnabled = true

local unavailable = Contracts.evaluateEligibility(enabled, {
	NodeAvailable = false,
	EquippedToolRefId = "tool.fixture.pickaxe",
})
assert(unavailable.Eligible == false)
assert(unavailable.ReasonId == Contracts.DenialReasonIds.NodeUnavailable)

local wrongTool = Contracts.evaluateEligibility(enabled, {
	NodeAvailable = true,
	EquippedToolRefId = "tool.fixture.hatchet",
})
assert(wrongTool.Eligible == false)
assert(wrongTool.ReasonId == Contracts.DenialReasonIds.ToolRequired)
assert(wrongTool.RequiredToolRefId == "tool.fixture.pickaxe")

local noTool = Contracts.evaluateEligibility(enabled, {
	NodeAvailable = true,
	EquippedToolRefId = nil,
})
assert(noTool.Eligible == false)
assert(noTool.ReasonId == Contracts.DenialReasonIds.ToolRequired)

local eligible = Contracts.evaluateEligibility(enabled, {
	NodeAvailable = true,
	EquippedToolRefId = "tool.fixture.pickaxe",
})
assert(eligible.Eligible == true)
assert(eligible.ReasonId == nil)

local toolOptional = table.clone(enabled)
toolOptional.RequiredToolRefId = nil
local optionalToolEligible = Contracts.evaluateEligibility(toolOptional, {
	NodeAvailable = true,
	EquippedToolRefId = nil,
})
assert(optionalToolEligible.Eligible == true)

local duplicateReward = table.clone(definition)
duplicateReward.RewardRefs = {
	definition.RewardRefs[1],
	definition.RewardRefs[1],
}
assert(Contracts.validateNodeDefinition(duplicateReward) == false)

local zeroReward = table.clone(definition)
zeroReward.RewardRefs = {
	{ RewardRefId = "reward.fixture.iron-ore", Quantity = 0 },
}
assert(Contracts.validateNodeDefinition(zeroReward) == false)

local noRewards = table.clone(definition)
noRewards.RewardRefs = {}
assert(Contracts.validateNodeDefinition(noRewards) == false)

local emptyRespawnRef = table.clone(definition)
emptyRespawnRef.RespawnPolicyRefId = ""
assert(Contracts.validateNodeDefinition(emptyRespawnRef) == false)

local duplicateNodeId = table.clone(definition)
assert(Contracts.validateNodeSet({ definition, duplicateNodeId }) == false)

local unknownField = table.clone(definition)
unknownField.ClientMayHarvest = true
assert(Contracts.validateNodeDefinition(unknownField) == false)

-- BA-023 must stay pure eligibility architecture with no runtime/mutation path.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)
assert(string.find(source, "task.delay", 1, true) == nil)
assert(string.find(source, "task.wait", 1, true) == nil)

print("BA-023 GatheringContracts fixture passed")
