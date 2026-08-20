--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DEPENDENCY_WAIT_SECONDS = 20

local Shared = ReplicatedStorage:WaitForChild("Shared", DEPENDENCY_WAIT_SECONDS)
assert(Shared ~= nil, "ReplicatedStorage.Shared did not become available before the Main World server timeout")
local Config = require(Shared.Config.MainWorldBootstrapAllowlistConfig)
local stabilizerModule = script.Parent:WaitForChild("MainWorldStaticSceneStabilizer", DEPENDENCY_WAIT_SECONDS)
assert(
	stabilizerModule ~= nil,
	"MainWorldStaticSceneStabilizer did not become available before the Main World server timeout"
)
local MainWorldStaticSceneStabilizer = require(stabilizerModule)

local stabilization = Config.StaticSceneStabilization
if stabilization.Enabled then
	-- Bounded: stabilization is static-scene presentation, so a world root that
	-- never arrives should be reported rather than parking this script on a
	-- yield that no failure containment can interrupt.
	local worldRoot = Workspace:WaitForChild(stabilization.WorldRootName, DEPENDENCY_WAIT_SECONDS)
	if worldRoot == nil then
		warn(
			string.format(
				"[Living Kingdoms] Main World static scene stabilization skipped: %s was not ready",
				stabilization.WorldRootName
			)
		)
	else
		MainWorldStaticSceneStabilizer.stabilize(worldRoot, stabilization.StaticRootNames)
	end
end

if not Config.RuntimeEnabled then
	return
end

-- Intentionally empty until the dedicated Main World project, lifecycle,
-- arrival/return semantics, and canonical owner adapters pass their gates.
error("Main World server runtime was enabled before bootstrap implementation")
