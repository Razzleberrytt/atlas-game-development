--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "sanitized equipment comparison assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local Resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentComparisonResolver.luau"), {
	debugName = "EquipmentComparisonResolver",
	environment = {
		script = { Parent = { EquipmentRewardContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected comparison dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

-- These deliberately contain only fields disclosed by the owner inventory
-- snapshot that the comparison resolver actually needs. Reward-only GrantId,
-- RunId, Seed, and server transaction metadata are absent.
local equipped = {
	InstanceId = "owned_primary_a",
	DefinitionId = "frontier-rifle",
	Slot = contracts.SlotIds.Primary,
	Rarity = contracts.RarityIds.Uncommon,
	Power = 10,
	Affixes = {
		{ Id = "keen", Version = "1.0.0", DisplayName = "Keen", EffectId = "DamagePercent", Value = 4 },
	},
}
local candidate = {
	InstanceId = "owned_primary_b",
	DefinitionId = "breach-shotgun",
	Slot = contracts.SlotIds.Primary,
	Rarity = contracts.RarityIds.Rare,
	Power = 12,
	Affixes = {
		{
			Id = "swift-loader",
			Version = "1.0.0",
			DisplayName = "Swift Loader",
			EffectId = "ReloadSpeedPercent",
			Value = 8,
		},
	},
}

local result = Resolver.compare(candidate, equipped, nil)
assert(result.Accepted == true, "sanitized owner inventory items compare without reward-only metadata")
assert(result.Comparison.VerdictId == "Upgrade", "power/rarity facts still resolve")
assert(result.Comparison.PowerDelta == 2, "power delta is preserved")
assert(#result.Comparison.AffixDeltas == 2, "affix tradeoff reports lost and gained effects")
assert(result.Comparison.AffixDeltas[1].EffectId == "DamagePercent", "affix deltas stay sorted")
assert(result.Comparison.AffixDeltas[1].Delta == -4, "lost equipped damage is explicit")
assert(result.Comparison.AffixDeltas[2].EffectId == "ReloadSpeedPercent", "gained effect is explicit")
assert(result.Comparison.AffixDeltas[2].Delta == 8, "gained reload speed is explicit")

local byId = {
	[equipped.InstanceId] = equipped,
	[candidate.InstanceId] = candidate,
}
local againstEquipped = Resolver.compareAgainstEquipped(candidate, { Primary = equipped.InstanceId }, byId, nil)
assert(againstEquipped.Accepted == true, "sanitized owner map uses the same equipped comparison path")
assert(
	againstEquipped.Comparison.IncumbentInstanceId == equipped.InstanceId,
	"equipped sanitized item is the canonical baseline"
)

print("EquipmentComparisonSanitizedView fixture passed")
