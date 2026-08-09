--!strict

--[[
	BA-021 canonical NPC definition, conversation, and interaction contracts.

	This module is pure, dormant architecture. It defines stable NPC/role/dialogue/
	capability references and validates their shape. It does not spawn characters,
	create prompts or UI, bind networking, mutate domain state, or activate any
	Main World interaction surface.
]]

local Contracts = {}

Contracts.RuntimeConsumptionActive = false
Contracts.MutationIntentAllowed = false

Contracts.RoleIds = table.freeze({
	Guide = "Guide",
	OperationContact = "OperationContact",
	VendorContact = "VendorContact",
	CraftingContact = "CraftingContact",
	GatheringContact = "GatheringContact",
})

Contracts.CapabilityKindIds = table.freeze({
	Conversation = "Conversation",
	Information = "Information",
	DomainReferral = "DomainReferral",
})

export type NPCDialogueReference = {
	DialogueRefId: string,
	EntryNodeRefId: string,
}

export type NPCCapabilityDefinition = {
	CapabilityId: string,
	KindId: string,
	TargetRefId: string,
	DialogueRefId: string?,
	MutationAllowed: boolean,
}

export type NPCDefinition = {
	NPCId: string,
	Version: string,
	RoleIds: { string },
	DialogueRefs: { NPCDialogueReference },
	Capabilities: { NPCCapabilityDefinition },
	RuntimeEnabled: boolean,
}

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

local validRoleIds = {}
for _, roleId in Contracts.RoleIds do
	validRoleIds[roleId] = true
end

local validCapabilityKindIds = {}
for _, kindId in Contracts.CapabilityKindIds do
	validCapabilityKindIds[kindId] = true
end

local function validateRoleIds(value: unknown): boolean
	if type(value) ~= "table" or not isDenseArray(value :: { [any]: any }) or #value < 1 then
		return false
	end
	local seen = {}
	for _, roleId in value :: { any } do
		if type(roleId) ~= "string" or validRoleIds[roleId] ~= true or seen[roleId] then
			return false
		end
		seen[roleId] = true
	end
	return true
end

local function validateDialogueReference(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local reference = value :: { [any]: any }
	return hasOnlyKeys(reference, {
		DialogueRefId = true,
		EntryNodeRefId = true,
	})
		and isNonEmptyBoundedString(reference.DialogueRefId, 128)
		and isNonEmptyBoundedString(reference.EntryNodeRefId, 128)
end

local function validateCapability(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local capability = value :: { [any]: any }
	if
		not hasOnlyKeys(capability, {
			CapabilityId = true,
			KindId = true,
			TargetRefId = true,
			DialogueRefId = true,
			MutationAllowed = true,
		})
	then
		return false
	end
	if
		not isNonEmptyBoundedString(capability.CapabilityId, 96)
		or type(capability.KindId) ~= "string"
		or validCapabilityKindIds[capability.KindId] ~= true
		or not isNonEmptyBoundedString(capability.TargetRefId, 128)
	then
		return false
	end
	if capability.DialogueRefId ~= nil and not isNonEmptyBoundedString(capability.DialogueRefId, 128) then
		return false
	end
	return capability.MutationAllowed == false
end

function Contracts.validateNPCDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			NPCId = true,
			Version = true,
			RoleIds = true,
			DialogueRefs = true,
			Capabilities = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.NPCId, 96) or not isNonEmptyBoundedString(definition.Version, 24) then
		return false
	end
	if not validateRoleIds(definition.RoleIds) then
		return false
	end
	if type(definition.DialogueRefs) ~= "table" or not isDenseArray(definition.DialogueRefs) then
		return false
	end
	local dialogueIds = {}
	for _, reference in definition.DialogueRefs do
		if not validateDialogueReference(reference) or dialogueIds[reference.DialogueRefId] then
			return false
		end
		dialogueIds[reference.DialogueRefId] = true
	end
	if type(definition.Capabilities) ~= "table" or not isDenseArray(definition.Capabilities) or #definition.Capabilities < 1 then
		return false
	end
	local capabilityIds = {}
	for _, capability in definition.Capabilities do
		if not validateCapability(capability) or capabilityIds[capability.CapabilityId] then
			return false
		end
		if capability.DialogueRefId ~= nil and dialogueIds[capability.DialogueRefId] ~= true then
			return false
		end
		if capability.KindId == Contracts.CapabilityKindIds.Conversation and capability.DialogueRefId == nil then
			return false
		end
		capabilityIds[capability.CapabilityId] = true
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.validateDefinitionSet(definitions: unknown): boolean
	if type(definitions) ~= "table" or not isDenseArray(definitions :: { [any]: any }) then
		return false
	end
	local seenNPCIds = {}
	for _, definition in definitions :: { any } do
		if not Contracts.validateNPCDefinition(definition) or seenNPCIds[definition.NPCId] then
			return false
		end
		seenNPCIds[definition.NPCId] = true
	end
	return true
end

function Contracts.hasCapability(definition: NPCDefinition, capabilityId: string): boolean
	for _, capability in definition.Capabilities do
		if capability.CapabilityId == capabilityId then
			return true
		end
	end
	return false
end

assert(Contracts.RuntimeConsumptionActive == false, "BA-021 must remain dormant")
assert(Contracts.MutationIntentAllowed == false, "BA-021 cannot authorize domain mutation")

return table.freeze(Contracts)
