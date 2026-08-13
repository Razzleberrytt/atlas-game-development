--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RunVariationEncounterView assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string): any
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local View = loadModule(
	"games/living-kingdoms/src/shared/Expeditions/RunVariationEncounterView.luau",
	"RunVariationEncounterView"
)

local roomPlan = {
	Seed = 321,
	PlanIdentity = "room-plan:321",
	Nodes = {
		{ Index = 1, RoomId = "entry", Role = "Entry", EncounterSlotId = "none", EncounterIntensity = 0 },
		{ Index = 2, RoomId = "combat-a", Role = "Combat", EncounterSlotId = "standard", EncounterIntensity = 2 },
		{ Index = 3, RoomId = "combat-b", Role = "Combat", EncounterSlotId = "standard", EncounterIntensity = 3 },
	},
}

local variationPlan = {
	Seed = 321,
	RoomPlanIdentity = "room-plan:321",
	VariationIdentity = "variation:321",
	RunModifier = {
		IntensityOverrides = {
			{
				NodeIndex = 3,
				RoomId = "combat-b",
				EncounterSlotId = "standard",
				BaseIntensity = 3,
				ModifiedIntensity = 4,
			},
		},
	},
}

local originalNodeIntensity = roomPlan.Nodes[3].EncounterIntensity
local originalOverrideIntensity = variationPlan.RunModifier.IntensityOverrides[1].ModifiedIntensity
local view = View.build(roomPlan, variationPlan)

check(view.Seed == 321)
check(view.RoomPlanIdentity == roomPlan.PlanIdentity)
check(view.VariationIdentity == variationPlan.VariationIdentity)
check(#view.Records == 3)
check(view.Records[2].BaseIntensity == 2 and view.Records[2].EffectiveIntensity == 2)
check(view.Records[2].ModifierApplied == false)
check(view.Records[3].BaseIntensity == 3 and view.Records[3].EffectiveIntensity == 4)
check(view.Records[3].ModifierApplied == true)
check(roomPlan.Nodes[3].EncounterIntensity == originalNodeIntensity, "view must not mutate canonical room intensity")
check(
	variationPlan.RunModifier.IntensityOverrides[1].ModifiedIntensity == originalOverrideIntensity,
	"view must not mutate modifier overrides"
)
check(table.isfrozen(view) == true)
check(table.isfrozen(view.Records) == true)
check(table.isfrozen(view.Records[3]) == true)

local noModifierView = View.build(roomPlan, {
	Seed = 321,
	RoomPlanIdentity = "room-plan:321",
	VariationIdentity = "variation:none",
	RunModifier = nil,
})
check(noModifierView.Records[3].EffectiveIntensity == 3)
check(noModifierView.Records[3].ModifierApplied == false)

local okSeed = pcall(function()
	View.build(roomPlan, {
		Seed = 999,
		RoomPlanIdentity = "room-plan:321",
		VariationIdentity = "variation:bad-seed",
		RunModifier = nil,
	})
end)
check(okSeed == false, "mismatched variation seed must fail closed")

local okIdentity = pcall(function()
	View.build(roomPlan, {
		Seed = 321,
		RoomPlanIdentity = "room-plan:other",
		VariationIdentity = "variation:bad-room",
		RunModifier = nil,
	})
end)
check(okIdentity == false, "mismatched room identity must fail closed")

local okOverride = pcall(function()
	View.build(roomPlan, {
		Seed = 321,
		RoomPlanIdentity = "room-plan:321",
		VariationIdentity = "variation:bad-override",
		RunModifier = {
			IntensityOverrides = {
				{
					NodeIndex = 3,
					RoomId = "wrong-room",
					EncounterSlotId = "standard",
					BaseIntensity = 3,
					ModifiedIntensity = 4,
				},
			},
		},
	})
end)
check(okOverride == false, "drifted modifier override must fail closed")

print("Run variation encounter view fixture passed")
