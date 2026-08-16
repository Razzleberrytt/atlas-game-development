--!strict

-- Studio-only inspection bridge for the canonical read-only gameplay snapshot.
-- It creates no client remote, scheduler, or gameplay authority path.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GameplayObservabilityService = require(script.Parent.Systems.GameplayObservabilityService)

if RunService:IsStudio() then
	local existing = ServerStorage:FindFirstChild("LivingKingdomsGameplayObservability")
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "LivingKingdomsGameplayObservability"
	folder.Parent = ServerStorage

	local readSnapshot = Instance.new("BindableFunction")
	readSnapshot.Name = "ReadSnapshot"
	readSnapshot.OnInvoke = GameplayObservabilityService.readSnapshot
	readSnapshot.Parent = folder
end
