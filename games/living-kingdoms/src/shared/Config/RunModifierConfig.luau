--!strict

--[[
	Patch 0.6 bounded run-modifier content.

	Modifiers operate only on authored expedition encounter intensity carried by
	the deterministic room plan. They do not own spawning, enemy health/damage,
	rewards, progression, or combat resolution. Runtime systems may consume the
	planned overrides through their existing encounter/spawn authority later.
]]

local RunModifierConfig = {
	Version = "P06-RUN-MODIFIERS-v1",
	AppearanceChancePercent = 70,
	MinimumEncounterIntensity = 1,
	MaximumEncounterIntensity = 3,
	Modifiers = table.freeze({
		table.freeze({
			Id = "dense-contacts",
			Version = "1.0.0",
			DisplayName = "Dense Contacts",
			Description = "Standard combat rooms carry one additional authored pressure tier.",
			EncounterIntensityDelta = 1,
			EligibleEncounterSlots = table.freeze({
				StandardSquad = true,
			}),
		}),
		table.freeze({
			Id = "quiet-approach",
			Version = "1.0.0",
			DisplayName = "Quiet Approach",
			Description = "Patrol and standard encounters carry one less authored pressure tier.",
			EncounterIntensityDelta = -1,
			EligibleEncounterSlots = table.freeze({
				LightPatrol = true,
				StandardSquad = true,
			}),
		}),
		table.freeze({
			Id = "elite-pressure",
			Version = "1.0.0",
			DisplayName = "Elite Pressure",
			Description = "The authored elite encounter carries one additional pressure tier.",
			EncounterIntensityDelta = 1,
			EligibleEncounterSlots = table.freeze({
				EliteGuard = true,
			}),
		}),
	}),
}

assert(
	RunModifierConfig.AppearanceChancePercent >= 1 and RunModifierConfig.AppearanceChancePercent <= 100,
	"run modifier chance must be a bounded integer percentage"
)
assert(RunModifierConfig.AppearanceChancePercent % 1 == 0, "run modifier chance must be an integer")
assert(
	RunModifierConfig.MinimumEncounterIntensity >= 1
		and RunModifierConfig.MaximumEncounterIntensity >= RunModifierConfig.MinimumEncounterIntensity,
	"run modifier encounter intensity bounds are invalid"
)
assert(#RunModifierConfig.Modifiers == 3, "Patch 0.6 requires a small curated run-modifier pool")

local seenIds = {}
for _, modifier in RunModifierConfig.Modifiers do
	assert(type(modifier.Id) == "string" and modifier.Id ~= "", "run modifier id is required")
	assert(type(modifier.Version) == "string" and modifier.Version ~= "", "run modifier version is required")
	assert(seenIds[modifier.Id] == nil, "run modifier ids must be unique")
	seenIds[modifier.Id] = true
	assert(
		modifier.EncounterIntensityDelta == -1 or modifier.EncounterIntensityDelta == 1,
		"run modifier intensity delta must stay bounded to one tier"
	)
	assert(next(modifier.EligibleEncounterSlots) ~= nil, "run modifier requires at least one eligible encounter slot")
end

return table.freeze(RunModifierConfig)
