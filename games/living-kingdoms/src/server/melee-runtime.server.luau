--!strict

-- MVP 0.1 live melee input mount. The client contributes only a bounded request
-- id and aim direction; MeleeCombatService retains every legality, targeting,
-- occlusion, cadence, health, death, and contribution decision on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeCombatService = require(script.Parent.Systems.MeleeCombatService)

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
assert(combatNetwork:IsA("Folder"), "CombatNetwork must be a Folder")

local existing = combatNetwork:FindFirstChild("MeleeIntent")
local meleeIntent: RemoteEvent
if existing == nil then
	meleeIntent = Instance.new("RemoteEvent")
	meleeIntent.Name = "MeleeIntent"
	meleeIntent.Parent = combatNetwork
else
	assert(existing:IsA("RemoteEvent"), "CombatNetwork.MeleeIntent must be a RemoteEvent")
	meleeIntent = existing
end

MeleeCombatService.start()
local connection = meleeIntent.OnServerEvent:Connect(function(player, requestId, aimDirection)
	MeleeCombatService.tryStrike(player, requestId, aimDirection)
end)

game:BindToClose(function()
	connection:Disconnect()
	MeleeCombatService.stop()
end)
