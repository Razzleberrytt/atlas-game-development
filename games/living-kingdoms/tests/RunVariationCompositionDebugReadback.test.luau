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
	entry = { Waves = {} },
	combat = {
		Waves = { { Units = { { ArchetypeId = "walker", Count = 2 }, { ArchetypeId = "spitter", Count = 1 } } } },
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
		return { Records = { { RoomId = "entry" }, { RoomId = "combat" } } }
	end,
}
local composer = {
	compose = function(_seed: number, record: any): any
		local combat = record.RoomId == "combat"
		return {
			NodeIndex = if combat then 2 else 1,
			RoomId = record.RoomId,
			EncounterSlotId = if combat then "StandardSquad" else "None",
			BaseIntensity = if combat then 2 else 0,
			EffectiveIntensity = if combat then 3 else 0,
			ModifierApplied = combat,
			UnitCountDelta = if combat then 1 else 0,
			SelectedWaveIndex = if combat then 1 else nil,
			OriginalUnitCount = if combat then 3 else 0,
			AppliedUnitCount = if combat then 4 else 0,
			CompositionIdentity = "composition|" .. record.RoomId,
			Waves = if combat
				then {
					{
						Units = { { ArchetypeId = "walker", Count = 3 }, { ArchetypeId = "spitter", Count = 1 } },
						VariationApplication = { ApplicationIdentity = "wave|combat|1" },
					},
				}
				else {},
		}
	end,
}
local schemaSource = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationDebugSchema.luau")
local schema = luau.load(schemaSource, { injectGlobals = true })()
local readbackSource = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationCompositionDebugReadback.luau")
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
	},
}
local result = readback.build(plan)
check(result.SchemaVersion == "P06-COMPOSITION-READBACK-v3", "schema version drift")
check(
	result.OriginalUnitCount == 3 and result.AppliedUnitCount == 4 and result.UnitCountDelta == 1,
	"aggregate totals drift"
)
check(result.EncounterCount == 2 and result.ModifiedEncounterCount == 1, "encounter totals drift")
check(result.RecordByRoomId.combat == result.Records[2], "cached room lookup drift")
check(
	result.Records[2].ModifierId == "dense" and result.Records[2].SelectedWaveIdentity == "wave|combat|1",
	"record diagnostics drift"
)
check(result.UnitCountsByArchetypeId.walker.UnitCountDelta == 1, "archetype aggregation drift")
check(result.HasSecretBranch and result.HasOptionalObjective, "variation presence drift")
check(
	string.find(result.CompositionIdentity, "roomPlan=room-plan%7C17", 1, true) ~= nil,
	"central identity escaping drift"
)
check(readback.recordForRoom(result, "combat") == result.Records[2], "room helper drift")

local started = os.clock()
for _ = 1, 100 do
	readback.build(plan)
end
local elapsedMs = (os.clock() - started) * 1_000
check(elapsedMs <= 500, string.format("composition fixture budget exceeded: %.2fms", elapsedMs))

local originalView = view.build
view.build = function(): any
	return { Records = { { RoomId = "combat" }, { RoomId = "combat" } } }
end
check(not pcall(function()
	readback.build(plan)
end), "duplicate records must fail closed")
view.build = function(): any
	return { Records = { { RoomId = "combat" } } }
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
