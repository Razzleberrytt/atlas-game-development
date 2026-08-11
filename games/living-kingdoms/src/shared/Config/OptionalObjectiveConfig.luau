--!strict

--[[
	Patch 0.6 bounded optional-objective content.

	Objectives are authored descriptors only. They do not grant rewards, spawn
	enemies, alter progression, or mutate combat. A planner may attach at most one
	objective to an eligible room in a run.
]]

local OptionalObjectiveConfig = {
	Version = "P06-OPTIONAL-OBJECTIVES-v1",
	AppearanceChancePercent = 65,
	MinimumHostDepth = 2,
	MaximumHostDepth = 5,
	Objectives = table.freeze({
		table.freeze({
			Id = "recover-field-cache",
			Version = "1.0.0",
			DisplayName = "Recover the Field Cache",
			ObjectiveType = "Interact",
			RequiredProgress = 1,
			EligibleHostRoles = table.freeze({
				Traversal = true,
			}),
		}),
		table.freeze({
			Id = "stabilize-signal-relay",
			Version = "1.0.0",
			DisplayName = "Stabilize the Signal Relay",
			ObjectiveType = "Interact",
			RequiredProgress = 2,
			EligibleHostRoles = table.freeze({
				Traversal = true,
				Combat = true,
			}),
		}),
		table.freeze({
			Id = "clear-infested-nest",
			Version = "1.0.0",
			DisplayName = "Clear the Infested Nest",
			ObjectiveType = "Elimination",
			RequiredProgress = 3,
			EligibleHostRoles = table.freeze({
				Combat = true,
			}),
		}),
	}),
}

assert(
	OptionalObjectiveConfig.AppearanceChancePercent >= 1 and OptionalObjectiveConfig.AppearanceChancePercent <= 100,
	"optional objective chance must be a bounded integer percentage"
)
assert(OptionalObjectiveConfig.AppearanceChancePercent % 1 == 0, "optional objective chance must be an integer")
assert(
	OptionalObjectiveConfig.MinimumHostDepth >= 1
		and OptionalObjectiveConfig.MaximumHostDepth >= OptionalObjectiveConfig.MinimumHostDepth,
	"optional objective host depth bounds are invalid"
)
assert(#OptionalObjectiveConfig.Objectives == 3, "Patch 0.6 requires a small curated optional-objective pool")

local seenIds = {}
for _, objective in OptionalObjectiveConfig.Objectives do
	assert(type(objective.Id) == "string" and objective.Id ~= "", "optional objective id is required")
	assert(type(objective.Version) == "string" and objective.Version ~= "", "optional objective version is required")
	assert(seenIds[objective.Id] == nil, "optional objective ids must be unique")
	seenIds[objective.Id] = true
	assert(
		objective.ObjectiveType == "Interact" or objective.ObjectiveType == "Elimination",
		"optional objective type is unsupported"
	)
	assert(
		objective.RequiredProgress >= 1 and objective.RequiredProgress % 1 == 0 and objective.RequiredProgress <= 5,
		"optional objective progress target must remain small and bounded"
	)
	assert(next(objective.EligibleHostRoles) ~= nil, "optional objective requires at least one eligible host role")
end

return table.freeze(OptionalObjectiveConfig)
