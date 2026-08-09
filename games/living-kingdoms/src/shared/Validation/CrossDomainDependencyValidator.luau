--!strict

--[[
	BA-025 cross-domain dependency validation for the dormant BA-020 through BA-024 contracts.

	This module validates references between already shape-valid domain definitions. It does
	not own quest, NPC, crafting, gathering, vendor, reward, inventory, economy, persistence,
	networking, or runtime behavior.
]]

local Validator = {}

Validator.RuntimeConsumptionActive = false
Validator.MutationIntentAllowed = false

Validator.IssueCodes = table.freeze({
	UnknownQuestPrerequisite = "UnknownQuestPrerequisite",
	QuestPrerequisiteCycle = "QuestPrerequisiteCycle",
	ImpossibleQuestPrerequisite = "ImpossibleQuestPrerequisite",
	UnknownProgressSourceRef = "UnknownProgressSourceRef",
	UnknownRewardRef = "UnknownRewardRef",
	UnknownRewardAuthorityOwner = "UnknownRewardAuthorityOwner",
	UnknownNPCTargetRef = "UnknownNPCTargetRef",
	UnknownItemRef = "UnknownItemRef",
	UnknownStationRef = "UnknownStationRef",
	UnknownUnlockRef = "UnknownUnlockRef",
	UnknownResourceRef = "UnknownResourceRef",
	UnknownToolRef = "UnknownToolRef",
	UnknownRespawnPolicyRef = "UnknownRespawnPolicyRef",
	UnknownVendorCatalogRef = "UnknownVendorCatalogRef",
	ImpossibleVendorCatalogDependency = "ImpossibleVendorCatalogDependency",
	UnknownCurrencyRef = "UnknownCurrencyRef",
})

export type RewardReference = {
	RewardRefId: string,
	RewardAuthorityOwnerId: string?,
}

export type QuestObjectiveReference = {
	ProgressSourceRef: string,
}

export type QuestDefinition = {
	QuestId: string,
	PrerequisiteQuestIds: { string },
	Objectives: { QuestObjectiveReference },
	RewardRefs: { RewardReference },
	RuntimeEnabled: boolean,
}

export type NPCCapabilityReference = {
	TargetRefId: string,
}

export type NPCDefinition = {
	NPCId: string,
	Capabilities: { NPCCapabilityReference },
}

export type ItemReference = {
	ItemRefId: string,
}

export type CraftingRecipeDefinition = {
	RecipeId: string,
	IngredientRefs: { ItemReference },
	OutputRefs: { ItemReference },
	RequiredStationRefId: string?,
	RequiredUnlockId: string?,
}

export type GatheringRewardReference = {
	RewardRefId: string,
}

export type ResourceNodeDefinition = {
	NodeId: string,
	ResourceRefId: string,
	RequiredToolRefId: string?,
	RespawnPolicyRefId: string,
	RewardRefs: { GatheringRewardReference },
}

export type VendorDefinition = {
	VendorId: string,
	CatalogRefIds: { string },
	RuntimeEnabled: boolean,
}

export type VendorPriceDefinition = {
	CurrencyRefId: string,
}

export type VendorCatalogEntryDefinition = {
	EntryId: string,
	ItemRefId: string,
	Price: VendorPriceDefinition,
}

export type VendorCatalogDefinition = {
	CatalogId: string,
	Entries: { VendorCatalogEntryDefinition },
	RuntimeEnabled: boolean,
}

export type ReferenceRegistry = {
	ProgressSourceRefIds: { string },
	RewardRefIds: { string },
	RewardAuthorityOwnerIds: { string },
	NPCTargetRefIds: { string },
	ItemRefIds: { string },
	StationRefIds: { string },
	UnlockRefIds: { string },
	ResourceRefIds: { string },
	ToolRefIds: { string },
	RespawnPolicyRefIds: { string },
	CurrencyRefIds: { string },
}

export type CrossDomainGraph = {
	Quests: { QuestDefinition },
	NPCs: { NPCDefinition },
	Recipes: { CraftingRecipeDefinition },
	ResourceNodes: { ResourceNodeDefinition },
	Vendors: { VendorDefinition },
	Catalogs: { VendorCatalogDefinition },
	Registry: ReferenceRegistry,
}

export type ValidationIssue = {
	Code: string,
	Domain: string,
	DefinitionId: string,
	RefId: string?,
}

export type ValidationResult = {
	Valid: boolean,
	Issues: { ValidationIssue },
}

local function makeSet(values: { string }): { [string]: boolean }
	local result = {}
	for _, value in values do
		result[value] = true
	end
	return result
end

local function addIssue(issues: { ValidationIssue }, code: string, domain: string, definitionId: string, refId: string?)
	table.insert(issues, {
		Code = code,
		Domain = domain,
		DefinitionId = definitionId,
		RefId = refId,
	})
end

local function sortIssues(issues: { ValidationIssue })
	table.sort(issues, function(left: ValidationIssue, right: ValidationIssue): boolean
		if left.Domain ~= right.Domain then
			return left.Domain < right.Domain
		end
		if left.DefinitionId ~= right.DefinitionId then
			return left.DefinitionId < right.DefinitionId
		end
		if left.Code ~= right.Code then
			return left.Code < right.Code
		end
		return (left.RefId or "") < (right.RefId or "")
	end)
end

local function validateQuestReferences(graph: CrossDomainGraph, issues: { ValidationIssue })
	local questsById = {}
	for _, quest in graph.Quests do
		questsById[quest.QuestId] = quest
	end

	local progressSourceIds = makeSet(graph.Registry.ProgressSourceRefIds)
	local rewardIds = makeSet(graph.Registry.RewardRefIds)
	local rewardAuthorityOwnerIds = makeSet(graph.Registry.RewardAuthorityOwnerIds)

	for _, quest in graph.Quests do
		for _, prerequisiteQuestId in quest.PrerequisiteQuestIds do
			local prerequisite = questsById[prerequisiteQuestId]
			if prerequisite == nil then
				addIssue(
					issues,
					Validator.IssueCodes.UnknownQuestPrerequisite,
					"Quest",
					quest.QuestId,
					prerequisiteQuestId
				)
			elseif quest.RuntimeEnabled and not prerequisite.RuntimeEnabled then
				addIssue(
					issues,
					Validator.IssueCodes.ImpossibleQuestPrerequisite,
					"Quest",
					quest.QuestId,
					prerequisiteQuestId
				)
			end
		end

		for _, objective in quest.Objectives do
			if progressSourceIds[objective.ProgressSourceRef] ~= true then
				addIssue(
					issues,
					Validator.IssueCodes.UnknownProgressSourceRef,
					"Quest",
					quest.QuestId,
					objective.ProgressSourceRef
				)
			end
		end

		for _, reward in quest.RewardRefs do
			if rewardIds[reward.RewardRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownRewardRef, "Quest", quest.QuestId, reward.RewardRefId)
			end
			if reward.RewardAuthorityOwnerId ~= nil and rewardAuthorityOwnerIds[reward.RewardAuthorityOwnerId] ~= true then
				addIssue(
					issues,
					Validator.IssueCodes.UnknownRewardAuthorityOwner,
					"Quest",
					quest.QuestId,
					reward.RewardAuthorityOwnerId
				)
			end
		end
	end
end

local function validateQuestCycles(graph: CrossDomainGraph, issues: { ValidationIssue })
	local prerequisitesByQuestId = {}
	local knownQuestIds = {}
	for _, quest in graph.Quests do
		knownQuestIds[quest.QuestId] = true
		prerequisitesByQuestId[quest.QuestId] = quest.PrerequisiteQuestIds
	end

	local state = {}
	local cycleMembers = {}
	local stack = {}
	local stackIndex = {}

	local function visit(questId: string)
		if state[questId] == 2 then
			return
		end
		if state[questId] == 1 then
			local firstIndex = stackIndex[questId]
			if firstIndex ~= nil then
				for index = firstIndex, #stack do
					cycleMembers[stack[index]] = true
				end
			end
			return
		end

		state[questId] = 1
		table.insert(stack, questId)
		stackIndex[questId] = #stack

		for _, prerequisiteQuestId in prerequisitesByQuestId[questId] or {} do
			if knownQuestIds[prerequisiteQuestId] == true then
				visit(prerequisiteQuestId)
			end
		end

		stackIndex[questId] = nil
		table.remove(stack)
		state[questId] = 2
	end

	for questId in knownQuestIds do
		visit(questId)
	end

	for questId in cycleMembers do
		addIssue(issues, Validator.IssueCodes.QuestPrerequisiteCycle, "Quest", questId, nil)
	end
end

local function validateNPCReferences(graph: CrossDomainGraph, issues: { ValidationIssue })
	local targetIds = makeSet(graph.Registry.NPCTargetRefIds)
	for _, npc in graph.NPCs do
		for _, capability in npc.Capabilities do
			if targetIds[capability.TargetRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownNPCTargetRef, "NPC", npc.NPCId, capability.TargetRefId)
			end
		end
	end
end

local function validateCraftingReferences(graph: CrossDomainGraph, issues: { ValidationIssue })
	local itemIds = makeSet(graph.Registry.ItemRefIds)
	local stationIds = makeSet(graph.Registry.StationRefIds)
	local unlockIds = makeSet(graph.Registry.UnlockRefIds)

	for _, recipe in graph.Recipes do
		for _, ingredient in recipe.IngredientRefs do
			if itemIds[ingredient.ItemRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownItemRef, "Crafting", recipe.RecipeId, ingredient.ItemRefId)
			end
		end
		for _, output in recipe.OutputRefs do
			if itemIds[output.ItemRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownItemRef, "Crafting", recipe.RecipeId, output.ItemRefId)
			end
		end
		if recipe.RequiredStationRefId ~= nil and stationIds[recipe.RequiredStationRefId] ~= true then
			addIssue(
				issues,
				Validator.IssueCodes.UnknownStationRef,
				"Crafting",
				recipe.RecipeId,
				recipe.RequiredStationRefId
			)
		end
		if recipe.RequiredUnlockId ~= nil and unlockIds[recipe.RequiredUnlockId] ~= true then
			addIssue(
				issues,
				Validator.IssueCodes.UnknownUnlockRef,
				"Crafting",
				recipe.RecipeId,
				recipe.RequiredUnlockId
			)
		end
	end
end

local function validateGatheringReferences(graph: CrossDomainGraph, issues: { ValidationIssue })
	local resourceIds = makeSet(graph.Registry.ResourceRefIds)
	local toolIds = makeSet(graph.Registry.ToolRefIds)
	local respawnPolicyIds = makeSet(graph.Registry.RespawnPolicyRefIds)
	local rewardIds = makeSet(graph.Registry.RewardRefIds)

	for _, node in graph.ResourceNodes do
		if resourceIds[node.ResourceRefId] ~= true then
			addIssue(issues, Validator.IssueCodes.UnknownResourceRef, "Gathering", node.NodeId, node.ResourceRefId)
		end
		if node.RequiredToolRefId ~= nil and toolIds[node.RequiredToolRefId] ~= true then
			addIssue(issues, Validator.IssueCodes.UnknownToolRef, "Gathering", node.NodeId, node.RequiredToolRefId)
		end
		if respawnPolicyIds[node.RespawnPolicyRefId] ~= true then
			addIssue(
				issues,
				Validator.IssueCodes.UnknownRespawnPolicyRef,
				"Gathering",
				node.NodeId,
				node.RespawnPolicyRefId
			)
		end
		for _, reward in node.RewardRefs do
			if rewardIds[reward.RewardRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownRewardRef, "Gathering", node.NodeId, reward.RewardRefId)
			end
		end
	end
end

local function validateVendorReferences(graph: CrossDomainGraph, issues: { ValidationIssue })
	local catalogsById = {}
	for _, catalog in graph.Catalogs do
		catalogsById[catalog.CatalogId] = catalog
	end
	local itemIds = makeSet(graph.Registry.ItemRefIds)
	local currencyIds = makeSet(graph.Registry.CurrencyRefIds)

	for _, vendor in graph.Vendors do
		for _, catalogRefId in vendor.CatalogRefIds do
			local catalog = catalogsById[catalogRefId]
			if catalog == nil then
				addIssue(
					issues,
					Validator.IssueCodes.UnknownVendorCatalogRef,
					"Vendor",
					vendor.VendorId,
					catalogRefId
				)
			elseif vendor.RuntimeEnabled and not catalog.RuntimeEnabled then
				addIssue(
					issues,
					Validator.IssueCodes.ImpossibleVendorCatalogDependency,
					"Vendor",
					vendor.VendorId,
					catalogRefId
				)
			end
		end
	end

	for _, catalog in graph.Catalogs do
		for _, entry in catalog.Entries do
			if itemIds[entry.ItemRefId] ~= true then
				addIssue(issues, Validator.IssueCodes.UnknownItemRef, "VendorCatalog", catalog.CatalogId, entry.ItemRefId)
			end
			if currencyIds[entry.Price.CurrencyRefId] ~= true then
				addIssue(
					issues,
					Validator.IssueCodes.UnknownCurrencyRef,
					"VendorCatalog",
					catalog.CatalogId,
					entry.Price.CurrencyRefId
				)
			end
		end
	end
end

function Validator.validate(graph: CrossDomainGraph): ValidationResult
	local issues = {}

	validateQuestReferences(graph, issues)
	validateQuestCycles(graph, issues)
	validateNPCReferences(graph, issues)
	validateCraftingReferences(graph, issues)
	validateGatheringReferences(graph, issues)
	validateVendorReferences(graph, issues)
	sortIssues(issues)

	return table.freeze({
		Valid = #issues == 0,
		Issues = table.freeze(issues),
	})
end

assert(Validator.RuntimeConsumptionActive == false, "BA-025 must remain source/static validation")
assert(Validator.MutationIntentAllowed == false, "BA-025 cannot authorize domain mutation")

return table.freeze(Validator)
