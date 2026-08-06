--!strict

-- Live inventory bootstrap. Loads only after atomic lease acquisition, renews
-- active leases, and releases them when players leave or the server closes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")
local InventoryLiveService = require(Systems.InventoryLiveService)

local RENEW_INTERVAL_SECONDS = 30
local accumulatedSeconds = 0

local function loadPlayer(player: Player)
	local result = InventoryLiveService.loadPlayer(player.UserId, os.time())
	if not result.Accepted then
		warn(string.format("[AtlasPersistence] failed to load %s (%d): %s", player.Name, player.UserId, result.ReasonId))
		player:Kick("Your inventory is active on another server or could not be loaded safely. Please rejoin.")
	end
end

for _, player in Players:GetPlayers() do task.spawn(loadPlayer, player) end
Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
	local released = InventoryLiveService.releasePlayer(player.UserId)
	if released.Accepted ~= true and released.ReasonId ~= "LeaseNotOwned" then
		warn(string.format("[AtlasPersistence] lease release failed for %d: %s", player.UserId, released.ReasonId))
	end
end)

local renewalConnection = RunService.Heartbeat:Connect(function(deltaTime)
	accumulatedSeconds += deltaTime
	if accumulatedSeconds < RENEW_INTERVAL_SECONDS then return end
	accumulatedSeconds = 0
	local nowUnix = os.time()
	for _, player in Players:GetPlayers() do
		local renewed = InventoryLiveService.renewPlayer(player.UserId, nowUnix)
		if renewed.Accepted ~= true then
			warn(string.format("[AtlasPersistence] lease renewal failed for %d: %s", player.UserId, renewed.ReasonId))
			player:Kick("Your inventory session could no longer be protected. Please rejoin.")
		end
	end
end)

game:BindToClose(function()
	renewalConnection:Disconnect()
	InventoryLiveService.destroy()
end)

return nil
