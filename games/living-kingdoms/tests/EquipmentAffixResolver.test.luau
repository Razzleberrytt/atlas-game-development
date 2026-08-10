--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixContracts.luau"), {
	debugName = "EquipmentAffixContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau"), {
	debugName = "EquipmentAffixConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Equipment = { EquipmentAffixContracts = CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected affix-config dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixResolver.luau"), {
	debugName = "EquipmentAffixResolver",
	environment = {
		script = { Parent = { EquipmentAffixContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected affix-resolver dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local function context(definitionId: string, slot: string, rarity: string, tags: { string }, seed: number)
	return {
		DefinitionId = definitionId,
		Slot = slot,
		Rarity = rarity,
		Tags = tags,
		Seed = seed,
	}
end

local function compatibleIds(slot: string, tags: { string }): { [string]: boolean }
	local tagSet = {}
	for _, tag in tags do
		tagSet[tag] = true
	end
	local ids = {}
	for _, definition in config.Definitions do
		local slotAllowed = false
		for _, allowedSlot in definition.AllowedSlots do
			if allowedSlot == slot then
				slotAllowed = true
				break
			end
		end
		local tagsSatisfied = true
		for _, requiredTag in definition.RequiredTags do
			if not tagSet[requiredTag] then
				tagsSatisfied = false
				break
			end
		end
		if slotAllowed and tagsSatisfied then
			ids[definition.Id] = true
		end
	end
	return ids
end

assertThat(config.Version == "PATCH-0.3-AFFIX-v2", "affix config version must be stable")
assertThat(#config.Definitions == 16, "v2 should expose sixteen bounded authored affixes")
assertThat(config.AffixCountByRarity.Common == 1, "common items should roll one affix")
assertThat(config.AffixCountByRarity.Uncommon == 1, "uncommon items should roll one affix")
assertThat(config.AffixCountByRarity.Rare == 2, "rare items should roll two affixes")

local rifleContext = context("frontier-rifle", "Primary", "Rare", { "rifle", "precision" }, 34567)
local first = resolver.resolve(config, rifleContext)
local repeated = resolver.resolve(config, rifleContext)
assertThat(first.Accepted, "valid rifle affixes must resolve")
assertThat(repeated.Accepted, "repeated valid context must resolve")
assertThat(first.Signature == repeated.Signature, "same context must reproduce the same affix signature")
assertThat(#first.Affixes == 2, "rare item must receive the configured number of affixes")
assertThat(first.Affixes[1].Id ~= first.Affixes[2].Id, "affix selection must not duplicate IDs")
assertThat(first.Affixes[1].Id < first.Affixes[2].Id, "affixes must use stable canonical ordering")

for index, roll in first.Affixes do
	local repeatedRoll = repeated.Affixes[index]
	assertThat(roll.Id == repeatedRoll.Id, "same context changed affix identity")
	assertThat(roll.Value == repeatedRoll.Value, "same context changed affix magnitude")
end

local signatures = {}
for seed = 1, 128 do
	local result =
		resolver.resolve(config, context("frontier-rifle", "Primary", "Rare", { "rifle", "precision" }, seed))
	assertThat(result.Accepted, "valid seed must resolve")
	signatures[result.Signature] = true
end
local distinctSignatures = 0
for _ in signatures do
	distinctSignatures += 1
end
assertThat(distinctSignatures >= 8, "expanded rifle pool should produce meaningful deterministic variety")

local rifleIds = compatibleIds("Primary", { "rifle", "precision" })
assertThat(rifleIds.deadeye and rifleIds["measured-cycle"], "precision rifle must expose both role affixes")
assertThat(not rifleIds.breacher and not rifleIds["slam-loader"], "precision rifle must exclude close-range affixes")

local shotgunIds = compatibleIds("Primary", { "shotgun", "close-range" })
assertThat(shotgunIds.breacher and shotgunIds["slam-loader"], "shotgun must expose both close-range affixes")
assertThat(not shotgunIds.deadeye and not shotgunIds["measured-cycle"], "shotgun must exclude precision affixes")
local shotgun =
	resolver.resolve(config, context("breach-shotgun", "Primary", "Rare", { "shotgun", "close-range" }, 777))
assertThat(shotgun.Accepted and #shotgun.Affixes == 2, "shotgun must have a sufficient compatible pool")
for _, roll in shotgun.Affixes do
	assertThat(roll.Id ~= "deadeye", "precision-only affix must not appear on shotgun")
end

local sidearmIds = compatibleIds("Secondary", { "sidearm", "reliable" })
assertThat(sidearmIds.keen and sidearmIds["swift-loader"], "sidearm keeps broad weapon rolls")
assertThat(sidearmIds["steady-hand"] and sidearmIds["field-service"], "sidearm gains two role-specific rolls")
assertThat(not sidearmIds.deadeye and not sidearmIds.breacher, "sidearm cannot roll primary-only identities")

local armorIds = compatibleIds("Armor", { "armor", "survival" })
assertThat(armorIds.reinforced and armorIds.trailborn, "armor keeps broad defensive/traversal rolls")
assertThat(armorIds.bulwark and armorIds.pathfinder, "survival armor gains two role-specific rolls")
local armor = resolver.resolve(config, context("delver-plate", "Armor", "Rare", { "armor", "survival" }, 888))
assertThat(armor.Accepted and #armor.Affixes == 2, "armor rare must resolve two compatible affixes")
for _, roll in armor.Affixes do
	assertThat(roll.EffectId ~= contracts.EffectIds.DamagePercent, "weapon damage affixes must not appear on armor")
end

local relicIds = compatibleIds("Relic", { "relic", "ability" })
assertThat(relicIds.resonant and relicIds.focused, "relic keeps broad ability rolls")
assertThat(relicIds.quickening and relicIds.overcharged, "ability relic gains two role-specific rolls")
local relic = resolver.resolve(config, context("keeper-sigil", "Relic", "Rare", { "relic", "ability" }, 999))
assertThat(relic.Accepted and #relic.Affixes == 2, "relic rare must resolve two compatible affixes")

local malformedContext = resolver.resolve(config, { DefinitionId = "bad" })
assertThat(not malformedContext.Accepted, "malformed context must fail closed")
assertThat(malformedContext.ReasonId == contracts.ReasonIds.InvalidContext, "malformed context reason must be stable")

local duplicateConfig = {
	Version = "bad",
	AffixCountByRarity = { Rare = 1 },
	Definitions = {
		{
			Id = "duplicate",
			Version = "1",
			DisplayName = "One",
			EffectId = contracts.EffectIds.DamagePercent,
			MinimumValue = 1,
			MaximumValue = 1,
			AllowedSlots = { "Primary" },
			RequiredTags = {},
		},
		{
			Id = "duplicate",
			Version = "1",
			DisplayName = "Two",
			EffectId = contracts.EffectIds.DamagePercent,
			MinimumValue = 1,
			MaximumValue = 1,
			AllowedSlots = { "Primary" },
			RequiredTags = {},
		},
	},
}
local duplicateResult = resolver.resolve(duplicateConfig, rifleContext)
assertThat(not duplicateResult.Accepted, "duplicate authored affix IDs must fail closed")
assertThat(duplicateResult.ReasonId == contracts.ReasonIds.InvalidConfig, "invalid config reason must be stable")

local insufficientConfig = {
	Version = "insufficient",
	AffixCountByRarity = { Rare = 2 },
	Definitions = {
		{
			Id = "only-one",
			Version = "1",
			DisplayName = "Only One",
			EffectId = contracts.EffectIds.DamagePercent,
			MinimumValue = 1,
			MaximumValue = 1,
			AllowedSlots = { "Primary" },
			RequiredTags = {},
		},
	},
}
local insufficient = resolver.resolve(insufficientConfig, rifleContext)
assertThat(not insufficient.Accepted, "insufficient compatible pool must fail closed")
assertThat(
	insufficient.ReasonId == contracts.ReasonIds.InsufficientEligibleAffixes,
	"insufficient pool reason must be stable"
)
