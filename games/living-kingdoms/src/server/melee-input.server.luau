--!strict

-- Application-scoped mount for the server-owned primary combat mode and the
-- narrow melee intent bridge. Enemy/life services remain the existing combat
-- authorities; this mount adds no second health, target, or progression owner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureMeleeNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("MeleeNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "MeleeNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "MeleeNetwork must be a Folder")
		network = existingNetwork
	end

	local existingIntent = network:FindFirstChild("StrikeIntent")
	if existingIntent == nil then
		local intent = Instance.new("RemoteEvent")
		intent.Name = "StrikeIntent"
		intent.Parent = network
	else
		assert(existingIntent:IsA("RemoteEvent"), "MeleeNetwork.StrikeIntent must be a RemoteEvent")
	end
end

-- Create the narrow transport before requiring the intent service, whose module
-- resolves these replicated objects at load time.
ensureMeleeNetwork()

local MeleeCombatService = require(script.Parent.Systems.MeleeCombatService)
local MeleeIntentService = require(script.Parent.Systems.MeleeIntentService)
local PrimaryCombatModeService = require(script.Parent.Systems.PrimaryCombatModeService)

PrimaryCombatModeService.start()
MeleeCombatService.start()
MeleeIntentService.start()

game:BindToClose(function()
	MeleeIntentService.stop()
	MeleeCombatService.stop()
	PrimaryCombatModeService.stop()
end)

print("[Living Kingdoms] Melee input runtime mounted")
