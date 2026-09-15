--!strict

-- Roblox adapter for the runtime-agnostic environmental composition kernel.
-- Keeping service access here lets Studio, Lune tests, and visualization tools all
-- execute the exact same deterministic placement equations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnvironmentModelPlacementConfig = require(ReplicatedStorage.Shared.Config.EnvironmentModelPlacementConfig)
local EnvironmentCompositionMath = require(ReplicatedStorage.Shared.Environment.EnvironmentCompositionMath)

local EnvironmentCompositionPlanner = {}

function EnvironmentCompositionPlanner.Plan()
	return EnvironmentCompositionMath.Plan(WorldFoundationConfig, EnvironmentModelPlacementConfig)
end

return table.freeze(EnvironmentCompositionPlanner)
