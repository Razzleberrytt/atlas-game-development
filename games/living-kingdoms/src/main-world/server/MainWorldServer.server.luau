--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.MainWorldBootstrapAllowlistConfig)

if not Config.RuntimeEnabled then
	return
end

-- Intentionally empty until the dedicated Main World project, lifecycle,
-- arrival/return semantics, and canonical owner adapters pass their gates.
error("Main World server runtime was enabled before bootstrap implementation")
