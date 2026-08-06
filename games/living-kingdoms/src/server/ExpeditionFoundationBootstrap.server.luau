--!strict

--[[
	VS-0110 live bootstrap for the account-safe inventory persistence boundary.
	This script deliberately exposes no remotes. It loads server-owned records on
	join; trusted server systems share the same InventoryLiveService instance.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")
local InventoryLiveService = require(Systems.InventoryLiveService)

local function loadPlayer(player: Player)
	local result = InventoryLiveService.loadPlayer(player.UserId, os.time())
	if not result.Accepted then
		warn(string.format("[AtlasPersistence] failed to load %s (%d): %s", player.Name, player.UserId, result.ReasonId))
		player:Kick("Your inventory could not be loaded safely. Please rejoin.")
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end
Players.PlayerAdded:Connect(loadPlayer)

game:BindToClose(function()
	InventoryLiveService.destroy()
end)

return nil
