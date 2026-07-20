--!strict

-- RPG-0102 server-only lifecycle adapter for the pure RunBuildStateStore.

local Players = game:GetService("Players")

local RunBuildStateStore = require(script.Parent.RunBuildStateStore)

local RunBuildService = {}

local store = RunBuildStateStore.new()
local started = false
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function operativeId(player: Player): string
	return tostring(player.UserId)
end

local function register(player: Player)
	store:registerOperative(operativeId(player))
end

function RunBuildService.start()
	if started then
		return
	end
	started = true
	store:startOperation()
	for _, player in Players:GetPlayers() do
		register(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(register)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		store:disconnectOperative(operativeId(player))
	end)
end

function RunBuildService.resetOperation()
	if not started then
		return
	end
	store:startOperation()
	for _, player in Players:GetPlayers() do
		register(player)
	end
end

function RunBuildService.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	store:stopOperation()
end

function RunBuildService.readOperationGeneration(): number
	return store:readOperationGeneration()
end

function RunBuildService.readSquadUpgradeStacks(): RunBuildStateStore.UpgradeStacks
	return store:readUpgradeStacks()
end

function RunBuildService.readSafeSnapshot(player: Player): any?
	return store:readSafeSnapshot(operativeId(player))
end

function RunBuildService.commitSquadUpgradeStacks(
	operationGeneration: number,
	requestId: string,
	upgradeStacks: RunBuildStateStore.UpgradeStacks
): (boolean, string?)
	return store:commitUpgradeStacks(operationGeneration, requestId, upgradeStacks)
end

return table.freeze(RunBuildService)
