--!strict

-- RPG-0107 deterministic relic offer generation, weapon compatibility filtering,
-- equipped-relic exclusion, and fail-closed handling of malformed facts.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local R_CONTRACTS_TOKEN = {}
local R_CONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		RPG = { RunRpgContracts = R_CONTRACTS_TOKEN },
		Config = { RunRpgConfig = R_CONFIG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RelicRewardResolver.luau"), {
	debugName = "RelicRewardResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "resolver may only require replicated declarations")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == R_CONTRACTS_TOKEN then
				return contracts
			elseif token == R_CONFIG_TOKEN then
				return config
			end
			error("unexpected RelicRewardResolver dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local RelicIds = contracts.RelicIds
local CompatibilityIds = contracts.RelicCompatibilityIds
local choiceCount = config.Limits.relicChoiceCountPerReward

local function isDistinctKnownRelicPair(choices: { string }): boolean
	if #choices ~= choiceCount then
		return false
	end
	local seen = {}
	for _, relicId in choices do
		if not contracts.isKnownRelicId(relicId) or seen[relicId] then
			return false
		end
		seen[relicId] = true
	end
	return true
end

-- Baseline: a plain loadout with no special weapon tag still yields two distinct
-- known relics for every reward sequence.
for sequence = 1, 100 do
	local choices = resolver.generateChoices(1, sequence, {}, {})
	assertThat(isDistinctKnownRelicPair(choices), "empty-loadout offer " .. sequence .. " must be two distinct relics")
end

-- Determinism: identical facts reproduce the identical offer (reconnect safety).
local firstOffer = resolver.generateChoices(3, 9, {}, {})
local repeatOffer = resolver.generateChoices(3, 9, {}, {})
assertThat(
	firstOffer[1] == repeatOffer[1] and firstOffer[2] == repeatOffer[2],
	"identical reward facts must reproduce the identical offer"
)

-- Weapon-gated relics never appear without the matching loadout tag.
local weaponGatedRelicIds = {
	[RelicIds.BreachDoctrine] = true,
	[RelicIds.LongwatchDoctrine] = true,
	[RelicIds.SuppressionEngine] = true,
}
for sequence = 1, 120 do
	for _, relicId in resolver.generateChoices(1, sequence, {}, {}) do
		assertThat(not weaponGatedRelicIds[relicId], "weapon-gated relic offered without a compatible loadout")
	end
end

-- A shotgun loadout opens Breach Doctrine to the offer pool.
local sawBreachDoctrine = false
for sequence = 1, 120 do
	for _, relicId in resolver.generateChoices(1, sequence, { [CompatibilityIds.Shotgun] = true }, {}) do
		if relicId == RelicIds.BreachDoctrine then
			sawBreachDoctrine = true
		end
	end
end
assertThat(sawBreachDoctrine, "a shotgun loadout must make Breach Doctrine offerable")

-- Cooperative relics are never weapon-gated.
local sawGuardianSignal = false
for sequence = 1, 120 do
	for _, relicId in resolver.generateChoices(1, sequence, {}, {}) do
		if relicId == RelicIds.GuardianSignal then
			sawGuardianSignal = true
		end
	end
end
assertThat(sawGuardianSignal, "cooperative relics must be offerable regardless of weapon")

-- Equipped relics are excluded from future offers (non-stackable).
for sequence = 1, 120 do
	for _, relicId in resolver.generateChoices(1, sequence, {}, { [RelicIds.BloodBattery] = true }) do
		assertThat(relicId ~= RelicIds.BloodBattery, "an equipped relic must not be offered again")
	end
end

-- Fail closed on malformed facts.
assertThat(#resolver.generateChoices(0, 1, {}, {}) == 0, "non-positive generation must produce no offer")
assertThat(#resolver.generateChoices(1, 0, {}, {}) == 0, "non-positive sequence must produce no offer")
assertThat(#resolver.generateChoices(1.5, 1, {}, {}) == 0, "fractional generation must produce no offer")
assertThat(#resolver.generateChoices(1, 1, "not-a-table" :: any, {}) == 0, "non-table loadout must produce no offer")
assertThat(#resolver.generateChoices(1, 1, { [5] = true } :: any, {}) == 0, "non-string loadout key must fail closed")
assertThat(
	#resolver.generateChoices(1, 1, { [CompatibilityIds.Shotgun] = "yes" } :: any, {}) == 0,
	"non-boolean loadout flag must fail closed"
)

print("RelicRewardResolver: deterministic, compatibility-filtered, exclusion-safe, and fail-closed")
