--!strict

--[[
	VS-0110 live bootstrap for the account-safe inventory persistence boundary.
	This script deliberately exposes no remotes. It loads server-owned records on
	join and releases cached state on shutdown; reward/equip requests remain wired
	through trusted server systems only.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")
local RobloxInventoryDataStoreAdapter = require(Systems.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(Systems.PlayerInventoryPersistenceService)

local store = RobloxInventoryDataStoreAdapter.new({
	DataStoreName = "AtlasPlayerInventoryV1",
	KeyPrefix = "atlas-prod",
	MaximumAttempts = 4,
	BaseRetryDelaySeconds = 0.5,
})
local persistence = PlayerInventoryPersistenceService.new(store)

local function loadPlayer(player: Player)
	local result = persistence:loadPlayer(player.UserId, os.time())
	if not result.Accepted then
		warn(string.format("[AtlasPersistence] failed to load %s (%d): %s", player.Name, player.UserId, result.ReasonId))
		player:Kick("Your inventory could not be loaded safely. Please rejoin.")
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end
Players.PlayerAdded:Connect(loadPlayer)

-- The current domain service persists each accepted mutation immediately, so
-- shutdown only clears cached authoritative copies. A later session-lock layer
-- should release leases here as part of the Studio/live integration gate.
game:BindToClose(function()
	persistence:destroy()
end)

return nil
