--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEPENDENCY_WAIT_SECONDS = 20

local Shared = ReplicatedStorage:WaitForChild("Shared", DEPENDENCY_WAIT_SECONDS)
assert(Shared ~= nil, "ReplicatedStorage.Shared did not become available before the Main World client timeout")
local Config = require(Shared.Config.MainWorldBootstrapAllowlistConfig)

if not Config.RuntimeEnabled then
	return
end

-- Intentionally empty until the dedicated Main World project and presentation
-- lifecycle have accepted source/build/Studio evidence.
error("Main World client runtime was enabled before bootstrap implementation")
