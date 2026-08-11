--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.MainWorldBootstrapAllowlistConfig)

if not Config.RuntimeEnabled then
	return
end

-- Intentionally empty until the dedicated Main World project and presentation
-- lifecycle have accepted source/build/Studio evidence.
error("Main World client runtime was enabled before bootstrap implementation")
