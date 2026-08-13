--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "run variation composition debug readback assertion failed", 2)
	end
end

local CONFIG_TOKEN = {}
local PLANNER_TOKEN = {}
local VIEW_TOKEN = {}
local COMPOSER_TOKEN = {}

local authoredByRoomId = {
	entry = { RoomId = "entry" },
	combat = { RoomId = "combat" },
}

local planner = {
	plan = function(roomPlan: any)
		return table.freeze({
			VariationIdentity = `variation|{roomPlan.PlanIdentity}`,
			RunModifier = table.freeze({ ModifierId = "dense", PlanIdentity = "modifier|dense" }),
		})
	end,
}

local view = {
	build = function(_roomPlan: any, _variationPlan: any)
		return table.freeze({
			Records = table.freeze({
				table.freeze({ RoomId = "entry" }),
				table.freeze({ RoomId = "combat" }),
			}),
		})
	end,
}

local composer = {
	compose = function(_seed: number, record: any, authored: any)
		assert(authored == authoredByRoomId[record.RoomId], "readback must resolve canonical authored content")
		local entry = record.RoomId == "entry"
		return table.freeze({
			NodeIndex = if entry then 1 else 2,
			RoomId = record.RoomId,
			EncounterSlotId = if entry then "None" else "StandardSquad",
			BaseIntensity = if entry then 0 else 2,
			EffectiveIntensity = if entry then 0 else 3,
			ModifierApplied = not entry,
			UnitCountDelta = if entry then 0 else 1,
			SelectedWaveIndex = if entry then nil else 1,
			OriginalUnitCount = if entry then 0 else 3,
			AppliedUnitCount = if entry then 0 else 4,
			CompositionIdentity = `composition|{record.RoomId}`,
		})
	end,
}

local readback =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationCompositionDebugReadback.luau"), {
		debugName = "RunVariationCompositionDebugReadback",
		environment = {
			script = {
				Parent = {
					Parent = { Config = { FirstDungeonContentConfig = CONFIG_TOKEN } },
					RunVariationPlanner = PLANNER_TOKEN,
					RunVariationEncounterView = VIEW_TOKEN,
					RunVariationAuthoredEncounterComposer = COMPOSER_TOKEN,
				},
			},
			require = function(token: unknown): any
				if token == CONFIG_TOKEN then
					return { Encounters = authoredByRoomId }
				elseif token == PLANNER_TOKEN then
					return planner
				elseif token == VIEW_TOKEN then
					return view
				elseif token == COMPOSER_TOKEN then
					return composer
				end
				error("unexpected debug readback dependency")
			end,
		},
		injectGlobals = true,
	})()

local roomPlan = { Seed = 17, PlanIdentity = "room-plan|17" }
local result = readback.build(roomPlan)

assert(#result.Records == 2, "readback must retain ordered composition records")
assert(result.RecordByRoomId.entry == result.Records[1], "room lookup must reference the stable ordered record")
assert(result.RecordByRoomId.combat == result.Records[2], "room lookup must resolve composed combat records")
assert(result.OriginalUnitCount == 3, "readback must aggregate original unit count")
assert(result.AppliedUnitCount == 4, "readback must aggregate applied unit count")
assert(result.UnitCountDelta == 1, "readback must expose the aggregate composition delta")
assert(
	string.find(result.CompositionIdentity, "composition|entry;composition|combat", 1, true) ~= nil,
	"readback identity must bind the complete ordered composition"
)

local repeated = readback.build(roomPlan)
assert(repeated.CompositionIdentity == result.CompositionIdentity, "same plan must reproduce readback identity")
assert(table.isfrozen(result), "readback must be immutable")
assert(table.isfrozen(result.RecordByRoomId), "room lookup must be immutable")

local duplicateView = view.build
view.build = function(_roomPlan: any, _variationPlan: any)
	return { Records = { { RoomId = "combat" }, { RoomId = "combat" } } }
end
local ok = pcall(function()
	readback.build(roomPlan)
end)
assert(not ok, "duplicate room identities must fail closed")
view.build = duplicateView

print("Run variation composition debug readback fixture passed")
