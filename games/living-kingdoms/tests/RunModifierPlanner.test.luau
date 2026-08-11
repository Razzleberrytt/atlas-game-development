--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.6 run modifier assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunModifierConfig.luau"), {
	debugName = "RunModifierConfig",
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local planner = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunModifierPlanner.luau"), {
	debugName = "RunModifierPlanner",
	environment = {
		script = { Parent = { Parent = { Config = { RunModifierConfig = CONFIG_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected run modifier planner dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local function makePlan(seed: number)
	return {
		Seed = seed,
		Nodes = {
			{ Index = 1, RoomId = "entry", EncounterSlotId = "None", EncounterIntensity = 0 },
			{ Index = 2, RoomId = "patrol", EncounterSlotId = "LightPatrol", EncounterIntensity = 2 },
			{ Index = 3, RoomId = "combat-a", EncounterSlotId = "StandardSquad", EncounterIntensity = 2 },
			{ Index = 4, RoomId = "combat-b", EncounterSlotId = "StandardSquad", EncounterIntensity = 3 },
			{ Index = 5, RoomId = "elite", EncounterSlotId = "EliteGuard", EncounterIntensity = 2 },
			{ Index = 6, RoomId = "boss", EncounterSlotId = "BossEncounter", EncounterIntensity = 3 },
		},
	}
end

local modifierById = {}
for _, modifier in config.Modifiers do
	modifierById[modifier.Id] = modifier
end

local sawNoModifier = false
local seenModifierIds = {}
local representativePlan = nil
local representativeSeed = nil
for seed = 1, 2000 do
	local plan = planner.plan(makePlan(seed))
	if plan == nil then
		sawNoModifier = true
	else
		seenModifierIds[plan.ModifierId] = true
		if representativePlan == nil and #plan.IntensityOverrides > 0 then
			representativePlan = plan
			representativeSeed = seed
		end
	end
end

assert(sawNoModifier, "appearance chance must preserve runs with no modifier")
for _, modifier in config.Modifiers do
	assert(seenModifierIds[modifier.Id] == true, "bounded seed range must exercise every curated modifier")
end
assert(representativePlan ~= nil and representativeSeed ~= nil, "fixture requires one effective modifier plan")

local repeated = planner.plan(makePlan(representativeSeed :: number))
assert(repeated ~= nil, "same seed should reproduce the modifier")
assert(repeated.PlanIdentity == representativePlan.PlanIdentity, "same seed must reproduce modifier identity")
assert(repeated.ModifierId == representativePlan.ModifierId, "same seed must reproduce modifier choice")
assert(repeated.ConfigVersion == config.Version, "modifier plan must record config version")
assert(
	string.find(repeated.PlanIdentity, `seed={representativeSeed}`, 1, true) ~= nil,
	"modifier identity must include run seed"
)

local definition = modifierById[repeated.ModifierId]
assert(definition ~= nil, "planned modifier must resolve to config")
for _, override in repeated.IntensityOverrides do
	assert(override.ModifiedIntensity >= config.MinimumEncounterIntensity, "modifier intensity must respect minimum")
	assert(override.ModifiedIntensity <= config.MaximumEncounterIntensity, "modifier intensity must respect maximum")
	assert(definition.EligibleEncounterSlots[override.EncounterSlotId] == true, "override must target eligible slot")
	assert(
		override.ModifiedIntensity == math.clamp(
			override.BaseIntensity + definition.EncounterIntensityDelta,
			config.MinimumEncounterIntensity,
			config.MaximumEncounterIntensity
		),
		"override must apply exactly one bounded authored intensity delta"
	)
	assert(
		string.find(
			repeated.PlanIdentity,
			`{override.NodeIndex}:{override.RoomId}:{override.BaseIntensity}>{override.ModifiedIntensity}`,
			1,
			true
		) ~= nil,
		"modifier identity must record every intensity override"
	)
end

local original = makePlan(representativeSeed :: number)
local before = {}
for index, node in original.Nodes do
	before[index] = node.EncounterIntensity
end
planner.plan(original)
for index, node in original.Nodes do
	assert(node.EncounterIntensity == before[index], "modifier planning must not mutate room-plan intensity")
end

local bossOnly = {
	Seed = 7,
	Nodes = {
		{ Index = 1, RoomId = "boss", EncounterSlotId = "BossEncounter", EncounterIntensity = 3 },
	},
}
for seed = 1, 100 do
	bossOnly.Seed = seed
	local plan = planner.plan(bossOnly)
	if plan ~= nil then
		assert(#plan.IntensityOverrides == 0, "run modifiers must not alter boss encounter authority")
	end
end

print("Patch 0.6 RunModifierPlanner fixture passed")
