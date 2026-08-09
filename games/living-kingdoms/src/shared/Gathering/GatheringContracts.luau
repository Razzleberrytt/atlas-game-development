--!strict

--[[
	BA-023 canonical gathering/resource-node contracts and pure eligibility resolver.

	This module is dormant architecture. Resource, tool, respawn-policy, and reward
	references remain opaque IDs until BA-025 cross-domain validation. It does not
	harvest nodes, deplete world state, schedule respawns, grant rewards, persist
	state, bind networking, or activate a gathering interaction surface.
]]

local Contracts = {}

Contracts.RuntimeConsumptionActive = false
Contracts.MutationIntentAllowed = false

Contracts.DenialReasonIds = table.freeze({
	RuntimeDisabled = "RuntimeDisabled",
	NodeUnavailable = "NodeUnavailable",
	ToolRequired = "ToolRequired",
})

export type GatheringRewardReference = {
	RewardRefId: string,
	Quantity: number,
}

export type ResourceNodeDefinition = {
	NodeId: string,
	Version: string,
	ResourceRefId: string,
	RequiredToolRefId: string?,
	RespawnPolicyRefId: string,
	RewardRefs: { GatheringRewardReference },
	RuntimeEnabled: boolean,
}

export type GatheringEligibilityContext = {
	NodeAvailable: boolean,
	EquippedToolRefId: string?,
}

export type GatheringEligibilityResult = {
	Eligible: boolean,
	ReasonId: string?,
	RequiredToolRefId: string?,
}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

local function isDenseArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return #value == count
end

local function validateRewardReference(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local reference = value :: { [any]: any }
	return hasOnlyKeys(reference, {
		RewardRefId = true,
		Quantity = true,
	}) and isNonEmptyBoundedString(reference.RewardRefId, 128) and isPositiveInteger(reference.Quantity)
end

local function validateRewardReferenceList(value: unknown): boolean
	if type(value) ~= "table" or not isDenseArray(value :: { [any]: any }) or #value < 1 then
		return false
	end
	local seen = {}
	for _, reference in value :: { any } do
		if not validateRewardReference(reference) or seen[reference.RewardRefId] then
			return false
		end
		seen[reference.RewardRefId] = true
	end
	return true
end

function Contracts.validateNodeDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			NodeId = true,
			Version = true,
			ResourceRefId = true,
			RequiredToolRefId = true,
			RespawnPolicyRefId = true,
			RewardRefs = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if
		not isNonEmptyBoundedString(definition.NodeId, 96)
		or not isNonEmptyBoundedString(definition.Version, 24)
		or not isNonEmptyBoundedString(definition.ResourceRefId, 128)
		or not isNonEmptyBoundedString(definition.RespawnPolicyRefId, 128)
	then
		return false
	end
	if definition.RequiredToolRefId ~= nil and not isNonEmptyBoundedString(definition.RequiredToolRefId, 128) then
		return false
	end
	if not validateRewardReferenceList(definition.RewardRefs) then
		return false
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.validateNodeSet(definitions: unknown): boolean
	if type(definitions) ~= "table" or not isDenseArray(definitions :: { [any]: any }) then
		return false
	end
	local seenNodeIds = {}
	for _, definition in definitions :: { any } do
		if not Contracts.validateNodeDefinition(definition) or seenNodeIds[definition.NodeId] then
			return false
		end
		seenNodeIds[definition.NodeId] = true
	end
	return true
end

function Contracts.evaluateEligibility(
	definition: ResourceNodeDefinition,
	context: GatheringEligibilityContext
): GatheringEligibilityResult
	if not definition.RuntimeEnabled then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.RuntimeDisabled,
			RequiredToolRefId = nil,
		})
	end
	if not context.NodeAvailable then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.NodeUnavailable,
			RequiredToolRefId = nil,
		})
	end
	if definition.RequiredToolRefId ~= nil and context.EquippedToolRefId ~= definition.RequiredToolRefId then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.ToolRequired,
			RequiredToolRefId = definition.RequiredToolRefId,
		})
	end
	return table.freeze({
		Eligible = true,
		ReasonId = nil,
		RequiredToolRefId = nil,
	})
end

assert(Contracts.RuntimeConsumptionActive == false, "BA-023 must remain dormant")
assert(Contracts.MutationIntentAllowed == false, "BA-023 cannot authorize gathering mutation")

return table.freeze(Contracts)
