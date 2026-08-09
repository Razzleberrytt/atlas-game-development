--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-025 cross-domain dependency assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Validation/CrossDomainDependencyValidator.luau"
local source = fs.readFile(sourcePath)
local Validator = luau.load(source, {
	debugName = "CrossDomainDependencyValidator",
	injectGlobals = true,
})()

local function makeValidGraph()
	return {
		Quests = {
			{
				QuestId = "quest.fixture.intro",
				PrerequisiteQuestIds = {},
				Objectives = {
					{ ProgressSourceRef = "progress.fixture.intro" },
				},
				RewardRefs = {
					{
						RewardRefId = "reward.fixture.intro",
						RewardAuthorityOwnerId = "reward-owner.fixture.quest",
					},
				},
				RuntimeEnabled = true,
			},
			{
				QuestId = "quest.fixture.followup",
				PrerequisiteQuestIds = { "quest.fixture.intro" },
				Objectives = {
					{ ProgressSourceRef = "progress.fixture.followup" },
				},
				RewardRefs = {},
				RuntimeEnabled = true,
			},
		},
		NPCs = {
			{
				NPCId = "npc.fixture.guide",
				Capabilities = {
					{ TargetRefId = "target.fixture.quest-board" },
				},
			},
		},
		Recipes = {
			{
				RecipeId = "recipe.fixture.tool",
				IngredientRefs = {
					{ ItemRefId = "item.fixture.scrap" },
				},
				OutputRefs = {
					{ ItemRefId = "item.fixture.tool" },
				},
				RequiredStationRefId = "station.fixture.crafting",
				RequiredUnlockId = "unlock.fixture.tool",
			},
		},
		ResourceNodes = {
			{
				NodeId = "node.fixture.ore",
				ResourceRefId = "resource.fixture.ore",
				RequiredToolRefId = "item.fixture.tool",
				RespawnPolicyRefId = "respawn.fixture.standard",
				RewardRefs = {
					{ RewardRefId = "reward.fixture.ore" },
				},
			},
		},
		Vendors = {
			{
				VendorId = "vendor.fixture.general",
				CatalogRefIds = { "catalog.fixture.general" },
				RuntimeEnabled = true,
			},
		},
		Catalogs = {
			{
				CatalogId = "catalog.fixture.general",
				Entries = {
					{
						EntryId = "entry.fixture.scrap",
						ItemRefId = "item.fixture.scrap",
						Price = { CurrencyRefId = "currency.fixture.credit" },
					},
				},
				RuntimeEnabled = true,
			},
		},
		Registry = {
			ProgressSourceRefIds = { "progress.fixture.intro", "progress.fixture.followup" },
			RewardRefIds = { "reward.fixture.intro", "reward.fixture.ore" },
			RewardAuthorityOwnerIds = { "reward-owner.fixture.quest" },
			NPCTargetRefIds = { "target.fixture.quest-board" },
			ItemRefIds = { "item.fixture.scrap", "item.fixture.tool" },
			StationRefIds = { "station.fixture.crafting" },
			UnlockRefIds = { "unlock.fixture.tool" },
			ResourceRefIds = { "resource.fixture.ore" },
			ToolRefIds = { "item.fixture.tool" },
			RespawnPolicyRefIds = { "respawn.fixture.standard" },
			CurrencyRefIds = { "currency.fixture.credit" },
		},
	}
end

local function hasIssue(result, code: string, definitionId: string?, refId: string?): boolean
	for _, issue in result.Issues do
		if
			issue.Code == code
			and (definitionId == nil or issue.DefinitionId == definitionId)
			and (refId == nil or issue.RefId == refId)
		then
			return true
		end
	end
	return false
end

assert(Validator.RuntimeConsumptionActive == false)
assert(Validator.MutationIntentAllowed == false)

local valid = Validator.validate(makeValidGraph())
assert(valid.Valid == true)
assert(#valid.Issues == 0)

local unknownRefsGraph = makeValidGraph()
unknownRefsGraph.Quests[1].PrerequisiteQuestIds = { "quest.fixture.missing" }
unknownRefsGraph.Quests[1].Objectives[1].ProgressSourceRef = "progress.fixture.missing"
unknownRefsGraph.Quests[1].RewardRefs[1].RewardRefId = "reward.fixture.missing"
unknownRefsGraph.Quests[1].RewardRefs[1].RewardAuthorityOwnerId = "reward-owner.fixture.missing"
unknownRefsGraph.NPCs[1].Capabilities[1].TargetRefId = "target.fixture.missing"
unknownRefsGraph.Recipes[1].IngredientRefs[1].ItemRefId = "item.fixture.missing"
unknownRefsGraph.Recipes[1].RequiredStationRefId = "station.fixture.missing"
unknownRefsGraph.Recipes[1].RequiredUnlockId = "unlock.fixture.missing"
unknownRefsGraph.ResourceNodes[1].ResourceRefId = "resource.fixture.missing"
unknownRefsGraph.ResourceNodes[1].RequiredToolRefId = "tool.fixture.missing"
unknownRefsGraph.ResourceNodes[1].RespawnPolicyRefId = "respawn.fixture.missing"
unknownRefsGraph.ResourceNodes[1].RewardRefs[1].RewardRefId = "reward.fixture.missing-node"
unknownRefsGraph.Vendors[1].CatalogRefIds = { "catalog.fixture.missing" }
unknownRefsGraph.Catalogs[1].Entries[1].ItemRefId = "item.fixture.missing-vendor"
unknownRefsGraph.Catalogs[1].Entries[1].Price.CurrencyRefId = "currency.fixture.missing"

local unknownRefs = Validator.validate(unknownRefsGraph)
assert(unknownRefs.Valid == false)
assert(
	hasIssue(unknownRefs, Validator.IssueCodes.UnknownQuestPrerequisite, "quest.fixture.intro", "quest.fixture.missing")
)
assert(
	hasIssue(
		unknownRefs,
		Validator.IssueCodes.UnknownProgressSourceRef,
		"quest.fixture.intro",
		"progress.fixture.missing"
	)
)
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownRewardRef, "quest.fixture.intro", "reward.fixture.missing"))
assert(
	hasIssue(
		unknownRefs,
		Validator.IssueCodes.UnknownRewardAuthorityOwner,
		"quest.fixture.intro",
		"reward-owner.fixture.missing"
	)
)
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownNPCTargetRef, "npc.fixture.guide", "target.fixture.missing"))
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownItemRef, "recipe.fixture.tool", "item.fixture.missing"))
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownStationRef, "recipe.fixture.tool", "station.fixture.missing"))
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownUnlockRef, "recipe.fixture.tool", "unlock.fixture.missing"))
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownResourceRef, "node.fixture.ore", "resource.fixture.missing"))
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownToolRef, "node.fixture.ore", "tool.fixture.missing"))
assert(
	hasIssue(unknownRefs, Validator.IssueCodes.UnknownRespawnPolicyRef, "node.fixture.ore", "respawn.fixture.missing")
)
assert(hasIssue(unknownRefs, Validator.IssueCodes.UnknownRewardRef, "node.fixture.ore", "reward.fixture.missing-node"))
assert(
	hasIssue(
		unknownRefs,
		Validator.IssueCodes.UnknownVendorCatalogRef,
		"vendor.fixture.general",
		"catalog.fixture.missing"
	)
)
assert(
	hasIssue(unknownRefs, Validator.IssueCodes.UnknownItemRef, "catalog.fixture.general", "item.fixture.missing-vendor")
)
assert(
	hasIssue(
		unknownRefs,
		Validator.IssueCodes.UnknownCurrencyRef,
		"catalog.fixture.general",
		"currency.fixture.missing"
	)
)

local cycleGraph = makeValidGraph()
cycleGraph.Quests[1].PrerequisiteQuestIds = { "quest.fixture.followup" }
local cycle = Validator.validate(cycleGraph)
assert(cycle.Valid == false)
assert(hasIssue(cycle, Validator.IssueCodes.QuestPrerequisiteCycle, "quest.fixture.intro"))
assert(hasIssue(cycle, Validator.IssueCodes.QuestPrerequisiteCycle, "quest.fixture.followup"))

local impossibleQuestGraph = makeValidGraph()
impossibleQuestGraph.Quests[1].RuntimeEnabled = false
local impossibleQuest = Validator.validate(impossibleQuestGraph)
assert(impossibleQuest.Valid == false)
assert(
	hasIssue(
		impossibleQuest,
		Validator.IssueCodes.ImpossibleQuestPrerequisite,
		"quest.fixture.followup",
		"quest.fixture.intro"
	)
)

local impossibleVendorGraph = makeValidGraph()
impossibleVendorGraph.Catalogs[1].RuntimeEnabled = false
local impossibleVendor = Validator.validate(impossibleVendorGraph)
assert(impossibleVendor.Valid == false)
assert(
	hasIssue(
		impossibleVendor,
		Validator.IssueCodes.ImpossibleVendorCatalogDependency,
		"vendor.fixture.general",
		"catalog.fixture.general"
	)
)

local deterministicGraph = makeValidGraph()
deterministicGraph.Recipes[1].RequiredUnlockId = "unlock.fixture.missing"
deterministicGraph.Recipes[1].RequiredStationRefId = "station.fixture.missing"
local deterministic = Validator.validate(deterministicGraph)
assert(#deterministic.Issues == 2)
assert(deterministic.Issues[1].Code == Validator.IssueCodes.UnknownStationRef)
assert(deterministic.Issues[2].Code == Validator.IssueCodes.UnknownUnlockRef)

-- BA-025 must remain pure/static validation with no runtime or mutation path.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)

print("BA-025 CrossDomainDependencyValidator fixture passed")
