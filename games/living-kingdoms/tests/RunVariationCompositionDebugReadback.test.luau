--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(v: unknown, m: string)
	if not v then
		error(m, 2)
	end
end

local CONFIG, PLANNER, VIEW, COMPOSER, SCHEMA = {}, {}, {}, {}, {}
local authored = {
	entry = { SpawnSourceId = nil, RewardSourceId = nil, Waves = {} },
	combat = {
		SpawnSourceId = "AuthoredWave",
		RewardSourceId = "Elite",
		Waves = { { Units = { { ArchetypeId = "walker", Count = 2 }, { ArchetypeId = "spitter", Count = 1 } } } },
	},
	boss = {
		SpawnSourceId = "AuthoredWave",
		RewardSourceId = "Boss",
		Waves = { { Units = { { ArchetypeId = "boss", Count = 1 } } } },
	},
}
local planner = {
	plan = function(plan: any): any
		return {
			VariationIdentity = "variation|" .. plan.PlanIdentity,
			SecretBranch = {},
			OptionalObjective = {},
			RunModifier = { ModifierId = "dense", PlanIdentity = "modifier|dense" },
		}
	end,
}
local view = {
	build = function(): any
		return { Records = { { RoomId = "entry" }, { RoomId = "combat" }, { RoomId = "boss" } } }
	end,
}
local composer = {
	compose = function(_seed: number, record: any): any
		if record.RoomId == "entry" then
			return {
				NodeIndex = 1,
				RoomId = "entry",
				EncounterSlotId = "None",
				BaseIntensity = 0,
				EffectiveIntensity = 0,
				ModifierApplied = false,
				UnitCountDelta = 0,
				MinimumRetainedUnits = 0,
				SelectedWaveIndex = nil,
				OriginalUnitCount = 0,
				AppliedUnitCount = 0,
				SpawnSourceId = nil,
				RewardSourceId = nil,
				CompositionIdentity = "composition|entry",
				Waves = {},
			}
		elseif record.RoomId == "boss" then
			return {
				NodeIndex = 3,
				RoomId = "boss",
				EncounterSlotId = "BossEncounter",
				BaseIntensity = 3,
				EffectiveIntensity = 3,
				ModifierApplied = false,
				UnitCountDelta = 0,
				MinimumRetainedUnits = 1,
				SelectedWaveIndex = nil,
				OriginalUnitCount = 1,
				AppliedUnitCount = 1,
				SpawnSourceId = "AuthoredWave",
				RewardSourceId = "Boss",
				CompositionIdentity = "composition|boss",
				Waves = {
					{
						Units = { { ArchetypeId = "boss", Count = 1 } },
						VariationApplication = {
							ApplicationIdentity = "wave|boss|1",
							UnitCountDelta = 0,
							OriginalUnitCount = 1,
							AppliedUnitCount = 1,
							SelectedUnitIndex = nil,
							SelectedArchetypeId = nil,
						},
					},
				},
			}
		end
		return {
			NodeIndex = 2,
			RoomId = "combat",
			EncounterSlotId = "StandardSquad",
			BaseIntensity = 2,
			EffectiveIntensity = 3,
			ModifierApplied = true,
			UnitCountDelta = 1,
			MinimumRetainedUnits = 1,
			SelectedWaveIndex = 1,
			OriginalUnitCount = 3,
			AppliedUnitCount = 4,
			SpawnSourceId = "AuthoredWave",
			RewardSourceId = "Elite",
			CompositionIdentity = "composition|combat",
			Waves = {
				{
					Units = { { ArchetypeId = "walker", Count = 3 }, { ArchetypeId = "spitter", Count = 1 } },
					VariationApplication = {
						ApplicationIdentity = "wave|combat|1",
						UnitCountDelta = 1,
						OriginalUnitCount = 3,
						AppliedUnitCount = 4,
						SelectedUnitIndex = 1,
						SelectedArchetypeId = "walker",
					},
				},
			},
		}
	end,
}
local schemaSource = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationDebugSchema.luau")
local schema = luau.load(schemaSource, { injectGlobals = true })()
local readbackSource =
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationCompositionDebugReadback.luau")
local readback = luau.load(readbackSource, {
	environment = {
		script = {
			Parent = {
				Parent = { Config = { FirstDungeonContentConfig = CONFIG } },
				RunVariationPlanner = PLANNER,
				RunVariationEncounterView = VIEW,
				RunVariationAuthoredEncounterComposer = COMPOSER,
				RunVariationDebugSchema = SCHEMA,
			},
		},
		require = function(token: unknown): any
			if token == CONFIG then
				return { Encounters = authored }
			elseif token == PLANNER then
				return planner
			elseif token == VIEW then
				return view
			elseif token == COMPOSER then
				return composer
			elseif token == SCHEMA then
				return schema
			end
			error("unexpected dependency")
		end,
	},
	injectGlobals = true,
})()
local plan = {
	Seed = 17,
	PlanIdentity = "room-plan|17",
	Nodes = {
		{ RoomId = "entry", EncounterSlotId = "None", EncounterIntensity = 0 },
		{ RoomId = "combat", EncounterSlotId = "StandardSquad", EncounterIntensity = 2 },
		{ RoomId = "boss", EncounterSlotId = "BossEncounter", EncounterIntensity = 3 },
	},
}
local result = readback.build(plan)
check(result.SchemaVersion == "P06-COMPOSITION-READBACK-v3", "schema version drift")
check(
	result.OriginalUnitCount == 4 and result.AppliedUnitCount == 5 and result.UnitCountDelta == 1,
	"aggregate totals drift"
)
check(result.EncounterCount == 3 and result.ModifiedEncounterCount == 1, "encounter totals drift")
check(result.RecordByRoomId.combat == result.Records[2], "cached room lookup drift")
local combat = result.RecordByRoomId.combat
check(combat.ModifierId == "dense" and combat.SelectedWaveIdentity == "wave|combat|1", "record diagnostics drift")
check(combat.MinimumRetainedUnits == 1, "minimum-retained-unit diagnostics drift")
check(combat.SelectedUnitGroupIndex == 1, "selected authored unit-group index drift")
check(combat.SelectedArchetypeId == "walker", "selected authored archetype drift")
check(combat.SpawnSourceId == "AuthoredWave" and combat.RewardSourceId == "Elite", "content source diagnostics drift")
check(#combat.WaveDiagnostics == 1, "per-wave diagnostics cardinality drift")
check(
	combat.WaveDiagnostics[1].OriginalUnitCount == 3
		and combat.WaveDiagnostics[1].AppliedUnitCount == 4
		and combat.WaveDiagnostics[1].UnitCountDelta == 1,
	"per-wave count diagnostics drift"
)
check(combat.WaveDiagnostics[1].WaveIdentity == "wave|combat|1", "per-wave identity drift")
check(result.UnitCountsByArchetypeId.walker.UnitCountDelta == 1, "archetype aggregation drift")
check(result.HasSecretBranch and result.HasOptionalObjective, "variation presence drift")
check(
	string.find(result.CompositionIdentity, "roomPlan=room-plan%7C17", 1, true) ~= nil,
	"central identity escaping drift"
)
check(readback.recordForRoom(result, "combat") == result.Records[2], "room helper drift")
check(table.isfrozen(combat.WaveDiagnostics) and table.isfrozen(combat.WaveDiagnostics[1]), "wave diagnostics must be immutable")

local started = os.clock()
for _ = 1, 100 do
	readback.build(plan)
end
local elapsedMs = (os.clock() - started) * 1_000
check(elapsedMs <= 500, string.format("composition fixture budget exceeded: %.2fms", elapsedMs))

local originalCompose = composer.compose
local function mustRejectCompositionMutation(roomId: string, mutate: (any) -> (), message: string)
	composer.compose = function(seed: number, record: any): any
		local value = originalCompose(seed, record)
		if record.RoomId == roomId then
			local copy = table.clone(value)
			mutate(copy)
			return copy
		end
		return value
	end
	check(not pcall(function()
		readback.build(plan)
	end), message)
	composer.compose = originalCompose
end

mustRejectCompositionMutation("boss", function(value: any)
	value.UnitCountDelta = 1
end, "boss composition mutation must fail closed")
mustRejectCompositionMutation("entry", function(value: any)
	value.AppliedUnitCount = 1
end, "empty-room composition mutation must fail closed")
mustRejectCompositionMutation("combat", function(value: any)
	value.SpawnSourceId = "DifferentSource"
end, "spawn-source drift must fail closed")
mustRejectCompositionMutation("combat", function(value: any)
	value.RewardSourceId = "DifferentReward"
end, "reward-source drift must fail closed")

local originalView = view.build
view.build = function(): any
	return { Records = { { RoomId = "combat" }, { RoomId = "combat" }, { RoomId = "boss" } } }
end
check(not pcall(function()
	readback.build(plan)
end), "duplicate records must fail closed")
view.build = function(): any
	return { Records = { { RoomId = "combat" }, { RoomId = "boss" } } }
end
check(not pcall(function()
	readback.build(plan)
end), "cardinality mismatch must fail closed")
view.build = originalView

local originalPlanner = planner.plan
planner.plan = function(p: any): any
	return { VariationIdentity = "variation|" .. p.PlanIdentity .. "|none", RunModifier = nil }
end
local baseline = readback.build(plan)
check(
	baseline.RunModifierId == nil and baseline.HasSecretBranch == false and baseline.HasOptionalObjective == false,
	"baseline variation absence drift"
)
planner.plan = originalPlanner
check(table.isfrozen(result) and table.isfrozen(result.RecordByRoomId), "readback must remain immutable")
print("Run variation composition debug readback fixture passed")
