--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local modifierConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunModifierConfig.luau"), {
	injectGlobals = true,
})()
local secretConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SecretBranchConfig.luau"), {
	injectGlobals = true,
})()
local objectiveConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/OptionalObjectiveConfig.luau"), {
	injectGlobals = true,
})()
local fixtures =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationReplayFixtures.luau"), {
		injectGlobals = true,
	})()

local function nextValue(value: number): number
	return (value * 48_271) % 2_147_483_647
end

local function rollAt(seed: number, step: number): number
	local value = seed
	for _ = 1, step do
		value = nextValue(value)
	end
	return (value % 100) + 1
end

local function modifierIndex(seed: number): number
	local value = seed
	for _ = 1, 7 do
		value = nextValue(value)
	end
	return (value % #modifierConfig.Modifiers) + 1
end

local seen = {}
local function claim(seed: number)
	check(seen[seed] == nil, "replay fixture values must be unique")
	seen[seed] = true
end

for _, seed in fixtures.DenseContacts do
	claim(seed)
	check(rollAt(seed, 1) > secretConfig.BranchChancePercent, "dense fixture must isolate the modifier")
	check(rollAt(seed, 4) > objectiveConfig.AppearanceChancePercent, "dense fixture must isolate the modifier")
	check(rollAt(seed, 6) <= modifierConfig.AppearanceChancePercent, "dense fixture must produce a modifier")
	check(modifierConfig.Modifiers[modifierIndex(seed)].Id == "dense-contacts", "dense fixture selection drift")
end

for _, seed in fixtures.QuietApproach do
	claim(seed)
	check(rollAt(seed, 1) > secretConfig.BranchChancePercent, "quiet fixture must isolate the modifier")
	check(rollAt(seed, 4) > objectiveConfig.AppearanceChancePercent, "quiet fixture must isolate the modifier")
	check(rollAt(seed, 6) <= modifierConfig.AppearanceChancePercent, "quiet fixture must produce a modifier")
	check(modifierConfig.Modifiers[modifierIndex(seed)].Id == "quiet-approach", "quiet fixture selection drift")
end

for _, seed in fixtures.NoVariation do
	claim(seed)
	check(rollAt(seed, 1) > secretConfig.BranchChancePercent, "baseline fixture must suppress secret branch")
	check(rollAt(seed, 4) > objectiveConfig.AppearanceChancePercent, "baseline fixture must suppress objective")
	check(rollAt(seed, 6) > modifierConfig.AppearanceChancePercent, "baseline fixture must suppress modifier")
end

check(fixtures.Version == "P06-RUN-VARIATION-REPLAY-FIXTURES-v1", "replay fixture version drift")
print("Patch 0.6 run variation replay fixtures passed")
