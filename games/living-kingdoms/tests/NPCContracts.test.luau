--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-021 NPC contract assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/NPC/NPCContracts.luau"
local source = fs.readFile(sourcePath)
local Contracts = luau.load(source, {
	debugName = "NPCContracts",
	injectGlobals = true,
})()

assert(Contracts.RuntimeConsumptionActive == false)
assert(Contracts.MutationIntentAllowed == false)

local guideDefinition = table.freeze({
	NPCId = "npc.fixture.guide",
	Version = "1",
	RoleIds = table.freeze({ Contracts.RoleIds.Guide, Contracts.RoleIds.OperationContact }),
	DialogueRefs = table.freeze({
		table.freeze({
			DialogueRefId = "dialogue.fixture.guide.intro",
			EntryNodeRefId = "node.start",
		}),
	}),
	Capabilities = table.freeze({
		table.freeze({
			CapabilityId = "capability.fixture.guide.conversation",
			KindId = Contracts.CapabilityKindIds.Conversation,
			TargetRefId = "dialogue.fixture.guide.intro",
			DialogueRefId = "dialogue.fixture.guide.intro",
			MutationAllowed = false,
		}),
		table.freeze({
			CapabilityId = "capability.fixture.guide.operation-board-referral",
			KindId = Contracts.CapabilityKindIds.DomainReferral,
			TargetRefId = "station.hub.operation_board",
			DialogueRefId = "dialogue.fixture.guide.intro",
			MutationAllowed = false,
		}),
	}),
	RuntimeEnabled = false,
})

assert(Contracts.validateNPCDefinition(guideDefinition) == true)
assert(Contracts.validateDefinitionSet({ guideDefinition }) == true)
assert(Contracts.hasCapability(guideDefinition, "capability.fixture.guide.conversation") == true)
assert(Contracts.hasCapability(guideDefinition, "capability.unknown") == false)

local duplicateRole = table.clone(guideDefinition)
duplicateRole.RoleIds = { Contracts.RoleIds.Guide, Contracts.RoleIds.Guide }
assert(Contracts.validateNPCDefinition(duplicateRole) == false)

local unknownRole = table.clone(guideDefinition)
unknownRole.RoleIds = { "UnknownRole" }
assert(Contracts.validateNPCDefinition(unknownRole) == false)

local duplicateDialogue = table.clone(guideDefinition)
duplicateDialogue.DialogueRefs = {
	guideDefinition.DialogueRefs[1],
	guideDefinition.DialogueRefs[1],
}
assert(Contracts.validateNPCDefinition(duplicateDialogue) == false)

local missingDialogue = table.clone(guideDefinition)
missingDialogue.Capabilities = {
	table.freeze({
		CapabilityId = "capability.fixture.bad-dialogue-ref",
		KindId = Contracts.CapabilityKindIds.Conversation,
		TargetRefId = "dialogue.fixture.missing",
		DialogueRefId = "dialogue.fixture.missing",
		MutationAllowed = false,
	}),
}
assert(Contracts.validateNPCDefinition(missingDialogue) == false)

local conversationWithoutDialogue = table.clone(guideDefinition)
conversationWithoutDialogue.Capabilities = {
	table.freeze({
		CapabilityId = "capability.fixture.no-dialogue",
		KindId = Contracts.CapabilityKindIds.Conversation,
		TargetRefId = "dialogue.fixture.guide.intro",
		MutationAllowed = false,
	}),
}
assert(Contracts.validateNPCDefinition(conversationWithoutDialogue) == false)

local mutationCapability = table.clone(guideDefinition)
mutationCapability.Capabilities = {
	table.freeze({
		CapabilityId = "capability.fixture.mutation",
		KindId = Contracts.CapabilityKindIds.DomainReferral,
		TargetRefId = "station.hub.operation_board",
		MutationAllowed = true,
	}),
}
assert(Contracts.validateNPCDefinition(mutationCapability) == false)

local duplicateCapability = table.clone(guideDefinition)
duplicateCapability.Capabilities = {
	guideDefinition.Capabilities[1],
	guideDefinition.Capabilities[1],
}
assert(Contracts.validateNPCDefinition(duplicateCapability) == false)

local unknownField = table.clone(guideDefinition)
unknownField.ClientOwnsConversationState = true
assert(Contracts.validateNPCDefinition(unknownField) == false)

local secondDefinition = table.clone(guideDefinition)
secondDefinition.NPCId = "npc.fixture.second"
assert(Contracts.validateDefinitionSet({ guideDefinition, secondDefinition }) == true)
assert(Contracts.validateDefinitionSet({ guideDefinition, guideDefinition }) == false)

-- BA-021 must remain pure contract/validation work.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "ProximityPrompt", 1, true) == nil)

print("BA-021 NPCContracts fixture passed")
