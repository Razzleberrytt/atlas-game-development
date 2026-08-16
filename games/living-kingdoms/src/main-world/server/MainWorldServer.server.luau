--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.MainWorldBootstrapAllowlistConfig)
local MainWorldStaticSceneStabilizer = require(script.Parent:WaitForChild("MainWorldStaticSceneStabilizer"))

local stabilization = Config.StaticSceneStabilization
if stabilization.Enabled then
	local worldRoot = Workspace:WaitForChild(stabilization.WorldRootName)
	MainWorldStaticSceneStabilizer.stabilize(worldRoot, stabilization.StaticRootNames)
end

if not Config.RuntimeEnabled then
	return
end

-- Intentionally empty until the dedicated Main World project, lifecycle,
-- arrival/return semantics, and canonical owner adapters pass their gates.
error("Main World server runtime was enabled before bootstrap implementation")
