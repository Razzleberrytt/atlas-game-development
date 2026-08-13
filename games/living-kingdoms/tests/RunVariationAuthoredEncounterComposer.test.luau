--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "run variation authored encounter composer assertion failed", 2)
	end
end

local CONTRACTS_TOKEN = {}
local contracts = {
	EncounterSlotIds = {
		None = "None",
		LightPatrol = "LightPatrol",
		StandardSquad = "StandardSquad",
		EliteGuard = "EliteGuard",
		BossEncounter = "BossEncounter",
	},
}

local policy = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationEncounterConsequencePolicy.luau"),
	{
		debugName = "RunVariationEncounterConsequencePolicy",
		environment = {
			script = { Parent = { RoomAssemblyContracts = CONTRACTS_TOKEN } },
			require = function(token: unknown): any
				assert(token == CONTRACTS_TOKEN, "unexpected consequence policy dependency")
				return contracts
			end,
		},
		injectGlobals = true,
	}
)()

local applicator = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationAuthoredWaveApplicator.luau"),
	{
		debugName = "RunVariationAuthoredWaveApplicator",
		injectGlobals = true,
	}
)()

local POLICY_TOKEN = {}
local APPLICATOR_TOKEN = {}
local composer = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationAuthoredEncounterComposer.luau"),
	{
		debugName = "RunVariationAuthoredEncounterComposer",
		environment = {
			script = {
				Parent = {
					RunVariationEncounterConsequencePolicy = POLICY_TOKEN,
					RunVariationAuthoredWaveApplicator = APPLICATOR_TOKEN,
				},
			},
			require = function(token: unknown): any
				if token == POLICY_TOKEN then
					return policy
			elseif token == APPLICATOR_TOKEN then
					return applicator
			end
				error("unexpected encounter composer dependency")
			end,
		},
		injectGlobals = true,
	}
)()

local function record(
	encounterSlotId: string,
	baseIntensity: number,
	effectiveIntensity: number,
	modifierApplied: boolean,
	nodeIndex: number?
): any
	return {
		NodeIndex = nodeIndex or 3,
		RoomId = "warden-barracks",
		EncounterSlotId = encounterSlotId,
		BaseIntensity = baseIntensity,
		EffectiveIntensity = effectiveIntensity,
		ModifierApplied = modifierApplied,
	}
end

local function twoWaveEncounter(): any
	return {
		RoomId = "warden-barracks",
		EncounterSlotId = "StandardSquad",
		EncounterIntensity = 2,
		SpawnSourceId = "AuthoredWave",
		RewardSourceId = "Elite",
		Waves = {
			{
				Units = {
					{ ArchetypeId = "walker", Count = 2, HordeRoleId = "basic" },
				},
			},
			{
				Units = {
					{ ArchetypeId = "walker", Count = 2, HordeRoleId = "runner" },
					{ ArchetypeId = "spitter", Count = 1 },
				},
			},
		},
	}
end

local source = twoWaveEncounter()
local unchanged = composer.compose(10, record("StandardSquad", 2, 2, false), source)
assert(unchanged.UnitCountDelta == 0, "unchanged pressure must preserve the encounter unit budget")
assert(unchanged.SelectedWaveIndex == nil, "zero encounter delta must not select a wave")
assert(unchanged.OriginalUnitCount == 5 and unchanged.AppliedUnitCount == 5, "zero delta must preserve total count")
assert(unchanged.SpawnSourceId == source.SpawnSourceId, "composer must preserve authored spawn authority")
assert(unchanged.RewardSourceId == source.RewardSourceId, "composer must preserve authored reward authority")
assert(unchanged.Waves[1] ~= source.Waves[1], "composer must clone authored wave records")
assert(unchanged.Waves[1].Units ~= source.Waves[1].Units, "composer must clone authored unit collections")
assert(table.isfrozen(unchanged), "composed encounter must be immutable")
assert(table.isfrozen(unchanged.Waves), "composed encounter waves must be immutable")
assert(table.isfrozen(unchanged.Waves[1]), "composed wave records must be immutable")
assert(table.isfrozen(unchanged.Waves[1].Units[1]), "composed authored units must be immutable")

local denser = composer.compose(10, record("StandardSquad", 2, 3, true), source)
assert(denser.SelectedWaveIndex == 2, "seed 10 and node 3 must deterministically select the second wave")
assert(denser.OriginalUnitCount == 5 and denser.AppliedUnitCount == 6, "denser encounter must add exactly one total unit")
assert(denser.Waves[1].VariationApplication.UnitCountDelta == 0, "unselected wave must not receive the encounter delta")
assert(denser.Waves[2].VariationApplication.UnitCountDelta == 1, "selected wave must receive the encounter delta")
assert(denser.Waves[1].Units[1].Count == 2, "unselected authored wave must remain count-stable")
assert(denser.Waves[2].Units[2].Count == 2, "selected authored group must receive exactly one added unit")

local repeated = composer.compose(10, record("StandardSquad", 2, 3, true), source)
assert(repeated.SelectedWaveIndex == denser.SelectedWaveIndex, "same seed and node must reproduce wave selection")
assert(repeated.CompositionIdentity == denser.CompositionIdentity, "same inputs must reproduce composition identity")

local alternateSeed = composer.compose(11, record("StandardSquad", 2, 3, true), source)
assert(alternateSeed.SelectedWaveIndex == 1, "adjacent seed must exercise the alternate wave in this fixture")
assert(alternateSeed.AppliedUnitCount == 6, "alternate wave selection must preserve the bounded total delta")
assert(alternateSeed.Waves[1].Units[1].Count == 3, "alternate selected wave must receive the added authored unit")
assert(alternateSeed.Waves[2].Units[1].Count == 2, "alternate unselected wave must stay unchanged")

local quieter = composer.compose(10, record("StandardSquad", 2, 1, true), source)
assert(quieter.SelectedWaveIndex == 2, "quieter encounter must use the same deterministic wave selection")
assert(quieter.OriginalUnitCount == 5 and quieter.AppliedUnitCount == 4, "quieter encounter must remove exactly one total unit")
assert(#quieter.Waves[2].Units == 1, "removing a singleton selected group may remove that group from the wave")
assert(quieter.Waves[2].Units[1].Count == 2, "remaining selected-wave authored group must stay unchanged")

assert(source.Waves[1].Units[1].Count == 2, "composer must not mutate the first source wave")
assert(source.Waves[2].Units[2].Count == 1, "composer must not mutate the second source wave")

local contentVariant = twoWaveEncounter()
contentVariant.Waves[2].Units[2].ArchetypeId = "different-special"
local variant = composer.compose(10, record("StandardSquad", 2, 3, true), contentVariant)
assert(variant.CompositionIdentity ~= denser.CompositionIdentity, "composition identity must include authored unit identity")

local bossEncounter = {
	RoomId = "warden-barracks",
	EncounterSlotId = "BossEncounter",
	EncounterIntensity = 3,
	SpawnSourceId = "AuthoredWave",
	RewardSourceId = "Boss",
	Waves = {
		{ Units = { { ArchetypeId = "boss", Count = 1 } } },
	},
}
local boss = composer.compose(17, record("BossEncounter", 3, 3, false), bossEncounter)
assert(boss.UnitCountDelta == 0 and boss.AppliedUnitCount == 1, "boss composition must remain untouched")
assert(boss.SelectedWaveIndex == nil, "boss composition must not select a variation wave")
assert(boss.RewardSourceId == "Boss", "boss reward source must remain authored")

local emptyEncounter = {
	RoomId = "warden-barracks",
	EncounterSlotId = "None",
	EncounterIntensity = 0,
	Waves = {},
}
local empty = composer.compose(5, record("None", 0, 0, false), emptyEncounter)
assert(empty.OriginalUnitCount == 0 and empty.AppliedUnitCount == 0, "non-encounter composition must remain empty")
assert(#empty.Waves == 0 and empty.SelectedWaveIndex == nil, "non-encounter composition must not invent waves")

local function mustReject(callback: () -> (), message: string)
	local ok = pcall(callback)
	assert(not ok, message)
end

mustReject(function()
	local mismatch = twoWaveEncounter()
	mismatch.RoomId = "different-room"
	composer.compose(10, record("StandardSquad", 2, 3, true), mismatch)
end, "room identity mismatch must fail closed")

mustReject(function()
	local mismatch = twoWaveEncounter()
	mismatch.EncounterSlotId = "EliteGuard"
	composer.compose(10, record("StandardSquad", 2, 3, true), mismatch)
end, "encounter slot mismatch must fail closed")

mustReject(function()
	local mismatch = twoWaveEncounter()
	mismatch.EncounterIntensity = 1
	composer.compose(10, record("StandardSquad", 2, 3, true), mismatch)
end, "authored base-intensity mismatch must fail closed")

mustReject(function()
	local noWaves = twoWaveEncounter()
	noWaves.Waves = {}
	composer.compose(10, record("StandardSquad", 2, 3, true), noWaves)
end, "non-zero variation cannot target an encounter without an authored wave")

local fragileEncounter = {
	RoomId = "warden-barracks",
	EncounterSlotId = "StandardSquad",
	EncounterIntensity = 2,
	SpawnSourceId = "AuthoredWave",
	Waves = {
		{ Units = { { ArchetypeId = "walker", Count = 2, HordeRoleId = "basic" } } },
		{ Units = { { ArchetypeId = "walker", Count = 1, HordeRoleId = "runner" } } },
	},
}
mustReject(function()
	composer.compose(10, record("StandardSquad", 2, 1, true), fragileEncounter)
end, "selected wave minimum-retention failure must fail closed rather than silently retarget variation")

print("Run variation authored encounter composer fixture passed")
